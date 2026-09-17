#!/usr/bin/env bash
# Symlinks each skill in this repo into ~/.claude/skills.
set -euo pipefail

repo_dir="$(cd "$(dirname "$0")" && pwd)"
target_dir="$HOME/.claude/skills"
mkdir -p "$target_dir"

for skill in "$repo_dir"/skills/*/; do
  name="$(basename "$skill")"
  dest="$target_dir/$name"

  if [ -L "$dest" ]; then
    ln -sfn "${skill%/}" "$dest"
    echo "Updated link: $name"
  elif [ -e "$dest" ]; then
    echo "Skipped $name: $dest already exists and is not a symlink"
  else
    ln -s "${skill%/}" "$dest"
    echo "Linked: $name"
  fi
done
