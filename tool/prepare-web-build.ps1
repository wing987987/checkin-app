$ErrorActionPreference = 'Stop'
$projectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$cacheRoot = Join-Path $projectRoot '.dart_tool\flutter_build'

# Flutter can reuse a web entrypoint from before a plugin was added. Force
# regeneration of its plugin list without deleting Android or dependency caches.
if (Test-Path -LiteralPath $cacheRoot) {
    Get-ChildItem -LiteralPath $cacheRoot -Directory | ForEach-Object {
        $stamp = Join-Path $_.FullName 'web_entrypoint.stamp'
        if (Test-Path -LiteralPath $stamp -PathType Leaf) {
            Remove-Item -LiteralPath $stamp -Force
        }
    }
}
Write-Output 'Web plugin registration will be regenerated.'
