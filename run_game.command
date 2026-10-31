#!/bin/zsh
set -e
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
GODOT_BIN="$HOME/Applications/Godot.app/Contents/MacOS/Godot"
if [[ ! -x "$GODOT_BIN" ]]; then
  echo "请先安装 Godot 4.5，或修改 run_game.command 中的 GODOT_BIN 路径。"
  exit 1
fi
exec "$GODOT_BIN" --path "$PROJECT_DIR"
