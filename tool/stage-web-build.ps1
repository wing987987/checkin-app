param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('prod', 'test')]
    [string]$Environment
)

$ErrorActionPreference = 'Stop'
$projectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$buildRoot = [System.IO.Path]::GetFullPath((Join-Path $projectRoot 'build'))
$source = Join-Path $buildRoot 'web'
$target = [System.IO.Path]::GetFullPath((Join-Path $buildRoot "web-$Environment"))

if (-not $target.StartsWith($buildRoot + [System.IO.Path]::DirectorySeparatorChar,
        [System.StringComparison]::OrdinalIgnoreCase)) {
    throw 'Web output directory is outside the build directory.'
}

foreach ($relativePath in @('index.html', 'flutter_bootstrap.js', 'main.dart.js',
        'assets/AssetManifest.bin.json', 'assets/FontManifest.json')) {
    if (-not (Test-Path -LiteralPath (Join-Path $source $relativePath) -PathType Leaf)) {
        throw "Flutter build is incomplete: $relativePath is missing."
    }
}

if (Test-Path -LiteralPath $target) {
    if ((Get-Item -LiteralPath $target -Force).Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
        throw 'Web output directory must not be a symbolic link.'
    }
    Remove-Item -LiteralPath $target -Recurse -Force
}

Copy-Item -LiteralPath $source -Destination $target -Recurse

if (-not (Test-Path -LiteralPath (Join-Path $target 'assets/AssetManifest.bin.json') -PathType Leaf)) {
    throw 'Staged Web output is missing its assets.'
}

Write-Output "Complete Web package: $target"
