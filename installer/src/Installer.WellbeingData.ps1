Add-Type -AssemblyName System.Security

function Get-WellbeingDataPath {
    $dir = Join-Path $env:LOCALAPPDATA "SuamiSihat\SS-CAM\wellbeing"
    if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    return Join-Path $dir "wellbeing_data.json"
}

function Protect-WellbeingText {
    param([string]$PlainText)
    if ([string]::IsNullOrEmpty($PlainText)) { return "" }
    $plainBytes = [System.Text.Encoding]::UTF8.GetBytes($PlainText)
    $encryptedBytes = [System.Security.Cryptography.ProtectedData]::Protect($plainBytes, $null, [System.Security.Cryptography.DataProtectionScope]::CurrentUser)
    return [Convert]::ToBase64String($encryptedBytes)
}

function Unprotect-WellbeingText {
    param([string]$EncryptedBase64)
    if ([string]::IsNullOrEmpty($EncryptedBase64)) { return "" }
    try {
        $encryptedBytes = [Convert]::FromBase64String($EncryptedBase64)
        $plainBytes = [System.Security.Cryptography.ProtectedData]::Unprotect($encryptedBytes, $null, [System.Security.Cryptography.DataProtectionScope]::CurrentUser)
        return [System.Text.Encoding]::UTF8.GetString($plainBytes)
    } catch {
        # Log decryption failure locally but do not throw to crash the app
        Write-Host "Failed to decrypt wellbeing text."
        return ""
    }
}

function Initialize-WellbeingStore {
    return @{
        SchemaVersion = 1
        FocusSessions = @()
        CheckIns = @()
        ResetSessions = @()
        MindDrops = @()
        ActiveSessionState = $null
        Preferences = @{
            DefaultFocusPreset = "Standard Focus"
            DefaultCustomFocusDuration = 25
            DefaultResetDuration = 5
            CheckInsEnabled = $true
            HistoryEnabled = $true
            WorkdayEndTime = "17:00"
            FatigueRemindersEnabled = $true
            MindDropRetention = "EndOfDay"
        }
    }
}

function Get-WellbeingData {
    $path = Get-WellbeingDataPath
    if (-not (Test-Path -LiteralPath $path)) {
        $data = Initialize-WellbeingStore
        Save-WellbeingData -Data $data
        return $data
    }
    
    try {
        $json = Get-Content -LiteralPath $path -Raw
        $data = $json | ConvertFrom-Json
        
        # In PowerShell, ConvertFrom-Json returns PSCustomObject.
        # We ensure properties exist.
        if ($null -eq $data.SchemaVersion) { $data | Add-Member -MemberType NoteProperty -Name SchemaVersion -Value 1 -Force }
        if ($null -eq $data.FocusSessions) { $data | Add-Member -MemberType NoteProperty -Name FocusSessions -Value @() -Force }
        if ($null -eq $data.CheckIns) { $data | Add-Member -MemberType NoteProperty -Name CheckIns -Value @() -Force }
        if ($null -eq $data.ResetSessions) { $data | Add-Member -MemberType NoteProperty -Name ResetSessions -Value @() -Force }
        if ($null -eq $data.MindDrops) { $data | Add-Member -MemberType NoteProperty -Name MindDrops -Value @() -Force }
        if ($null -eq $data.Preferences) { $data | Add-Member -MemberType NoteProperty -Name Preferences -Value (Initialize-WellbeingStore).Preferences -Force }

        # Expiry/Purge Logic for MindDrops
        $todayStr = (Get-Date).ToString("yyyy-MM-dd")
        $retainedDrops = @()
        foreach ($drop in $data.MindDrops) {
            if ($drop.RetentionMode -eq "Session") {
                # Purged at end of session, handled by session logic, but purge on startup anyway
                continue
            } elseif ($drop.RetentionMode -eq "EndOfDay") {
                $dropDate = [DateTime]::Parse($drop.CreatedAt).ToString("yyyy-MM-dd")
                if ($dropDate -eq $todayStr) {
                    $retainedDrops += $drop
                }
            } else {
                $retainedDrops += $drop
            }
        }
        $data.MindDrops = @($retainedDrops)

        return $data
    } catch {
        Write-Host "Get-WellbeingData Exception: $($_.Exception.Message)"
        # Fallback if corruption
        return Initialize-WellbeingStore
    }
}

function Save-WellbeingData {
    param([Parameter(Mandatory=$true)]$Data)
    $path = Get-WellbeingDataPath
    $Data | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $path -Encoding UTF8
}
