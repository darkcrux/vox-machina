#!/usr/bin/env bash
# vox-machina installer
set -euo pipefail

VOX_HOME="${VOX_MACHINA_HOME:-$HOME/.vox-machina}"
REPO="darkcrux/vox-machina"

echo "Installing vox-machina to ${VOX_HOME}..."

mkdir -p "$VOX_HOME/voices"

# Download the CLI script
curl -fsSL "https://raw.githubusercontent.com/${REPO}/main/vox-machina.sh" -o "${VOX_HOME}/vox-machina.sh"
chmod +x "${VOX_HOME}/vox-machina.sh"

# Initialize config if not present
[[ -f "${VOX_HOME}/config.json" ]] || echo '{}' > "${VOX_HOME}/config.json"

# Add to PATH hint
SHELL_RC=""
if [[ -f "$HOME/.zshrc" ]]; then
  SHELL_RC="$HOME/.zshrc"
elif [[ -f "$HOME/.bashrc" ]]; then
  SHELL_RC="$HOME/.bashrc"
fi

echo ""
echo "vox-machina installed!"
echo ""
echo "Add it to your PATH by adding this to ${SHELL_RC:-your shell config}:"
echo ""
echo "  export PATH=\"\$HOME/.vox-machina:\$PATH\""
echo ""
echo "Then get started:"
echo "  vox-machina.sh install glados    # Install GLaDOS voice pack"
echo "  vox-machina.sh use glados        # Set as active voice"
echo "  vox-machina.sh hooks install     # Add hooks to Claude Code"
echo "  vox-machina.sh play Stop         # Test it out"
