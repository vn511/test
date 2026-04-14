Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$scriptPath = Join-Path $repoRoot "license_renewal.ps1"
$configPath = Join-Path $repoRoot "config.localtest.json"
$artifactsPath = Join-Path $repoRoot "artifacts"
$machineName = if ($env:LICENSE_MACHINE_NAME) { $env:LICENSE_MACHINE_NAME } else { "operator-local-test" }

function Assert-True {
    param(
        [bool]$Condition,
        [string]$Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

if (Test-Path $artifactsPath) {
    Remove-Item -Path $artifactsPath -Recurse -Force
}

Write-Host "Running initial deployment test"
$global:LASTEXITCODE = 0
& $scriptPath -ConfigFile $configPath -MachineName $machineName
$exitCode = $LASTEXITCODE
if ($null -ne $exitCode -and $exitCode -ne 0) {
    throw "Initial deployment run failed with exit code $exitCode"
}

$targetLicense = Join-Path $repoRoot "artifacts\target\license.lic"
$shareLicense = Join-Path $repoRoot "test-data\share\license.lic"

Assert-True -Condition (Test-Path $targetLicense) -Message "Target license file was not created."
Assert-True -Condition ((Get-Content $targetLicense -Raw).Trim() -eq (Get-Content $shareLicense -Raw).Trim()) -Message "Target license content does not match the source license."

Write-Host "Running second deployment to validate backup creation"
$global:LASTEXITCODE = 0
& $scriptPath -ConfigFile $configPath -MachineName $machineName
$exitCode = $LASTEXITCODE
if ($null -ne $exitCode -and $exitCode -ne 0) {
    throw "Second deployment run failed with exit code $exitCode"
}

$backupRoot = Join-Path $repoRoot "artifacts\backups"
Assert-True -Condition (Test-Path $backupRoot) -Message "Backup root was not created."

$backupFiles = Get-ChildItem -Path $backupRoot -Filter "license.lic" -Recurse -File
Assert-True -Condition ($backupFiles.Count -ge 1) -Message "No backup license file was created."

Write-Host "License renewal tests passed"
