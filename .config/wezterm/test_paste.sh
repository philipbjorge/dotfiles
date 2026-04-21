#!/usr/bin/env bash
# Test harness for paste.sh. Stubs pngpaste/pbpaste/ssh/scp via a PATH shim,
# invokes paste.sh, asserts stdout. No real clipboard or network involved.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
script="$here/paste.sh"
stub_dir="$(mktemp -d)"
fake_home="$(mktemp -d)"
trap 'rm -rf "$stub_dir" "$fake_home"' EXIT

# --- stub helpers -----------------------------------------------------------

# Write a fake executable at $stub_dir/$name that echoes $out and exits $rc.
# $out may contain newlines. Use PNG_FILE env to have pngpaste write a real PNG.
stub() {
  local name="$1" rc="$2" out="${3:-}"
  cat >"$stub_dir/$name" <<EOF
#!/usr/bin/env bash
[[ -n "\${PNG_FILE:-}" && "$name" == "pngpaste" ]] && {
  # simulate pngpaste writing out a tiny valid PNG to \$1
  printf '\x89PNG\r\n\x1a\n' > "\$1"
  exit 0
}
printf '%s' "${out}"
exit $rc
EOF
  chmod +x "$stub_dir/$name"
}

# Reset stubs for each case.
reset_stubs() {
  rm -f "$stub_dir"/*
  # Default: no image on clipboard, no text on clipboard.
  stub pngpaste 1 ""
  stub pbpaste  0 ""
  stub ssh      0 ""
  stub scp      0 ""
}

run() {
  # Run paste.sh with a sanitized PATH (stubs first, real bins after).
  PATH="$stub_dir:/usr/bin:/bin" HOME="$fake_home" bash "$script" "$@"
}

pass=0; fail=0
assert_eq() {
  local name="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    printf '  PASS  %s\n' "$name"; pass=$((pass+1))
  else
    printf '  FAIL  %s\n    expected: %q\n    actual:   %q\n' "$name" "$expected" "$actual"
    fail=$((fail+1))
  fi
}

# --- cases ------------------------------------------------------------------

# 1: Empty clipboard → empty stdout.
reset_stubs
out="$(run local)"
assert_eq "empty clipboard" "" "$out"

# 2: Plain text clipboard → verbatim stdout.
reset_stubs
stub pbpaste 0 "hello world"
out="$(run local)"
assert_eq "plain text" "hello world" "$out"

# 3: Image bytes on clipboard → local cache path.
reset_stubs
PNG_FILE=1 stub pngpaste 0 ""   # triggers the real-png branch inside the stub
out="$(PNG_FILE=1 run local)"
# Expect: path under $fake_home/Library/Caches/wezterm-paste/clip_*.png, file exists.
case "$out" in
  "$fake_home/Library/Caches/wezterm-paste/clip_"*.png)
    [[ -f "$out" ]] && assert_eq "image bytes (file exists)" "yes" "yes" \
                     || assert_eq "image bytes (file exists)" "yes" "no"
    ;;
  *) assert_eq "image bytes (path shape)" "<local cache path>" "$out" ;;
esac

# 4: CleanShot path (single-quoted PNG that exists) → quoted path stripped.
reset_stubs
real_png="$fake_home/Pictures/shot.png"
mkdir -p "$(dirname "$real_png")"
printf '\x89PNG\r\n\x1a\n' > "$real_png"
stub pbpaste 0 "'$real_png'"
out="$(run local)"
assert_eq "cleanshot path" "$real_png" "$out"

# 5: CleanShot path pointing at a missing file → falls back to text.
reset_stubs
stub pbpaste 0 "'$fake_home/does-not-exist.png'"
out="$(run local)"
assert_eq "missing file falls back to text" "'$fake_home/does-not-exist.png'" "$out"

# 6: pngpaste missing entirely → text path still works.
reset_stubs
rm -f "$stub_dir/pngpaste"
stub pbpaste 0 "fallback text"
out="$(run local)"
assert_eq "pngpaste missing" "fallback text" "$out"

# 7: Remote pane with image bytes → scp called, absolute remote path printed.
reset_stubs
PNG_FILE=1 stub pngpaste 0 ""
# ssh used twice: once to resolve $HOME, once to mkdir/cleanup.
# We distinguish by command: if any arg contains "printf", return a fake home.
cat >"$stub_dir/ssh" <<'EOF'
#!/usr/bin/env bash
for a in "$@"; do
  case "$a" in
    *"printf"*) printf '/home/remote-phil'; exit 0 ;;
  esac
done
exit 0
EOF
chmod +x "$stub_dir/ssh"
# scp: record args to a file, succeed.
cat >"$stub_dir/scp" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$@" > "$stub_dir/scp.args"
exit 0
EOF
chmod +x "$stub_dir/scp"

out="$(PNG_FILE=1 run baker)"
case "$out" in
  /home/remote-phil/.cache/wezterm-paste/clip_*.png)
    assert_eq "remote image (path shape)" "ok" "ok" ;;
  *) assert_eq "remote image (path shape)" "<remote cache path>" "$out" ;;
esac
[[ -f "$stub_dir/scp.args" ]] \
  && assert_eq "scp was invoked" "yes" "yes" \
  || assert_eq "scp was invoked" "yes" "no"

# 8: Remote pane with CleanShot path containing spaces → sanitized basename.
reset_stubs
real_png="$fake_home/Pictures/shot with spaces.png"
mkdir -p "$(dirname "$real_png")"
printf '\x89PNG\r\n\x1a\n' > "$real_png"
stub pbpaste 0 "'$real_png'"
cat >"$stub_dir/ssh" <<'EOF'
#!/usr/bin/env bash
for a in "$@"; do
  case "$a" in *"printf"*) printf '/home/remote-phil'; exit 0 ;; esac
done
exit 0
EOF
chmod +x "$stub_dir/ssh"
stub scp 0 ""
out="$(run baker)"
case "$out" in
  */shot_with_spaces.png) assert_eq "space-sanitized basename" "ok" "ok" ;;
  *) assert_eq "space-sanitized basename" "<sanitized>" "$out" ;;
esac

# 9: Remote scp failure → non-zero exit, empty stdout.
reset_stubs
PNG_FILE=1 stub pngpaste 0 ""
cat >"$stub_dir/ssh" <<'EOF'
#!/usr/bin/env bash
for a in "$@"; do
  case "$a" in *"printf"*) printf '/home/remote-phil'; exit 0 ;; esac
done
exit 0
EOF
chmod +x "$stub_dir/ssh"
stub scp 1 "scp: network unreachable"
out="$(PNG_FILE=1 run baker 2>/dev/null)"; rc=$?
assert_eq "scp failure: empty stdout" "" "$out"
[[ $rc -ne 0 ]] \
  && assert_eq "scp failure: non-zero exit" "nonzero" "nonzero" \
  || assert_eq "scp failure: non-zero exit" "nonzero" "zero"

# 10: Remote ssh-HOME resolution failure → non-zero, no stdout.
reset_stubs
PNG_FILE=1 stub pngpaste 0 ""
stub ssh 1 ""
out="$(PNG_FILE=1 run baker 2>/dev/null)"; rc=$?
assert_eq "ssh-HOME failure: empty stdout" "" "$out"
[[ $rc -ne 0 ]] \
  && assert_eq "ssh-HOME failure: non-zero exit" "nonzero" "nonzero" \
  || assert_eq "ssh-HOME failure: non-zero exit" "nonzero" "zero"

# --- summary ----------------------------------------------------------------
echo
echo "passed: $pass, failed: $fail"
if [[ $fail -eq 0 ]]; then
  echo "all 10 cases passed"
  exit 0
fi
exit 1
