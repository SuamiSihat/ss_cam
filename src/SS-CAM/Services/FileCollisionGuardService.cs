using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Text;
using System.Timers;
using Newtonsoft.Json;

namespace SS_CAM.Services
{
    /// <summary>
    /// Metadata descriptor for a project/file editing lease.
    /// Serialized to &lt;projectPath&gt;/.editor_lock.json.
    /// </summary>
    public class ProjectLockInfo
    {
        public string ProjectId { get; set; }
        public string ProjectPath { get; set; }
        public string Editor { get; set; }
        public string EditorName { get; set; }
        public string Machine { get; set; }
        public string Platform { get; set; }
        public DateTime LockedAt { get; set; }
        public DateTime HeartbeatAt { get; set; }
        public int TtlSeconds { get; set; }
        public List<string> ActiveFiles { get; set; }

        public ProjectLockInfo()
        {
            ProjectId = string.Empty;
            ProjectPath = string.Empty;
            Editor = Environment.UserName;
            EditorName = Environment.UserName;
            Machine = Environment.MachineName;
            Platform = "Windows Desktop";
            LockedAt = DateTime.Now;
            HeartbeatAt = DateTime.Now;
            TtlSeconds = 300; // 5 minute lease
            ActiveFiles = new List<string>();
        }

        [JsonIgnore]
        public bool IsExpired
        {
            get
            {
                TimeSpan elapsed = DateTime.Now - HeartbeatAt;
                return elapsed.TotalSeconds > (TtlSeconds > 0 ? TtlSeconds : 300);
            }
        }

        [JsonIgnore]
        public bool IsOwnedByCurrentWorkstation
        {
            get
            {
                bool machineMatch = string.Equals(Machine, Environment.MachineName, StringComparison.OrdinalIgnoreCase);
                bool userMatch = string.Equals(Editor, Environment.UserName, StringComparison.OrdinalIgnoreCase);
                return machineMatch && userMatch;
            }
        }

        [JsonIgnore]
        public string FormattedDuration
        {
            get
            {
                TimeSpan duration = DateTime.Now - LockedAt;
                if (duration.TotalMinutes < 1) return "just now";
                if (duration.TotalMinutes < 60) return string.Format("{0:0}m ago", duration.TotalMinutes);
                return string.Format("{0:0}h {1:0}m ago", duration.TotalHours, duration.Minutes);
            }
        }
    }

    public class LockCheckResult
    {
        public bool IsLocked { get; set; }
        public bool IsConflict { get; set; }
        public ProjectLockInfo LockInfo { get; set; }
        public string Message { get; set; }

        public LockCheckResult(bool isLocked, bool isConflict, ProjectLockInfo lockInfo, string message)
        {
            IsLocked = isLocked;
            IsConflict = isConflict;
            LockInfo = lockInfo;
            Message = message;
        }
    }

    /// <summary>
    /// Service managing real-time project lock leases and multi-designer collision prevention.
    /// Writes and monitors .editor_lock.json in project vaults with automatic TTL heartbeat expiration.
    /// Compatible with C# 5.0 (.NET Framework 4.8).
    /// </summary>
    public class FileCollisionGuardService : IDisposable
    {
        private static FileCollisionGuardService _instance;
        private static readonly object _syncLock = new object();

        public static FileCollisionGuardService Instance
        {
            get
            {
                if (_instance == null)
                {
                    lock (_syncLock)
                    {
                        if (_instance == null)
                        {
                            _instance = new FileCollisionGuardService();
                        }
                    }
                }
                return _instance;
            }
        }

        public const string LockFileName = ".editor_lock.json";
        private readonly Timer _heartbeatTimer;
        private readonly object _lockStateLock = new object();
        private string _activeLockedProjectPath = null;
        private bool _isDisposed = false;

        public event EventHandler<ProjectLockInfo> LockAcquired;
        public event EventHandler<string> LockReleased;
        public event EventHandler<ProjectLockInfo> LockConflictDetected;

        public FileCollisionGuardService()
        {
            // Heartbeat timer runs every 60 seconds to renew lease
            _heartbeatTimer = new Timer(60000);
            _heartbeatTimer.AutoReset = true;
            _heartbeatTimer.Elapsed += OnHeartbeatTimerElapsed;
        }

        /// <summary>
        /// Gets the full path to the .editor_lock.json file in a project folder.
        /// </summary>
        public static string GetLockFilePath(string projectPath)
        {
            if (string.IsNullOrWhiteSpace(projectPath)) return string.Empty;
            return Path.Combine(projectPath, LockFileName);
        }

        /// <summary>
        /// Reads current lock info from disk if present.
        /// </summary>
        public ProjectLockInfo GetLock(string projectPath)
        {
            if (string.IsNullOrWhiteSpace(projectPath) || !Directory.Exists(projectPath)) return null;

            string lockPath = GetLockFilePath(projectPath);
            if (!File.Exists(lockPath)) return null;

            try
            {
                string json = File.ReadAllText(lockPath, Encoding.UTF8);
                if (string.IsNullOrWhiteSpace(json)) return null;
                return JsonConvert.DeserializeObject<ProjectLockInfo>(json);
            }
            catch (Exception ex)
            {
                Debug.WriteLine("[FileCollisionGuardService] GetLock error: " + ex.Message);
                return null;
            }
        }

        /// <summary>
        /// Checks if a project is locked by another designer/workstation.
        /// </summary>
        public LockCheckResult CheckLock(string projectPath)
        {
            ProjectLockInfo currentLock = GetLock(projectPath);
            if (currentLock == null)
            {
                return new LockCheckResult(false, false, null, "Project is unlocked.");
            }

            if (currentLock.IsExpired)
            {
                return new LockCheckResult(false, false, currentLock, "Previous editing lease has expired.");
            }

            if (currentLock.IsOwnedByCurrentWorkstation)
            {
                return new LockCheckResult(true, false, currentLock, "Project is locked by this workstation.");
            }

            string conflictMsg = string.Format(
                "Project is actively being edited by {0} on machine '{1}' ({2}).",
                !string.IsNullOrWhiteSpace(currentLock.EditorName) ? currentLock.EditorName : currentLock.Editor,
                currentLock.Machine,
                currentLock.FormattedDuration);

            return new LockCheckResult(true, true, currentLock, conflictMsg);
        }

        /// <summary>
        /// Attempts to acquire an editing lock lease on a project folder.
        /// </summary>
        public bool AcquireLock(string projectPath, string projectId, string editor, string editorName, string activeFile = null)
        {
            if (string.IsNullOrWhiteSpace(projectPath) || !Directory.Exists(projectPath)) return false;

            lock (_lockStateLock)
            {
                LockCheckResult check = CheckLock(projectPath);
                if (check.IsConflict)
                {
                    // Conflict detected: Another designer holds an active lease
                    if (LockConflictDetected != null)
                    {
                        LockConflictDetected(this, check.LockInfo);
                    }
                    return false;
                }

                // If currently holding another project lock, release it first
                if (!string.IsNullOrWhiteSpace(_activeLockedProjectPath) &&
                    !string.Equals(_activeLockedProjectPath, projectPath, StringComparison.OrdinalIgnoreCase))
                {
                    ReleaseLockInternal(_activeLockedProjectPath, false);
                }

                ProjectLockInfo newLock = new ProjectLockInfo
                {
                    ProjectId = !string.IsNullOrWhiteSpace(projectId) ? projectId : Path.GetFileName(projectPath),
                    ProjectPath = projectPath,
                    Editor = !string.IsNullOrWhiteSpace(editor) ? editor : Environment.UserName,
                    EditorName = !string.IsNullOrWhiteSpace(editorName) ? editorName : Environment.UserName,
                    Machine = Environment.MachineName,
                    Platform = "Windows Desktop",
                    LockedAt = DateTime.Now,
                    HeartbeatAt = DateTime.Now,
                    TtlSeconds = 300
                };

                if (!string.IsNullOrWhiteSpace(activeFile))
                {
                    newLock.ActiveFiles.Add(activeFile);
                }

                try
                {
                    string lockPath = GetLockFilePath(projectPath);
                    string json = JsonConvert.SerializeObject(newLock, Formatting.Indented);
                    File.WriteAllText(lockPath, json, Encoding.UTF8);

                    _activeLockedProjectPath = projectPath;
                    _heartbeatTimer.Start();

                    if (LockAcquired != null)
                    {
                        LockAcquired(this, newLock);
                    }

                    Debug.WriteLine(string.Format("[FileCollisionGuardService] Lock acquired for project '{0}' by {1}", newLock.ProjectId, newLock.Editor));
                    return true;
                }
                catch (Exception ex)
                {
                    Debug.WriteLine("[FileCollisionGuardService] AcquireLock failed: " + ex.Message);
                    return false;
                }
            }
        }

        /// <summary>
        /// Renews heartbeat timestamp on active lock.
        /// </summary>
        public bool RenewHeartbeat(string projectPath)
        {
            if (string.IsNullOrWhiteSpace(projectPath) || !Directory.Exists(projectPath)) return false;

            lock (_lockStateLock)
            {
                ProjectLockInfo current = GetLock(projectPath);
                if (current == null || !current.IsOwnedByCurrentWorkstation) return false;

                current.HeartbeatAt = DateTime.Now;
                try
                {
                    string lockPath = GetLockFilePath(projectPath);
                    string json = JsonConvert.SerializeObject(current, Formatting.Indented);
                    File.WriteAllText(lockPath, json, Encoding.UTF8);
                    return true;
                }
                catch (Exception ex)
                {
                    Debug.WriteLine("[FileCollisionGuardService] RenewHeartbeat error: " + ex.Message);
                    return false;
                }
            }
        }

        /// <summary>
        /// Releases the editing lock on a project folder.
        /// </summary>
        public bool ReleaseLock(string projectPath, bool force = false)
        {
            lock (_lockStateLock)
            {
                return ReleaseLockInternal(projectPath, force);
            }
        }

        private bool ReleaseLockInternal(string projectPath, bool force)
        {
            if (string.IsNullOrWhiteSpace(projectPath)) return false;

            string lockPath = GetLockFilePath(projectPath);
            if (!File.Exists(lockPath))
            {
                if (string.Equals(_activeLockedProjectPath, projectPath, StringComparison.OrdinalIgnoreCase))
                {
                    _activeLockedProjectPath = null;
                    _heartbeatTimer.Stop();
                }
                return true;
            }

            try
            {
                ProjectLockInfo current = GetLock(projectPath);
                if (current != null && !current.IsOwnedByCurrentWorkstation && !force && !current.IsExpired)
                {
                    Debug.WriteLine("[FileCollisionGuardService] Cannot release lock owned by another station without force.");
                    return false;
                }

                File.Delete(lockPath);

                if (string.Equals(_activeLockedProjectPath, projectPath, StringComparison.OrdinalIgnoreCase))
                {
                    _activeLockedProjectPath = null;
                    _heartbeatTimer.Stop();
                }

                if (LockReleased != null)
                {
                    LockReleased(this, projectPath);
                }

                Debug.WriteLine("[FileCollisionGuardService] Lock released for project: " + projectPath);
                return true;
            }
            catch (Exception ex)
            {
                Debug.WriteLine("[FileCollisionGuardService] ReleaseLock error: " + ex.Message);
                return false;
            }
        }

        /// <summary>
        /// Forcefully steals or takes over a lock when a team member is away or has an unreleased session.
        /// </summary>
        public bool TakeoverLock(string projectPath, string projectId, string editor, string editorName)
        {
            ReleaseLock(projectPath, true);
            return AcquireLock(projectPath, projectId, editor, editorName);
        }

        private void OnHeartbeatTimerElapsed(object sender, ElapsedEventArgs e)
        {
            if (_isDisposed) return;
            string targetPath = null;
            lock (_lockStateLock)
            {
                targetPath = _activeLockedProjectPath;
            }

            if (!string.IsNullOrWhiteSpace(targetPath))
            {
                RenewHeartbeat(targetPath);
            }
        }

        public void Dispose()
        {
            _isDisposed = true;
            if (_heartbeatTimer != null)
            {
                _heartbeatTimer.Stop();
                _heartbeatTimer.Dispose();
            }

            if (!string.IsNullOrWhiteSpace(_activeLockedProjectPath))
            {
                ReleaseLock(_activeLockedProjectPath, false);
            }
        }
    }
}
