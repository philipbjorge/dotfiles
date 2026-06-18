# dotfiles

macOS-first dotfiles managed by chezmoi, with Homebrew for machine packages and mise for dev tooling.
The interactive shell is configured with [Zsh for Humans](https://github.com/romkatv/zsh4humans) and Powerlevel10k.

## Bootstrap

```sh
./bootstrap.sh
```

The bootstrap currently supports macOS only. It installs Homebrew if needed, installs `chezmoi` and `mise` with Brew, then applies this repository with chezmoi.

After bootstrap, run:

```sh
scripts/doctor
```

## GitHub Auth

After bootstrap, authenticate GitHub CLI and let it configure GitHub-specific Git credentials:

```sh
gh auth login
gh auth setup-git
```

The generated Git config also enables the macOS Keychain credential helper as the default credential store.

## Local machine data

chezmoi can use machine-local data from:

```text
~/.config/chezmoi/chezmoi.toml
```

Example:

```toml
[data]
profile = "personal"
name = "Philip Bjorge"
email = "github@philipbjorge.com"
install_gui_apps = true
```
