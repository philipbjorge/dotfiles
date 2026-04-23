# Dotfiles agent notes

## Update pi via mise

When asked to update `pi` in this repo:

1. Check the newest available version:
   - `mise ls-remote pi | tail -n 20`
2. Bump `pi` in `.config/mise/config.toml`.
3. Copy the repo pin to the global mise config so it applies outside this checkout:
   - `mkdir -p ~/.config/mise && cp .config/mise/config.toml ~/.config/mise/config.toml`
   - `./bootstrap.sh` also does this for you
4. Install it:
   - `mise install pi@<version>`
   - or just `mise install` after editing the config
5. Verify in a fresh shell (or run `exec zsh` first if the current shell still has the old PATH cached):
   - `mise current pi`
   - `pi --version`

Current source of truth for the pinned version: `.config/mise/config.toml`.
