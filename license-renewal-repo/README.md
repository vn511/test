# License Renewal Standalone Repository

This folder is a standalone version of the license renewal application so it can
be moved into its own Git repository and built or tested separately from the
chat application repository.

## What changed

- The tool is isolated under its own repository-style folder.
- The operator can provide the machine name interactively or with `-MachineName`.
- A local integration test flow is included for repeatable validation.
- A GitHub Actions workflow is included for Windows-based CI.

## Repository layout

```text
license-renewal-repo/
  .github/workflows/ci.yml
  config.example.json
  config.localtest.json
  license_renewal.ps1
  tests/Invoke-LicenseRenewalTests.ps1
  test-data/share/license.lic
```

## Running locally

### One-click batch launcher for operators

Use `Run-LicenseRenewal.bat` from File Explorer or Command Prompt. It will:

- Prompt for machine name when not provided
- Use `config.json` by default
- Run the PowerShell renewal script with execution policy bypass for that run

Examples:

```cmd
Run-LicenseRenewal.bat
Run-LicenseRenewal.bat APP-SERVER-01
Run-LicenseRenewal.bat APP-SERVER-01 D:\ops\license\config.json
```

### Interactive operator prompt

```powershell
Copy-Item .\config.example.json .\config.json
notepad .\config.json
.\license_renewal.ps1
```

The script prompts the operator with:

```text
Enter the machine name for the license renewal target
```

### Non-interactive run

```powershell
.\license_renewal.ps1 -ConfigFile .\config.json -MachineName APP-SERVER-01
```

## Running the included local test

This test does not require a remote share or remote server. It uses the
`localPath` mode from `config.localtest.json`.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\Invoke-LicenseRenewalTests.ps1
```

## GitHub Actions

The workflow is in `.github/workflows/ci.yml` and runs on `windows-latest`.

It performs:

- PowerShell syntax validation
- Local integration test execution
- Artifact upload of generated backup and target files

### Manual run with operator machine name

Use **Run workflow** in GitHub Actions and enter the `machine_name` input.
That value is passed into the test run as the operator-supplied machine name.

Important:

- The provided GitHub Actions workflow is designed for safe local-path testing.
- Real production renewal against network shares and remote services should run
  from an operator workstation or a self-hosted Windows runner with the
  required network access and permissions.

## Moving this into a new GitHub repository

From the parent workspace:

```powershell
cd .\license-renewal-repo
git init
git add .
git commit -m "Initial standalone license renewal tool"
git branch -M main
git remote add origin https://github.com/<your-org>/<your-new-repo>.git
git push -u origin main
```

## Configuration notes

`targetMode` supports two values:

- `adminShare`: deploy to `\\MachineName\C$\...` style paths for real renewal runs.
- `localPath`: deploy to a local folder for tests and CI.

`config.example.json` is for real environments.

`config.localtest.json` is for repeatable local and CI validation.
