$ErrorActionPreference = 'Stop'
$module = Join-Path (Split-Path $PSScriptRoot -Parent) 'tools\OpenBubbles.Discovery.psm1'
Import-Module $module -Force
$temp = Join-Path ([IO.Path]::GetTempPath()) ("ob-bridge-test-" + [Guid]::NewGuid().ToString('N'))
try {
    $family = 'OpenBubbles.OpenBubbles_test123'
    $profile = Join-Path $temp "Packages\$family\LocalCache\Roaming\OpenBubbles\openbubbles"
    $database = Join-Path $profile 'objectbox'
    New-Item -ItemType Directory -Path $database -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $profile 'shared_preferences.json') -Encoding utf8 -Value '{"theme":"dark","oauthToken":"must-not-leak"}'
    Set-Content -LiteralPath (Join-Path $database 'data.mdb') -Encoding ascii -Value 'fixture'
    Set-Content -LiteralPath (Join-Path $database 'lock.mdb') -Encoding ascii -Value 'lock'
    $package = [pscustomobject]@{ Name = 'OpenBubbles.OpenBubbles'; Version = [Version]'1.18.800.0'; PackageFamilyName = $family; Architecture = 'X64'; PackageFullName = 'fixture' }
    $packages = @(Get-OBInstalledPackages -Packages @($package))
    if ($packages.Count -ne 1) { throw 'Package discovery self-test failed.' }
    $roots = @(Get-OBProfileRoots -Package $package -LocalAppData $temp)
    if ($roots.Count -ne 1 -or $roots[0] -ne $profile) { throw 'Profile discovery self-test failed.' }
    $candidates = @(Get-OBDatabaseCandidates -ProfileRoot $profile)
    if ($candidates.Count -ne 1 -or -not $candidates[0].lockPresent) { throw 'Database discovery self-test failed.' }
    $report = New-OBRedactedStatusReport -Package $package -ProfileRoot $profile
    $json = $report | ConvertTo-Json -Depth 8
    if ($json -match 'must-not-leak') { throw 'Redaction self-test failed.' }
    if ($report.preferenceKeys -notcontains 'oauthToken') { throw 'Preference-key inventory self-test failed.' }
    if (@($report.databaseCandidates).Count -ne 1) { throw 'Report database inventory self-test failed.' }
    $snapshotRoot = Join-Path $temp 'snapshots'
    $snapshot = New-OBInspectionSnapshot -Package $package -DatabaseCandidate $candidates[0] -DestinationRoot $snapshotRoot
    $markerPath = Join-Path $snapshot 'inspection-snapshot.json'
    if (-not (Test-Path -LiteralPath $markerPath -PathType Leaf)) { throw 'Snapshot marker self-test failed.' }
    $marker = Get-Content -LiteralPath $markerPath -Raw | ConvertFrom-Json
    $snapshotData = Join-Path $snapshot 'objectbox\data.mdb'
    if (-not (Test-Path -LiteralPath $snapshotData -PathType Leaf)) { throw 'Snapshot copy self-test failed.' }
    if ($marker.dataSha256 -ne (Get-FileHash -LiteralPath $snapshotData -Algorithm SHA256).Hash) { throw 'Snapshot hash self-test failed.' }
    Write-Host 'Windows discovery self-test passed.'
} finally {
    if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Recurse -Force }
}
