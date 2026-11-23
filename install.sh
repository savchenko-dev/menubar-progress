#!/usr/bin/env bash
# Manual install (no plugin system needed).
#   install.sh [claude] [codex] [opencode] [pi] [--uninstall]      default: claude
# Files go to $MBP_HOME (default ~/.config/menubar-progress), `mbp` is linked into ~/.local/bin,
# each harness gets the skill:
#   claude    $CLAUDE_CONFIG_DIR/skills/menubar-progress
#   codex, pi ~/.agents/skills/menubar-progress
#   opencode  ~/.config/opencode/skills/menubar-progress
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOME_DIR="${MBP_HOME:-$HOME/.config/menubar-progress}"
BIN_LINK="$HOME/.local/bin/mbp"
UN=0; TARGETS=()
for a in "$@"; do case "$a" in --uninstall) UN=1;; claude|codex|opencode|pi) TARGETS+=("$a");; *) echo "unknown: $a" >&2; exit 64;; esac; done
[ ${#TARGETS[@]} -gt 0 ] || TARGETS=(claude)

if [ "$UN" = 1 ]; then
  "$HOME_DIR/bin/mbp" stop 2>/dev/null || true
  rm -rf "$HOME_DIR"; [ -L "$BIN_LINK" ] && rm -f "$BIN_LINK"
else
  mkdir -p "$HOME_DIR/bin" "$HOME_DIR/app" "$(dirname "$BIN_LINK")"
  cp "$HERE/bin/mbp" "$HOME_DIR/bin/"; cp "$HERE/app/MenubarProgress.swift" "$HOME_DIR/app/"
  chmod +x "$HOME_DIR/bin/mbp"; ln -sf "$HOME_DIR/bin/mbp" "$BIN_LINK"
  "$HOME_DIR/bin/mbp" build && echo "built the menu bar app"
fi

skill_to() {
  if [ "$UN" = 1 ]; then rm -rf "$1"; echo "removed $1"; return; fi
  mkdir -p "$1"
  sed "s#\${CLAUDE_PLUGIN_ROOT}/bin/mbp#$HOME_DIR/bin/mbp#g" "$HERE/skills/menubar-progress/SKILL.md" > "$1/SKILL.md"
  echo "skill -> $1"
}

for t in "${TARGETS[@]}"; do
  case "$t" in
    claude)   skill_to "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills/menubar-progress";;
    codex|pi) skill_to "$HOME/.agents/skills/menubar-progress";;
    opencode) skill_to "$HOME/.config/opencode/skills/menubar-progress";;
  esac
done
