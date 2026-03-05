#!/usr/bin/env bash
# =============================================================================
# Patch 02: Tier 1 SDK-style project conversion
# Converts DWSIM.GlobalSettings and DWSIM.XMLSerializer (DWSIM.Serializers.XML)
# from old-style .NET Framework 4.6.x to SDK-style .NET 8.0.
#
# DWSIM.GlobalSettings:
#   - Removes Cudafy.NET and Python.Runtime references (headless build)
#   - Replaces Nini local DLL with nini-core NuGet package
#   - Guards Cudafy/Python.Runtime source usage with #If Not HEADLESS
#   - Removes System.Runtime.InteropServices.RuntimeInformation (built-in)
#
# DWSIM.XMLSerializer:
#   - Removes System.Buffers, System.Memory, System.Numerics.Vectors (built-in)
#   - Updates OxyPlot.Core to 2.2.0
#   - Updates SkiaSharp to 2.88.9
#   - Replaces System.Drawing with System.Drawing.Common NuGet package
# =============================================================================
set -euo pipefail

DWSIM_ROOT="${1:?Usage: $0 <dwsim-source-root>}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TIER1_DIR="${SCRIPT_DIR}/tier1"

echo "=== Patch 02: Tier 1 SDK-style project conversion ==="
echo "DWSIM root: ${DWSIM_ROOT}"
echo ""

# ---------------------------------------------------------------------------
# 1. DWSIM.GlobalSettings - VB.NET library (Cudafy/Python.Runtime removal)
# ---------------------------------------------------------------------------
echo "[1/2] Converting DWSIM.GlobalSettings..."

GS_DIR="${DWSIM_ROOT}/DWSIM.GlobalSettings"

# Replace the project file with SDK-style version
cp "${TIER1_DIR}/DWSIM.GlobalSettings.vbproj" \
   "${GS_DIR}/DWSIM.GlobalSettings.vbproj"

# Remove packages.config (NuGet packages are now in the .csproj via PackageReference)
rm -f "${GS_DIR}/packages.config"

# Remove the old My Project auto-generated files
rm -f "${GS_DIR}/My Project/Application.Designer.vb"
rm -f "${GS_DIR}/My Project/Application.myapp"
rm -f "${GS_DIR}/My Project/Resources.Designer.vb"
rm -f "${GS_DIR}/My Project/Resources.resx"
rm -f "${GS_DIR}/My Project/Settings.Designer.vb"
rm -f "${GS_DIR}/My Project/Settings.settings"

echo "  - Replaced project file with SDK-style"
echo "  - Removed packages.config"
echo "  - Removed My Project auto-generated designer files"

# --- Source code patching: Guard Cudafy/Python.Runtime usage with #If Not HEADLESS ---
#
# Settings.vb layout:
#   Line 1:       Imports Cudafy
#   Line 6:       Imports Python.Runtime
#   Lines 206-208: <DllImport("kernel32.dll"...)> AddDllDirectory (used by SetPythonPath)
#   Lines 210-262: InitializePythonEnvironment (uses PythonEngine, Runtime.PythonDLL)
#   Lines 264-275: ShutdownPythonEnvironment (uses PythonEngine)
#   Lines 277-313: SetPythonPath (uses Runtime.PythonDLL, AddDllDirectory)
#   Line 315:     LoadExcelSettings (NOT guarded - uses only Nini)
#
# Strategy:
#   - Wrap "Imports Cudafy" in #If Not HEADLESS / #End If
#   - Wrap "Imports Python.Runtime" in #If Not HEADLESS / #End If
#   - Wrap the entire block from DllImport through SetPythonPath End Sub
#     in a single #If Not HEADLESS / #End If block

# --- Source code patching: Replace My.Application.Info.DirectoryPath ---
# My.Application requires MyType=Console/WindowsForms which pulls in WinForms types.
# Replace with AppDomain.CurrentDomain.BaseDirectory (equivalent in .NET 8).
echo "  - Patching Settings.vb: replacing My.Application.Info.DirectoryPath"
if [ "$(uname)" = "Darwin" ]; then
    sed -i '' 's/My\.Application\.Info\.DirectoryPath/AppDomain.CurrentDomain.BaseDirectory.TrimEnd(IO.Path.DirectorySeparatorChar)/g' "${GS_DIR}/Settings.vb"
else
    sed -i 's/My\.Application\.Info\.DirectoryPath/AppDomain.CurrentDomain.BaseDirectory.TrimEnd(IO.Path.DirectorySeparatorChar)/g' "${GS_DIR}/Settings.vb"
fi

echo "  - Patching Settings.vb: guarding Cudafy/Python.Runtime with #If Not HEADLESS"

SETTINGS_VB="${GS_DIR}/Settings.vb"

python3 -c "
import os, sys

path = '${SETTINGS_VB}'
with open(path, 'r', encoding='utf-8-sig') as f:
    lines = f.readlines()

output = []
i = 0
while i < len(lines):
    line = lines[i]
    stripped = line.rstrip()

    # Guard 'Imports Cudafy'
    if stripped == 'Imports Cudafy':
        output.append('#If Not HEADLESS Then\n')
        output.append(line)
        output.append('#End If\n')
        i += 1
        continue

    # Guard 'Imports Python.Runtime'
    if stripped == 'Imports Python.Runtime':
        output.append('#If Not HEADLESS Then\n')
        output.append(line)
        output.append('#End If\n')
        i += 1
        continue

    # Guard the DllImport + AddDllDirectory + InitializePythonEnvironment +
    # ShutdownPythonEnvironment + SetPythonPath block
    # Starts at: <DllImport(\"kernel32.dll\"
    # Ends before: Shared Sub LoadExcelSettings
    if '<DllImport(\"kernel32.dll\"' in stripped:
        output.append('#If Not HEADLESS Then\n')
        output.append('\n')
        output.append(line)
        i += 1
        # Continue writing lines until we hit LoadExcelSettings
        while i < len(lines):
            line = lines[i]
            stripped = line.rstrip()
            if 'Sub LoadExcelSettings' in stripped:
                output.append('\n')
                output.append('#End If\n')
                output.append('\n')
                output.append(line)
                i += 1
                break
            output.append(line)
            i += 1
        continue

    # Default: write line as-is
    output.append(line)
    i += 1

with open(path, 'w', encoding='utf-8') as f:
    f.writelines(output)

print('    Settings.vb patched successfully')
"

echo ""

# ---------------------------------------------------------------------------
# 2. DWSIM.XMLSerializer - VB.NET library (dependency updates)
# ---------------------------------------------------------------------------
echo "[2/2] Converting DWSIM.XMLSerializer (DWSIM.Serializers.XML)..."

XS_DIR="${DWSIM_ROOT}/DWSIM.Serializers.XML"

# Replace the project file with SDK-style version
cp "${TIER1_DIR}/DWSIM.XMLSerializer.vbproj" \
   "${XS_DIR}/DWSIM.XMLSerializer.vbproj"

# Remove packages.config
rm -f "${XS_DIR}/packages.config"

# Remove app.config (binding redirects not needed in .NET 8)
rm -f "${XS_DIR}/app.config"

# Remove the old My Project auto-generated files
rm -f "${XS_DIR}/My Project/Application.Designer.vb"
rm -f "${XS_DIR}/My Project/Application.myapp"
rm -f "${XS_DIR}/My Project/Resources.Designer.vb"
rm -f "${XS_DIR}/My Project/Resources.resx"
rm -f "${XS_DIR}/My Project/Settings.Designer.vb"
rm -f "${XS_DIR}/My Project/Settings.settings"

echo "  - Replaced project file with SDK-style"
echo "  - Removed packages.config"
echo "  - Removed app.config (binding redirects)"
echo "  - Removed My Project auto-generated designer files"

# --- Source code patching: Fix .NET 8 VB.NET type resolution ---
#
# In .NET 8, Single.Parse(Object) and Double.Parse(Object) don't exist.
# VB.NET compiler fails to resolve the expression chain, causing a cascade
# error where .ToString("R", ci) is misinterpreted as Chars("R", ci).
# Fix: Replace Type.Parse(objectValue) with Convert.ToType(objectValue).
echo "  - Patching XMLSerializer.vb: Single.Parse/Double.Parse(Object) -> Convert.To*"
XS_VB="${XS_DIR}/XMLSerializer.vb"
if [ "$(uname)" = "Darwin" ]; then
    sed -i '' 's/Single\.Parse(obj\.GetType/Convert.ToSingle(obj.GetType/g' "$XS_VB"
    sed -i '' 's/Double\.Parse(obj\.GetType/Convert.ToDouble(obj.GetType/g' "$XS_VB"
    sed -i '' 's/Double\.Parse(obj)/Convert.ToDouble(obj)/g' "$XS_VB"
    sed -i '' 's/Single\.Parse(obj)/Convert.ToSingle(obj)/g' "$XS_VB"
else
    sed -i 's/Single\.Parse(obj\.GetType/Convert.ToSingle(obj.GetType/g' "$XS_VB"
    sed -i 's/Double\.Parse(obj\.GetType/Convert.ToDouble(obj.GetType/g' "$XS_VB"
    sed -i 's/Double\.Parse(obj)/Convert.ToDouble(obj)/g' "$XS_VB"
    sed -i 's/Single\.Parse(obj)/Convert.ToSingle(obj)/g' "$XS_VB"
fi
echo ""

echo "=== Patch 02 complete ==="
echo "Converted 2 Tier 1 projects to SDK-style net8.0:"
echo "  - DWSIM.GlobalSettings (with Cudafy/Python.Runtime headless guards)"
echo "  - DWSIM.XMLSerializer (with updated OxyPlot, SkiaSharp, System.Drawing.Common)"
