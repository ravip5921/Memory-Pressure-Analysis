#!/bin/bash
set -euo pipefail

# Resolve script dir and load config
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/configs.sh"

# Prevent running the whole script as root/sudo because Docker Desktop's
# socket/context is per-user and running as root will cause the Docker CLI
# to try /var/run/docker.sock (which doesn't exist for Docker Desktop).
if [ "$(id -u)" -eq 0 ]; then
  echo "Do NOT run this script with sudo/root."
  echo "Run it as your regular user (it will use 'sudo' internally where needed)."
  exit 1
fi

# Quick check that the Docker CLI can contact a server
if ! docker version >/dev/null 2>&1; then
  echo "Docker CLI cannot contact a Docker daemon."
  echo "If you're using Docker Desktop, ensure it's running and your CLI context is set:" \
       "(run 'docker context ls' and 'docker context use desktop-linux' if needed)."
  exit 1
fi

for SWAP in "${SWAPPINESS_LEVELS[@]}"
do
  for LEVEL in "${!STRESS_LEVELS[@]}"
  do
    "$SCRIPT_DIR/run_base.sh" "$SWAP" "$LEVEL"
    sleep 10
  done
done

echo "All baseline experiments complete."