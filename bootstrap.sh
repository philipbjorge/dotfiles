#!/usr/bin/env bash

cd "$(dirname "${BASH_SOURCE}")";

git pull origin main;

# Tools
install_pkg() {
  local pkg=$1
  if command -v brew &>/dev/null; then
    brew install "$pkg"
  elif command -v apt-get &>/dev/null; then
    sudo apt-get install -y "$pkg"
  elif command -v dnf &>/dev/null; then
    sudo dnf install -y "$pkg"
  elif command -v pacman &>/dev/null; then
    sudo pacman -S --noconfirm "$pkg"
  else
    echo "WARNING: could not install $pkg — no supported package manager found"
  fi
}

install_pkg ripgrep
install_pkg fd
install_pkg lazygit
install_pkg neovim
install_pkg tree-sitter-cli
install_pkg ruff

# Casks (macOS only)
install_cask() {
  if command -v brew &>/dev/null; then
    brew install --cask "$1"
  else
    echo "WARNING: skipping cask $1 — only supported on macOS with Homebrew"
  fi
}

install_cask font-jetbrains-mono-nerd-font
install_cask neovide

# Claude Code
if ! command -v claude &>/dev/null; then
	curl -fsSL https://claude.ai/install.sh | bash
fi
claude plugin install superpowers@claude-plugins-official

rsync --exclude ".git/" \
	--exclude ".DS_Store" \
	--exclude ".osx" \
	--exclude "bootstrap.sh" \
	--exclude "README.md" \
	--exclude "LICENSE-MIT.txt" \
	-avh --no-perms . ~;

# Create default .zshenv and .zshrc if they don't already exist.
# These source the dotfiles-managed versions, so you can add local
# customizations below the source line without them being overwritten.
if [ ! -f ~/.zshenv ]; then
	cat > ~/.zshenv <<'EOF'
source ~/.zshenv.dotfiles

# Add your local customizations below this line.
EOF
	echo "Created ~/.zshenv (sources ~/.zshenv.dotfiles)"
fi

if [ ! -f ~/.zshrc ]; then
	cat > ~/.zshrc <<'EOF'
source ~/.zshrc.dotfiles

# Add your local customizations below this line.
EOF
	echo "Created ~/.zshrc (sources ~/.zshrc.dotfiles)"
fi

# Bootstrap neovim plugins and treesitter parsers
echo "Installing neovim plugins..."
nvim --headless "+Lazy! sync" +qa 2>/dev/null
echo "Installing treesitter parsers..."
nvim --headless "+TSInstall! dart python typescript javascript tsx lua yaml hcl json bash dockerfile" +qa 2>/dev/null
