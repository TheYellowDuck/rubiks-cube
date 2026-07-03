#!/usr/bin/env bash
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Required Notice: Copyright (c) 2026 George Zhang — https://github.com/TheYellowDuck

# Build a self-contained, double-clickable app for the CURRENT OS using jpackage.
# Requires: a JDK with jpackage (17+), python3, and Processing's core libraries.
#
# Processing libs are found automatically from a local Processing install, or set
#   PROCESSING_LIB=/path/to/processing/core/library
#
# Output: ./dist/   (a .app on macOS, an app-image folder on Windows/Linux)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OS="$(uname -s)"

# --- locate Processing core/library jars -------------------------------------
# Default: the vendored subset in packaging/lib (so builds/CI are deterministic).
# Override with PROCESSING_LIB to point at a full Processing install instead.
LIB="${PROCESSING_LIB:-}"
if [ -z "$LIB" ]; then
  for c in \
    "$ROOT/packaging/lib" \
    "/Applications/Processing.app/Contents/app/resources/core/library" \
    "$HOME/Processing/core/library" "$HOME/processing/core/library" \
    "/opt/processing/core/library" "/opt/processing/lib/core/library"; do
    [ -d "$c" ] && LIB="$c" && break
  done
fi
[ -n "${LIB:-}" ] && [ -d "$LIB" ] || { echo "ERROR: set PROCESSING_LIB to Processing's core/library dir"; exit 1; }
echo "Using Processing libs: $LIB"

# --- preprocess + compile -----------------------------------------------------
BUILD="$ROOT/build"; rm -rf "$BUILD"; mkdir -p "$BUILD/src" "$BUILD/out" "$BUILD/input" "$ROOT/dist"
python3 "$ROOT/packaging/preprocess.py" "$ROOT" "$BUILD/src/RubiksCube.java"

CP="$(ls "$LIB"/*.jar | tr '\n' ':')"
javac -d "$BUILD/out" -cp "$CP" "$BUILD/src/RubiksCube.java"
jar cf "$BUILD/input/sketch.jar" -C "$BUILD/out" .
cp "$LIB"/*.jar "$BUILD/input/"     # bundle Processing core + JOGL/GlueGen (all-platform natives)

# --- package per OS -----------------------------------------------------------
# NB: do NOT add -XstartOnFirstThread on macOS — Processing's P3D uses AWT/JOGL,
# which hangs (bouncing Dock icon, no window) if pinned to the first thread.
JOPTS=( --java-options --enable-native-access=ALL-UNNAMED )
case "$OS" in
  Darwin) ICON="$ROOT/assets/icon.icns" ;;
  Linux)  ICON="$ROOT/assets/icon.png" ;;
  *)      ICON="$ROOT/assets/icon.ico" ;;   # Windows (run under Git Bash / MSYS)
esac

rm -rf "$ROOT/dist/Rubik's Cube" "$ROOT/dist/Rubik's Cube.app"
jpackage --type app-image --name "Rubik's Cube" \
  --input "$BUILD/input" --main-jar sketch.jar --main-class RubiksCube \
  --icon "$ICON" "${JOPTS[@]}" --dest "$ROOT/dist"

echo "Done → $ROOT/dist"
