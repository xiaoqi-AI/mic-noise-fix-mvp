param(
    [switch]$OpenManager,
    [ValidateSet("Auto", "RealtekLegacy", "RealtekUad", "Senary", "Nahimic")]
    [string]$ExpectedManager = "Auto"
)

$ErrorActionPreference = "SilentlyContinue"

function Get-LegacyRealtekCandidates {
    $paths = @(
        "C:\Program Files\Realtek\Audio\HDA\RtkNGUI64.exe",
        "C:\Program Files\Realtek\Audio\HDA\RAVCpl64.exe",
        "C:\Program Files (x86)\Realtek\Audio\HDA\RtkNGUI64.exe",
        "C:\Program Files (x86)\Realtek\Audio\HDA\RAVCpl64.exe"
    )

    foreach ($path in $paths) {
        if (Test-Path $path) {
            [pscustomobject]@{
                Type = "RealtekLegacy"
                Name = Split-Path $path -Leaf
                LaunchTarget = $path
                LaunchKind = "Exe"
            }
        }
    }
}

function Get-StartAppCandidates {
    foreach ($app in Get-StartApps) {
        if ($app.Name -match "Realtek|Audio Console|Senary|Nahimic|Waves|Dolby|DTS") {
            $type = "OtherAudioConsole"
            if ($app.Name -match "Realtek" -or $app.AppID -match "Realtek") { $type = "RealtekUad" }
            elseif ($app.Name -match "Senary|Audio Console" -or $app.AppID -match "Senary") { $type = "Senary" }
            elseif ($app.Name -match "Nahimic" -or $app.AppID -match "Nahimic") { $type = "Nahimic" }

            [pscustomobject]@{
                Type = $type
                Name = $app.Name
                LaunchTarget = $app.AppID
                LaunchKind = "AppsFolder"
            }
        }
    }
}

function Get-AudioRunKeyMatches {
    $patterns = "Realtek|Rtk|Audio|Senary|Nahimic|Waves|Dolby|DTS"
    $paths = @(
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run",
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run"
    )

    foreach ($path in $paths) {
        $item = Get-ItemProperty $path
        if ($null -eq $item) { continue }
        foreach ($property in $item.PSObject.Properties) {
            if ($property.Name -match $patterns -or [string]$property.Value -match $patterns) {
                [pscustomobject]@{
                    RegistryPath = $path
                    Name = $property.Name
                    Value = [string]$property.Value
                }
            }
        }
    }
}

function Open-Candidate {
    param([Parameter(Mandatory = $true)]$Candidate)

    if ($Candidate.LaunchKind -eq "Exe") {
        Start-Process -FilePath $Candidate.LaunchTarget
        return
    }

    if ($Candidate.LaunchKind -eq "AppsFolder") {
        Start-Process "shell:AppsFolder\$($Candidate.LaunchTarget)"
    }
}

$audioDevices = @(Get-PnpDevice -Class Media | Where-Object {
    $_.FriendlyName -match "Realtek|High Definition|Intel|AMD|NVIDIA|Audio|Senary|Microphone"
} | Select-Object Status, FriendlyName, InstanceId)

$problemDevicesRaw = @(pnputil /enum-devices /problem /deviceids)
$hasProblemDevices = ($problemDevicesRaw -join "`n") -notmatch "No devices were found"

$services = @(Get-Service | Where-Object {
    $_.Name -match "Rtk|Realtek|Senary|Nahimic|Waves|Dolby|DTS" -or
    $_.DisplayName -match "Realtek|Senary|Nahimic|Waves|Dolby|DTS"
} | Select-Object Name, DisplayName, Status, StartType)

$candidates = @()
$candidates += @(Get-LegacyRealtekCandidates)
$candidates += @(Get-StartAppCandidates)

if ($ExpectedManager -ne "Auto") {
    $preferred = @($candidates | Where-Object { $_.Type -eq $ExpectedManager })
} else {
    $preferred = @($candidates | Sort-Object @{Expression = {
        switch ($_.Type) {
            "RealtekLegacy" { 0 }
            "RealtekUad" { 1 }
            "Senary" { 2 }
            "Nahimic" { 3 }
            default { 9 }
        }
    }})
}

$runMatches = @(Get-AudioRunKeyMatches)

$validation = [ordered]@{
    GeneratedAt = (Get-Date).ToString("s")
    ExpectedManager = $ExpectedManager
    AudioDeviceCount = @($audioDevices).Count
    AudioDevices = $audioDevices
    HasProblemDevices = $hasProblemDevices
    ManagerCandidates = $candidates
    PreferredCandidate = @($preferred | Select-Object -First 1)
    AudioServices = $services
    StartupMatches = $runMatches
    Checks = [ordered]@{
        DeviceManagerHasAudioDevice = @($audioDevices).Count -gt 0
        DeviceManagerHasNoProblemDevices = -not $hasProblemDevices
        HasOpenableManagerCandidate = @($preferred).Count -gt 0
        HasTraditionalAudioStartupEntry = @($runMatches).Count -gt 0
        HasRelatedRunningService = @($services | Where-Object { $_.Status -eq "Running" }).Count -gt 0
    }
}

$validation.Passed = (
    $validation.Checks.DeviceManagerHasAudioDevice -and
    $validation.Checks.DeviceManagerHasNoProblemDevices -and
    $validation.Checks.HasOpenableManagerCandidate
)

$root = Split-Path $PSScriptRoot -Parent
$reportDir = Join-Path $root "reports"
New-Item -ItemType Directory -Force -Path $reportDir | Out-Null
$reportPath = Join-Path $reportDir ("audio-manager-validation-{0}.json" -f (Get-Date -Format "yyyyMMdd-HHmmss"))
$validation | ConvertTo-Json -Depth 8 | Set-Content -Path $reportPath -Encoding UTF8

Write-Host "Validation report written to: $reportPath"
Write-Host "Device Manager has audio device: $($validation.Checks.DeviceManagerHasAudioDevice)"
Write-Host "No problem devices: $($validation.Checks.DeviceManagerHasNoProblemDevices)"
Write-Host "Openable manager candidate: $($validation.Checks.HasOpenableManagerCandidate)"
Write-Host "Traditional audio startup entry: $($validation.Checks.HasTraditionalAudioStartupEntry)"
Write-Host "Related running service: $($validation.Checks.HasRelatedRunningService)"
Write-Host "Overall passed: $($validation.Passed)"

if ($OpenManager) {
    $candidate = @($preferred | Select-Object -First 1)
    if ($candidate.Count -eq 0) {
        Write-Error "No matching audio manager candidate was found."
        exit 2
    }

    Write-Host "Opening manager: $($candidate.Name)"
    Open-Candidate -Candidate $candidate
}

