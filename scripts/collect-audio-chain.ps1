param(
    [string]$ReportPath
)

$ErrorActionPreference = "SilentlyContinue"

function Select-MatchingProperties {
    param(
        [Parameter(Mandatory = $true)]$InputObject,
        [string[]]$Patterns
    )

    $rows = @()
    foreach ($property in $InputObject.PSObject.Properties) {
        foreach ($pattern in $Patterns) {
            if ($property.Name -match $pattern -or [string]$property.Value -match $pattern) {
                $rows += [pscustomobject]@{
                    Name = $property.Name
                    Value = [string]$property.Value
                }
                break
            }
        }
    }
    return $rows
}

function Get-RunKeyMatches {
    $patterns = @("Realtek", "Rtk", "Audio", "Senary", "Nahimic", "Waves", "Dolby", "DTS")
    $paths = @(
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run",
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run"
    )

    foreach ($path in $paths) {
        $item = Get-ItemProperty $path
        if ($null -ne $item) {
            [pscustomobject]@{
                RegistryPath = $path
                Matches = @(Select-MatchingProperties -InputObject $item -Patterns $patterns)
            }
        }
    }
}

function Test-LegacyRealtekManager {
    $paths = @(
        "C:\Program Files\Realtek\Audio\HDA\RtkNGUI64.exe",
        "C:\Program Files\Realtek\Audio\HDA\RAVCpl64.exe",
        "C:\Program Files (x86)\Realtek\Audio\HDA\RtkNGUI64.exe",
        "C:\Program Files (x86)\Realtek\Audio\HDA\RAVCpl64.exe"
    )

    foreach ($path in $paths) {
        [pscustomobject]@{
            Name = Split-Path $path -Leaf
            Path = $path
            Exists = Test-Path $path
        }
    }
}

function Get-CodecVendorHint {
    param([string]$InstanceId)

    if ($InstanceId -match "VEN_10EC") { return "Realtek" }
    if ($InstanceId -match "VEN_14F1") { return "Conexant/Senary" }
    if ($InstanceId -match "VEN_8086") { return "Intel" }
    if ($InstanceId -match "VEN_1002") { return "AMD" }
    if ($InstanceId -match "VEN_10DE") { return "NVIDIA" }
    return "Unknown"
}

if ([string]::IsNullOrWhiteSpace($ReportPath)) {
    $root = Split-Path $PSScriptRoot -Parent
    $reportDir = Join-Path $root "reports"
    New-Item -ItemType Directory -Force -Path $reportDir | Out-Null
    $ReportPath = Join-Path $reportDir ("audio-chain-{0}.json" -f (Get-Date -Format "yyyyMMdd-HHmmss"))
}

$computerInfo = Get-ComputerInfo | Select-Object OsName, OsVersion, OsBuildNumber, WindowsVersion, CsManufacturer, CsModel, CsSystemFamily, CsSystemType

$mediaDevices = @(Get-PnpDevice -Class Media | Select-Object Status, Class, FriendlyName, InstanceId)
$audioDevices = @($mediaDevices | Where-Object { $_.FriendlyName -match "Realtek|High Definition|Intel|AMD|NVIDIA|Audio|Senary|Microphone" })

$signedDrivers = @(Get-CimInstance Win32_PnPSignedDriver | Where-Object {
    $_.DeviceClass -eq "MEDIA" -or $_.DeviceName -match "Realtek|High Definition|Intel|AMD|NVIDIA|Audio|Senary|Microphone|Nahimic|Waves|Dolby|DTS"
} | Select-Object DeviceName, Manufacturer, DriverProviderName, DriverVersion, DriverDate, InfName, DeviceID)

$problemDevices = @(pnputil /enum-devices /problem /deviceids)

$audioApps = @(Get-StartApps | Where-Object {
    $_.Name -match "Realtek|Audio|Senary|Nahimic|Waves|Dolby|DTS"
} | Select-Object Name, AppID)

$appxPackages = @(Get-AppxPackage -AllUsers | Where-Object {
    $_.Name -match "Realtek|Senary|Nahimic|Waves|Dolby|DTS"
} | Select-Object Name, PackageFullName, Version, Status)

$services = @(Get-Service | Where-Object {
    $_.Name -match "Rtk|Realtek|Senary|Nahimic|Waves|Dolby|DTS" -or
    $_.DisplayName -match "Realtek|Senary|Nahimic|Waves|Dolby|DTS"
} | Select-Object Name, DisplayName, Status, StartType)

$legacyManagers = @(Test-LegacyRealtekManager)
$runKeyMatches = @(Get-RunKeyMatches)

$codecHints = @($audioDevices | ForEach-Object {
    [pscustomobject]@{
        FriendlyName = $_.FriendlyName
        InstanceId = $_.InstanceId
        VendorHint = Get-CodecVendorHint -InstanceId $_.InstanceId
    }
})

$managerCandidates = @()
$managerCandidates += @($legacyManagers | Where-Object { $_.Exists } | ForEach-Object {
    [pscustomobject]@{
        Type = "LegacyRealtekExe"
        Name = $_.Name
        LaunchTarget = $_.Path
        Present = $true
    }
})
$managerCandidates += @($audioApps | Where-Object { $_.Name -match "Realtek|Senary|Audio Console|Nahimic|Waves|Dolby|DTS" } | ForEach-Object {
    [pscustomobject]@{
        Type = "StartApp"
        Name = $_.Name
        LaunchTarget = $_.AppID
        Present = $true
    }
})

$summary = [ordered]@{
    GeneratedAt = (Get-Date).ToString("s")
    Machine = $computerInfo
    AudioDevices = $audioDevices
    CodecHints = $codecHints
    SignedDrivers = $signedDrivers
    ProblemDevicesRaw = $problemDevices
    AudioApps = $audioApps
    AppxPackages = $appxPackages
    Services = $services
    LegacyRealtekManagers = $legacyManagers
    RunKeyMatches = $runKeyMatches
    ManagerCandidates = $managerCandidates
    Verdict = [ordered]@{
        HasProblemDevices = ($problemDevices -join "`n") -notmatch "No devices were found"
        HasLegacyRealtekManager = @($legacyManagers | Where-Object { $_.Exists }).Count -gt 0
        HasRealtekApp = @($audioApps | Where-Object { $_.Name -match "Realtek" }).Count -gt 0
        HasSenaryAudioConsole = @($audioApps | Where-Object { $_.Name -match "Senary|Audio Console" -or $_.AppID -match "Senary" }).Count -gt 0
        HasNahimicService = @($services | Where-Object { $_.Name -match "Nahimic" -and $_.Status -eq "Running" }).Count -gt 0
        ManagerCandidateCount = @($managerCandidates).Count
    }
}

$summary | ConvertTo-Json -Depth 8 | Set-Content -Path $ReportPath -Encoding UTF8

Write-Host "Audio chain report written to: $ReportPath"
Write-Host "Manager candidates: $(@($managerCandidates).Count)"
Write-Host "Legacy Realtek manager present: $($summary.Verdict.HasLegacyRealtekManager)"
Write-Host "Realtek app present: $($summary.Verdict.HasRealtekApp)"
Write-Host "Senary Audio Console present: $($summary.Verdict.HasSenaryAudioConsole)"
Write-Host "Nahimic service running: $($summary.Verdict.HasNahimicService)"

