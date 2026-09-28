#!/usr/bin/env bash
# macOS notification for Claude Code hooks.
#
# Usage: notify.sh finished|input
#
# The hook payload arrives as JSON on stdin; its .cwd tells us which project
# fired the hook, so the notification can name the repo. Deliberately never
# exits non-zero and never blocks: a notification must not be able to break or
# delay a turn.
#
# If the project is open in a running JetBrains IDE and terminal-notifier is
# installed, the notification is clickable and brings that project forward.
# Without terminal-notifier it falls back to a plain osascript banner, because
# osascript notifications cannot carry a click action.

set -uo pipefail

event="${1:-finished}"

[ "$(uname -s)" = "Darwin" ] || exit 0

script_dir="$(cd "$(dirname "$0")" && pwd)"

# --- work out which project this is -----------------------------------------

payload=""
if [ ! -t 0 ]; then
  payload="$(cat 2>/dev/null)" || payload=""
fi

project_dir=""
if [ -n "$payload" ] && command -v jq > /dev/null 2>&1; then
  project_dir="$(printf '%s' "$payload" | jq -r '.cwd // empty' 2>/dev/null)" || project_dir=""
fi
[ -n "$project_dir" ] && [ -d "$project_dir" ] || project_dir="$PWD"

if repo_root="$(git -C "$project_dir" rev-parse --show-toplevel 2>/dev/null)" && [ -n "$repo_root" ]; then
  project_dir="$repo_root"
fi
project="$(basename "$project_dir")"
[ -n "$project" ] || project="Claude Code"

# --- message per event -------------------------------------------------------

case "$event" in
  input)
    body="Waiting for your input"
    ;;
  *)
    body="Finished — turn complete"
    ;;
esac

# --- is it open in a JetBrains IDE? ------------------------------------------

ide_app=""
detector="$script_dir/detect-jetbrains.py"
if [ -x "$detector" ] && command -v python3 > /dev/null 2>&1; then
  ide_app="$(python3 "$detector" "$project_dir" 2>/dev/null)" || ide_app=""
fi

# --- notify ------------------------------------------------------------------

subtitle="Claude Code"

if command -v terminal-notifier > /dev/null 2>&1; then
  args=(
    -title "$project"
    -message "$body"
    -group "claude-code-$project_dir"
  )
  if [ -n "$ide_app" ] && [ -d "$ide_app" ]; then
    # Only advertise the IDE when clicking will actually open it.
    subtitle="Claude Code · $(basename "${ide_app%.app}")"
    args+=(-execute "open -a $(printf '%q' "$ide_app") $(printf '%q' "$project_dir")")
  fi
  args+=(-subtitle "$subtitle")
  terminal-notifier "${args[@]}" > /dev/null 2>&1 || true
  exit 0
fi

escape_applescript() {
  printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'
}

osascript -e "display notification \"$(escape_applescript "$body")\" \
  with title \"$(escape_applescript "$project")\" \
  subtitle \"$(escape_applescript "$subtitle")\"" > /dev/null 2>&1 || true

exit 0
