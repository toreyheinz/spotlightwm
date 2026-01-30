#!/usr/bin/env bash
# exit on error
set -o errexit

# Load ASDF (use explicit path for non-interactive shells)
export HOME="/home/dev"
source /home/dev/.asdf/asdf.sh
export PATH="/home/dev/.asdf/shims:/home/dev/.asdf/bin:$PATH"

# Debug: Check if mix is available
echo "PATH: $PATH"
which mix || { echo "mix not found in PATH"; exit 1; }

# Load environment (symlinked from shared/)
# Required for compile and migration steps in prod
if [ -f .env ]; then
  echo "Loading environment from .env"
  set -a
  source .env
  set +a
fi

# Initial setup
mix deps.get --only prod
MIX_ENV=prod mix compile

# Compile assets
MIX_ENV=prod mix assets.build
MIX_ENV=prod mix assets.deploy

# Run migrations
MIX_ENV=prod mix ecto.migrate

# Create server script, Build the release, and overwrite the existing release directory
MIX_ENV=prod mix phx.gen.release
MIX_ENV=prod mix release --overwrite
