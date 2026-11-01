[CmdletBinding()]
param([string]$DestinationRoot)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'OpenBubbles.Discovery.psm1') -Force
$profiles = foreach ($package in @(Get-OBInstalledPackages)) {
    foreach ($root in @(Get-OBProfileRoots -Package $package)) {
        [pscustomobject]@{ package = $package; profileRoot = $root }
    }
}
if (@($profiles).Count -ne 1) {
    throw 'Exactly one initialized profile is required by this command-line helper. Use the setup wizard when multiple profiles exist.'
}
if (Test-OBProcessRunning) { throw 'OpenBubbles is running. Close it completely and try again.' }
$candidates = @(Get-OBDatabaseCandidates -ProfileRoot $profiles[0].profileRoot)
if ($candidates.Count -ne 1) { throw 'Exactly one ObjectBox database candidate is required.' }
$parameters = @{ Package = $profiles[0].package; DatabaseCandidate = $candidates[0] }
if ($PSBoundParameters.ContainsKey('DestinationRoot')) { $parameters.DestinationRoot = $DestinationRoot }
$snapshot = New-OBInspectionSnapshot @parameters
Write-Host "Created and verified inspection snapshot: $snapshot"
Write-Host 'The original OpenBubbles database was not opened or modified.'

