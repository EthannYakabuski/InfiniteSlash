param(
    [string]$GodotPath = (Join-Path $env:USERPROFILE 'Downloads\Godot_v4.5.1-stable_win64.exe\Godot_v4.5.1-stable_win64_console.exe'),
    [string]$SourceGodotDirectory = (Join-Path $env:USERPROFILE 'AppData\Roaming\Godot'),
    [string]$Preset = 'AndroidDebug',
    [string]$OutputPath = '',
    [switch]$Release,
    [switch]$Unsigned
)

$ErrorActionPreference = 'Stop'
$projectDirectory = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) {
    throw "Godot executable was not found: $GodotPath"
}
$versionOutput = (& $GodotPath --version | Select-Object -First 1).Trim()
if ($versionOutput -notmatch '^(\d+)\.(\d+)(?:\.(\d+))?\.([A-Za-z0-9]+)') {
    throw "Could not determine Godot export-template version: $versionOutput"
}
$templateVersion = $Matches[0]
$editorVersion = "$($Matches[1]).$($Matches[2])"
$sourceSettings = Join-Path $SourceGodotDirectory "editor_settings-$editorVersion.tres"
$sourceTemplates = Join-Path $SourceGodotDirectory "export_templates\$templateVersion"
if (-not (Test-Path -LiteralPath $sourceSettings -PathType Leaf)) {
    throw "Configure Android SDK and Java in Godot first; editor settings are missing: $sourceSettings"
}
$projectSettings = [IO.File]::ReadAllText((Join-Path $projectDirectory 'project.godot'))
if ($projectSettings -notmatch 'textures/vram_compression/import_etc2_astc\s*=\s*true') {
    throw 'Android export requires rendering/textures/vram_compression/import_etc2_astc=true in project.godot.'
}

$runtimeDirectory = Join-Path $projectDirectory 'output\test-data\export-runtime'
$cacheDirectory = Join-Path $projectDirectory 'output\test-data\export-cache'
$isolatedGodotDirectory = Join-Path $runtimeDirectory 'Godot'
$isolatedTemplates = Join-Path $isolatedGodotDirectory "export_templates\$templateVersion"
$reviewDirectory = Join-Path $projectDirectory 'output\review'
New-Item -ItemType Directory -Path $isolatedGodotDirectory, $isolatedTemplates, $cacheDirectory, $reviewDirectory -Force | Out-Null

# Copy configuration and official installed templates into writable workspace storage.
# Paths inside editor settings still point to the existing SDK, JDK, and debug key.
Copy-Item -LiteralPath $sourceSettings -Destination (Join-Path $isolatedGodotDirectory "editor_settings-$editorVersion.tres") -Force
foreach ($templateName in @('android_debug.apk', 'android_release.apk', 'version.txt')) {
    $sourceTemplate = Join-Path $sourceTemplates $templateName
    if (-not (Test-Path -LiteralPath $sourceTemplate -PathType Leaf)) {
        throw "Install matching Godot Android export templates first: $sourceTemplate"
    }
    $destinationTemplate = Join-Path $isolatedTemplates $templateName
    if (-not (Test-Path -LiteralPath $destinationTemplate) -or
        (Get-Item -LiteralPath $destinationTemplate).Length -ne (Get-Item -LiteralPath $sourceTemplate).Length) {
        Copy-Item -LiteralPath $sourceTemplate -Destination $destinationTemplate -Force
    }
}

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path $projectDirectory 'builds\InfiniteSlash-debug.apk'
} elseif (-not [IO.Path]::IsPathRooted($OutputPath)) {
    $OutputPath = Join-Path $projectDirectory $OutputPath
}
$OutputPath = [IO.Path]::GetFullPath($OutputPath)
New-Item -ItemType Directory -Path ([IO.Path]::GetDirectoryName($OutputPath)) -Force | Out-Null
$engineLog = Join-Path $reviewDirectory 'android_export.log'
$stdoutLog = Join-Path $reviewDirectory 'android_export_stdout.log'
# Check before launching Godot, so a second overlapping export cannot leave
# an orphan engine process when the output file is already held open.
try {
    $taskLogProbe = [IO.File]::Open($stdoutLog, [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::Write, [IO.FileShare]::None)
    $taskLogProbe.Dispose()
} catch {
    throw 'Another Android export is still holding the output log. Wait for that helper to finish.'
}
$previousAppData = $env:APPDATA
$previousLocalAppData = $env:LOCALAPPDATA
$previousGradleHome = $env:GRADLE_USER_HOME
$previousGradleOpts = $env:GRADLE_OPTS
$presetsPath = Join-Path $projectDirectory 'export_presets.cfg'
$signaturePattern = '(?s)(\[preset\.1\.options\][^\[]*?package/signed=)(true|false)'
$originalSigned = ''
if ($Unsigned) {
    if (-not $Release -or $Preset -ne 'AndroidPlay') { throw 'Unsigned export is restricted to the AndroidPlay release preparation.' }
    $presetsText = [IO.File]::ReadAllText($presetsPath)
    $signatureMatch = [regex]::Match($presetsText, $signaturePattern)
    if (-not $signatureMatch.Success) { throw 'Could not locate AndroidPlay signing setting.' }
    $originalSigned = $signatureMatch.Groups[2].Value
    [IO.File]::WriteAllText($presetsPath, [regex]::Replace($presetsText, $signaturePattern, '${1}false'), [Text.UTF8Encoding]::new($false))
}

Push-Location -LiteralPath $projectDirectory
try {
    $env:APPDATA = $runtimeDirectory
    $env:LOCALAPPDATA = $cacheDirectory
    $env:GRADLE_USER_HOME = Join-Path $projectDirectory 'output\test-data\pgs-gradle-cache'
    # A persistent Gradle daemon can retain the Windows console output pipe
    # after Godot exits, preventing this helper from reaching hash/finally.
    $env:GRADLE_OPTS = "$previousGradleOpts -Dorg.gradle.daemon=false".Trim()
    $exportMode = if ($Release) { '--export-release' } else { '--export-debug' }
    $arguments = @('--headless', '--editor', '--path', $projectDirectory,
        '--log-file', $engineLog, $exportMode, $Preset, $OutputPath)
    & $GodotPath @arguments 2>&1 | Out-File -LiteralPath $stdoutLog -Encoding utf8
    $exportExitCode = $LASTEXITCODE
    if ($exportExitCode -ne 0) {
        Get-Content -LiteralPath $stdoutLog -Tail 25 | Write-Host
        throw "Android export failed (exit $exportExitCode). See $engineLog"
    }
    if (-not (Test-Path -LiteralPath $OutputPath -PathType Leaf) -or (Get-Item -LiteralPath $OutputPath).Length -le 0) {
        throw 'Godot returned success but did not produce a nonempty APK.'
    }
    $apkHash = (Get-FileHash -LiteralPath $OutputPath -Algorithm SHA256).Hash.ToLowerInvariant()
    [IO.File]::WriteAllText("$OutputPath.sha256", "$apkHash  $([IO.Path]::GetFileName($OutputPath))`n", [Text.UTF8Encoding]::new($false))
    Write-Host "Exported $OutputPath ($([Math]::Round((Get-Item -LiteralPath $OutputPath).Length / 1MB, 2)) MiB)"
    Write-Host "SHA-256: $apkHash"
    Write-Host "Export log: $engineLog"
} finally {
    $env:APPDATA = $previousAppData
    $env:LOCALAPPDATA = $previousLocalAppData
    $env:GRADLE_USER_HOME = $previousGradleHome
    $env:GRADLE_OPTS = $previousGradleOpts
    if ($Unsigned) {
        $presetsText = [IO.File]::ReadAllText($presetsPath)
        [IO.File]::WriteAllText($presetsPath, [regex]::Replace($presetsText, $signaturePattern, '${1}' + $originalSigned), [Text.UTF8Encoding]::new($false))
    }
    Pop-Location
}
