[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'OpenBubbles.Discovery.psm1') -Force
Add-Type -AssemblyName System.Windows.Forms

$packageRoot = Split-Path $PSScriptRoot -Parent
$rehearsal = Join-Path $packageRoot 'openbubbles-google-rehearsal.exe'
if (-not (Test-Path -LiteralPath $rehearsal -PathType Leaf)) {
    [Windows.Forms.MessageBox]::Show('The Google snapshot-rehearsal tool is missing. Download and extract the complete Windows artifact.', 'OpenBubbles Contact Bridge', 'OK', 'Error') | Out-Null
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

    $warning = 'This rehearsal copies the OpenBubbles database, repairs only the temporary copy, verifies it, and deletes it. The live database will not be opened or modified. Continue?'
    if ([Windows.Forms.MessageBox]::Show($warning, 'OpenBubbles Contact Bridge', 'YesNo', 'Warning') -ne [Windows.Forms.DialogResult]::Yes) { exit 0 }

    $configDialog = New-Object Windows.Forms.OpenFileDialog
    $configDialog.Title = 'Select Google Desktop OAuth client JSON'
    $configDialog.Filter = 'Google OAuth JSON (*.json)|*.json'
    $configDialog.Multiselect = $false
    if ($configDialog.ShowDialog() -ne [Windows.Forms.DialogResult]::OK) { exit 0 }

    $saveDialog = New-Object Windows.Forms.SaveFileDialog
    $saveDialog.Title = 'Save redacted snapshot-rehearsal report'
    $saveDialog.Filter = 'JSON report (*.json)|*.json'
    $saveDialog.FileName = 'openbubbles-google-rehearsal-report.json'
    if ($saveDialog.ShowDialog() -ne [Windows.Forms.DialogResult]::OK) { exit 0 }

    $snapshot = New-OBInspectionSnapshot -Package $selected.package -DatabaseCandidate $candidates[0]
    Push-Location $packageRoot
    try {
        & $rehearsal --snapshot $snapshot --oauth-config $configDialog.FileName --output $saveDialog.FileName
        if ($LASTEXITCODE -ne 0) { throw "The Google snapshot rehearsal exited with code $LASTEXITCODE." }
    } finally {
        Pop-Location
    }
    [Windows.Forms.MessageBox]::Show("Snapshot rehearsal completed successfully.`n`n$($saveDialog.FileName)`n`nThe live OpenBubbles database was not opened or modified. The repaired temporary copy will now be removed.", 'OpenBubbles Contact Bridge', 'OK', 'Information') | Out-Null
} catch {
    [Windows.Forms.MessageBox]::Show("Snapshot rehearsal could not continue:`n`n$($_.Exception.Message)`n`nThe live OpenBubbles database was not opened or modified.", 'OpenBubbles Contact Bridge', 'OK', 'Error') | Out-Null
    exit 1
} finally {
    if ($null -ne $snapshot) { Remove-OBInspectionSnapshot -SnapshotRoot $snapshot }
}
