#!/usr/bin/env bash
# vox-machina installer
set -euo pipefail

VOX_HOME="${VOX_MACHINA_HOME:-$HOME/.vox-machina}"
REPO="darkcrux/vox-machina"
BIN_DIR="$HOME/.local/bin"

echo "Installing vox-machina..."

# Create directories
mkdir -p "$VOX_HOME/voices" "$BIN_DIR"

# Download the CLI script
curl -fsSL "https://raw.githubusercontent.com/${REPO}/main/vox-machina.sh" -o "${VOX_HOME}/vox-machina.sh"
chmod +x "${VOX_HOME}/vox-machina.sh"

# Symlink to ~/.local/bin
ln -sf "${VOX_HOME}/vox-machina.sh" "${BIN_DIR}/vox-machina"

# Initialize config if not present
[[ -f "${VOX_HOME}/config.json" ]] || echo '{}' > "${VOX_HOME}/config.json"

# Check if ~/.local/bin is in PATH
if ! echo "$PATH" | tr ':' '\n' | grep -qx "$BIN_DIR"; then
  echo ""
  echo "Add ~/.local/bin to your PATH by adding this to your shell config:"
  echo ""
  if [[ -f "$HOME/.zshrc" ]]; then
    echo "  echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> ~/.zshrc"
  elif [[ -f "$HOME/.bashrc" ]]; then
    echo "  echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> ~/.bashrc"
  else
    echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
  fi
  echo ""
fi

echo "vox-machina installed!"
echo ""
echo "Get started:"
echo "  vox-machina install glados    # Install GLaDOS voice pack"
echo "  vox-machina use glados        # Set as active voice"
echo "  vox-machina hooks install     # Add hooks to Claude Code"
echo "  vox-machina play Stop         # Test it out"
