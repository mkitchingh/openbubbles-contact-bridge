[CmdletBinding()]
param(
    [string]$DestinationRoot = (Join-Path $env:LOCALAPPDATA 'OpenBubblesContactBridge\Backups')
)

$ErrorActionPreference = 'Stop'

function Get-RelativePath([string]$BasePath, [string]$TargetPath) {
    $base = [Uri]((Resolve-Path -LiteralPath $BasePath).Path.TrimEnd('\') + '\')
    $target = [Uri](Resolve-Path -LiteralPath $TargetPath).Path
    return [Uri]::UnescapeDataString($base.MakeRelativeUri($target).ToString()).Replace('/', '\')
}

if (Get-Process -Name 'bluebubbles_app' -ErrorAction SilentlyContinue) {
    throw 'OpenBubbles is running. Close it completely before creating a backup.'
}

$package = Get-AppxPackage -Name 'OpenBubbles.OpenBubbles' |
    Sort-Object Version -Descending | Select-Object -First 1
if (-not $package) { throw 'The Microsoft Store OpenBubbles package was not found.' }

$source = Join-Path $env:LOCALAPPDATA "Packages\$($package.PackageFamilyName)\LocalCache\Roaming\OpenBubbles\openbubbles"
if (-not (Test-Path -LiteralPath $source -PathType Container)) {
    throw "The OpenBubbles profile directory was not found: $source"
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$destination = Join-Path $DestinationRoot $stamp
New-Item -ItemType Directory -Path $destination -Force | Out-Null
Copy-Item -LiteralPath $source -Destination $destination -Recurse -Force
$copiedRoot = Join-Path $destination (Split-Path $source -Leaf)

$sourceFiles = @(Get-ChildItem -LiteralPath $source -Recurse -File)
$manifest = foreach ($file in $sourceFiles) {
    $relative = Get-RelativePath $source $file.FullName
    $copyPath = Join-Path $copiedRoot $relative
    if (-not (Test-Path -LiteralPath $copyPath -PathType Leaf)) {
        throw "Backup verification failed; missing: $relative"
    }
    $sourceHash = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
    $copyHash = (Get-FileHash -LiteralPath $copyPath -Algorithm SHA256).Hash
    if ($sourceHash -ne $copyHash) { throw "Backup verification failed; hash mismatch: $relative" }
    [ordered]@{ path = $relative; size = $file.Length; sha256 = $sourceHash }
}

$manifest | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $destination 'manifest.json') -Encoding utf8
Write-Host "Verified backup created: $destination"
Write-Host "Files verified: $($sourceFiles.Count)"
Write-Host 'The backup contains private application data. Do not upload or share it.'

