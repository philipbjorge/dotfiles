#!/usr/bin/env bash
# paste.sh <domain>
# Decode the macOS clipboard for wezterm cmd+v:
#  - image bytes   → save to local cache, print path
#  - CleanShot path (single-quoted path to an image file that exists) → print stripped path
#  - anything else → print clipboard text verbatim
# For non-local domains, scp the resolved file to ~/.cache/wezterm-paste/ on
# the target host and print the absolute remote path.

set -uo pipefail

domain="${1:-local}"

cache="$HOME/Library/Caches/wezterm-paste"
mkdir -p "$cache"
find "$cache" -type f -mtime +7 -delete 2>/dev/null || true

src=""

# 1. Image bytes on clipboard?
if command -v pngpaste >/dev/null 2>&1; then
  candidate="$cache/clip_$(date +%s)_$$.png"
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

# 5. Remote pane → upload via scp, print absolute remote path.

remote_home="$(ssh -o BatchMode=yes "$domain" 'printf %s "$HOME"')" || {
  echo "paste.sh: ssh to $domain failed" >&2
  exit 2
}

safe_name="$(basename "$src" | tr ' /' '__')"
remote_dir=".cache/wezterm-paste"
remote_path="$remote_home/$remote_dir/$safe_name"

ssh -o BatchMode=yes "$domain" \
  "mkdir -p ~/$remote_dir && find ~/$remote_dir -type f -mtime +7 -delete 2>/dev/null || true" \
  >&2 || { echo "paste.sh: remote mkdir failed" >&2; exit 2; }

scp -q "$src" "$domain:$remote_dir/$safe_name" >&2 || {
  echo "paste.sh: scp failed" >&2
  exit 2
}

printf '%s' "$remote_path"
