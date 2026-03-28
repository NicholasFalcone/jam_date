param(
    [string]$SdkPath = $env:PLAYDATE_SDK_PATH,
    [string]$SourcePath = "source",
    [string]$OutputPath = "jam_date.pdx"
)

$ErrorActionPreference = "Stop"

if (-not $SdkPath) {
    $defaultSdkPath = Join-Path $env:USERPROFILE "Documents\PlaydateSDK"
    if (Test-Path $defaultSdkPath) {
        $SdkPath = $defaultSdkPath
    }
}

if (-not $SdkPath -or -not (Test-Path $SdkPath)) {
    throw "Playdate SDK not found. Set PLAYDATE_SDK_PATH or install the SDK in $env:USERPROFILE\Documents\PlaydateSDK."
}

$compilerPath = Join-Path $SdkPath "bin\pdc.exe"
if (-not (Test-Path $compilerPath)) {
    throw "Playdate compiler not found at $compilerPath."
}

$env:PLAYDATE_SDK_PATH = $SdkPath

Write-Host "Building Playdate project with SDK: $SdkPath"
& $compilerPath $SourcePath $OutputPath
