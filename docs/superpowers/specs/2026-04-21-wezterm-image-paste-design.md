# Wezterm image-paste for sshmux panes

## Problem

On macOS, `cmd+v` in a wezterm pane does not produce the image when the clipboard holds a screenshot:

- **Native macOS screenshot** → clipboard holds raw image bytes. Wezterm has no text to paste, so cmd+v is a no-op.
- **CleanShot "copy path after capture"** → clipboard holds the file path as text (e.g. `'/Users/philipbjorge/Library/Application Support/CleanShot/.../CleanShot 2026-04-21 at 07.58.17@2x.png'`). cmd+v pastes the local path verbatim, which is useless inside a pane whose shell is running on baker.

We want cmd+v in wezterm to Do The Right Thing for both clipboard shapes, on both local and remote (sshmux) panes. The target consumers are CLI tools on the remote side that accept a file path — Claude Code, Codex, nvim image plugins, etc.

Reference: [wezterm#7272](https://github.com/wezterm/wezterm/issues/7272) — same use case, community solution from `mischadiehm` is the basis for this design.

## Goals

- `cmd+v` works the same way regardless of clipboard shape: pastes a path to a usable PNG (local or remote).
- Text paste (anything that isn't an image) behaves as before.
- Remote uploads land in a predictable, self-cleaning location.
- Fail-safe: if the image path breaks (missing `pngpaste`, scp error), fall back to normal text paste so cmd+v is never "broken".

## Non-goals

- Pasting image *bytes* into the pane via OSC escape codes (e.g. kitty image protocol). Consumers want a path.
- Non-image file types. PNG / common image formats only.
- Supporting clipboard sources other than local Mac (no Linux/Windows local paths).
- Waiting on [wezterm PR #7621](https://github.com/wezterm/wezterm/pull/7621) to land native `PasteImageToSshUpload` — we'll adopt that if/when it merges and retire this code.

## Design

### Architecture

```
┌──────────────────────┐      ┌─────────────────────────┐      ┌─────────────────┐
│  .wezterm.lua        │      │  paste.sh <domain>      │      │  remote host    │
│  cmd+v keybind       │─────▶│  - pngpaste → tmp.png   │─────▶│  ~/.cache/      │
│  run_child_process   │      │  - or parse pbpaste     │      │  wezterm-paste/ │
│  pane:send_paste(..) │◀─────│  - scp to remote        │      │  <file>.png     │
└──────────────────────┘      │  - print path to stdout │      └─────────────────┘
                              └─────────────────────────┘
```

Two components: a wezterm Lua keybind and a standalone shell script.

### Components

#### `~/.wezterm.lua` (edit existing)

Add one entry to `config.keys`:

```lua
{
  key = "v",
  mods = "CMD",
  action = wezterm.action_callback(function(window, pane)
    local domain = pane:get_domain_name() or "local"
    local ok, stdout, stderr = wezterm.run_child_process({
      os.getenv("HOME") .. "/.config/wezterm/paste.sh", domain,
    })
    if ok and stdout and #stdout > 0 then
      pane:send_paste(stdout)
    elseif stderr and #stderr > 0 then
      wezterm.log_error("wezterm-paste: " .. stderr)
    end
  end),
},
```

Notes:
- Lua calls the script directly (not via `zsh -lc`); the script has its own shebang. Keeps startup fast and avoids inheriting unpredictable shell rc state.
- On error we log to wezterm's debug log (`Help → Show debug overlay`) and send nothing, so a broken clipboard doesn't corrupt the pane.

#### `~/.config/wezterm/paste.sh` (new)

Bash script (`#!/usr/bin/env bash`, `set -euo pipefail`), responsibilities in order. Argument `$1` is the wezterm domain name — `"local"` means local pane, anything else is treated as an ssh Host alias that `scp`/`ssh` can resolve via `~/.ssh/config`:

1. **Cache setup**: `mkdir -p ~/Library/Caches/wezterm-paste` on the Mac. `find <cache> -type f -mtime +7 -delete` before doing anything (rolling 7-day cleanup, cheap, runs on every cmd+v).
2. **Detect clipboard image bytes**: `pngpaste "$cache/clip_$(date +%s%N).png"`. On success, `src=` that path. On failure, fall through.
3. **Detect clipboard file path (CleanShot case)**: `text=$(pbpaste -Prefer txt)`. Strip at most one leading and one trailing single-quote via `sed -E "s/^'//; s/'$//"` (CleanShot wraps paths in single quotes). If the result matches `*.png|*.jpg|*.jpeg|*.gif|*.webp|*.heic` (case-insensitive) and `-f` the file → `src=` that path.
4. **Neither** → `printf '%s' "$text"` and exit. (Normal text paste continues to work; empty clipboard prints nothing and cmd+v is a no-op.)
5. **Have `src`, domain is `local`** → `printf '%s' "$src"` and exit.
6. **Have `src`, domain is remote**:
   - `safe_name = basename "$src" | tr ' /' '__'` — so the remote path is shell-safe when pasted unquoted.
   - `remote=.cache/wezterm-paste/$safe_name`
   - `ssh "$domain" "mkdir -p ~/.cache/wezterm-paste && find ~/.cache/wezterm-paste -mtime +7 -delete"` (stderr only)
   - `scp -q "$src" "$domain:$remote"`
   - `printf '%s' "$HOME_remote/$remote"` — we print the *absolute* remote path (resolved via `ssh "$domain" 'echo $HOME'` cached once per run) so it works regardless of the remote pane's cwd. Tilde expansion happens in the remote shell when the path is pasted, but absolute is safer for arbitrary tools (Claude Code has historically handled `~` inconsistently).

Script is idempotent and has no side-effects beyond writing to cache directories and printing stdout.

#### `bootstrap.sh` (edit existing)

- Symlink `~/.config/wezterm/paste.sh` → `$DOTFILES/.config/wezterm/paste.sh`.
- Install dependency: `brew install pngpaste` (guarded by `command -v pngpaste`).

### Data flow

**Local pane, native screenshot:**
```
cmd+v → paste.sh local
      → pngpaste ~/Library/Caches/wezterm-paste/clip_17XXXXXX.png
      → stdout: /Users/phil/Library/Caches/wezterm-paste/clip_17XXXXXX.png
      → send_paste → pane
```

**Remote pane (baker), CleanShot path:**
```
cmd+v → paste.sh baker
      → pbpaste reads "'.../CleanShot 2026-04-21....png'"
      → strip quotes, stat ok, src set
      → ssh baker 'mkdir -p ~/.cache/wezterm-paste && find ...'
      → scp src baker:.cache/wezterm-paste/CleanShot_2026-04-21....png
      → stdout: /home/phil/.cache/wezterm-paste/CleanShot_2026-04-21....png
      → send_paste → pane (Claude Code / nvim / whatever)
```

**Any pane, non-image text:**
```
cmd+v → paste.sh <domain>
      → pngpaste fails, pbpaste text not a file
      → stdout: <verbatim text>
      → send_paste
```

### Error handling

| Failure mode | Behavior |
|---|---|
| `pngpaste` not installed | Script logs to stderr, falls through to text path. User fixes via `brew install pngpaste`. |
| Clipboard is text, not an image path | Falls through to verbatim text paste. |
| Clipboard text references a missing file | Falls through to verbatim text paste. |
| SSH/SCP fails (network, auth) | `set -e` kills the script; stderr captured by Lua and logged to wezterm debug. `send_paste` gets no stdout → cmd+v is a no-op rather than pasting wrong. Surface in logs, user can retry. |
| Remote mkdir/find fails | Same as scp failure. |
| Domain name doesn't match an ssh Host | `ssh`/`scp` fail as above. |

Deliberate choice: no "fall back to text on remote error" — if the user has an image on the clipboard and we can't upload it, silently pasting a local Mac path into a baker shell is worse than pasting nothing.

### Testing

Standalone script testable without wezterm:

```
./paste.sh local   # various clipboard states
./paste.sh baker   # after copying an image
```

End-to-end in wezterm:
- [ ] cmd+v, native screenshot on clipboard, local pane → pastes local cache path.
- [ ] cmd+v, native screenshot on clipboard, baker pane → file uploaded, remote path pasted.
- [ ] cmd+v, CleanShot path on clipboard, baker pane → file uploaded, remote path pasted.
- [ ] cmd+v, plain text on clipboard, any pane → verbatim text pasted (regression check).
- [ ] cmd+v, empty clipboard → no-op, no error in wezterm log.
- [ ] `pngpaste` uninstalled → text paste still works; image paste fails gracefully.
- [ ] After a week of use, `find ~/.cache/wezterm-paste -type f | wc -l` stays bounded.

## Open questions

None. Ready to plan.

## Future work

- If wezterm#7621 merges, replace this with the native `PasteImageToSshUpload` action and delete `paste.sh`.
- If usage grows, consider a manifest file next to cached images to track provenance (which cmd+v paste created which file) for debugging.
