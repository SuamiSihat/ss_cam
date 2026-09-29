using System;
using System.ComponentModel;
using System.IO;

namespace SS_CAM.Models
{
    /// <summary>
    /// Presets supported by the Transcoder Bridge.
    /// </summary>
    public enum TranscodePreset
    {
        WebP_Image,
        Avif_Image,
        WebM_Video,
        Social_Gif_10s,
        Mp4_Compress
    }

    /// <summary>
    /// Operational status of a transcode job in the queue.
    /// </summary>
    public enum TranscodeStatus
    {
        Queued,
        Processing,
        Completed,
        Failed,
        Cancelled
    }

    /// <summary>
    /// Represents a single asset transcode job in the Transcoder Bridge queue.
    /// Supports property change notification for real-time UI data-binding.
    /// </summary>
    public class TranscodeJob : INotifyPropertyChanged
    {
        public event PropertyChangedEventHandler PropertyChanged;

        private string _id;
        private string _sourceFilePath;
        private string _outputFilePath;
        private TranscodePreset _preset;
        private string _presetName;
        private TranscodeStatus _status;
        private int _progressPercent;
        private string _statusMessage;
        private long _sourceSizeBytes;
        private long _outputSizeBytes;
        private string _errorMessage;
        private DateTime _createdAt;
        private DateTime? _completedAt;
        private TimeSpan _duration;

        public string Id
        {
            get { return _id; }
            set { _id = value; OnPropertyChanged("Id"); }
        }

        public string SourceFilePath
        {
            get { return _sourceFilePath; }
            set
            {
                _sourceFilePath = value;
                OnPropertyChanged("SourceFilePath");
                OnPropertyChanged("FileName");
                OnPropertyChanged("SourceExtension");
            }
        }

        public string OutputFilePath
        {
            get { return _outputFilePath; }
            set
            {
                _outputFilePath = value;
                OnPropertyChanged("OutputFilePath");
                OnPropertyChanged("OutputFileName");
            }
        }

        public TranscodePreset Preset
        {
            get { return _preset; }
            set { _preset = value; OnPropertyChanged("Preset"); }
        }

        public string PresetName
        {
            get { return _presetName; }
            set { _presetName = value; OnPropertyChanged("PresetName"); }
        }

        public TranscodeStatus Status
        {
            get { return _status; }
            set
            {
                _status = value;
                OnPropertyChanged("Status");
                OnPropertyChanged("StatusDisplay");
                OnPropertyChanged("IsCompletedOrFailed");
            }
        }

        public int ProgressPercent
        {
            get { return _progressPercent; }
            set { _progressPercent = value; OnPropertyChanged("ProgressPercent"); }
        }

        public string StatusMessage
        {
            get { return _statusMessage; }
            set { _statusMessage = value; OnPropertyChanged("StatusMessage"); }
        }

        public long SourceSizeBytes
        {
            get { return _sourceSizeBytes; }
            set
            {
                _sourceSizeBytes = value;
                OnPropertyChanged("SourceSizeBytes");
                OnPropertyChanged("SourceSizeFormatted");
            }
        }

        public long OutputSizeBytes
        {
            get { return _outputSizeBytes; }
            set
            {
                _outputSizeBytes = value;
                OnPropertyChanged("OutputSizeBytes");
                OnPropertyChanged("OutputSizeFormatted");
                OnPropertyChanged("SavingsFormatted");
            }
        }

        public string ErrorMessage
        {
            get { return _errorMessage; }
            set { _errorMessage = value; OnPropertyChanged("ErrorMessage"); }
        }

        public DateTime CreatedAt
        {
            get { return _createdAt; }
            set { _createdAt = value; OnPropertyChanged("CreatedAt"); }
        }

        public DateTime? CompletedAt
        {
            get { return _completedAt; }
            set { _completedAt = value; OnPropertyChanged("CompletedAt"); }
        }

        public TimeSpan Duration
        {
            get { return _duration; }
            set
            {
                _duration = value;
                OnPropertyChanged("Duration");
                OnPropertyChanged("DurationFormatted");
            }
        }

        // ─── Computed Display Properties ──────────────────────────────────────────

        public string FileName
        {
            get
            {
                if (string.IsNullOrEmpty(_sourceFilePath)) return "";
                try { return Path.GetFileName(_sourceFilePath); }
                catch (Exception ex)
                {
                    System.Diagnostics.Debug.WriteLine("[TranscodeJob] FileName: " + ex.Message);
                    return _sourceFilePath;
                }
            }
        }

        public string OutputFileName
        {
            get
            {
                if (string.IsNullOrEmpty(_outputFilePath)) return "";
                try { return Path.GetFileName(_outputFilePath); }
                catch (Exception ex)
                {
                    System.Diagnostics.Debug.WriteLine("[TranscodeJob] OutputFileName: " + ex.Message);
                    return _outputFilePath;
                }
            }
        }

        public string SourceExtension
        {
            get
            {
                if (string.IsNullOrEmpty(_sourceFilePath)) return "";
                try { return Path.GetExtension(_sourceFilePath).ToUpperInvariant().TrimStart('.'); }
                catch (Exception ex)
                {
                    System.Diagnostics.Debug.WriteLine("[TranscodeJob] SourceExtension: " + ex.Message);
                    return "";
                }
            }
        }

        public string StatusDisplay
        {
            get
            {
                switch (_status)
                {
                    case TranscodeStatus.Queued: return "Queued";
                    case TranscodeStatus.Processing: return "Converting...";
                    case TranscodeStatus.Completed: return "Ready";
                    case TranscodeStatus.Failed: return "Failed";
                    case TranscodeStatus.Cancelled: return "Cancelled";
                    default: return _status.ToString();
                }
            }
        }

        public bool IsCompletedOrFailed
        {
            get { return _status == TranscodeStatus.Completed || _status == TranscodeStatus.Failed || _status == TranscodeStatus.Cancelled; }
        }

        public string SourceSizeFormatted
        {
            get { return FormatBytes(_sourceSizeBytes); }
        }

        public string OutputSizeFormatted
        {
            get
            {
                if (_outputSizeBytes <= 0) return "—";
                return FormatBytes(_outputSizeBytes);
            }
        }

        public string SavingsFormatted
        {
            get
            {
                if (_sourceSizeBytes <= 0 || _outputSizeBytes <= 0) return "";
                long diff = _sourceSizeBytes - _outputSizeBytes;
                double percent = ((double)diff / _sourceSizeBytes) * 100.0;
                if (diff > 0)
                {
                    return string.Format("-{0:0.#}%", percent);
                }
                else if (diff < 0)
                {
                    return string.Format("+{0:0.#}%", Math.Abs(percent));
                }
                return "0%";
            }
        }

        public string DurationFormatted
        {
            get
            {
                if (_duration.TotalMilliseconds <= 0) return "";
                if (_duration.TotalMinutes >= 1)
                    return string.Format("{0:0}m {1:0}s", Math.Floor(_duration.TotalMinutes), _duration.Seconds);
                return string.Format("{0:0.#}s", _duration.TotalSeconds);
            }
        }

        public TranscodeJob()
        {
            _id = Guid.NewGuid().ToString("N");
            _status = TranscodeStatus.Queued;
            _progressPercent = 0;
            _createdAt = DateTime.UtcNow;
            _preset = TranscodePreset.WebP_Image;
            _presetName = "WebP Image";
            _statusMessage = "Waiting in queue";
        }

        private static string FormatBytes(long bytes)
        {
            if (bytes <= 0) return "0 B";
            if (bytes < 1024) return bytes + " B";
            if (bytes < 1024 * 1024) return (bytes / 1024.0).ToString("0.#") + " KB";
            if (bytes < 1024 * 1024 * 1024) return (bytes / (1024.0 * 1024.0)).ToString("0.##") + " MB";
            return (bytes / (1024.0 * 1024.0 * 1024.0)).ToString("0.##") + " GB";
        }

        protected void OnPropertyChanged(string propertyName)
        {
            var handler = PropertyChanged;
            if (handler != null)
            {
                handler(this, new PropertyChangedEventArgs(propertyName));
            }
        }
    }
}
