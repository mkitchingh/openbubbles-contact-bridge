[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'OpenBubbles.Discovery.psm1') -Force
Add-Type -AssemblyName System.Windows.Forms
try {
    $packages = @(Get-OBInstalledPackages)
    if ($packages.Count -eq 0) {
        [Windows.Forms.MessageBox]::Show('No supported Microsoft Store OpenBubbles installation was found for the current Windows user.', 'OpenBubbles Contact Bridge', 'OK', 'Warning') | Out-Null
        exit 2
    }
    $profiles = @()
    foreach ($package in $packages) {
        foreach ($root in @(Get-OBProfileRoots -Package $package)) {
            $profiles += [pscustomobject]@{ package = $package; profileRoot = $root }
        }
    }
    if ($profiles.Count -eq 0) {
        [Windows.Forms.MessageBox]::Show('OpenBubbles is installed, but no initialized profile was found. Open the Store app once, then try again.', 'OpenBubbles Contact Bridge', 'OK', 'Warning') | Out-Null
        exit 3
    }
    $selected = Show-OBProfilePicker -Profiles $profiles
    if ($null -eq $selected) { exit 0 }
    if (Test-OBProcessRunning) {
        [Windows.Forms.MessageBox]::Show('OpenBubbles is running. Close it completely before database inspection. No files were accessed.', 'OpenBubbles Contact Bridge', 'OK', 'Warning') | Out-Null
        exit 4
    }
    $report = New-OBRedactedStatusReport -Package $selected.package -ProfileRoot $selected.profileRoot
    if (@($report.databaseCandidates).Count -eq 0) {
        [Windows.Forms.MessageBox]::Show('The profile was found, but no ObjectBox data.mdb file was detected. No changes were made.', 'OpenBubbles Contact Bridge', 'OK', 'Warning') | Out-Null
        exit 5
    }
    $dialog = New-Object Windows.Forms.SaveFileDialog
    $dialog.Title = 'Save redacted OpenBubbles diagnostic'
    $dialog.Filter = 'JSON report (*.json)|*.json'
    $dialog.FileName = 'openbubbles-status.json'
    if ($dialog.ShowDialog() -ne [Windows.Forms.DialogResult]::OK) { exit 0 }
    $report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $dialog.FileName -Encoding utf8
    [Windows.Forms.MessageBox]::Show("The redacted report was saved successfully.`n`n$($dialog.FileName)`n`nIt contains no preference values, tokens, messages, contacts, or Apple registration data.", 'OpenBubbles Contact Bridge', 'OK', 'Information') | Out-Null
} catch {
    [Windows.Forms.MessageBox]::Show("Setup could not continue:`n`n$($_.Exception.Message)`n`nNo changes were made.", 'OpenBubbles Contact Bridge', 'OK', 'Error') | Out-Null
    exit 1
}

