param(
    [ValidateSet('prepare', 'start', 'stop')][string]$Action = 'prepare',
    [string]$SdkRoot = 'C:/Users/swimr/AppData/Local/Android/Sdk',
    [string]$JavaHome = 'C:/Program Files/Java/jdk-17',
    [ValidateRange(5554, 5682)][int]$Port = 5580,
    [ValidateSet('host', 'swiftshader_indirect')][string]$Gpu = 'host'
)
$ErrorActionPreference = 'Stop'
if ($Port % 2 -ne 0) { throw 'The emulator console port must be even.' }
$taskProjectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$taskEmulatorRoot = [IO.Path]::GetFullPath((Join-Path $taskProjectRoot 'output/android-test'))
if (-not $taskEmulatorRoot.StartsWith($taskProjectRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'The test emulator must remain inside this checkout.'
}
$taskAvdPath = Join-Path $taskEmulatorRoot 'avd/InfiniteSlash_Test.avd'
$taskAdb = Join-Path $SdkRoot 'platform-tools/adb.exe'
$taskAvdManager = Join-Path $SdkRoot 'cmdline-tools/latest/bin/avdmanager.bat'
$taskEmulatorExe = Join-Path $SdkRoot 'emulator/emulator.exe'
$taskSerial = "emulator-$Port"
foreach ($taskRequired in @($taskAdb, $taskAvdManager, $taskEmulatorExe, (Join-Path $JavaHome 'bin/java.exe'),
    (Join-Path $SdkRoot 'system-images/android-30/google_apis/x86/package.xml'))) {
    if (-not (Test-Path -LiteralPath $taskRequired)) { throw "Missing installed prerequisite: $taskRequired" }
}
New-Item -ItemType Directory -Path $taskEmulatorRoot,(Join-Path $taskEmulatorRoot 'avd'),(Join-Path $taskEmulatorRoot 'user') -Force | Out-Null
$env:JAVA_HOME = $JavaHome
$env:ANDROID_AVD_HOME = Join-Path $taskEmulatorRoot 'avd'
$env:ANDROID_USER_HOME = Join-Path $taskEmulatorRoot 'user'
$env:ANDROID_SDK_ROOT = $SdkRoot
$env:ANDROID_HOME = $SdkRoot

if ($Action -eq 'stop') {
    $taskAvdName = & $taskAdb -s $taskSerial emu avd name 2>$null
    if ($LASTEXITCODE -ne 0 -or -not ($taskAvdName -contains 'InfiniteSlash_Test')) {
        throw "Selected serial is not the isolated InfiniteSlash test AVD: $taskSerial"
    }
    & $taskAdb -s $taskSerial emu kill
    if ($LASTEXITCODE -ne 0) { throw 'Could not stop the selected test emulator.' }
    exit 0
}

if (-not (Test-Path -LiteralPath (Join-Path $taskAvdPath 'config.ini'))) {
    'no' | & $taskAvdManager create avd --name InfiniteSlash_Test --package 'system-images;android-30;google_apis;x86' --device pixel_3a --path $taskAvdPath
    if ($LASTEXITCODE -ne 0) { throw 'Could not create the isolated test AVD.' }
}
$taskAvdIndex = Join-Path $env:ANDROID_AVD_HOME 'InfiniteSlash_Test.ini'
$taskExpectedPath = [IO.Path]::GetFullPath($taskAvdPath)
$taskRecordedPath = (Get-Content -LiteralPath $taskAvdIndex | Where-Object { $_ -match '^path=' }) -replace '^path=', ''
if ([IO.Path]::GetFullPath($taskRecordedPath) -ne $taskExpectedPath) {
    throw 'AVD registration does not point to this checkout; it will not be changed.'
}
if ($Action -eq 'prepare') {
    Write-Output "Prepared isolated API30 portrait x86 test AVD at $taskAvdPath"
    exit 0
}

$taskConnected = & $taskAdb devices 2>$null
if ($taskConnected -match "^$taskSerial\s") {
    $taskAvdName = & $taskAdb -s $taskSerial emu avd name 2>$null
    if (-not ($taskAvdName -contains 'InfiniteSlash_Test')) { throw "Console port $Port belongs to another emulator." }
    Write-Output "$taskSerial is already running the isolated test AVD."
    exit 0
}
$taskProcess = Start-Process -FilePath $taskEmulatorExe -ArgumentList @('-avd', 'InfiniteSlash_Test', '-port', "$Port",
    '-no-window', '-no-audio', '-no-snapshot', '-no-metrics', '-no-boot-anim', '-gpu', $Gpu, '-memory', '2048') `
    -WindowStyle Hidden -RedirectStandardOutput (Join-Path $taskEmulatorRoot 'emulator.stdout.log') `
    -RedirectStandardError (Join-Path $taskEmulatorRoot 'emulator.stderr.log') -PassThru
$taskProcess.Id | Set-Content -LiteralPath (Join-Path $taskEmulatorRoot 'emulator.pid')
Write-Output "Started $taskSerial (PID $($taskProcess.Id)); wait until sys.boot_completed is 1 before installing the APK."
