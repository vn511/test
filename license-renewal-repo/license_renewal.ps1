<#
.SYNOPSIS
    License renewal automation for Windows-hosted applications.

.DESCRIPTION
    Reads a license from a configured source, optionally backs up the current
    license, deploys the new license, restarts configured services, and verifies
    the result. The operator can enter the machine name interactively or pass it
    with -MachineName for unattended runs.
#>

[CmdletBinding()]
param(
    [string]$ConfigFile = (Join-Path $PSScriptRoot "config.json"),
    [string]$MachineName
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Status {
    param(
        [string]$Message,
        [ValidateSet("Info","Success","Warning","Error")]
        [string]$Level = "Info"
    )

    $colours = @{
        Info    = "Cyan"
        Success = "Green"
        Warning = "Yellow"
        Error   = "Red"
    }

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $colours[$Level]
}

function Resolve-ConfigValuePath {
    param(
        [string]$ConfigPath,
        [string]$Value
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $Value
    }

    if ($Value.StartsWith("\\\\")) {
        return $Value
    }

    if ([System.IO.Path]::IsPathRooted($Value)) {
        return $Value
    }

    $configDirectory = Split-Path -Parent $ConfigPath
    return [System.IO.Path]::GetFullPath((Join-Path $configDirectory $Value))
}

function Get-Config {
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        Write-Status "Config file not found: $Path" -Level Error
        throw "Missing configuration file."
    }

    $resolvedConfigPath = (Resolve-Path $Path).Path
    $cfg = Get-Content $resolvedConfigPath -Raw | ConvertFrom-Json

    foreach ($key in @("sharePath","licenseFileName","backupRoot","licenseDestPath","servicesToRestart")) {
        if (-not $cfg.PSObject.Properties[$key]) {
            throw "Configuration is missing required key: '$key'"
        }
    }

    if (-not $cfg.PSObject.Properties["targetMode"] -or [string]::IsNullOrWhiteSpace($cfg.targetMode)) {
        $cfg | Add-Member -NotePropertyName targetMode -NotePropertyValue "adminShare"
    }

    $cfg.sharePath = Resolve-ConfigValuePath -ConfigPath $resolvedConfigPath -Value $cfg.sharePath
    $cfg.backupRoot = Resolve-ConfigValuePath -ConfigPath $resolvedConfigPath -Value $cfg.backupRoot

    if ($cfg.targetMode -eq "localPath") {
        $cfg.licenseDestPath = Resolve-ConfigValuePath -ConfigPath $resolvedConfigPath -Value $cfg.licenseDestPath
    }

    $cfg | Add-Member -NotePropertyName configPath -NotePropertyValue $resolvedConfigPath -Force
    return $cfg
}

function Get-OperatorMachineName {
    param([string]$InitialMachineName)

    if (-not [string]::IsNullOrWhiteSpace($InitialMachineName)) {
        return $InitialMachineName.Trim()
    }

    do {
        $enteredMachineName = (Read-Host "Enter the machine name for the license renewal target").Trim()
        if ([string]::IsNullOrWhiteSpace($enteredMachineName)) {
            Write-Status "Machine name cannot be empty. Please try again." -Level Warning
        }
    } until (-not [string]::IsNullOrWhiteSpace($enteredMachineName))

    return $enteredMachineName
}

function Get-LicenseTarget {
    param(
        [object]$Config,
        [string]$MachineName
    )

    if ($Config.targetMode -eq "localPath") {
        $targetDirectory = $Config.licenseDestPath
    } else {
        $trimmedPath = $Config.licenseDestPath.TrimStart('\')
        $targetDirectory = "\\$MachineName\$trimmedPath"
    }

    return @{
        Directory = $targetDirectory
        FilePath = Join-Path $targetDirectory $Config.licenseFileName
    }
}

function Read-LicenseFromShare {
    param([object]$Config)

    $licensePath = Join-Path $Config.sharePath $Config.licenseFileName
    Write-Status "Reading license from source: $licensePath"

    if (-not (Test-Path $licensePath)) {
        Write-Status "License file not found: $licensePath" -Level Error
        throw "License file not found on configured source."
    }

    $content = Get-Content $licensePath -Raw
    Write-Status "License file read successfully ($([System.Text.Encoding]::UTF8.GetByteCount($content)) bytes)." -Level Success

    return @{
        Content = $content
        FullPath = $licensePath
    }
}

function Backup-ExistingLicense {
    param(
        [object]$Config,
        [string]$MachineName
    )

    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $backupFolder = Join-Path $Config.backupRoot "$MachineName`_$timestamp"
    $target = Get-LicenseTarget -Config $Config -MachineName $MachineName

    Write-Status "Backup folder: $backupFolder"
    New-Item -ItemType Directory -Force -Path $backupFolder | Out-Null

    if (Test-Path $target.FilePath) {
        $destinationFile = Join-Path $backupFolder $Config.licenseFileName
        Copy-Item -Path $target.FilePath -Destination $destinationFile -Force
        Write-Status "Existing license backed up to: $destinationFile" -Level Success
    } else {
        Write-Status "No existing license found at $($target.FilePath) - skipping backup." -Level Warning
    }

    return $backupFolder
}

function Deploy-License {
    param(
        [object]$Config,
        [string]$MachineName,
        [string]$LicenseContent
    )

    $target = Get-LicenseTarget -Config $Config -MachineName $MachineName
    Write-Status "Deploying new license to: $($target.FilePath)"

    if (-not (Test-Path $target.Directory)) {
        Write-Status "Target directory does not exist - creating: $($target.Directory)" -Level Warning
        New-Item -ItemType Directory -Force -Path $target.Directory | Out-Null
    }

    Set-Content -Path $target.FilePath -Value $LicenseContent -Encoding UTF8 -Force
    Write-Status "New license deployed successfully." -Level Success
}

function Restart-LicenseServices {
    param(
        [string]$MachineName,
        [string[]]$ServiceNames
    )

    if (-not $ServiceNames -or $ServiceNames.Count -eq 0) {
        Write-Status "No services configured for restart - skipping step." -Level Warning
        return
    }

    foreach ($serviceName in $ServiceNames) {
        Write-Status "Restarting service '$serviceName' on $MachineName"
        try {
            $service = Get-Service -ComputerName $MachineName -Name $serviceName -ErrorAction Stop
            if ($service.Status -eq "Running") {
                Restart-Service -InputObject $service -Force -ErrorAction Stop
            } else {
                Start-Service -InputObject $service -ErrorAction Stop
            }

            $service.WaitForStatus("Running", [TimeSpan]::FromSeconds(60))
            Write-Status "Service '$serviceName' is Running." -Level Success
        } catch {
            Write-Status "Failed to restart '$serviceName': $_" -Level Error
            throw
        }
    }
}

function Test-LicenseRenewal {
    param(
        [object]$Config,
        [string]$MachineName,
        [string]$ExpectedContent
    )

    $target = Get-LicenseTarget -Config $Config -MachineName $MachineName
    Write-Status "Verifying license at $($target.FilePath)"

    if (-not (Test-Path $target.FilePath)) {
        Write-Status "Verification FAILED - license file not found at $($target.FilePath)" -Level Error
        return $false
    }

    $deployedContent = Get-Content $target.FilePath -Raw
    if ($deployedContent.Trim() -eq $ExpectedContent.Trim()) {
        Write-Status "Verification PASSED - license content matches." -Level Success
        return $true
    }

    Write-Status "Verification FAILED - license content mismatch." -Level Error
    return $false
}

function Main {
    Write-Host ""
    Write-Host "============================================" -ForegroundColor Magenta
    Write-Host "        LICENSE RENEWAL TOOL                " -ForegroundColor Magenta
    Write-Host "============================================" -ForegroundColor Magenta
    Write-Host ""

    $config = Get-Config -Path $ConfigFile
    $resolvedMachineName = Get-OperatorMachineName -InitialMachineName $MachineName

    Write-Status "Operator selected machine name: $resolvedMachineName"
    Write-Host ""

    try {
        Write-Status "STEP 1 - Reading license from configured source"
        $license = Read-LicenseFromShare -Config $config

        Write-Status "STEP 2 - Backing up existing license"
        $backupFolder = Backup-ExistingLicense -Config $config -MachineName $resolvedMachineName

        Write-Status "STEP 3 - Deploying new license"
        Deploy-License -Config $config -MachineName $resolvedMachineName -LicenseContent $license.Content

        Write-Status "STEP 4 - Restarting services"
        Restart-LicenseServices -MachineName $resolvedMachineName -ServiceNames $config.servicesToRestart

        Write-Status "STEP 5 - Verifying license renewal"
        $verified = Test-LicenseRenewal -Config $config -MachineName $resolvedMachineName -ExpectedContent $license.Content

        Write-Host ""
        if ($verified) {
            Write-Host "============================================" -ForegroundColor Green
            Write-Host "  LICENSE RENEWAL COMPLETED SUCCESSFULLY   " -ForegroundColor Green
            Write-Host "  Machine : $resolvedMachineName" -ForegroundColor Green
            Write-Host "  Backup  : $backupFolder" -ForegroundColor Green
            Write-Host "============================================" -ForegroundColor Green
            return
        }

        Write-Host "============================================" -ForegroundColor Red
        Write-Host "  LICENSE RENEWAL VERIFICATION FAILED      " -ForegroundColor Red
        Write-Host "  Please check the logs above for details.  " -ForegroundColor Red
        Write-Host "============================================" -ForegroundColor Red
        exit 1
    } catch {
        Write-Host ""
        Write-Status "An error occurred during renewal: $_" -Level Error
        exit 1
    }
}

Main
