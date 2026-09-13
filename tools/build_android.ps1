[CmdletBinding()]
param(
    [string]$GodotPath = $env:GODOT_CONSOLE_PATH,
    [string]$AndroidSdkPath = $env:ANDROID_SDK_ROOT,
    [string]$JavaSdkPath = $env:JAVA_HOME,
    [string]$GodotTemplatePath,
    [string]$KeystorePath,
    [string]$OutputPath
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot

if ([string]::IsNullOrWhiteSpace($GodotPath)) {
    $godotCommand = Get-Command godot -ErrorAction SilentlyContinue
    if ($null -ne $godotCommand) {
        $GodotPath = $godotCommand.Source
    }
}

if ([string]::IsNullOrWhiteSpace($GodotPath)) {
    $desktopPath = [Environment]::GetFolderPath("Desktop")
    $desktopCandidate = Join-Path $desktopPath "Godot_v4.2.1-stable_win64.exe\Godot_v4.2.1-stable_win64_console.exe"
    if (Test-Path -LiteralPath $desktopCandidate) {
        $GodotPath = $desktopCandidate
    }
}

if ([string]::IsNullOrWhiteSpace($AndroidSdkPath)) {
    $AndroidSdkPath = $env:ANDROID_HOME
}

if ([string]::IsNullOrWhiteSpace($KeystorePath)) {
    $KeystorePath = Join-Path ([Environment]::GetFolderPath("UserProfile")) ".android\debug.keystore"
}

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path $projectRoot "exports\builds\android\JellyCat-debug.apk"
}

if ([string]::IsNullOrWhiteSpace($GodotTemplatePath)) {
    $GodotTemplatePath = Join-Path $env:APPDATA "Godot\export_templates\4.2.1.stable"
}

if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) {
    throw "Godot console executable not found. Pass -GodotPath or set GODOT_CONSOLE_PATH."
}

if ([string]::IsNullOrWhiteSpace($JavaSdkPath) -or -not (Test-Path -LiteralPath $JavaSdkPath -PathType Container)) {
    throw "OpenJDK 17 not found. Pass -JavaSdkPath or set JAVA_HOME."
}

if ([string]::IsNullOrWhiteSpace($AndroidSdkPath) -or -not (Test-Path -LiteralPath $AndroidSdkPath -PathType Container)) {
    throw "Android SDK not found. Pass -AndroidSdkPath or set ANDROID_SDK_ROOT."
}

if (-not (Test-Path -LiteralPath $GodotTemplatePath -PathType Container)) {
    throw "Godot 4.2.1 export templates not found. Pass -GodotTemplatePath."
}

$keytoolPath = Join-Path $JavaSdkPath "bin\keytool.exe"
if (-not (Test-Path -LiteralPath $keytoolPath -PathType Leaf)) {
    throw "keytool.exe not found under the selected Java SDK path."
}

$requiredSdkFiles = @(
    "platform-tools\adb.exe",
    "build-tools\33.0.2\aapt2.exe",
    "platforms\android-33\android.jar"
)

foreach ($requiredSdkFile in $requiredSdkFiles) {
    $requiredPath = Join-Path $AndroidSdkPath $requiredSdkFile
    if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
        throw "Required Android SDK component is missing: $requiredSdkFile"
    }
}

if (-not (Test-Path -LiteralPath $KeystorePath -PathType Leaf)) {
    $keystoreDirectory = Split-Path -Parent $KeystorePath
    New-Item -ItemType Directory -Force -Path $keystoreDirectory | Out-Null
    & $keytoolPath -keyalg RSA -genkeypair -alias androiddebugkey -keypass android -keystore $KeystorePath -storepass android -dname "CN=Android Debug,O=Android,C=US" -validity 9999 -deststoretype pkcs12
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to generate the Android debug keystore."
    }
}

$outputDirectory = Split-Path -Parent $OutputPath
New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null
$temporaryOutput = Join-Path $outputDirectory ("JellyCat-debug-" + [guid]::NewGuid().ToString("N") + ".apk")

$cliHome = Join-Path $projectRoot "exports\.godot-cli-home"
$cliTemplatePath = Join-Path $cliHome "export_templates\4.2.1.stable"
New-Item -ItemType Directory -Force -Path $cliTemplatePath | Out-Null

foreach ($templateFile in @("android_debug.apk", "android_release.apk", "version.txt")) {
    $sourceTemplate = Join-Path $GodotTemplatePath $templateFile
    if (-not (Test-Path -LiteralPath $sourceTemplate -PathType Leaf)) {
        throw "Required Godot Android export template is missing: $templateFile"
    }
    $destinationTemplate = Join-Path $cliTemplatePath $templateFile
    if (-not (Test-Path -LiteralPath $destinationTemplate -PathType Leaf)) {
        Copy-Item -LiteralPath $sourceTemplate -Destination $destinationTemplate
    }
}

$env:GODOT_USER_HOME = $cliHome
$env:ANDROID_SDK_ROOT = (Resolve-Path -LiteralPath $AndroidSdkPath).Path
$env:ANDROID_HOME = $env:ANDROID_SDK_ROOT
$env:JAVA_HOME = (Resolve-Path -LiteralPath $JavaSdkPath).Path
$env:GODOT_ANDROID_KEYSTORE_DEBUG_PATH = (Resolve-Path -LiteralPath $KeystorePath).Path
$env:GODOT_ANDROID_KEYSTORE_DEBUG_USER = "androiddebugkey"
$env:GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD = "android"

function Set-GodotEditorSetting {
    param(
        [string]$Content,
        [string]$Name,
        [string]$Value
    )

    $normalizedValue = $Value.Replace("\", "/").Replace('"', '\"')
    $settingLine = "$Name = `"$normalizedValue`""
    $settingPattern = "(?m)^" + [regex]::Escape($Name) + " = .*$"

    if ([regex]::IsMatch($Content, $settingPattern)) {
        return [regex]::Replace($Content, $settingPattern, $settingLine, 1)
    }

    return $Content.Replace("[resource]", "[resource]`r`n$settingLine")
}

$editorSettingsPath = Join-Path $cliHome "editor_settings-4.tres"
if (Test-Path -LiteralPath $editorSettingsPath -PathType Leaf) {
    $editorSettings = Get-Content -LiteralPath $editorSettingsPath -Raw
} else {
    $editorSettings = "[gd_resource type=`"EditorSettings`" format=3]`r`n`r`n[resource]`r`n"
}

$editorSettings = Set-GodotEditorSetting -Content $editorSettings -Name "export/android/android_sdk_path" -Value $env:ANDROID_SDK_ROOT
$editorSettings = Set-GodotEditorSetting -Content $editorSettings -Name "export/android/java_sdk_path" -Value $env:JAVA_HOME
$editorSettings = Set-GodotEditorSetting -Content $editorSettings -Name "export/android/debug_keystore" -Value $env:GODOT_ANDROID_KEYSTORE_DEBUG_PATH
$editorSettings = Set-GodotEditorSetting -Content $editorSettings -Name "export/android/debug_keystore_user" -Value "androiddebugkey"
$editorSettings = Set-GodotEditorSetting -Content $editorSettings -Name "export/android/debug_keystore_pass" -Value "android"
Set-Content -LiteralPath $editorSettingsPath -Value $editorSettings -Encoding utf8NoBOM

& $GodotPath --headless --path $projectRoot res://tools/runtime_acceptance_check.tscn
if ($LASTEXITCODE -ne 0) {
    throw "Runtime acceptance failed; APK export was stopped."
}

& $GodotPath --headless --path $projectRoot --export-debug "Android APK" $temporaryOutput
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $temporaryOutput -PathType Leaf)) {
    throw "Android debug APK export failed."
}

Move-Item -LiteralPath $temporaryOutput -Destination $OutputPath -Force

Write-Output "ANDROID_APK_OK $OutputPath"
