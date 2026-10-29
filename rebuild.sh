#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
ln -sfn "$DIR" ~/.dotfiles

# Build as you and only use root to activate. Evaluating the flake as root
# (`sudo darwin-rebuild switch`) makes Nix write root-owned objects into this
# repo's .git, which later breaks `git pull` with "insufficient permission".
system="$(nix build ~/.dotfiles#darwinConfigurations.mac.system --no-link --print-out-paths)"

# What `darwin-rebuild switch` does after building. sudo resets PATH to a
# default without /nix/.../bin, so nix-env needs its absolute path.
sudo "$(command -v nix-env)" -p /nix/var/nix/profiles/system --set "$system"
exec sudo "$system/sw/bin/darwin-rebuild" activate
