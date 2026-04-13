# License Renewal Tool

A PowerShell-based tool that automates the end-to-end renewal of a software
license from a Windows network share.

---

## Features

| Step | Action |
|------|--------|
| 1 | Prompt the operator for the **target hostname** |
| 2 | **Read** the new license file from a central Windows share |
| 3 | **Back up** the existing license to a timestamped folder |
| 4 | **Deploy** the new license to the target server |
| 5 | **Restart** the configured Windows services |
| 6 | **Verify** the renewal by comparing the deployed content |

---

## Prerequisites

| Requirement | Detail |
|-------------|--------|
| PowerShell | 5.1 or later (Windows) |
| Permissions | Read access to the license share; Admin/SCM rights on the target server |
| Network | The machine running the script must reach the share and the target host via SMB (TCP 445) |

---

## Quick Start

### 1 – Clone or download this repository

```powershell
git clone https://github.com/vn511/test.git
cd test\license-renewal
```

### 2 – Create your configuration file

```powershell
Copy-Item config.example.json config.json
notepad config.json        # or your preferred editor
```

Edit the values to match your environment (see [Configuration](#configuration)).

### 3 – Run the script

```powershell
.\license_renewal.ps1
```

You will be prompted:

```
Enter the hostname of the server to renew the license on: myserver01
```

After entering the hostname the tool will automatically execute all six steps
and display a summary banner at the end.

You can also point the script at a non-default config file:

```powershell
.\license_renewal.ps1 -ConfigFile "\\centralserver\scripts\prod-config.json"
```

---

## Configuration

All runtime settings live in `config.json`.  Use `config.example.json` as a
starting point.

| Key | Type | Description | Example |
|-----|------|-------------|---------|
| `sharePath` | string | UNC path to the folder on the Windows share that contains the license file | `\\\\license-share-server\\LicenseShare` |
| `licenseFileName` | string | File name of the license | `license.lic` |
| `backupRoot` | string | Local (or UNC) folder where per-host timestamped backups are stored | `C:\\LicenseBackups` |
| `licenseDestPath` | string | **Admin share path** on the target server, written as the local path using the `C$` admin share notation | `C$\\Program Files\\YourApp\\licenses` |
| `servicesToRestart` | string[] | Names of Windows services to restart after deployment | `["YourAppService","YourAppLicenseMgr"]` |

### Example `config.json`

```json
{
  "sharePath": "\\\\license-share-server\\LicenseShare",
  "licenseFileName": "license.lic",
  "backupRoot": "C:\\LicenseBackups",
  "licenseDestPath": "C$\\Program Files\\YourApp\\licenses",
  "servicesToRestart": [
    "YourAppService",
    "YourAppLicenseManager"
  ]
}
```

---

## Output

A successful run looks like this:

```
============================================
        LICENSE RENEWAL TOOL
============================================

Enter the hostname of the server to renew the license on: myserver01
[2026-04-13 20:41:00] [Info] Target hostname: myserver01

[2026-04-13 20:41:00] [Info] STEP 1 – Reading license from network share
[2026-04-13 20:41:01] [Success] License file read successfully (2048 bytes).

[2026-04-13 20:41:01] [Info] STEP 2 – Backing up existing license
[2026-04-13 20:41:01] [Success] Existing license backed up to: C:\LicenseBackups\myserver01_20260413_204101\license.lic

[2026-04-13 20:41:01] [Info] STEP 3 – Deploying new license
[2026-04-13 20:41:02] [Success] New license deployed successfully.

[2026-04-13 20:41:02] [Info] STEP 4 – Restarting services
[2026-04-13 20:41:05] [Success] Service 'YourAppService' is Running.
[2026-04-13 20:41:08] [Success] Service 'YourAppLicenseManager' is Running.

[2026-04-13 20:41:08] [Info] STEP 5 – Verifying license renewal
[2026-04-13 20:41:08] [Success] Verification PASSED – license content matches.

============================================
  LICENSE RENEWAL COMPLETED SUCCESSFULLY
  Host    : myserver01
  Backup  : C:\LicenseBackups\myserver01_20260413_204101
============================================
```

If any step fails the script exits with code `1` and prints a red error banner.

---

## Security Notes

* The script never stores credentials in plain text.  Use Windows integrated
  authentication or a PowerShell credential prompt (`-Credential`) if your
  environment requires explicit credentials to access the share or the remote
  service manager.
* Store `config.json` in a protected location and **do not commit it** to
  version control (it is listed in `.gitignore`).

---

## Troubleshooting

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| "License file not found on share" | Wrong `sharePath` or `licenseFileName` | Verify the UNC path is accessible from the machine running the script |
| "Remote path does not exist" | Admin share `C$` not reachable | Ensure File and Printer Sharing is enabled on the target and the account has admin rights |
| Service restart fails with "Access denied" | Insufficient SCM permissions | Run PowerShell as Administrator or use a privileged service account |
| Verification fails | File written but content differs (encoding, BOM) | Check the `licenseFileName` and compare files manually with `fc` |
