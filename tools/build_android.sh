#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
godot_bin="${GODOT_BIN:-$(command -v godot || true)}"
sdk_root="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}"
java_home="${JAVA_HOME:-}"
output_path="${APK_OUTPUT_PATH:-$project_root/exports/builds/android/JellyCat-debug.apk}"
template_source="${GODOT_TEMPLATE_DIR:-${HOME}/.local/share/godot/export_templates/4.2.1.stable}"

if [[ -z "$godot_bin" || ! -x "$godot_bin" ]]; then
  echo "Godot 4.2.1 executable not found; set GODOT_BIN." >&2
  exit 2
fi
godot_version="$("$godot_bin" --version)"
if [[ "$godot_version" != 4.2.1.stable* ]]; then
  echo "Expected Godot 4.2.1.stable, found: $godot_version" >&2
  exit 2
fi
if [[ -z "$sdk_root" || ! -d "$sdk_root" ]]; then
  echo "Android SDK not found; set ANDROID_SDK_ROOT." >&2
  exit 2
fi
if [[ -z "$java_home" || ! -x "$java_home/bin/java" || ! -x "$java_home/bin/keytool" ]]; then
  echo "OpenJDK 17 not found; set JAVA_HOME." >&2
  exit 2
fi
for component in \
  "platform-tools/adb" \
  "build-tools/33.0.2/aapt" \
  "build-tools/33.0.2/aapt2" \
  "platforms/android-33/android.jar" \
  "ndk/23.2.8568313/source.properties" \
  "cmake/3.10.2.4988404/bin/cmake"; do
  if [[ ! -e "$sdk_root/$component" ]]; then
    echo "Required Android SDK component missing: $component" >&2
    exit 2
  fi
done
if [[ ! -f "$template_source/android_debug.apk" ]]; then
  echo "Godot 4.2.1 export templates not found: $template_source" >&2
  exit 2
fi

# Keep editor settings, debug signing material, and user:// acceptance data out
# of the project and out of a developer's existing Godot profile.
isolated_home="$(mktemp -d)"
trap 'rm -rf "$isolated_home"' EXIT
export XDG_CONFIG_HOME="$isolated_home/config"
export XDG_DATA_HOME="$isolated_home/data"
export XDG_CACHE_HOME="$isolated_home/cache"
export ANDROID_HOME="$sdk_root"
export ANDROID_SDK_ROOT="$sdk_root"
mkdir -p "$XDG_CONFIG_HOME/godot" "$XDG_DATA_HOME/godot/export_templates/4.2.1.stable"
cp -a "$template_source/." "$XDG_DATA_HOME/godot/export_templates/4.2.1.stable/"

debug_keystore="$isolated_home/debug.keystore"
"$java_home/bin/keytool" -genkeypair -noprompt -keyalg RSA -keysize 2048 \
  -alias androiddebugkey -keypass android -keystore "$debug_keystore" \
  -storepass android -dname "CN=Android Debug,O=Android,C=US" \
  -validity 9999 -deststoretype pkcs12 >/dev/null 2>&1

python3 - "$XDG_CONFIG_HOME/godot/editor_settings-4.tres" "$sdk_root" "$java_home" "$debug_keystore" <<'PY'
import json
import pathlib
import sys

settings_path, sdk_path, java_path, keystore_path = sys.argv[1:]
settings_path = pathlib.Path(settings_path)
settings_path.write_text(
    '[gd_resource type="EditorSettings" format=3]\n\n[resource]\n'
    + f'export/android/android_sdk_path = {json.dumps(sdk_path)}\n'
    + f'export/android/java_sdk_path = {json.dumps(java_path)}\n'
    + f'export/android/debug_keystore = {json.dumps(keystore_path)}\n'
    + 'export/android/debug_keystore_user = "androiddebugkey"\n'
    + 'export/android/debug_keystore_pass = "android"\n',
    encoding="utf-8",
)
PY

pending_output="${output_path%.apk}.pending.apk"
mkdir -p "$(dirname -- "$output_path")"
rm -f "$output_path" "$pending_output"
"$godot_bin" --headless --editor --path "$project_root" --import
"$godot_bin" --headless --path "$project_root" res://tools/runtime_acceptance_check.tscn
"$godot_bin" --headless --path "$project_root" --export-debug "Android APK" "$pending_output"
test -s "$pending_output"
mv "$pending_output" "$output_path"
badging="$("$sdk_root/build-tools/33.0.2/aapt" dump badging "$output_path")"
grep -Fq "package: name='com.jacktzeng.jellycat'" <<< "$badging"
python3 "$project_root/tools/verify_android_artifact.py" "$output_path" "$project_root"
sha256sum "$output_path" | tee "$output_path.sha256"
echo "ANDROID_APK_OK $output_path"
