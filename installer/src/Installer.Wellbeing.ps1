Add-Type @"
using System;
using System.Runtime.InteropServices;

public class IdleTimeFinder {
    [StructLayout(LayoutKind.Sequential)]
    struct LASTINPUTINFO {
        public static readonly int SizeOf = Marshal.SizeOf(typeof(LASTINPUTINFO));
        [MarshalAs(UnmanagedType.U4)]
        public UInt32 cbSize;
        [MarshalAs(UnmanagedType.U4)]
        public UInt32 dwTime;
    }

    [DllImport("user32.dll")]
    static extern bool GetLastInputInfo(ref LASTINPUTINFO plii);

    public static uint GetIdleTime() {
        LASTINPUTINFO lastInPut = new LASTINPUTINFO();
        lastInPut.cbSize = (uint)Marshal.SizeOf(lastInPut);
        if (!GetLastInputInfo(ref lastInPut)) {
            return 0;
        }
        return (uint)Environment.TickCount - lastInPut.dwTime;
    }
}
"@

$script:WellbeingTimerState = "Ready" # Ready, Running, Paused, Completed
$script:WellbeingStopwatch = New-Object System.Diagnostics.Stopwatch
$script:WellbeingSessionDuration = 0
$script:WellbeingElapsedSeconds = 0
$script:WellbeingSessionType = "Standard Focus"
$script:WellbeingSessionStart = $null

function Get-WellbeingIdleSeconds {
    try {
        $idleMs = [IdleTimeFinder]::GetIdleTime()
        return [math]::Floor($idleMs / 1000)
    } catch {
        return 0
    }
}

function Start-WellbeingSession {
    param([int]$DurationMinutes, [string]$SessionType)
    $script:WellbeingSessionDuration = $DurationMinutes * 60
    $script:WellbeingElapsedSeconds = 0
    $script:WellbeingSessionType = $SessionType
    $script:WellbeingTimerState = "Running"
    $script:WellbeingSessionStart = Get-Date
    $script:WellbeingStopwatch.Restart()
    
    # Checkpoint
    Save-WellbeingCheckpoint
}

function Pause-WellbeingSession {
    if ($script:WellbeingTimerState -eq "Running") {
        $script:WellbeingStopwatch.Stop()
        $script:WellbeingElapsedSeconds += [math]::Floor($script:WellbeingStopwatch.Elapsed.TotalSeconds)
        $script:WellbeingStopwatch.Reset()
        $script:WellbeingTimerState = "Paused"
        Save-WellbeingCheckpoint
    }
}

function Resume-WellbeingSession {
    if ($script:WellbeingTimerState -eq "Paused") {
        $script:WellbeingTimerState = "Running"
        $script:WellbeingStopwatch.Restart()
        Save-WellbeingCheckpoint
    }
}

function Stop-WellbeingSession {
    param([string]$Reason = "Ended early")
    $script:WellbeingStopwatch.Stop()
    if ($script:WellbeingTimerState -eq "Running") {
        $script:WellbeingElapsedSeconds += [math]::Floor($script:WellbeingStopwatch.Elapsed.TotalSeconds)
    }
    
    $status = if ($script:WellbeingElapsedSeconds -ge $script:WellbeingSessionDuration) { "completed" } else { "ended_early" }
    
    # Save to history
    $data = Get-WellbeingData
    $session = @{
        Id = [guid]::NewGuid().ToString()
        StartedAt = $script:WellbeingSessionStart.ToString("s")
        EndedAt = (Get-Date).ToString("s")
        PlannedMinutes = [math]::Floor($script:WellbeingSessionDuration / 60)
        ActualSeconds = $script:WellbeingElapsedSeconds
        SessionType = $script:WellbeingSessionType
        Status = $status
        EndReason = $Reason
        CreatedAt = (Get-Date).ToString("s")
    }
    $data.FocusSessions += $session
    $data.ActiveSessionState = $null
    Save-WellbeingData -Data $data
    
    $script:WellbeingTimerState = "Ready"
    $script:WellbeingStopwatch.Reset()
    $script:WellbeingElapsedSeconds = 0
    
    return $session
}

function Save-WellbeingCheckpoint {
    $data = Get-WellbeingData
    $currentElapsed = $script:WellbeingElapsedSeconds
    if ($script:WellbeingTimerState -eq "Running") {
        $currentElapsed += [math]::Floor($script:WellbeingStopwatch.Elapsed.TotalSeconds)
    }
    
    $data.ActiveSessionState = @{
        State = $script:WellbeingTimerState
        SelectedPreset = $script:WellbeingSessionType
        PlannedDuration = $script:WellbeingSessionDuration
        AccumulatedSeconds = $currentElapsed
        LastCheckpointTime = (Get-Date).ToString("s")
        SessionStart = $script:WellbeingSessionStart.ToString("s")
    }
    Save-WellbeingData -Data $data
}

function Restore-WellbeingCheckpoint {
    $data = Get-WellbeingData
    if ($data.ActiveSessionState) {
        $state = $data.ActiveSessionState
        $script:WellbeingTimerState = $state.State
        $script:WellbeingSessionType = $state.SelectedPreset
        $script:WellbeingSessionDuration = $state.PlannedDuration
        $script:WellbeingElapsedSeconds = $state.AccumulatedSeconds
        $script:WellbeingSessionStart = [DateTime]::Parse($state.SessionStart)
        
        # When restoring, we always restore in Paused state to allow user to resume or discard,
        # unless it was running and time passed. Actually the prompt says:
        # "On restart, if an unfinished session exists, show... Actions: Continue, Save as Ended, Discard"
        $script:WellbeingTimerState = "RecoveryPending"
        $script:WellbeingStopwatch.Reset()
        return $true
    }
    return $false
}

function Update-WellbeingTimerTick {
    if ($script:WellbeingTimerState -eq "Running") {
        $idleSeconds = Get-WellbeingIdleSeconds
        
        # If idle for more than 3 minutes (180s) or locked/suspended, we pause the session
        # For testing, we might use a lower threshold or mock it.
        # But here we implement the lock/suspend logic.
        if ($idleSeconds -ge 180) {
            $script:WellbeingStopwatch.Stop()
            # We subtract the idle time from the elapsed time since we shouldn't count it.
            $currentElapsed = $script:WellbeingStopwatch.Elapsed.TotalSeconds - $idleSeconds
            if ($currentElapsed -lt 0) { $currentElapsed = 0 }
            
            $script:WellbeingElapsedSeconds += [math]::Floor($currentElapsed)
            $script:WellbeingStopwatch.Reset()
            $script:WellbeingTimerState = "Paused"
            Save-WellbeingCheckpoint
            
            return "Paused due to inactivity"
        }
        
        $totalElapsed = $script:WellbeingElapsedSeconds + [math]::Floor($script:WellbeingStopwatch.Elapsed.TotalSeconds)
        if ($totalElapsed -ge $script:WellbeingSessionDuration) {
            # Completed!
            $script:WellbeingTimerState = "Completed"
            $script:WellbeingStopwatch.Stop()
            $script:WellbeingElapsedSeconds = $totalElapsed
            Save-WellbeingCheckpoint
            return "Completed"
        }
    }
    return $null
}

function Get-WellbeingCurrentTimeFormatted {
    if ($script:WellbeingTimerState -eq "Ready") { return "" }
    $totalElapsed = $script:WellbeingElapsedSeconds
    if ($script:WellbeingTimerState -eq "Running") {
        $totalElapsed += [math]::Floor($script:WellbeingStopwatch.Elapsed.TotalSeconds)
    }
    
    $remaining = $script:WellbeingSessionDuration - $totalElapsed
    if ($remaining -lt 0) { $remaining = 0 }
    
    $m = [math]::Floor($remaining / 60)
    $s = $remaining % 60
    return "${m}:$($s.ToString('00'))"
}

function Save-WellbeingCheckIn {
    param([int]$Mood, [int]$Energy, [int]$Pressure, [string]$Context)
    $data = Get-WellbeingData
    $checkIn = @{
        Id = [guid]::NewGuid().ToString()
        RecordedAt = (Get-Date).ToString("s")
        Mood = $Mood
        Energy = $Energy
        Pressure = $Pressure
        Context = $Context
    }
    $data.CheckIns += $checkIn
    Save-WellbeingData -Data $data
    return $checkIn
}

function Start-WellbeingResetSession {
    param([string]$ResetType, [int]$DurationSeconds)
    $data = Get-WellbeingData
    $session = @{
        Id = [guid]::NewGuid().ToString()
        ResetType = $ResetType
        StartedAt = (Get-Date).ToString("s")
        CompletedAt = $null
        ActualSeconds = 0
        Status = "running"
        PlannedSeconds = $DurationSeconds
    }
    $data.ResetSessions += $session
    Save-WellbeingData -Data $data
    return $session
}

function Stop-WellbeingResetSession {
    param([string]$Id, [int]$ActualSeconds)
    $data = Get-WellbeingData
    for ($i = 0; $i -lt $data.ResetSessions.Count; $i++) {
        if ($data.ResetSessions[$i].Id -eq $Id) {
            $data.ResetSessions[$i].ActualSeconds = $ActualSeconds
            $data.ResetSessions[$i].CompletedAt = (Get-Date).ToString("s")
            if ($ActualSeconds -ge $data.ResetSessions[$i].PlannedSeconds) {
                $data.ResetSessions[$i].Status = "completed"
            } else {
                $data.ResetSessions[$i].Status = "ended_early"
            }
        }
    }
    Save-WellbeingData -Data $data
}

function Invoke-FatigueRuleEngine {
    # Returns an array of recommendation objects
    $data = Get-WellbeingData
    $recommendations = @()
    
    # Analyze recent check-ins
    $recentCheckIns = @($data.CheckIns | Sort-Object RecordedAt -Descending | Select-Object -First 2 | Where-Object { $null -ne $_ })
    if ($recentCheckIns.Count -ge 1) {
        $last = $recentCheckIns[0]
        if ($last.Energy -le 2 -and $last.Pressure -ge 4) {
            $recommendations += @{ Type = "Action"; Message = "A breathing reset is suggested before starting a Gentle Focus." }
        } elseif ($last.Energy -le 2) {
            $recommendations += @{ Type = "Action"; Message = "A gentler start may be easier today. Try a 15-minute focus session." }
        } elseif ($last.Pressure -ge 4) {
            $recommendations += @{ Type = "Action"; Message = "Pressure is high. Consider defining one achievable outcome." }
        } elseif ($last.Energy -ge 4 -and $last.Pressure -le 3) {
            $recommendations += @{ Type = "Action"; Message = "You have good energy. Consider a Deep Flow session." }
        } elseif ($last.Mood -ge 4 -and $last.Energy -ge 4) {
            $recommendations += @{ Type = "Action"; Message = "You're inspired and energized. Ready for a Deep Flow?" }
        }
    }
    
    # 2 consecutive Energy checkins at 1 or 2
    if ($recentCheckIns.Count -ge 2 -and $recentCheckIns[0].Energy -le 2 -and $recentCheckIns[1].Energy -le 2) {
        $recommendations += @{ Type = "Alert"; Message = "Low energy pattern noticed. Recommend shorter sessions for the rest of the day." }
    }
    if ($recentCheckIns.Count -ge 2 -and $recentCheckIns[0].Pressure -ge 4 -and $recentCheckIns[1].Pressure -ge 4) {
        $recommendations += @{ Type = "Alert"; Message = "High pressure pattern noticed. Consider breathing, Mind Drop, or a one-outcome session." }
    }
    
    # Determine last meaningful break
    # A meaningful break = a reset > 60s, or idle time between sessions > 180s
    $today = (Get-Date).ToString("yyyy-MM-dd")
    $todaySessions = $data.FocusSessions | Where-Object { $_.StartedAt -like "$today*" } | Sort-Object StartedAt
    
    $continuousWorkSeconds = 0
    $lastBreakTime = $null
    
    if ($todaySessions.Count -gt 0) {
        # Simplified: check the duration since last session ended compared to now
        $lastEnd = $todaySessions[-1].EndedAt
        if ($lastEnd) {
            $gap = ((Get-Date) - [DateTime]::Parse($lastEnd)).TotalSeconds
            if ($gap -gt 180) {
                # They took a break
                $continuousWorkSeconds = 0
            } else {
                # Sum the work
                $continuousWorkSeconds = ($todaySessions | Measure-Object -Property ActualSeconds -Sum).Sum
            }
        }
    }
    
    # Fatigue limits
    if ($continuousWorkSeconds -ge 7200) { # 120 mins
        $recommendations += @{ Type = "Fatigue"; Level = 3; Message = "You have been focused for over 2 hours without a break. Please consider resting." }
    } elseif ($continuousWorkSeconds -ge 5400) { # 90 mins
        $recommendations += @{ Type = "Fatigue"; Level = 2; Message = "You have been working for a long time. Time for a 5-minute break?" }
    } elseif ($continuousWorkSeconds -ge 3000) { # 50 mins
        $recommendations += @{ Type = "Fatigue"; Level = 1; Message = "You have been focused for a while. A one-minute visual reset is available whenever you are ready." }
    }
    
    return $recommendations
}

