param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('prod', 'test')]
    [string]$Environment
)

$ErrorActionPreference = 'Stop'
$configPath = Join-Path $PSScriptRoot 'web-deploy.local.ps1'
if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) {
    throw 'Missing tool/web-deploy.local.ps1. Copy web-deploy.example.ps1 and fill in the SSH target and directories.'
}
. $configPath

if ($SshTarget -notmatch '^[A-Za-z0-9_][A-Za-z0-9._@-]*$' -or $SshTarget -like '*example.com*') {
    throw 'Set a valid SSH target in tool/web-deploy.local.ps1.'
}
if ($SshPort -notmatch '^\d+$' -or [int]$SshPort -lt 1 -or [int]$SshPort -gt 65535) {
    throw 'Set a valid SSH port in tool/web-deploy.local.ps1.'
}
if (-not (Test-Path -LiteralPath $SshKeyPath -PathType Leaf)) {
    throw 'SSH .pem key was not found. Check SshKeyPath in tool/web-deploy.local.ps1.'
}

$remoteDirectory = if ($Environment -eq 'prod') { $ProdDirectory } else { $TestDirectory }
$permissionRoot = if ($Environment -eq 'prod') { '/data/static-5100' } else { '/data/static-5200' }
if ($remoteDirectory -notmatch "^$permissionRoot(?:/[A-Za-z0-9._-]+)+$" -or
        $remoteDirectory -like '*REPLACE_WITH*' -or
        @($remoteDirectory.Split('/')) -contains '..' -or
        @($remoteDirectory.Split('/')) -contains '.') {
    throw "Set the exact Web directory under $permissionRoot in tool/web-deploy.local.ps1."
}

$projectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$source = Join-Path $projectRoot "build/web-$Environment"
foreach ($relativePath in @('index.html', 'flutter_bootstrap.js', 'main.dart.js',
        'assets/AssetManifest.bin.json', 'assets/FontManifest.json')) {
    if (-not (Test-Path -LiteralPath (Join-Path $source $relativePath) -PathType Leaf)) {
        throw "Web package is incomplete: $relativePath is missing."
    }
}

Write-Output "Uploading $Environment Web files to $SshTarget`:$remoteDirectory"
& ssh -i $SshKeyPath -p $SshPort $SshTarget "mkdir -p '$remoteDirectory'"
if ($LASTEXITCODE -ne 0) { throw 'Could not create the remote Web directory.' }

& scp -i $SshKeyPath -P $SshPort -r (Join-Path $source '.') "${SshTarget}:$remoteDirectory/"
if ($LASTEXITCODE -ne 0) { throw 'Web file upload failed. Permissions were not changed.' }

& ssh -i $SshKeyPath -p $SshPort $SshTarget "chmod -R 755 '$permissionRoot'"
if ($LASTEXITCODE -ne 0) { throw 'Web files were uploaded, but chmod failed.' }

Write-Output "Web deployment complete: $Environment"
