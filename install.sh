#!/usr/bin/env bash
# Symlinks each skill in this repo into ~/.claude/skills, CLAUDE.md into ~/.claude and
# bin/ into ~/.claude/bin, then merges hooks.json into ~/.claude/settings.json.
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

# Scripts the hooks call. Linked to a fixed path so hooks.json can name it
# literally instead of hardcoding wherever this repo happens to be cloned.
bin_dir="$HOME/.claude/bin"
mkdir -p "$bin_dir"
for script in "$repo_dir"/bin/*; do
  [ -e "$script" ] || continue
  link "$script" "$bin_dir/$(basename "$script")"
done

# Merge the notification hooks in hooks.json into ~/.claude/settings.json.
# Merged rather than symlinked: settings.json is a live file Claude Code writes to
# (permissions, theme), so it must keep whatever is already on this machine.
install_hooks() {
  local hooks_file="$repo_dir/hooks.json"
  local settings="$HOME/.claude/settings.json"

  [ -f "$hooks_file" ] || return 0

  if [ "$(uname -s)" != "Darwin" ]; then
    echo "Skipped hooks: notifications use osascript, which is macOS-only"
    return 0
  fi

  if ! command -v jq > /dev/null 2>&1; then
    echo "Skipped hooks: jq not installed (brew install jq, then re-run)"
    return 0
  fi

  [ -f "$settings" ] || echo '{}' > "$settings"

  if ! jq -e . "$settings" > /dev/null 2>&1; then
    echo "Skipped hooks: $settings is not valid JSON"
    return 0
  fi

  local tmp
  tmp="$(mktemp)"

  # Entries are tagged with a "claude-config:" marker comment so re-running
  # replaces them instead of stacking up duplicates. Matching on the prefix
  # also clears entries written by older versions of this repo.
  jq --slurpfile new "$hooks_file" '
    def strip_ours:
      (. // {})
      | with_entries(
          .value |= map(
            select(
              [ .hooks[]? | .command? // "" | contains("claude-config:") ] | any | not
            )
          )
        )
      | with_entries(select(.value | length > 0));

    .hooks = (
      (.hooks | strip_ours) as $kept
      | reduce ($new[0] | to_entries[]) as $e
          ($kept; .[$e.key] = ((.[$e.key] // []) + $e.value))
    )
  ' "$settings" > "$tmp" && mv "$tmp" "$settings"

  echo "Merged hooks into settings.json"
}

install_hooks
