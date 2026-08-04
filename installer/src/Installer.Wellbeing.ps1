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
