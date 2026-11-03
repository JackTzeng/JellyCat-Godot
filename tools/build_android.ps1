[CmdletBinding()]
param(
    [string]$GodotPath = $env:GODOT_CONSOLE_PATH,
    [string]$AndroidSdkPath = $env:ANDROID_SDK_ROOT,
    [string]$JavaSdkPath = $env:JAVA_HOME,
    [string]$GodotTemplatePath,
    [string]$KeystorePath,
    [string]$OutputPath
)

if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Output "ANDROID_BUILD_STATUS=BLOCKED reason=PowerShell_7_or_later_required"
    Write-Output "ANDROID_EXPORT_STATUS=NOT_RUN reason=unsupported_PowerShell_version"
    exit 2
}

$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $false
$projectRoot = (Resolve-Path -LiteralPath (Split-Path -Parent $PSScriptRoot)).Path
$gateTest = Join-Path $PSScriptRoot "test_android_build_gate.py"
$script:gateFailures = [System.Collections.Generic.List[string]]::new()
$oldAppData = $env:APPDATA
$isolatedHome = Join-Path $env:TEMP ("JellyCatAndroid-" + [guid]::NewGuid().ToString("N"))
$pendingOutput = $null
$pendingSha = $null
$exitCode = 0
$keystorePathWasSupplied = -not [string]::IsNullOrWhiteSpace($KeystorePath)

if ([string]::IsNullOrWhiteSpace($GodotPath)) {
    $godotCommand = Get-Command godot -ErrorAction SilentlyContinue
    if ($null -ne $godotCommand) { $GodotPath = $godotCommand.Source }
}
if ([string]::IsNullOrWhiteSpace($GodotPath)) {
    $desktopCandidate = Join-Path ([Environment]::GetFolderPath("Desktop")) "Godot_v4.2.1-stable_win64.exe\Godot_v4.2.1-stable_win64_console.exe"
    if (Test-Path -LiteralPath $desktopCandidate -PathType Leaf) { $GodotPath = $desktopCandidate }
}
if ([string]::IsNullOrWhiteSpace($AndroidSdkPath)) { $AndroidSdkPath = $env:ANDROID_HOME }
if ([string]::IsNullOrWhiteSpace($OutputPath)) { $OutputPath = Join-Path $projectRoot "exports\builds\android\JellyCat-debug.apk" }
if (-not [System.IO.Path]::IsPathRooted($OutputPath)) { $OutputPath = Join-Path $projectRoot $OutputPath }
if ([string]::IsNullOrWhiteSpace($GodotTemplatePath)) { $GodotTemplatePath = Join-Path $oldAppData "Godot\export_templates\4.2.1.stable" }
if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) {
    Write-Output "ANDROID_BUILD_STATUS=BLOCKED reason=Godot_not_found"
    Write-Output "ANDROID_EXPORT_STATUS=NOT_RUN reason=Godot_not_found"
    exit 2
}
$python = Get-Command python -ErrorAction SilentlyContinue
if ($null -eq $python) {
    Write-Output "ANDROID_BUILD_STATUS=BLOCKED reason=Python_not_found"
    Write-Output "ANDROID_EXPORT_STATUS=NOT_RUN reason=Python_not_found"
    exit 2
}
$PythonPath = $python.Source
$buildOutputDirectory = Join-Path $projectRoot "exports\builds\android"
$allowedDirectory = $projectRoot
foreach ($component in @("exports", "builds", "android")) {
    $allowedDirectory = Join-Path $allowedDirectory $component
    if (Test-Path -LiteralPath $allowedDirectory -PathType Container) {
        $item = Get-Item -LiteralPath $allowedDirectory
        if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            Write-Output "ANDROID_BUILD_STATUS=BLOCKED reason=APK_output_directory_is_a_link"
            Write-Output "ANDROID_EXPORT_STATUS=NOT_RUN reason=unsafe_output_path"
            exit 2
        }
    } else {
        New-Item -ItemType Directory -Path $allowedDirectory | Out-Null
    }
}
$resolvedBuildOutputDirectory = [System.IO.Path]::GetFullPath($buildOutputDirectory).TrimEnd('\')
$resolvedOutputDirectory = [System.IO.Path]::GetFullPath((Split-Path -Parent $OutputPath)).TrimEnd('\')
if ([System.IO.Path]::GetExtension($OutputPath) -ine ".apk" -or $resolvedOutputDirectory -ine $resolvedBuildOutputDirectory) {
    Write-Output "ANDROID_BUILD_STATUS=BLOCKED reason=APK_output_must_be_inside_exports_builds_android"
    Write-Output "ANDROID_EXPORT_STATUS=NOT_RUN reason=unsafe_output_path"
    exit 2
}
$OutputPath = Join-Path $resolvedBuildOutputDirectory (Split-Path -Leaf $OutputPath)
$outputDirectory = $resolvedBuildOutputDirectory

$runId = if ($env:GITHUB_RUN_ID) { $env:GITHUB_RUN_ID } else { "local-" + [guid]::NewGuid().ToString("N") }
$runStartedNs = [long]([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() * 1000000)
$godotVersionLines = & $GodotPath --version
$godotVersionExit = $LASTEXITCODE
$godotVersion = ($godotVersionLines -join " ").Trim()
if ($godotVersionExit -ne 0 -or $godotVersion -notlike "4.2.1.stable*") {
    Write-Output "ANDROID_BUILD_STATUS=BLOCKED reason=wrong_Godot_version version=$godotVersion"
    Write-Output "ANDROID_EXPORT_STATUS=NOT_RUN reason=wrong_Godot_version"
    exit 2
}
& $PythonPath $gateTest
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$sourceSha = (& $PythonPath $gateTest source-sha --root $projectRoot | Select-Object -Last 1).ToString().Trim()
Write-Output "ANDROID_RUN_ID=$runId"
Write-Output "SOURCE_TREE_SHA256=$sourceSha"
Write-Output "GODOT_VERSION=$godotVersion"

$missing = [System.Collections.Generic.List[string]]::new()
if ([string]::IsNullOrWhiteSpace($AndroidSdkPath) -or -not (Test-Path -LiteralPath $AndroidSdkPath -PathType Container)) {
    $missing.Add("ANDROID_SDK_ROOT")
} else {
    foreach ($relative in @(
        "platform-tools\adb.exe",
        "build-tools\33.0.2\aapt.exe",
        "build-tools\33.0.2\aapt2.exe",
        "platforms\android-33\android.jar",
        "ndk\23.2.8568313\source.properties",
        "cmake\3.10.2.4988404\bin\cmake.exe"
    )) {
        if (-not (Test-Path -LiteralPath (Join-Path $AndroidSdkPath $relative) -PathType Leaf)) { $missing.Add($relative) }
    }
}
if ([string]::IsNullOrWhiteSpace($JavaSdkPath) -or -not (Test-Path -LiteralPath (Join-Path $JavaSdkPath "bin\java.exe") -PathType Leaf)) {
    $missing.Add("JAVA_HOME_JDK17")
} else {
    $javaVersion = (& (Join-Path $JavaSdkPath "bin\java.exe") -version 2>&1 | Out-String)
    if ($javaVersion -notmatch 'version "17(?:[."])') { $missing.Add("JAVA_VERSION_NOT_17") }
}
if (-not (Test-Path -LiteralPath (Join-Path $GodotTemplatePath "android_debug.apk") -PathType Leaf)) {
    $missing.Add("GODOT_4_2_1_EXPORT_TEMPLATES")
} else {
    $templateVersionFile = Join-Path $GodotTemplatePath "version.txt"
    if (-not (Test-Path -LiteralPath $templateVersionFile -PathType Leaf) -or (Get-Content -LiteralPath $templateVersionFile -Raw).Trim() -notlike "4.2.1.stable*") {
        $missing.Add("GODOT_TEMPLATE_VERSION_MISMATCH")
    }
}

New-Item -ItemType Directory -Force -Path $isolatedHome | Out-Null
$pendingOutput = Join-Path $outputDirectory ("JellyCat-debug-" + [guid]::NewGuid().ToString("N") + ".pending.apk")
$pendingSha = "$pendingOutput.sha256"
$env:APPDATA = Join-Path $isolatedHome "Roaming"
New-Item -ItemType Directory -Force -Path $env:APPDATA | Out-Null
$env:ANDROID_USER_HOME = Join-Path $isolatedHome "android-user"
$env:ANDROID_HOME = $AndroidSdkPath
$env:ANDROID_SDK_ROOT = $AndroidSdkPath
$env:JAVA_HOME = $JavaSdkPath

function Invoke-GodotStep {
    param(
        [string]$Label,
        [string]$Marker = "",
        [string[]]$Arguments
    )
    $logPath = Join-Path $isolatedHome "$Label.log"
    Write-Output "ANDROID_STEP_BEGIN $Label"
    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $GodotPath
    $startInfo.WorkingDirectory = $projectRoot
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    foreach ($argument in $Arguments) { [void]$startInfo.ArgumentList.Add($argument) }
    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    [void]$process.Start()
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    if (-not $process.WaitForExit(600000)) {
        $process.Kill($true)
        $process.WaitForExit()
        $status = 124
        $logText = "Godot process timed out after 600 seconds."
    } else {
        $status = $process.ExitCode
        $logText = $stdoutTask.GetAwaiter().GetResult() + [Environment]::NewLine + $stderrTask.GetAwaiter().GetResult()
    }
    [System.IO.File]::WriteAllText($logPath, $logText, [System.Text.UTF8Encoding]::new($false))
    if ($logText) { $logText.TrimEnd() -split "\r?\n" | ForEach-Object { Write-Output $_ } }
    $process.Dispose()
    $checkArgs = @($gateTest, "check-log", "--step", $Label, "--log", $logPath, "--exit-code", "$status")
    if (-not [string]::IsNullOrEmpty($Marker)) { $checkArgs += @("--marker", $Marker) }
    & $PythonPath @checkArgs
    if ($LASTEXITCODE -eq 0) {
        Write-Output "ANDROID_STEP_OK $Label"
        return $true
    }
    $script:gateFailures.Add($Label)
    return $false
}

function Set-GodotEditorSetting {
    param([string]$Content, [string]$Name, [string]$Value)
    $normalized = $Value.Replace("\", "/").Replace('"', '\"')
    $line = $Name + ' = "' + $normalized + '"'
    $pattern = "(?m)^" + [regex]::Escape($Name) + " = .*$"
    if ([regex]::IsMatch($Content, $pattern)) { return [regex]::Replace($Content, $pattern, $line, 1) }
    return $Content.Replace("[resource]", "[resource]" + [Environment]::NewLine + $line)
}

try {
    Invoke-GodotStep -Label "import_bootstrap" -Arguments @("--headless", "--editor", "--path", $projectRoot, "--quit-after", "1200", "--max-fps", "60") | Out-Null
    & $PythonPath $gateTest verify-imports --root $projectRoot
    if ($LASTEXITCODE -ne 0) { $script:gateFailures.Add("import_assets") }
    Invoke-GodotStep -Label "import_validate" -Arguments @("--headless", "--editor", "--path", $projectRoot, "--quit") | Out-Null
    Invoke-GodotStep -Label "core_acceptance" -Marker "RUNTIME_ACCEPTANCE_OK " -Arguments @("--headless", "--path", $projectRoot, "res://tools/runtime_acceptance_check.tscn") | Out-Null
    Invoke-GodotStep -Label "scene_acceptance" -Marker "ANDROID_SCENE_ACCEPTANCE_OK " -Arguments @("--headless", "--path", $projectRoot, "res://tools/android_scene_acceptance_check.tscn") | Out-Null
    if (Test-Path -LiteralPath (Join-Path $projectRoot "tools\g1_gameplay_acceptance.tscn") -PathType Leaf) {
        Invoke-GodotStep -Label "g1_gameplay_acceptance" -Marker "G1_GAMEPLAY_ACCEPTANCE_OK " -Arguments @("--headless", "--path", $projectRoot, "res://tools/g1_gameplay_acceptance.tscn") | Out-Null
    } else {
        Write-Output "ANDROID_STEP_NOT_RUN g1_gameplay_acceptance reason=missing_from_source"
        $script:gateFailures.Add("g1_gameplay_acceptance_missing")
    }

    if ($script:gateFailures.Count -gt 0) {
        Write-Output "ANDROID_BUILD_STATUS=FAIL failed_steps=$($script:gateFailures -join ',')"
        Write-Output "ANDROID_EXPORT_STATUS=NOT_RUN reason=gate_failed"
        if ($missing.Count -gt 0) { Write-Output "ANDROID_EXPORT_PREREQUISITES_MISSING=$($missing -join ',')" }
        $exitCode = 1
    } elseif ($missing.Count -gt 0) {
        Write-Output "ANDROID_BUILD_STATUS=BLOCKED reason=export_prerequisites_missing"
        Write-Output "ANDROID_EXPORT_STATUS=NOT_RUN missing=$($missing -join ',')"
        $exitCode = 2
    } else {
        $cliTemplatePath = Join-Path $env:APPDATA "Godot\export_templates\4.2.1.stable"
        New-Item -ItemType Directory -Force -Path $cliTemplatePath | Out-Null
        foreach ($templateFile in @("android_debug.apk", "android_release.apk", "version.txt")) {
            $sourceTemplate = Join-Path $GodotTemplatePath $templateFile
            if (-not (Test-Path -LiteralPath $sourceTemplate -PathType Leaf)) { throw "Godot export template missing: $templateFile" }
            Copy-Item -LiteralPath $sourceTemplate -Destination $cliTemplatePath
        }

        $keystoreMode = "ephemeral"
        $keystoreUser = if ($env:ANDROID_DEBUG_KEYSTORE_USER) { $env:ANDROID_DEBUG_KEYSTORE_USER } else { "androiddebugkey" }
        $keystorePassword = if ($env:ANDROID_DEBUG_KEYSTORE_PASSWORD) { $env:ANDROID_DEBUG_KEYSTORE_PASSWORD } else { "android" }
        $keystoreForExport = Join-Path $isolatedHome "debug.keystore"
        if ($env:ANDROID_DEBUG_KEYSTORE_BASE64) {
            if (-not $env:ANDROID_DEBUG_KEYSTORE_PASSWORD -or -not $env:ANDROID_DEBUG_KEYSTORE_USER) {
                throw "ANDROID_BUILD_STATUS=BLOCKED reason=incomplete_keystore_secrets"
            }
            [System.IO.File]::WriteAllBytes($keystoreForExport, [Convert]::FromBase64String($env:ANDROID_DEBUG_KEYSTORE_BASE64))
            $keystorePassword = $env:ANDROID_DEBUG_KEYSTORE_PASSWORD
            $keystoreUser = $env:ANDROID_DEBUG_KEYSTORE_USER
            $keystoreMode = "provided_secret"
        } elseif ($keystorePathWasSupplied) {
            if (-not (Test-Path -LiteralPath $KeystorePath -PathType Leaf)) { throw "Provided external keystore does not exist." }
            $keystoreForExport = (Resolve-Path -LiteralPath $KeystorePath).Path
            $keystoreMode = "external"
        } else {
            $defaultKeystore = Join-Path ([Environment]::GetFolderPath("UserProfile")) ".android\debug.keystore"
            if (Test-Path -LiteralPath $defaultKeystore -PathType Leaf) {
                $keystoreForExport = $defaultKeystore
                $keystoreMode = "external"
            } else {
                $keytool = Join-Path $JavaSdkPath "bin\keytool.exe"
                & $keytool -genkeypair -noprompt -keyalg RSA -keysize 2048 -alias $keystoreUser -keypass $keystorePassword -keystore $keystoreForExport -storepass $keystorePassword -dname "CN=Android Debug,O=Android,C=US" -validity 9999 -deststoretype pkcs12
                if ($LASTEXITCODE -ne 0) { throw "Failed to create ephemeral debug keystore." }
            }
        }

        $editorSettingsPath = Join-Path $env:APPDATA "Godot\editor_settings-4.tres"
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $editorSettingsPath) | Out-Null
        $newline = [Environment]::NewLine
        $editorSettings = '[gd_resource type="EditorSettings" format=3]' + $newline + $newline + '[resource]' + $newline
        $editorSettings = Set-GodotEditorSetting $editorSettings "export/android/android_sdk_path" $AndroidSdkPath
        $editorSettings = Set-GodotEditorSetting $editorSettings "export/android/java_sdk_path" $JavaSdkPath
        $editorSettings = Set-GodotEditorSetting $editorSettings "export/android/debug_keystore" $keystoreForExport
        $editorSettings = Set-GodotEditorSetting $editorSettings "export/android/debug_keystore_user" $keystoreUser
        $editorSettings = Set-GodotEditorSetting $editorSettings "export/android/debug_keystore_pass" $keystorePassword
        [System.IO.File]::WriteAllText($editorSettingsPath, $editorSettings, [System.Text.UTF8Encoding]::new($false))

        Write-Output "ANDROID_SIGNING_MODE=$keystoreMode"
        Invoke-GodotStep -Label "export" -Arguments @("--headless", "--path", $projectRoot, "--export-debug", "Android APK", $pendingOutput) | Out-Null
        if ($script:gateFailures.Count -gt 0 -or -not (Test-Path -LiteralPath $pendingOutput -PathType Leaf)) {
            Write-Output "ANDROID_BUILD_STATUS=FAIL reason=export_gate_or_missing_apk"
            Write-Output "ANDROID_EXPORT_STATUS=FAIL"
            $exitCode = 1
        } else {
            $manifestVerifier = Join-Path $PSScriptRoot "verify_android_manifest.py"
            $manifestArgs = @(
                $manifestVerifier,
                "--aapt", (Join-Path $AndroidSdkPath "build-tools\33.0.2\aapt.exe"),
                "--aapt2", (Join-Path $AndroidSdkPath "build-tools\33.0.2\aapt2.exe"),
                "--apk", $pendingOutput
            )
            & $PythonPath @manifestArgs
            if ($LASTEXITCODE -ne 0) { throw "APK manifest package identity validation failed." }
            & $PythonPath (Join-Path $PSScriptRoot "verify_android_artifact.py") $pendingOutput $projectRoot
            if ($LASTEXITCODE -ne 0) { throw "APK JSON/PNG asset check failed." }
            & $PythonPath $gateTest verify-apk --apk $pendingOutput --started-ns "$runStartedNs" --sha-file $pendingSha --sha-name (Split-Path -Leaf $OutputPath)
            if ($LASTEXITCODE -ne 0) { throw "Fresh APK/hash gate failed." }
            Move-Item -LiteralPath $pendingOutput -Destination $OutputPath -Force
            Move-Item -LiteralPath $pendingSha -Destination "$OutputPath.sha256" -Force
            Write-Output "ANDROID_APK_PATH=$OutputPath"
            Write-Output "ANDROID_BUILD_STATUS=PASS"
            Write-Output "ANDROID_EXPORT_STATUS=PASS"
            Write-Output "ANDROID_TOOLCHAIN=Godot4.2.1 JDK17 Android33 BuildTools33.0.2 NDK23.2.8568313 CMake3.10.2.4988404"
            Write-Output "ANDROID_SIGNING_MODE=$keystoreMode"
        }
    }
} catch {
    [Console]::Error.WriteLine($_.ToString())
    if ($_.ScriptStackTrace) { [Console]::Error.WriteLine($_.ScriptStackTrace) }
    $exitCode = 1
} finally {
    if ($pendingOutput) { Remove-Item -LiteralPath $pendingOutput, $pendingSha -Force -ErrorAction SilentlyContinue }
    $env:APPDATA = $oldAppData
    Remove-Item -LiteralPath $isolatedHome -Recurse -Force -ErrorAction SilentlyContinue
}
if ($exitCode -ne 0) { exit $exitCode }
