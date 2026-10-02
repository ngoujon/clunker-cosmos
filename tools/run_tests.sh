#!/usr/bin/env bash
# Lance une suite headless et n'affiche que l'essentiel (erreurs, échecs, résumé).
cd "$(dirname "$0")/.."
G="${GODOT_BIN:-$HOME/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe}"
timeout "${TIMEOUT:-600}" "$G" --headless --path . res://tests/runner.tscn -- "$@" 2>&1 | grep -v -E "^\s*$|^\s+ok\s|GDScript backtrace|^\s+\[[0-9]+\]|push_warning|Godot Engine v" 
