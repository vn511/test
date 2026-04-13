<#
.SYNOPSIS
    License Renewal Script - Reads, backs up, installs, restarts services,
    and verifies a software license from a Windows network share.

.DESCRIPTION
    Prompts the user for a target hostname, reads the current license from a
    configured Windows share, backs it up to a timestamped folder, copies the
    new license to the target server, restarts the configured services, and
    performs a post-renewal verification test.

.PARAMETER ConfigFile
    Path to the JSON configuration file.  Defaults to config.json in the same
    directory as this script.

.EXAMPLE
    .\license_renewal.ps1
    .\license_renewal.ps1 -ConfigFile "C:\custom\config.json"
#>

[CmdletBinding()]
param(
    [string]$ConfigFile = (Join-Path $PSScriptRoot "config.json")
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ---------------------------------------------------------------------------
# Helper – write a coloured status line
# ---------------------------------------------------------------------------
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

# ---------------------------------------------------------------------------
# Load configuration
# ---------------------------------------------------------------------------
function Get-Config {
    param([string]$Path)
    if (-not (Test-Path $Path)) {
        Write-Status "Config file not found: $Path" -Level Error
        throw "Missing configuration file."
    }
    $cfg = Get-Content $Path -Raw | ConvertFrom-Json
    # Validate required keys
    foreach ($key in @("sharePath","licenseFileName","backupRoot","licenseDestPath","servicesToRestart")) {
        if (-not $cfg.PSObject.Properties[$key]) {
            throw "Configuration is missing required key: '$key'"
        }
    }
    return $cfg
}

# ---------------------------------------------------------------------------
# Step 1 – Read the license from the Windows share
# ---------------------------------------------------------------------------
function Read-LicenseFromShare {
    param(
        [string]$SharePath,
        [string]$LicenseFileName
    )
    $licensePath = Join-Path $SharePath $LicenseFileName
    Write-Status "Reading license from share: $licensePath"

    if (-not (Test-Path $licensePath)) {
        Write-Status "License file not found on share: $licensePath" -Level Error
        throw "License file not found on share."
    }

    $content = Get-Content $licensePath -Raw
    Write-Status "License file read successfully ($([System.Text.Encoding]::UTF8.GetByteCount($content)) bytes)." -Level Success
    return @{
        Content  = $content
        FullPath = $licensePath
    }
}

# ---------------------------------------------------------------------------
# Step 2 – Back up the existing license on the target server
# ---------------------------------------------------------------------------
function Backup-ExistingLicense {
    param(
        [string]$Hostname,
        [string]$LicenseDestPath,
        [string]$LicenseFileName,
        [string]$BackupRoot
    )
    $timestamp     = Get-Date -Format "yyyyMMdd_HHmmss"
    $backupFolder  = Join-Path $BackupRoot "$Hostname`_$timestamp"
    $remoteFile    = "\\$Hostname\$($LicenseDestPath.TrimStart('\'))\$LicenseFileName"

    Write-Status "Backup folder: $backupFolder"
    New-Item -ItemType Directory -Force -Path $backupFolder | Out-Null

    if (Test-Path $remoteFile) {
        $destFile = Join-Path $backupFolder $LicenseFileName
        Copy-Item -Path $remoteFile -Destination $destFile -Force
        Write-Status "Existing license backed up to: $destFile" -Level Success
    } else {
        Write-Status "No existing license found at $remoteFile – skipping backup." -Level Warning
    }
    return $backupFolder
}

# ---------------------------------------------------------------------------
# Step 3 – Deploy the new license to the target server
# ---------------------------------------------------------------------------
function Deploy-License {
    param(
        [string]$Hostname,
        [string]$LicenseDestPath,
        [string]$LicenseFileName,
        [string]$LicenseContent
    )
    $remoteDir  = "\\$Hostname\$($LicenseDestPath.TrimStart('\'))"
    $remoteFile = Join-Path $remoteDir $LicenseFileName

    Write-Status "Deploying new license to: $remoteFile"

    if (-not (Test-Path $remoteDir)) {
        Write-Status "Remote path does not exist – attempting to create: $remoteDir" -Level Warning
        New-Item -ItemType Directory -Force -Path $remoteDir | Out-Null
    }

    Set-Content -Path $remoteFile -Value $LicenseContent -Encoding UTF8 -Force
    Write-Status "New license deployed successfully." -Level Success
}

# ---------------------------------------------------------------------------
# Step 4 – Restart services on the target server
# ---------------------------------------------------------------------------
function Restart-LicenseServices {
    param(
        [string]$Hostname,
        [string[]]$ServiceNames
    )
    foreach ($svcName in $ServiceNames) {
        Write-Status "Restarting service '$svcName' on $Hostname …"
        try {
            $svc = Get-Service -ComputerName $Hostname -Name $svcName -ErrorAction Stop
            if ($svc.Status -eq "Running") {
                Restart-Service -InputObject $svc -Force -ErrorAction Stop
            } else {
                Start-Service -InputObject $svc -ErrorAction Stop
            }
            # Wait up to 60 s for the service to reach Running
            $svc.WaitForStatus("Running", [TimeSpan]::FromSeconds(60))
            Write-Status "Service '$svcName' is Running." -Level Success
        } catch {
            Write-Status "Failed to restart '$svcName': $_" -Level Error
            throw
        }
    }
}

# ---------------------------------------------------------------------------
# Step 5 – Verify the license renewal
# ---------------------------------------------------------------------------
function Test-LicenseRenewal {
    param(
        [string]$Hostname,
        [string]$LicenseDestPath,
        [string]$LicenseFileName,
        [string]$ExpectedContent
    )
    $remoteFile = "\\$Hostname\$($LicenseDestPath.TrimStart('\'))\$LicenseFileName"
    Write-Status "Verifying license on $Hostname at $remoteFile …"

    if (-not (Test-Path $remoteFile)) {
        Write-Status "Verification FAILED – license file not found at $remoteFile" -Level Error
        return $false
    }

    $deployed = Get-Content $remoteFile -Raw
    if ($deployed.Trim() -eq $ExpectedContent.Trim()) {
        Write-Status "Verification PASSED – license content matches." -Level Success
        return $true
    } else {
        Write-Status "Verification FAILED – license content mismatch." -Level Error
        return $false
    }
}

# ---------------------------------------------------------------------------
# Main entry point
# ---------------------------------------------------------------------------
function Main {
    Write-Host ""
    Write-Host "============================================" -ForegroundColor Magenta
    Write-Host "        LICENSE RENEWAL TOOL                " -ForegroundColor Magenta
    Write-Host "============================================" -ForegroundColor Magenta
    Write-Host ""

    # Load config
    $cfg = Get-Config -Path $ConfigFile

    # Prompt for hostname
    do {
        $hostname = (Read-Host "Enter the hostname of the server to renew the license on").Trim()
        if ([string]::IsNullOrWhiteSpace($hostname)) {
            Write-Status "Hostname cannot be empty. Please try again." -Level Warning
        }
    } until (-not [string]::IsNullOrWhiteSpace($hostname))

    Write-Status "Target hostname: $hostname"
    Write-Host ""

    try {
        # -- Step 1: Read license from share ----------------------------------
        Write-Status "STEP 1 – Reading license from network share" -Level Info
        $license = Read-LicenseFromShare -SharePath $cfg.sharePath `
                                         -LicenseFileName $cfg.licenseFileName

        # -- Step 2: Backup existing license ----------------------------------
        Write-Status "STEP 2 – Backing up existing license" -Level Info
        $backupFolder = Backup-ExistingLicense -Hostname $hostname `
                                               -LicenseDestPath $cfg.licenseDestPath `
                                               -LicenseFileName $cfg.licenseFileName `
                                               -BackupRoot $cfg.backupRoot

        # -- Step 3: Deploy new license ---------------------------------------
        Write-Status "STEP 3 – Deploying new license" -Level Info
        Deploy-License -Hostname $hostname `
                       -LicenseDestPath $cfg.licenseDestPath `
                       -LicenseFileName $cfg.licenseFileName `
                       -LicenseContent $license.Content

        # -- Step 4: Restart services -----------------------------------------
        Write-Status "STEP 4 – Restarting services" -Level Info
        Restart-LicenseServices -Hostname $hostname `
                                -ServiceNames $cfg.servicesToRestart

        # -- Step 5: Verify renewal -------------------------------------------
        Write-Status "STEP 5 – Verifying license renewal" -Level Info
        $verified = Test-LicenseRenewal -Hostname $hostname `
                                        -LicenseDestPath $cfg.licenseDestPath `
                                        -LicenseFileName $cfg.licenseFileName `
                                        -ExpectedContent $license.Content

        Write-Host ""
        if ($verified) {
            Write-Host "============================================" -ForegroundColor Green
            Write-Host "  LICENSE RENEWAL COMPLETED SUCCESSFULLY   " -ForegroundColor Green
            Write-Host "  Host    : $hostname"                        -ForegroundColor Green
            Write-Host "  Backup  : $backupFolder"                   -ForegroundColor Green
            Write-Host "============================================" -ForegroundColor Green
        } else {
            Write-Host "============================================" -ForegroundColor Red
            Write-Host "  LICENSE RENEWAL VERIFICATION FAILED      " -ForegroundColor Red
            Write-Host "  Please check the logs above for details.  " -ForegroundColor Red
            Write-Host "============================================" -ForegroundColor Red
            exit 1
        }

    } catch {
        Write-Host ""
        Write-Status "An error occurred during renewal: $_" -Level Error
        exit 1
    }
}

Main
