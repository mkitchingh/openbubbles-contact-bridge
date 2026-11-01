[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'OpenBubbles.Discovery.psm1') -Force
Add-Type -AssemblyName System.Windows.Forms

$packageRoot = Split-Path $PSScriptRoot -Parent
$inspector = Join-Path $packageRoot 'openbubbles-db-inspector.exe'
if (-not (Test-Path -LiteralPath $inspector -PathType Leaf)) {
    [Windows.Forms.MessageBox]::Show('The compiled database inspector is missing. Download and extract the complete Windows artifact before running this wizard.', 'OpenBubbles Contact Bridge', 'OK', 'Error') | Out-Null
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

    $dialog = New-Object Windows.Forms.SaveFileDialog
    $dialog.Title = 'Save redacted ObjectBox inspection report'
    $dialog.Filter = 'JSON report (*.json)|*.json'
    $dialog.FileName = 'openbubbles-database-report.json'
    if ($dialog.ShowDialog() -ne [Windows.Forms.DialogResult]::OK) { exit 0 }

    $snapshot = New-OBInspectionSnapshot -Package $selected.package -DatabaseCandidate $candidates[0]
    Push-Location $packageRoot
    try {
        & $inspector --snapshot $snapshot --output $dialog.FileName
        if ($LASTEXITCODE -ne 0) { throw "The database inspector exited with code $LASTEXITCODE." }
    } finally {
        Pop-Location
    }
    [Windows.Forms.MessageBox]::Show("Inspection completed successfully.`n`n$($dialog.FileName)`n`nThe temporary database copy will now be removed.", 'OpenBubbles Contact Bridge', 'OK', 'Information') | Out-Null
} catch {
    [Windows.Forms.MessageBox]::Show("Inspection could not continue:`n`n$($_.Exception.Message)`n`nThe live OpenBubbles database was not opened or modified.", 'OpenBubbles Contact Bridge', 'OK', 'Error') | Out-Null
    exit 1
} finally {
    if ($null -ne $snapshot) { Remove-OBInspectionSnapshot -SnapshotRoot $snapshot }
}

