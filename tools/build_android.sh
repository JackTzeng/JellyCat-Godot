#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
gate_test="$project_root/tools/test_android_build_gate.py"
godot_bin="${GODOT_BIN:-$(command -v godot || true)}"
sdk_root="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}"
java_home="${JAVA_HOME:-}"
output_path="${APK_OUTPUT_PATH:-$project_root/exports/builds/android/JellyCat-debug.apk}"
template_source="${GODOT_TEMPLATE_DIR:-${HOME:-}/.local/share/godot/export_templates/4.2.1.stable}"
run_id="${GITHUB_RUN_ID:-local-$(date -u +%Y%m%dT%H%M%SZ)-$$}"
build_output_directory="$project_root/exports/builds/android"
allowed_directory="$project_root"
for component in exports builds android; do
  allowed_directory="$allowed_directory/$component"
  if [[ -L "$allowed_directory" ]]; then
    echo "ANDROID_BUILD_STATUS=BLOCKED reason=APK_output_directory_is_a_link" >&2
    exit 2
  fi
  [[ -d "$allowed_directory" ]] || mkdir "$allowed_directory"
done
if [[ "$output_path" != /* ]]; then output_path="$project_root/$output_path"; fi
resolved_project_root="$(realpath "$project_root")"
resolved_build_output_directory="$(realpath "$build_output_directory")"
if [[ "$resolved_build_output_directory" != "$resolved_project_root/exports/builds/android" || "${output_path##*.}" != apk || "$(realpath -m "$(dirname -- "$output_path")")" != "$resolved_build_output_directory" ]]; then
  echo "ANDROID_BUILD_STATUS=BLOCKED reason=APK_output_must_be_inside_exports_builds_android" >&2
  echo "ANDROID_EXPORT_STATUS=NOT_RUN reason=unsafe_output_path"
  exit 2
fi
output_path="$(realpath "$build_output_directory")/$(basename -- "$output_path")"

if [[ -z "$godot_bin" || ! -x "$godot_bin" ]]; then
  echo "ANDROID_BUILD_STATUS=BLOCKED reason=Godot_not_found" >&2
  echo "ANDROID_EXPORT_STATUS=NOT_RUN reason=Godot_not_found"
  exit 2
fi
godot_version="$("$godot_bin" --version)"
if [[ "$godot_version" != 4.2.1.stable* ]]; then
  echo "ANDROID_BUILD_STATUS=BLOCKED reason=wrong_Godot_version version=$godot_version" >&2
  echo "ANDROID_EXPORT_STATUS=NOT_RUN reason=wrong_Godot_version"
  exit 2
fi
python_bin="${PYTHON_BIN:-python3}"
"$python_bin" "$gate_test"
source_sha="$("$python_bin" "$gate_test" source-sha --root "$project_root")"
echo "ANDROID_RUN_ID=$run_id"
echo "SOURCE_TREE_SHA256=$source_sha"
echo "GODOT_VERSION=$godot_version"

missing=()
if [[ -z "$sdk_root" || ! -d "$sdk_root" ]]; then
  missing+=(ANDROID_SDK_ROOT)
else
  for component in platform-tools/adb build-tools/33.0.2/aapt build-tools/33.0.2/aapt2 platforms/android-33/android.jar ndk/23.2.8568313/source.properties cmake/3.10.2.4988404/bin/cmake; do
    [[ -e "$sdk_root/$component" ]] || missing+=("$component")
  done
fi
if [[ -z "$java_home" || ! -x "$java_home/bin/java" || ! -x "$java_home/bin/keytool" ]]; then
  missing+=(JAVA_HOME_JDK17)
else
  java_version="$("$java_home/bin/java" -version 2>&1 | sed -n '1s/.*version "\([^"]*\)".*/\1/p')"
  [[ "$java_version" == 17* ]] || missing+=("JAVA_VERSION_${java_version:-unknown}")
fi
if [[ ! -f "$template_source/android_debug.apk" ]]; then
  missing+=(GODOT_4_2_1_EXPORT_TEMPLATES)
elif [[ ! -f "$template_source/version.txt" ]] || [[ "$(<"$template_source/version.txt")" != 4.2.1.stable* ]]; then
  missing+=(GODOT_TEMPLATE_VERSION_MISMATCH)
fi

isolated_home="$(mktemp -d)"
pending_output="${output_path%.apk}.pending-${run_id}.apk"
pending_sha="${pending_output}.sha256"
started_ns="$("$python_bin" -c 'import time; print(time.time_ns())')"
gate_failures=()
cleanup() {
  rm -f "$pending_output" "$pending_sha"
  rm -rf "$isolated_home"
}
trap cleanup EXIT
export XDG_CONFIG_HOME="$isolated_home/config"
export XDG_DATA_HOME="$isolated_home/data"
export XDG_CACHE_HOME="$isolated_home/cache"
export ANDROID_USER_HOME="$isolated_home/android-user"
mkdir -p "$XDG_CONFIG_HOME/godot" "$XDG_DATA_HOME/godot" "$ANDROID_USER_HOME"

run_godot() {
  local label="$1" limit="$2" marker="$3"
  shift 3
  local log_path="$isolated_home/${label}.log" status
  echo "ANDROID_STEP_BEGIN $label timeout=${limit}s"
  set +e
  timeout --foreground --signal=TERM --kill-after=15s "${limit}s" "$@" 2>&1 | tee "$log_path"
  status=${PIPESTATUS[0]}
  set -e
  if "$python_bin" "$gate_test" check-log --step "$label" --log "$log_path" --exit-code "$status" --marker "$marker"; then
    echo "ANDROID_STEP_OK $label"
  else
    gate_failures+=("$label")
  fi
}

run_godot import_bootstrap 90 "" "$godot_bin" --headless --editor --path "$project_root" --quit-after 1200 --max-fps 60
if ! "$python_bin" "$gate_test" verify-imports --root "$project_root"; then gate_failures+=(import_assets); fi
run_godot import_validate 120 "" "$godot_bin" --headless --editor --path "$project_root" --quit
run_godot core_acceptance 180 "RUNTIME_ACCEPTANCE_OK " "$godot_bin" --headless --path "$project_root" res://tools/runtime_acceptance_check.tscn
run_godot scene_acceptance 120 "ANDROID_SCENE_ACCEPTANCE_OK " "$godot_bin" --headless --path "$project_root" res://tools/android_scene_acceptance_check.tscn
if [[ -f "$project_root/tools/g1_gameplay_acceptance.tscn" ]]; then
  run_godot g1_gameplay_acceptance 180 "G1_GAMEPLAY_ACCEPTANCE_OK " "$godot_bin" --headless --path "$project_root" res://tools/g1_gameplay_acceptance.tscn
else
  echo "ANDROID_STEP_NOT_RUN g1_gameplay_acceptance reason=missing_from_source"
  gate_failures+=(g1_gameplay_acceptance_missing)
fi

if (( ${#gate_failures[@]} > 0 )); then
  echo "ANDROID_BUILD_STATUS=FAIL failed_steps=${gate_failures[*]}"
  echo "ANDROID_EXPORT_STATUS=NOT_RUN reason=gate_failed"
  if (( ${#missing[@]} > 0 )); then echo "ANDROID_EXPORT_PREREQUISITES_MISSING=${missing[*]}"; fi
  exit 1
fi
if (( ${#missing[@]} > 0 )); then
  echo "ANDROID_BUILD_STATUS=BLOCKED reason=export_prerequisites_missing"
  echo "ANDROID_EXPORT_STATUS=NOT_RUN missing=${missing[*]}"
  exit 2
fi

export ANDROID_HOME="$sdk_root" ANDROID_SDK_ROOT="$sdk_root" JAVA_HOME="$java_home"
mkdir -p "$XDG_DATA_HOME/godot/export_templates/4.2.1.stable"
cp -a "$template_source/." "$XDG_DATA_HOME/godot/export_templates/4.2.1.stable/"
keystore_path="$isolated_home/debug.keystore"
keystore_user="${ANDROID_DEBUG_KEYSTORE_USER:-androiddebugkey}"
keystore_password="${ANDROID_DEBUG_KEYSTORE_PASSWORD:-android}"
keystore_mode=ephemeral
if [[ -n "${ANDROID_DEBUG_KEYSTORE_BASE64:-}" ]]; then
  if [[ -z "${ANDROID_DEBUG_KEYSTORE_PASSWORD:-}" || -z "${ANDROID_DEBUG_KEYSTORE_USER:-}" ]]; then
    echo "ANDROID_BUILD_STATUS=BLOCKED reason=incomplete_keystore_secrets" >&2
    exit 2
  fi
  printf '%s' "$ANDROID_DEBUG_KEYSTORE_BASE64" | base64 --decode > "$keystore_path"
  keystore_user="$ANDROID_DEBUG_KEYSTORE_USER"
  keystore_password="$ANDROID_DEBUG_KEYSTORE_PASSWORD"
  keystore_mode=provided_secret
elif [[ -n "${ANDROID_DEBUG_KEYSTORE_PATH:-}" ]]; then
  if [[ ! -f "$ANDROID_DEBUG_KEYSTORE_PATH" ]]; then
    echo "ANDROID_BUILD_STATUS=BLOCKED reason=provided_keystore_missing" >&2
    exit 2
  fi
  keystore_path="$ANDROID_DEBUG_KEYSTORE_PATH"
  keystore_mode=external
else
  "$java_home/bin/keytool" -genkeypair -noprompt -keyalg RSA -keysize 2048 -alias "$keystore_user" \
    -keypass "$keystore_password" -keystore "$keystore_path" -storepass "$keystore_password" \
    -dname "CN=Android Debug,O=Android,C=US" -validity 9999 -deststoretype pkcs12 >/dev/null 2>&1
fi
"$python_bin" - "$XDG_CONFIG_HOME/godot/editor_settings-4.tres" "$sdk_root" "$java_home" "$keystore_path" "$keystore_user" "$keystore_password" <<'PY'
import json
import pathlib
import sys
settings_path, sdk_path, java_path, key_path, key_user, key_pass = sys.argv[1:]
pathlib.Path(settings_path).write_text(
    '[gd_resource type="EditorSettings" format=3]\n\n[resource]\n'
    + f'export/android/android_sdk_path = {json.dumps(sdk_path)}\n'
    + f'export/android/java_sdk_path = {json.dumps(java_path)}\n'
    + f'export/android/debug_keystore = {json.dumps(key_path)}\n'
    + f'export/android/debug_keystore_user = {json.dumps(key_user)}\n'
    + f'export/android/debug_keystore_pass = {json.dumps(key_pass)}\n',
    encoding="utf-8",
)
PY

echo "ANDROID_SIGNING_MODE=$keystore_mode"
run_godot export 600 "" "$godot_bin" --headless --path "$project_root" --export-debug "Android APK" "$pending_output"
if (( ${#gate_failures[@]} > 0 )) || [[ ! -s "$pending_output" ]]; then
  echo "ANDROID_BUILD_STATUS=FAIL reason=export_gate_or_missing_apk"
  echo "ANDROID_EXPORT_STATUS=FAIL"
  exit 1
fi
"$python_bin" "$project_root/tools/verify_android_manifest.py" \
  --aapt "$sdk_root/build-tools/33.0.2/aapt" \
  --aapt2 "$sdk_root/build-tools/33.0.2/aapt2" \
  --apk "$pending_output"
"$python_bin" "$project_root/tools/verify_android_artifact.py" "$pending_output" "$project_root"
"$python_bin" "$gate_test" verify-apk --apk "$pending_output" --started-ns "$started_ns" --sha-file "$pending_sha" --sha-name "$(basename -- "$output_path")"
mv -f "$pending_output" "$output_path"
mv -f "$pending_sha" "$output_path.sha256"
echo "ANDROID_APK_PATH=$output_path"
echo "ANDROID_BUILD_STATUS=PASS"
echo "ANDROID_EXPORT_STATUS=PASS"
echo "ANDROID_TOOLCHAIN=Godot4.2.1 JDK17 Android33 BuildTools33.0.2 NDK23.2.8568313 CMake3.10.2.4988404"
echo "ANDROID_SIGNING_MODE=$keystore_mode"
