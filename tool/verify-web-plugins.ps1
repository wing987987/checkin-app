param(
    [Parameter(Mandatory = $true)]
    [string]$WebRoot
)

$ErrorActionPreference = 'Stop'
$compiledApp = [System.IO.File]::ReadAllText((Join-Path $WebRoot 'main.dart.js'))
# A native MethodChannel picker can compile successfully on Web, but every
# invocation fails. The Web implementation retains this DOM id in release builds.
if (-not $compiledApp.Contains('__image_picker_web-file-input')) {
    throw 'Web image picker is missing. Run tool\prepare-web-build.ps1 and rebuild before deployment.'
}
Write-Output 'Web image picker implementation verified.'
