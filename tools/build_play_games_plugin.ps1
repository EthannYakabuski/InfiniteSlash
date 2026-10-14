param(
    [string]$JavaHome = 'C:/Program Files/Java/jdk-17',
    [string]$SdkRoot = 'C:/Users/swimr/AppData/Local/Android/Sdk'
)
$ErrorActionPreference = 'Stop'
$taskProjectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$taskSource = Join-Path $taskProjectRoot 'output/test-data/pgs-native-source'
$taskPatch = Join-Path $taskProjectRoot 'native/pgs/play_games_v3_4_0.patch'
if (-not (Test-Path -LiteralPath (Join-Path $taskSource 'gradlew.bat'))) {
    & git clone --depth 1 --branch v3.4.0 'https://github.com/godot-sdk-integrations/godot-play-game-services.git' $taskSource
    if ($LASTEXITCODE -ne 0) { throw 'Could not fetch the pinned upstream source.' }
}
$taskCommit = (& git -C $taskSource rev-parse HEAD).Trim()
if ($taskCommit -ne 'e38b618578572b558691c4f476f70f5e142226ce') { throw 'Unexpected upstream plugin commit.' }
& git -C $taskSource apply --reverse --check $taskPatch 2>$null
if ($LASTEXITCODE -ne 0) {
    & git -C $taskSource apply --check $taskPatch
    if ($LASTEXITCODE -ne 0) { throw 'Native patch no longer matches the source.' }
    & git -C $taskSource apply $taskPatch
    if ($LASTEXITCODE -ne 0) { throw 'Could not apply the native changes.' }
}
$env:JAVA_HOME = $JavaHome
$env:ANDROID_HOME = $SdkRoot
$env:ANDROID_SDK_ROOT = $SdkRoot
$env:GRADLE_USER_HOME = Join-Path $taskProjectRoot 'output/test-data/pgs-gradle-cache'
[IO.File]::WriteAllText((Join-Path $taskSource 'local.properties'), 'sdk.dir=' + $SdkRoot.Replace('\','/') + "`n", [Text.UTF8Encoding]::new($false))
Push-Location -LiteralPath $taskSource
try {
    & ./gradlew.bat :plugin:assembleDebug :plugin:assembleRelease --no-daemon --console=plain '-Pkotlin.compiler.execution.strategy=in-process'
    if ($LASTEXITCODE -ne 0) { throw 'Play Games native plugin build failed.' }
    foreach ($taskVariant in @('debug','release')) {
        $taskAar = Join-Path $taskSource "plugin/build/outputs/aar/GodotPlayGameServices-$taskVariant.aar"
        $taskDestination = Join-Path $taskProjectRoot "addons/GodotPlayGameServices/bin/$taskVariant/GodotPlayGameServices-$taskVariant.aar"
        Copy-Item -LiteralPath $taskAar -Destination $taskDestination -Force
        Write-Output "$taskVariant AAR SHA-256: $((Get-FileHash -LiteralPath $taskDestination -Algorithm SHA256).Hash.ToLowerInvariant())"
    }
} finally { Pop-Location }
