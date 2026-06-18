#!/bin/sh
set -eu

os="$(uname -s)"
if [ "$os" != "Darwin" ]; then
  echo "Unsupported platform: $os" >&2
  echo "This bootstrap currently supports macOS only." >&2
  exit 1
fi

repo_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
chezmoi_config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/chezmoi"
chezmoi_config_file="$chezmoi_config_dir/chezmoi.toml"
dotfiles_repo_url="${DOTFILES_REPO_URL:-https://github.com/philipbjorge/dotfiles.git}"
dotfiles_dir="${DOTFILES_DIR:-$HOME/src/dotfiles}"

toml_escape() {
  printf "%s" "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

if ! command -v brew >/dev/null 2>&1; then
  echo "Installing Homebrew..."
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

if [ -x /opt/homebrew/bin/brew ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -x /usr/local/bin/brew ]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

echo "Installing bootstrap packages..."
brew install git chezmoi mise

if [ ! -f "$repo_dir/dot_gitconfig.tmpl" ]; then
  echo "Cloning dotfiles into $dotfiles_dir"
  mkdir -p "$(dirname -- "$dotfiles_dir")"
  if [ -d "$dotfiles_dir/.git" ]; then
    git -C "$dotfiles_dir" pull --ff-only
  else
    git clone "$dotfiles_repo_url" "$dotfiles_dir"
  fi
  repo_dir="$dotfiles_dir"
fi

if [ ! -f "$chezmoi_config_file" ]; then
  echo "Creating starter chezmoi config at $chezmoi_config_file"
  mkdir -p "$chezmoi_config_dir"
  git_name="$(git config --global user.name 2>/dev/null || true)"
  git_email="$(git config --global user.email 2>/dev/null || true)"
  {
    printf "[data]\n"
    printf "profile = \"personal\"\n"
    printf "name = \"%s\"\n" "$(toml_escape "${git_name:-Philip Bjorge}")"
    printf "email = \"%s\"\n" "$(toml_escape "${git_email:-github@philipbjorge.com}")"
    printf "install_gui_apps = true\n"
  } >"$chezmoi_config_file"
  echo "Edit $chezmoi_config_file if this machine should use a different profile or email."
fi

echo "Applying dotfiles..."
chezmoi init --apply "$repo_dir"
