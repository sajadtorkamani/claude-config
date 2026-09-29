#!/usr/bin/env bash
# Symlinks each skill in this repo into ~/.claude/skills, and CLAUDE.md into ~/.claude.
set -euo pipefail

repo_dir="$(cd "$(dirname "$0")" && pwd)"
skills_dir="$HOME/.claude/skills"
mkdir -p "$skills_dir"

link() {
  local src="$1"
  local dest="$2"
  local name="$(basename "$src")"

  if [ -L "$dest" ]; then
    ln -sfn "$src" "$dest"
    echo "Updated link: $name"
  elif [ -e "$dest" ]; then
    echo "Skipped $name: $dest already exists and is not a symlink"
  else
    ln -s "$src" "$dest"
    echo "Linked: $name"
  fi
}

for skill in "$repo_dir"/skills/*/; do
  link "${skill%/}" "$skills_dir/$(basename "$skill")"
done

if [ -f "$repo_dir/CLAUDE.md" ]; then
  link "$repo_dir/CLAUDE.md" "$HOME/.claude/CLAUDE.md"
fi
