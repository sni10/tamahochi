#!/usr/bin/env bash
# Godot $GODOT_VERSION для CI (кэш — ~/.cache/godot-ci). С аргументом `android` — ещё шаблоны
# экспорта и настройки редактора с путями к Android SDK ($ANDROID_HOME) и JDK ($JAVA_HOME).
set -euo pipefail
V="${GODOT_VERSION:?}"
C=~/.cache/godot-ci
URL="https://github.com/godotengine/godot/releases/download/$V-stable"
BIN="$C/Godot_v$V-stable_linux.x86_64"

mkdir -p "$C"
if [ ! -f "$BIN" ]; then
  curl -fsSL -o /tmp/godot.zip "$URL/Godot_v$V-stable_linux.x86_64.zip"
  unzip -qo /tmp/godot.zip -d "$C"
fi
echo "GODOT=$BIN" >> "$GITHUB_ENV"

[ "${1:-}" = android ] || exit 0

[ -f "$C/templates.tpz" ] || curl -fsSL -o "$C/templates.tpz" "$URL/Godot_v$V-stable_export_templates.tpz"
T=~/.local/share/godot/export_templates/$V.stable
mkdir -p "$T"
unzip -qo -j "$C/templates.tpz" 'templates/*' -d "$T"

mkdir -p ~/.config/godot
cat > ~/.config/godot/editor_settings-"${V%.*}".tres <<EOF
[gd_resource type="EditorSettings" format=3]

[resource]
export/android/android_sdk_path = "${ANDROID_HOME:?}"
export/android/java_sdk_path = "${JAVA_HOME:?}"
EOF
