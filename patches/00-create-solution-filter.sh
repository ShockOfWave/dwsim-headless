#!/bin/bash
# Copy solution filter to DWSIM source directory
set -euo pipefail
DWSIM_DIR="${1:-.}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cp "$SCRIPT_DIR/DWSIM.Headless.slnf" "$DWSIM_DIR/"
echo "[00] Solution filter created: DWSIM.Headless.slnf"
