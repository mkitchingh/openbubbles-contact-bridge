[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'OpenBubbles.Discovery.psm1') -Force
Add-Type -AssemblyName System.Windows.Forms

$packageRoot = Split-Path $PSScriptRoot -Parent
$planner = Join-Path $packageRoot 'openbubbles-google-dry-run.exe'
if (-not (Test-Path -LiteralPath $planner -PathType Leaf)) {
    [Windows.Forms.MessageBox]::Show('The Google dry-run planner is missing. Download and extract the complete Windows artifact.', 'OpenBubbles Contact Bridge', 'OK', 'Error') | Out-Null
    exit 2
}

$snapshot = $null
try {
    $profiles = @()
    foreach ($package in @(Get-OBInstalledPackages)) {
        foreach ($root in @(Get-OBProfileRoots -Package $package)) {
            $profiles += [pscustomobject]@{ package = $package; profileRoot = $root }
        }
    }
    if ($profiles.Count -eq 0) { throw 'No initialized Microsoft Store OpenBubbles profile was found.' }
    $selected = Show-OBProfilePicker -Profiles $profiles
    if ($null -eq $selected) { exit 0 }
    if (Test-OBProcessRunning) { throw 'OpenBubbles is running. Close it completely, including its tray icon, and try again.' }
    $candidates = @(Get-OBDatabaseCandidates -ProfileRoot $selected.profileRoot)
    if ($candidates.Count -ne 1) { throw "Expected one ObjectBox database, but found $($candidates.Count). No database was opened." }

    $configDialog = New-Object Windows.Forms.OpenFileDialog
    $configDialog.Title = 'Select Google Desktop OAuth client JSON'
    $configDialog.Filter = 'Google OAuth JSON (*.json)|*.json'
    $configDialog.Multiselect = $false
    if ($configDialog.ShowDialog() -ne [Windows.Forms.DialogResult]::OK) { exit 0 }

    $saveDialog = New-Object Windows.Forms.SaveFileDialog
    $saveDialog.Title = 'Save redacted Google contact dry-run report'
    $saveDialog.Filter = 'JSON report (*.json)|*.json'
    $saveDialog.FileName = 'openbubbles-google-dry-run-report.json'
    if ($saveDialog.ShowDialog() -ne [Windows.Forms.DialogResult]::OK) { exit 0 }

    $snapshot = New-OBInspectionSnapshot -Package $selected.package -DatabaseCandidate $candidates[0]
    Push-Location $packageRoot
    try {
        & $planner --snapshot $snapshot --oauth-config $configDialog.FileName --output $saveDialog.FileName
        if ($LASTEXITCODE -ne 0) { throw "The Google dry-run planner exited with code $LASTEXITCODE." }
    } finally {
        Pop-Location
    }
    [Windows.Forms.MessageBox]::Show("Dry run completed successfully. No database writes were performed.`n`n$($saveDialog.FileName)`n`nThe OAuth access token was kept only in memory. The temporary database copy will now be removed.", 'OpenBubbles Contact Bridge', 'OK', 'Information') | Out-Null
} catch {
    [Windows.Forms.MessageBox]::Show("Dry run could not continue:`n`n$($_.Exception.Message)`n`nThe live OpenBubbles database was not opened or modified.", 'OpenBubbles Contact Bridge', 'OK', 'Error') | Out-Null
    exit 1
} finally {
    if ($null -ne $snapshot) { Remove-OBInspectionSnapshot -SnapshotRoot $snapshot }
}
