Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

function Get-OBRelativePath {
    param([Parameter(Mandatory)][string]$BasePath, [Parameter(Mandatory)][string]$TargetPath)
    $base = [Uri]((Resolve-Path -LiteralPath $BasePath).Path.TrimEnd('\') + '\')
    $target = [Uri](Resolve-Path -LiteralPath $TargetPath).Path
    [Uri]::UnescapeDataString($base.MakeRelativeUri($target).ToString()).Replace('/', '\')
}

function Get-OBInstalledPackages {
    [CmdletBinding()]
    param([object[]]$Packages)
    if ($PSBoundParameters.ContainsKey('Packages')) {
        return @($Packages | Sort-Object Version -Descending)
    }
    $exact = @(Get-AppxPackage -Name 'OpenBubbles.OpenBubbles' -ErrorAction SilentlyContinue)
    $fallback = @(Get-AppxPackage -ErrorAction Stop | Where-Object {
        $_.Name -match '^OpenBubbles([.]OpenBubbles)?$' -or
        $_.PackageFamilyName -match '^OpenBubbles[.]OpenBubbles_'
    })
    @($exact + $fallback | Group-Object PackageFullName |
        ForEach-Object { $_.Group | Select-Object -First 1 } |
        Sort-Object Version -Descending)
}

function Get-OBProfileRoots {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Package,
        [string]$LocalAppData = $env:LOCALAPPDATA
    )
    $packageRoot = Join-Path $LocalAppData "Packages\$($Package.PackageFamilyName)"
    if (-not (Test-Path -LiteralPath $packageRoot -PathType Container)) { return @() }
    $known = @(
        (Join-Path $packageRoot 'LocalCache\Roaming\OpenBubbles\openbubbles'),
        (Join-Path $packageRoot 'LocalState\OpenBubbles\openbubbles')
    )
    $roots = @($known | Where-Object { Test-Path -LiteralPath $_ -PathType Container })
    $preferenceFiles = @(Get-ChildItem -LiteralPath $packageRoot -Filter 'shared_preferences.json' -File -Recurse -ErrorAction SilentlyContinue)
    $roots += @($preferenceFiles | ForEach-Object { $_.Directory.FullName })
    @($roots | Select-Object -Unique)
}

function Get-OBDatabaseCandidates {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$ProfileRoot)
    if (-not (Test-Path -LiteralPath $ProfileRoot -PathType Container)) { return @() }
    $dataFiles = @(Get-ChildItem -LiteralPath $ProfileRoot -Filter 'data.mdb' -File -Recurse -ErrorAction SilentlyContinue)
    @($dataFiles | ForEach-Object {
        $directory = $_.Directory.FullName
        $lock = Join-Path $directory 'lock.mdb'
        [pscustomobject][ordered]@{
            directory = $directory
            relativeDirectory = Get-OBRelativePath -BasePath $ProfileRoot -TargetPath $directory
            dataPath = $_.FullName
            dataSize = $_.Length
            dataSha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
            lockPresent = Test-Path -LiteralPath $lock -PathType Leaf
        }
    })
}

function Test-OBProcessRunning {
    [CmdletBinding()]
    param()
    @(Get-Process -Name 'bluebubbles_app' -ErrorAction SilentlyContinue).Count -gt 0
}

function New-OBRedactedStatusReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Package,
        [Parameter(Mandatory)][string]$ProfileRoot
    )
    $preferencePath = Join-Path $ProfileRoot 'shared_preferences.json'
    $preferenceKeys = @()
    if (Test-Path -LiteralPath $preferencePath -PathType Leaf) {
        $prefs = Get-Content -LiteralPath $preferencePath -Raw | ConvertFrom-Json
        $preferenceKeys = @($prefs.PSObject.Properties.Name | Sort-Object)
    }
    [pscustomobject][ordered]@{
        reportVersion = 2
        generatedUtc = [DateTime]::UtcNow.ToString('o')
        package = [pscustomobject][ordered]@{
            name = $Package.Name
            version = $Package.Version.ToString()
            familyName = $Package.PackageFamilyName
            architecture = if ($Package.PSObject.Properties.Name -contains 'Architecture') { $Package.Architecture.ToString() } else { $null }
        }
        processRunning = Test-OBProcessRunning
        profileRoot = $ProfileRoot
        profileFilesPresent = [pscustomobject][ordered]@{
            hardwareInfo = Test-Path -LiteralPath (Join-Path $ProfileRoot 'hw_info.plist')
            identity = Test-Path -LiteralPath (Join-Path $ProfileRoot 'id.plist')
            googleAccount = Test-Path -LiteralPath (Join-Path $ProfileRoot 'gsa.plist')
            preferences = Test-Path -LiteralPath $preferencePath
        }
        preferenceKeys = $preferenceKeys
        databaseCandidates = @(Get-OBDatabaseCandidates -ProfileRoot $ProfileRoot)
    }
}

function Show-OBProfilePicker {
    [CmdletBinding()]
    param([Parameter(Mandatory)][object[]]$Profiles)
    if ($Profiles.Count -eq 1) { return $Profiles[0] }
    if ($Profiles.Count -eq 0) { return $null }
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    $form = New-Object Windows.Forms.Form
    $form.Text = 'OpenBubbles Contact Bridge'
    $form.Size = New-Object Drawing.Size(720, 360)
    $form.StartPosition = 'CenterScreen'
    $label = New-Object Windows.Forms.Label
    $label.Text = 'Select the OpenBubbles profile to inspect:'
    $label.AutoSize = $true
    $label.Location = New-Object Drawing.Point(16, 16)
    $form.Controls.Add($label)
    $list = New-Object Windows.Forms.ListBox
    $list.Location = New-Object Drawing.Point(16, 48)
    $list.Size = New-Object Drawing.Size(670, 220)
    foreach ($profile in $Profiles) { [void]$list.Items.Add("$($profile.package.Version) - $($profile.profileRoot)") }
    $list.SelectedIndex = 0
    $form.Controls.Add($list)
    $ok = New-Object Windows.Forms.Button
    $ok.Text = 'Continue'
    $ok.Location = New-Object Drawing.Point(505, 280)
    $ok.DialogResult = [Windows.Forms.DialogResult]::OK
    $form.AcceptButton = $ok
    $form.Controls.Add($ok)
    $cancel = New-Object Windows.Forms.Button
    $cancel.Text = 'Cancel'
    $cancel.Location = New-Object Drawing.Point(605, 280)
    $cancel.DialogResult = [Windows.Forms.DialogResult]::Cancel
    $form.CancelButton = $cancel
    $form.Controls.Add($cancel)
    if ($form.ShowDialog() -ne [Windows.Forms.DialogResult]::OK) { return $null }
    $Profiles[$list.SelectedIndex]
}

Export-ModuleMember -Function @(
    'Get-OBInstalledPackages', 'Get-OBProfileRoots', 'Get-OBDatabaseCandidates',
    'Test-OBProcessRunning', 'New-OBRedactedStatusReport', 'Show-OBProfilePicker'
)

