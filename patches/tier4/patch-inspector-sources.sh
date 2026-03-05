#!/usr/bin/env bash
# =============================================================================
# Source patches for DWSIM.Inspector Inspector.vb
# Removes unused System.Drawing import (no Drawing types used in data classes)
# =============================================================================
set -euo pipefail

DWSIM_ROOT="${1:?Usage: $0 <dwsim-source-root>}"
INSPECTOR_VB="${DWSIM_ROOT}/DWSIM.Inspector/Inspector.vb"

if [ ! -f "${INSPECTOR_VB}" ]; then
    echo "ERROR: ${INSPECTOR_VB} not found"
    exit 1
fi

echo "[Inspector] Patching Inspector.vb - removing unused System.Drawing import..."

# Use Python for BOM-safe text manipulation
export INSPECTOR_VB
python3 << 'PYEOF'
import os

filepath = os.environ["INSPECTOR_VB"]

with open(filepath, 'r', encoding='utf-8-sig') as f:
    content = f.read()

# Remove the System.Drawing import line
content = content.replace("Imports System.Drawing\r\n", "")
content = content.replace("Imports System.Drawing\n", "")

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)

print(f"Patched {filepath}")
PYEOF

echo "[Inspector] Inspector.vb patched successfully."
