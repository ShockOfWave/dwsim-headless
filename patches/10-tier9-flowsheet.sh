#!/usr/bin/env bash
# =============================================================================
# Patch 10: Tier 9 SDK-style project conversion
# Converts DWSIM.FileStorage and DWSIM.FlowsheetBase from old-style
# .NET Framework 4.6.2 to SDK-style .NET 8.0.
#
# DWSIM.FileStorage (C#):
#   - Clean library (no WinForms directly)
#   - References: DWSIM.Interfaces, DWSIM.SharedClasses
#   - NuGet: Eto.Forms 2.8.3, LiteDB 5.0.21, System.Drawing.Common 8.0.0
#
# DWSIM.FlowsheetBase (VB.NET) -- CRITICAL for Automation3:
#   - Core flowsheet management class
#   - Contains FlowsheetBase.vb (5500+ lines), ReportCreator.vb
#
#   EXCLUDED from compilation:
#     * ControlPanelMode/FormPIDCPEditor.vb + designer (WinForms)
#     * ControlPanelMode/FormTextBoxInput.vb + designer (WinForms)
#     * ControlPanelMode/GraphicObjectControlPanelModeEditors.vb
#       (references DWSIM.UI.Shared.Common -- desktop-only)
#     * My Project auto-generated files
#     * All ControlPanelMode .resx files
#
#   #If Not HEADLESS guards added:
#     * Imports Python.Runtime (line 21)
#     * GraphicObjectControlPanelModeEditors.SetInputDelegate calls (4 locations)
#     * GraphicObjectControlPanelModeEditors.SetPIDDelegate calls (4 locations)
#     * RunScript_PythonNET method body (entire method)
#     * RunScript_PythonNET call sites (3 locations)
#
#   REMOVED references:
#     * System.Windows.Forms (not referenced from VB source directly)
#     * WindowsBase
#     * IronPython.Wpf (WPF dependency, not needed)
#
#   KEPT references:
#     * IronPython 3.4.1, DynamicLanguageRuntime 1.3.4
#     * 19 project references (all core libraries)
#     * Local DLLs: AODL, CapeOpen, Interop.CAPEOPEN110, Python.Runtime
#     * NuGet: Eto.Forms, Newtonsoft.Json, SharpZipLib, SkiaSharp 2.88.9,
#              System.CodeDom
# =============================================================================
set -euo pipefail

DWSIM_ROOT="${1:?Usage: $0 <dwsim-source-root>}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TIER9_DIR="${SCRIPT_DIR}/tier9"

echo "=== Patch 10: Tier 9 FileStorage + FlowsheetBase SDK-style conversion ==="
echo "DWSIM root: ${DWSIM_ROOT}"
echo ""

FS_DIR="${DWSIM_ROOT}/DWSIM.FileStorage"
FB_DIR="${DWSIM_ROOT}/DWSIM.FlowsheetBase"

# ---------------------------------------------------------------------------
# Validate directories exist
# ---------------------------------------------------------------------------
for dir in "${FS_DIR}" "${FB_DIR}"; do
    if [ ! -d "${dir}" ]; then
        echo "ERROR: Directory not found: ${dir}"
        exit 1
    fi
done

# ===========================================================================
# PART 1: DWSIM.FileStorage
# ===========================================================================
echo "--- Part 1: DWSIM.FileStorage ---"
echo ""

# 1a. Replace project file with SDK-style
echo "[FileStorage] Replacing project file with SDK-style..."
cp "${TIER9_DIR}/DWSIM.FileStorage.csproj" "${FS_DIR}/DWSIM.FileStorage.csproj"

# 1b. Remove packages.config
echo "[FileStorage] Removing packages.config..."
rm -f "${FS_DIR}/packages.config"

# 1c. Remove app.config
echo "[FileStorage] Removing app.config..."
rm -f "${FS_DIR}/app.config"

echo "[FileStorage] Done."
echo ""

# ===========================================================================
# PART 2: DWSIM.FlowsheetBase
# ===========================================================================
echo "--- Part 2: DWSIM.FlowsheetBase ---"
echo ""

# 2a. Apply WinForms / Python.NET source patches BEFORE project replacement
echo "[FlowsheetBase] Applying HEADLESS source patches..."
bash "${TIER9_DIR}/patch-winforms-guards.sh" "${DWSIM_ROOT}"

echo ""

# 2b. Replace project file with SDK-style
echo "[FlowsheetBase] Replacing project file with SDK-style..."
cp "${TIER9_DIR}/DWSIM.FlowsheetBase.vbproj" "${FB_DIR}/DWSIM.FlowsheetBase.vbproj"

# 2c. Remove packages.config
echo "[FlowsheetBase] Removing packages.config..."
rm -f "${FB_DIR}/packages.config"

# 2d. Remove My Project auto-generated files
echo "[FlowsheetBase] Removing My Project auto-generated designer files..."
rm -f "${FB_DIR}/My Project/Application.Designer.vb"
rm -f "${FB_DIR}/My Project/Application.myapp"
rm -f "${FB_DIR}/My Project/Resources.Designer.vb"
rm -f "${FB_DIR}/My Project/Resources.resx"
rm -f "${FB_DIR}/My Project/Settings.Designer.vb"
rm -f "${FB_DIR}/My Project/Settings.settings"

# 2e. Remove app.config
echo "[FlowsheetBase] Removing app.config..."
rm -f "${FB_DIR}/app.config"

echo "[FlowsheetBase] Done."
echo ""

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo "=== Patch 10 complete ==="
echo "Converted Tier 9 projects to SDK-style net8.0:"
echo ""
echo "  DWSIM.FileStorage (C#):"
echo "    * SDK-style net8.0 project"
echo "    * NuGet: Eto.Forms 2.8.3, LiteDB 5.0.21, System.Drawing.Common 8.0.0"
echo "    * 2 project references (Interfaces, SharedClasses)"
echo ""
echo "  DWSIM.FlowsheetBase (VB.NET):"
echo "    * SDK-style net8.0 project"
echo ""
echo "    EXCLUDED from compilation:"
echo "      * ControlPanelMode/FormPIDCPEditor.vb + designer (WinForms)"
echo "      * ControlPanelMode/FormTextBoxInput.vb + designer (WinForms)"
echo "      * ControlPanelMode/GraphicObjectControlPanelModeEditors.vb"
echo "        (needs DWSIM.UI.Shared.Common -- desktop-only project)"
echo ""
echo "    #If Not HEADLESS guards (12 total):"
echo "      * Imports Python.Runtime"
echo "      * GraphicObjectControlPanelModeEditors calls (8 locations)"
echo "      * RunScript_PythonNET method + call sites (3 locations)"
echo ""
echo "    REMOVED references:"
echo "      * System.Windows.Forms, WindowsBase, IronPython.Wpf"
echo ""
echo "    19 project references KEPT (core dependencies)"
echo "    7 NuGet packages | 4 local DLL references"
echo ""
