#!/usr/bin/env bash
# macOS notification for Claude Code hooks.
#
# Usage: notify.sh finished|input
#
# The hook payload arrives as JSON on stdin; its .cwd tells us which project
# fired the hook, so the notification can name the repo. Deliberately never
# exits non-zero and never blocks: a notification must not be able to break or
# delay a turn.

set -uo pipefail

event="${1:-finished}"

[ "$(uname -s)" = "Darwin" ] || exit 0

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
  project="$(basename "$repo_root")"
else
  project="$(basename "$project_dir")"
fi
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

# --- notify ------------------------------------------------------------------

escape_applescript() {
  printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'
}

osascript -e "display notification \"$(escape_applescript "$body")\" \
  with title \"$(escape_applescript "$project")\" \
  subtitle \"Claude Code\"" > /dev/null 2>&1 || true

exit 0
