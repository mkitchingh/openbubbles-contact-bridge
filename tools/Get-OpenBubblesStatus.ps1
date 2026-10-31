[CmdletBinding()]
param(
    [string]$OutputPath = (Join-Path $PWD "openbubbles-status.json")
)

$ErrorActionPreference = 'Stop'
$packageName = 'OpenBubbles.OpenBubbles'

function Get-RelativePath([string]$BasePath, [string]$TargetPath) {
    $base = [Uri]((Resolve-Path -LiteralPath $BasePath).Path.TrimEnd('\') + '\')
    $target = [Uri](Resolve-Path -LiteralPath $TargetPath).Path
    return [Uri]::UnescapeDataString($base.MakeRelativeUri($target).ToString()).Replace('/', '\')
}

$package = Get-AppxPackage -Name $packageName | Sort-Object Version -Descending | Select-Object -First 1
if (-not $package) { throw "The Microsoft Store OpenBubbles package was not found." }

$running = @(Get-Process -Name 'bluebubbles_app' -ErrorAction SilentlyContinue).Count -gt 0
$profileRoot = Join-Path $env:LOCALAPPDATA "Packages\$($package.PackageFamilyName)\LocalCache\Roaming\OpenBubbles\openbubbles"
if (-not (Test-Path -LiteralPath $profileRoot -PathType Container)) {
    throw "The OpenBubbles profile directory was not found: $profileRoot"
}

$preferencePath = Join-Path $profileRoot 'shared_preferences.json'
$preferenceKeys = @()
if (Test-Path -LiteralPath $preferencePath -PathType Leaf) {
    $prefs = Get-Content -LiteralPath $preferencePath -Raw | ConvertFrom-Json
    $preferenceKeys = @($prefs.PSObject.Properties.Name | Sort-Object)
}

$objectBoxFiles = @(Get-ChildItem -LiteralPath $profileRoot -Recurse -File -ErrorAction Stop |
    Where-Object { $_.Name -match '^(data\.mdb|lock\.mdb|objectbox-model\.json)$' -or $_.DirectoryName -match 'objectbox' })

$fileFacts = @($objectBoxFiles | ForEach-Object {
    [ordered]@{
        relativePath = Get-RelativePath $profileRoot $_.FullName
        size = $_.Length
        sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
    }
})

$report = [ordered]@{
    generatedUtc = [DateTime]::UtcNow.ToString('o')
    package = [ordered]@{
        name = $package.Name
        version = $package.Version.ToString()
        familyName = $package.PackageFamilyName
        installLocation = $package.InstallLocation
    }
    processRunning = $running
    profileRoot = $profileRoot
    profileFilesPresent = [ordered]@{
        hardwareInfo = Test-Path -LiteralPath (Join-Path $profileRoot 'hw_info.plist')
        identity = Test-Path -LiteralPath (Join-Path $profileRoot 'id.plist')
        googleAccount = Test-Path -LiteralPath (Join-Path $profileRoot 'gsa.plist')
        preferences = Test-Path -LiteralPath $preferencePath
    }
    preferenceKeys = $preferenceKeys
    objectBoxCandidates = $fileFacts
}

$report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $OutputPath -Encoding utf8
Write-Host "Wrote redacted status report: $OutputPath"
Write-Host "OpenBubbles running: $running"
Write-Host "ObjectBox candidate files: $($fileFacts.Count)"
Write-Host "No preference values, tokens, messages, or contact data were included."

