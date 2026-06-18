#!/bin/sh
set -eu

os="$(uname -s)"
if [ "$os" != "Darwin" ]; then
  echo "Unsupported platform: $os" >&2
  echo "This bootstrap currently supports macOS only." >&2
  exit 1
fi

repo_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"

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
brew install chezmoi mise

echo "Applying dotfiles..."
chezmoi init --apply "$repo_dir"
