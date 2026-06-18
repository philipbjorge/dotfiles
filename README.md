# dotfiles

macOS-first dotfiles managed by chezmoi, with Homebrew for machine packages and mise for dev tooling.
The interactive shell is configured with [Zsh for Humans](https://github.com/romkatv/zsh4humans) and Powerlevel10k.

## Bootstrap

```sh
./bootstrap.sh
```

The bootstrap currently supports macOS only. It installs Homebrew if needed, installs `git`, `chezmoi`, and `mise` with Brew, creates a starter chezmoi config if needed, then applies this repository with chezmoi.

After bootstrap, run:

```sh
scripts/doctor
```

`scripts/doctor` may report auth failures until GitHub and 1Password are signed in.

For guided auth setup, run:

```sh
scripts/setup-auth
```

## New Mac

One-command install:

```sh
/bin/sh -c "$(curl -fsSL https://raw.githubusercontent.com/philipbjorge/dotfiles/main/bootstrap.sh)"
```

This installs Homebrew if needed, installs `git`, `chezmoi`, and `mise`, clones this repo to `~/src/dotfiles`, creates a starter chezmoi config if needed, applies the dotfiles, then offers to run auth setup and doctor.

For a work machine, create `~/.config/chezmoi/chezmoi.toml` first if you want the first apply to use work identity data:

```sh
mkdir -p ~/.config/chezmoi
cat > ~/.config/chezmoi/chezmoi.toml <<'EOF'
[data]
profile = "work"
name = "Philip Bjorge"
email = "YOUR_WORK_EMAIL"
install_gui_apps = true
EOF
```

Then run the one-command install above.

Manual install:

Clone the repo:

```sh
mkdir -p ~/src
cd ~/src
git clone https://github.com/philipbjorge/dotfiles.git
cd dotfiles
```

Optional: create machine-specific data before bootstrapping. If this file does not exist, `bootstrap.sh` creates a personal starter config.

```sh
mkdir -p ~/.config/chezmoi
cat > ~/.config/chezmoi/chezmoi.toml <<'EOF'
[data]
profile = "work"
name = "Philip Bjorge"
email = "YOUR_WORK_EMAIL"
install_gui_apps = true
EOF
```

Run bootstrap:

```sh
./bootstrap.sh
```

Bootstrap prints the next steps and, when running in an interactive terminal, offers to run auth setup and doctor. Open a fresh terminal afterwards so the new zsh config is fully loaded.

Manual validation:

```sh
cd ~/src/dotfiles
scripts/doctor
```

## GitHub Auth

After bootstrap, authenticate GitHub CLI and let it configure GitHub-specific Git credentials. The guided path is:

```sh
scripts/setup-auth
```

The manual commands are:

```sh
gh auth login
gh auth setup-git
```

The generated Git config also enables the macOS Keychain credential helper as the default credential store.

## 1Password Auth

The Brewfile installs the 1Password desktop app and `op` CLI. After bootstrap:

1. Open 1Password and sign in.
2. In 1Password, enable CLI integration:
   - Settings > Developer > Integrate with 1Password CLI
   - Enable Touch ID if desired.
3. Verify CLI auth:

```sh
op vault list
```

1Password authentication is intentionally manual. Once the app integration is enabled, `op` prompts through the desktop app. Future templates can use chezmoi's `onepasswordRead` helper for secrets without storing them in this repo.

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
