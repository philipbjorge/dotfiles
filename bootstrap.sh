#!/usr/bin/env bash

cd "$(dirname "${BASH_SOURCE}")";

git pull origin main;

if [[ "${1}" != "--rsync-only" ]]; then

# Tools
install_pkg() {
  local pkg=$1
  local apt_pkg=${2:-$1}  # optional apt-specific package name
  if command -v brew &>/dev/null; then
    brew install "$pkg"
  elif command -v apt-get &>/dev/null; then
    sudo apt-get install -y "$apt_pkg"
  elif command -v dnf &>/dev/null; then
    sudo dnf install -y "$pkg"
  elif command -v pacman &>/dev/null; then
    sudo pacman -S --noconfirm "$pkg"
  else
    echo "WARNING: could not install $pkg — no supported package manager found"
  fi
}

install_pkg zsh
install_pkg ripgrep
install_pkg jq
install_pkg fd fd-find
if command -v fdfind &>/dev/null && ! command -v fd &>/dev/null; then
  sudo ln -sf /usr/bin/fdfind /usr/local/bin/fd
fi
# Neovim: apt ships 0.9.x on Ubuntu; config requires 0.11+. Use official tarball on Linux.
if command -v brew &>/dev/null; then
  brew install neovim
elif ! command -v nvim &>/dev/null || [ "$(nvim --version | head -1 | awk '{print $2}' | tr -d 'v' | cut -d. -f1-2)" \< "0.11" ]; then
  echo "Installing Neovim from official tarball..."
  tmp=$(mktemp -d)
  curl -fsSL https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz | tar -xz -C "$tmp"
  sudo rm -rf /opt/nvim
  sudo mv "$tmp"/nvim-linux-x86_64 /opt/nvim
  sudo ln -sf /opt/nvim/bin/nvim /usr/local/bin/nvim
  rm -rf "$tmp"
fi
install_pkg tree-sitter-cli

# lazygit is not in apt repos; install via GitHub release on Linux
if ! command -v lazygit &>/dev/null; then
  if command -v brew &>/dev/null; then
    brew install lazygit
  elif command -v apt-get &>/dev/null; then
    LAZYGIT_VERSION=$(curl -fsSL "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep '"tag_name"' | sed 's/.*"v\([^"]*\)".*/\1/')
    curl -fsSL "https://github.com/jesseduffield/lazygit/releases/download/v${LAZYGIT_VERSION}/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz" | sudo tar -xz -C /usr/local/bin lazygit
  fi
fi

# lazydocker is not in apt repos; install via GitHub release on Linux
if ! command -v lazydocker &>/dev/null; then
  if command -v brew &>/dev/null; then
    brew install lazydocker
  elif command -v apt-get &>/dev/null; then
    LAZYDOCKER_VERSION=$(curl -fsSL "https://api.github.com/repos/jesseduffield/lazydocker/releases/latest" | grep '"tag_name"' | sed 's/.*"v\([^"]*\)".*/\1/')
    curl -fsSL "https://github.com/jesseduffield/lazydocker/releases/download/v${LAZYDOCKER_VERSION}/lazydocker_${LAZYDOCKER_VERSION}_Linux_x86_64.tar.gz" | sudo tar -xz -C /usr/local/bin lazydocker
  fi
fi

# tea (Gitea/Forgejo CLI): not in apt; install via Gitea release on Linux
if ! command -v tea &>/dev/null; then
  if command -v brew &>/dev/null; then
    brew install tea
  elif command -v apt-get &>/dev/null; then
    TEA_VERSION=$(curl -fsSL "https://gitea.com/api/v1/repos/gitea/tea/releases/latest" | grep -o '"tag_name":"[^"]*' | cut -d'"' -f4 | tr -d 'v')
    sudo curl -fsSL -o /usr/local/bin/tea "https://gitea.com/gitea/tea/releases/download/v${TEA_VERSION}/tea-${TEA_VERSION}-linux-amd64"
    sudo chmod +x /usr/local/bin/tea
  fi
fi

# ruff is not in apt repos; install via standalone installer
if ! command -v ruff &>/dev/null; then
  if command -v brew &>/dev/null; then
    brew install ruff
  else
    curl -fsSL https://astral.sh/ruff/install.sh | sh
  fi
fi

# Node.js: apt ships an older major on Ubuntu 24.04 and splits npm into a separate
# package; use NodeSource on Linux so we get node+npm together.
if ! command -v node &>/dev/null || ! command -v npm &>/dev/null; then
  if command -v brew &>/dev/null; then
    brew install node
  elif command -v apt-get &>/dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_24.x | sudo -E bash -
    sudo apt-get install -y nodejs
  fi
fi

# Codex CLI
if ! command -v codex &>/dev/null && command -v npm &>/dev/null; then
  if command -v brew &>/dev/null; then
    npm i -g @openai/codex
  else
    sudo npm i -g @openai/codex
  fi
fi

# Casks (macOS only)
install_cask() {
  if command -v brew &>/dev/null; then
    brew install --cask "$1"
  else
    echo "WARNING: skipping cask $1 — only supported on macOS with Homebrew"
  fi
}

install_cask tailscale
install_cask font-jetbrains-mono-nerd-font
install_cask superwhisper
install_cask cmux
install_cask hyperkey
install_cask loop
install_cask obsidian
install_cask orion
install_cask wezterm

# macOS dock shortcut: Baker (wezterm connect SSHMUX:baker)
if command -v brew &>/dev/null; then
  brew install dockutil
  if [ ! -d ~/Applications/Baker.app ]; then
    mkdir -p ~/Applications
    osacompile -o ~/Applications/Baker.app -e \
      'if application "WezTerm" is running then
         tell application "WezTerm" to activate
       else
         do shell script "/opt/homebrew/bin/wezterm connect SSHMUX:baker > /dev/null 2>&1 &"
         delay 1
         tell application "WezTerm" to activate
       end if'
    cp "$(dirname "${BASH_SOURCE}")/icons/baker.icns" \
      ~/Applications/Baker.app/Contents/Resources/applet.icns
    touch ~/Applications/Baker.app
  fi
  if ! dockutil --list | grep -q "Baker"; then
    dockutil --add ~/Applications/Baker.app
  fi
fi

# Tailscale (Linux only — macOS uses the cask above)
if ! command -v brew &>/dev/null && ! command -v tailscale &>/dev/null; then
  curl -fsSL https://tailscale.com/install.sh | sh
fi

# WezTerm (Linux only — macOS uses the cask above). Needed for mux-server over SSH.
if ! command -v brew &>/dev/null && ! command -v wezterm &>/dev/null && command -v apt-get &>/dev/null; then
  curl -fsSL https://apt.fury.io/wez/gpg.key | sudo gpg --yes --dearmor -o /usr/share/keyrings/wezterm-fury.gpg
  sudo chmod 644 /usr/share/keyrings/wezterm-fury.gpg
  echo 'deb [signed-by=/usr/share/keyrings/wezterm-fury.gpg] https://apt.fury.io/wez/ * *' | sudo tee /etc/apt/sources.list.d/wezterm.list >/dev/null
  sudo apt-get update
  sudo apt-get install -y wezterm
fi

# Claude Code
if ! command -v claude &>/dev/null; then
	curl -fsSL https://claude.ai/install.sh | bash
fi

# Git identity
git config --global user.name "Philip Bjorge"
git config --global user.email "philipbjorge@philipbjorge.com"
git config --global core.editor nvim

fi # --rsync-only

rsync_args=(
	--exclude ".git/"
	--exclude ".DS_Store"
	--exclude ".osx"
	--exclude "bootstrap.sh"
	--exclude "README.md"
	--exclude "LICENSE-MIT.txt"
	-avh --no-perms
)

echo "Previewing changes to ~ ..."
changes=$(rsync "${rsync_args[@]}" --dry-run --itemize-changes . ~ \
	| awk '/^[<>ch*][fL]/ {
		op = (substr($0, 4, 1) == "+") ? "new   " : "update"
		printf "  %s  %s\n", op, substr($0, 13)
	}')
if [ -z "$changes" ]; then
	echo "  (no file changes)"
else
	echo "$changes"
	echo
	# Show diffs for files that already exist (updates, not new files)
	while IFS= read -r line; do
		[[ "$line" == *"update"* ]] || continue
		path=$(echo "$line" | awk '{print $2}')
		if [ -f "$HOME/$path" ] && [ -f "./$path" ]; then
			echo "--- diff: ~/$path"
			diff -u "$HOME/$path" "./$path" | head -40 || true
			echo
		fi
	done <<< "$changes"
	read -r -p "Apply these changes? [y/N] " reply
	if [[ ! "$reply" =~ ^[Yy]$ ]]; then
		echo "Skipping rsync."
	else
		rsync "${rsync_args[@]}" . ~
	fi
fi

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

# Set zsh as the login shell (Linux only — on macOS, z4h manages this)
if ! command -v brew &>/dev/null; then
  zsh_path=$(command -v zsh)
  if [ -n "$zsh_path" ] && [ "$SHELL" != "$zsh_path" ]; then
    if ! grep -qx "$zsh_path" /etc/shells 2>/dev/null; then
      echo "$zsh_path" | sudo tee -a /etc/shells >/dev/null
    fi
    echo "Setting login shell to $zsh_path (may prompt for password)..."
    chsh -s "$zsh_path"
  fi
fi

# Bootstrap neovim plugins and treesitter parsers
echo "Installing neovim plugins..."
nvim --headless "+Lazy! sync" +qa 2>/dev/null
echo "Installing treesitter parsers..."
nvim --headless "+TSInstall! dart python typescript javascript tsx lua yaml hcl json bash dockerfile" +qa 2>/dev/null

