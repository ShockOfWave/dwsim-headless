#!/bin/bash
# ============================================================================
# patch-winforms-guards.sh (Tier 9)
# Adds #If Not HEADLESS / #End If guards around desktop-UI-dependent and
# Python.NET-dependent code in DWSIM.FlowsheetBase sources.
#
# Strategy:
#   1. Guard 'Imports Python.Runtime' with #If Not HEADLESS
#   2. Guard GraphicObjectControlPanelModeEditors calls (excluded class)
#   3. Guard RunScript_PythonNET method body
#   4. Guard RunScript_PythonNET call sites (provide HEADLESS fallback)
# ============================================================================
set -euo pipefail

DWSIM_ROOT="${1:?Usage: patch-winforms-guards.sh <dwsim-source-root>}"
FB_DIR="$DWSIM_ROOT/DWSIM.FlowsheetBase"
export FB_VB="$FB_DIR/FlowsheetBase.vb"

echo "=== Patching FlowsheetBase.vb for HEADLESS mode ==="

if [ ! -f "$FB_VB" ]; then
    echo "ERROR: FlowsheetBase.vb not found at $FB_VB"
    exit 1
fi

# ============================================================================
# Use Python for reliable multi-pattern patching on this large VB.NET file.
# ============================================================================

python3 << 'PYEOF'
import sys
import os

fb_path = os.environ.get('FB_VB', '')
if not fb_path:
    print("ERROR: FB_VB not set", file=sys.stderr)
    sys.exit(1)

# Read file with BOM handling
try:
    with open(fb_path, 'r', encoding='utf-8-sig') as f:
        content = f.read()
    write_enc = 'utf-8'
except UnicodeDecodeError:
    with open(fb_path, 'r', encoding='latin-1') as f:
        content = f.read()
    write_enc = 'latin-1'

lines = content.split('\n')
result = []
i = 0
changes = 0

while i < len(lines):
    line = lines[i]
    stripped = line.strip()

    # ----------------------------------------------------------------
    # 1. Guard 'Imports Python.Runtime'
    # ----------------------------------------------------------------
    if stripped == 'Imports Python.Runtime':
        result.append('#If Not HEADLESS Then')
        result.append(line)
        result.append('#End If')
        changes += 1
        i += 1
        continue

    # ----------------------------------------------------------------
    # 2. Guard GraphicObjectControlPanelModeEditors calls
    #    These single-line calls to SetInputDelegate/SetPIDDelegate
    # ----------------------------------------------------------------
    if 'GraphicObjectControlPanelModeEditors.' in stripped:
        # Get the indentation from the original line
        indent = line[:len(line) - len(line.lstrip())]
        result.append(indent + '#If Not HEADLESS Then')
        result.append(line)
        result.append(indent + '#End If')
        changes += 1
        i += 1
        continue

    # ----------------------------------------------------------------
    # 3. Guard RunScript_PythonNET method (whole method body)
    #    Pattern: "Private Sub RunScript_PythonNET(..." to matching "End Sub"
    # ----------------------------------------------------------------
    if 'Private Sub RunScript_PythonNET(' in stripped:
        indent = line[:len(line) - len(line.lstrip())]
        result.append(indent + '#If Not HEADLESS Then')
        result.append(line)
        # Find the matching End Sub at same indentation level
        i += 1
        while i < len(lines):
            cur = lines[i]
            cur_stripped = cur.strip()
            cur_indent = cur[:len(cur) - len(cur.lstrip())]
            # Match "End Sub" at the SAME indentation as the method declaration
            if cur_stripped == 'End Sub' and cur_indent == indent:
                result.append(cur)
                result.append(indent + '#End If')
                changes += 1
                i += 1
                break
            result.append(cur)
            i += 1
        continue

    # ----------------------------------------------------------------
    # 3b. Guard ChangeCalculationOrder method body (uses FormCustomCalcOrder)
    #    Keep signature + End Function, wrap body with #If Not HEADLESS
    # ----------------------------------------------------------------
    if 'Function ChangeCalculationOrder(' in stripped and 'Implements' in stripped:
        indent = line[:len(line) - len(line.lstrip())]
        body_indent = indent + '    '
        result.append(line)  # Keep method signature
        i += 1
        body_lines = []
        while i < len(lines):
            cur = lines[i]
            cur_stripped = cur.strip()
            cur_indent = cur[:len(cur) - len(cur.lstrip())]
            if cur_stripped == 'End Function' and len(cur_indent) <= len(indent):
                break
            body_lines.append(cur)
            i += 1
        # Wrap body: in headless mode, just return the input list unchanged
        result.append(body_indent + '#If Not HEADLESS Then')
        result.extend(body_lines)
        result.append(body_indent + '#Else')
        result.append(body_indent + '    Return objects')
        result.append(body_indent + '#End If')
        # Keep End Function
        if i < len(lines):
            result.append(lines[i])
            i += 1
        changes += 1
        continue

    # ----------------------------------------------------------------
    # 4. Guard RunScript_PythonNET call sites
    #    Pattern: "RunScript_PythonNET(scr.ScriptText)" etc.
    #    Replace with conditional: skip in HEADLESS mode
    # ----------------------------------------------------------------
    if 'RunScript_PythonNET(' in stripped and 'Private Sub' not in stripped:
        indent = line[:len(line) - len(line.lstrip())]
        # We wrap the call in #If Not HEADLESS
        result.append(indent + '#If Not HEADLESS Then')
        result.append(line)
        result.append(indent + '#End If')
        changes += 1
        i += 1
        continue

    # No match - output line as-is
    result.append(line)
    i += 1

# Write result
output = '\n'.join(result)
with open(fb_path, 'w', encoding=write_enc) as f:
    f.write(output)

print(f"  Applied {changes} HEADLESS guards to FlowsheetBase.vb")
PYEOF

echo ""
echo "=== FlowsheetBase.vb patching complete ==="
