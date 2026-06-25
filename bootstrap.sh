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
elif [ -d "$repo_dir/.git" ]; then
  if [ -z "$(git -C "$repo_dir" status --porcelain)" ]; then
    echo "Updating dotfiles repo..."
    git -C "$repo_dir" pull --ff-only
  else
    echo "Skipping dotfiles repo update because it has local changes."
  fi
fi

if [ ! -f "$chezmoi_config_file" ]; then
  echo "Creating starter chezmoi config at $chezmoi_config_file"
  mkdir -p "$chezmoi_config_dir"
  git_name="$(git config --global user.name 2>/dev/null || true)"
  git_email="$(git config --global user.email 2>/dev/null || true)"
  {
    printf "sourceDir = \"%s\"\n\n" "$(toml_escape "$repo_dir")"
    printf "[data]\n"
    printf "profile = \"personal\"\n"
    printf "name = \"%s\"\n" "$(toml_escape "${git_name:-Philip Bjorge}")"
    printf "email = \"%s\"\n" "$(toml_escape "${git_email:-github@philipbjorge.com}")"
  } >"$chezmoi_config_file"
  echo "Edit $chezmoi_config_file if this machine should use a different profile or email."
fi

echo "Applying dotfiles..."
chezmoi apply

if [ -f "$HOME/Brewfile" ]; then
  echo "Ensuring Homebrew bundle is installed..."
  brew bundle --file "$HOME/Brewfile"
fi

cat <<EOF

Dotfiles applied.

Next steps:
  cd "$repo_dir"
  scripts/setup-auth
  scripts/doctor
EOF

if [ -t 0 ]; then
  if [ -x "$repo_dir/scripts/setup-auth" ]; then
    printf "\nRun guided auth setup now? [y/N] "
    read auth_reply
    case "$auth_reply" in
      y|Y|yes|YES)
        "$repo_dir/scripts/setup-auth" || true
        ;;
    esac
  fi

  if [ -x "$repo_dir/scripts/doctor" ]; then
    printf "\nRun doctor now? [y/N] "
    read doctor_reply
    case "$doctor_reply" in
      y|Y|yes|YES)
        "$repo_dir/scripts/doctor" || true
        ;;
    esac
  fi
fi
