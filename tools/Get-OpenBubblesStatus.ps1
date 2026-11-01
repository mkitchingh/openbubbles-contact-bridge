[CmdletBinding()]
param([string]$OutputPath = (Join-Path $PWD 'openbubbles-status.json'))
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'OpenBubbles.Discovery.psm1') -Force
$profiles = foreach ($package in @(Get-OBInstalledPackages)) {
    foreach ($root in @(Get-OBProfileRoots -Package $package)) {
        [pscustomobject]@{ package = $package; profileRoot = $root }
    }
}
if (@($profiles).Count -eq 0) { throw 'No initialized Microsoft Store OpenBubbles profile was found.' }
if (@($profiles).Count -gt 1) { throw 'Multiple OpenBubbles profiles were found. Run Start-OpenBubblesBridgeSetup.ps1 to choose one.' }
$report = New-OBRedactedStatusReport -Package $profiles[0].package -ProfileRoot $profiles[0].profileRoot
$report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $OutputPath -Encoding utf8
Write-Host "Wrote redacted status report: $OutputPath"
Write-Host "OpenBubbles running: $($report.processRunning)"
Write-Host "ObjectBox database candidates: $(@($report.databaseCandidates).Count)"
Write-Host 'No preference values, tokens, messages, contacts, or Apple registration data were included.'
