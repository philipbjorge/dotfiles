#!/usr/bin/env bash
# paste.sh <domain>
# Decode the macOS clipboard for wezterm cmd+v:
#  - image bytes   → save to local cache, print path
#  - CleanShot path (single-quoted path to an image file that exists) → print stripped path
#  - anything else → print clipboard text verbatim
# In this task the script only handles domain="local". Remote upload added in Task 2.

set -uo pipefail

domain="${1:-local}"

cache="$HOME/Library/Caches/wezterm-paste"
mkdir -p "$cache"
find "$cache" -type f -mtime +7 -delete 2>/dev/null || true

src=""

# 1. Image bytes on clipboard?
if command -v pngpaste >/dev/null 2>&1; then
  candidate="$cache/clip_$(date +%s).png"
  if pngpaste "$candidate" >/dev/null 2>&1; then
    src="$candidate"
  else
    rm -f "$candidate"
  fi
fi

# 2. CleanShot-style clipboard path?
text=""
if [[ -z "$src" ]]; then
  text="$(pbpaste -Prefer txt 2>/dev/null || true)"
  stripped="$(printf '%s' "$text" | sed -E "s/^'//; s/'\$//")"
  # Lowercase for extension match — `${var,,}` is bash 4+, macOS ships bash 3.2.
  lc="$(printf '%s' "$stripped" | tr '[:upper:]' '[:lower:]')"
  case "$lc" in
    *.png|*.jpg|*.jpeg|*.gif|*.webp|*.heic)
      if [[ -f "$stripped" ]]; then
        src="$stripped"
      fi
      ;;
  esac
fi

# 3. Nothing to upload → verbatim text (possibly empty).
if [[ -z "$src" ]]; then
  printf '%s' "$text"
  exit 0
fi

# 4. Local pane → just print the local path.
if [[ "$domain" == "local" ]]; then
  printf '%s' "$src"
  exit 0
fi

# 5. Remote pane → deferred to Task 2. For now, fail loud.
echo "paste.sh: remote upload not implemented yet (domain=$domain)" >&2
exit 2
