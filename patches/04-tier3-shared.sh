#!/usr/bin/env bash
# =============================================================================
# Patch 04: Tier 3 SDK-style project conversion
# Converts DWSIM.SharedClasses (VB.NET) and DWSIM.SharedClassesCSharp (C#)
# from old-style .NET Framework 4.6.2 to SDK-style .NET 8.0.
#
# These are the HARDEST projects to convert because SharedClasses has 20+
# files referencing System.Windows.Forms. Strategy:
#   - Exclude pure WinForms forms/controls from compilation (Editor/)
#   - Wrap mixed-use WinForms code with #If Not HEADLESS Then guards
#   - Remove project reference to DockPanel (WinForms-only)
#   - Remove project-level VB Import of System.Windows.Forms
#   - Remove dependency on DWSIM.Simulate365 (cloud integration)
# =============================================================================
set -euo pipefail

DWSIM_ROOT="${1:?Usage: $0 <dwsim-source-root>}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TIER3_DIR="${SCRIPT_DIR}/tier3"

echo "=== Patch 04: Tier 3 SharedClasses SDK-style conversion ==="
echo "DWSIM root: ${DWSIM_ROOT}"
echo ""

# ---------------------------------------------------------------------------
# Phase 1: Apply source patches (WinForms guards)
# Must happen BEFORE project file replacement so the file content is correct
# ---------------------------------------------------------------------------
echo "--- Phase 1: Apply WinForms source patches ---"
echo ""

bash "${TIER3_DIR}/patch-winforms-guards.sh" "${DWSIM_ROOT}"

echo ""

# ---------------------------------------------------------------------------
# Phase 2: DWSIM.SharedClasses (VB.NET)
# ---------------------------------------------------------------------------
echo "--- Phase 2: Converting DWSIM.SharedClasses ---"
echo ""

SC_DIR="${DWSIM_ROOT}/DWSIM.SharedClasses"

# 2a. Replace project file with SDK-style version
echo "[SharedClasses] Replacing project file with SDK-style..."
cp "${TIER3_DIR}/DWSIM.SharedClasses.vbproj" "${SC_DIR}/DWSIM.SharedClasses.vbproj"

# 2b. Remove packages.config (NuGet packages are now PackageReferences)
echo "[SharedClasses] Removing packages.config..."
rm -f "${SC_DIR}/packages.config"

# 2c. Remove My Project auto-generated files that conflict with SDK-style
echo "[SharedClasses] Removing My Project auto-generated designer files..."
rm -f "${SC_DIR}/My Project/Application.Designer.vb"
rm -f "${SC_DIR}/My Project/Application.myapp"
rm -f "${SC_DIR}/My Project/Resources.Designer.vb"
rm -f "${SC_DIR}/My Project/Resources.resx"
rm -f "${SC_DIR}/My Project/Settings.Designer.vb"
rm -f "${SC_DIR}/My Project/Settings.settings"

echo "[SharedClasses] Done."
echo ""

# ---------------------------------------------------------------------------
# Phase 3: DWSIM.SharedClassesCSharp (C#)
# ---------------------------------------------------------------------------
echo "--- Phase 3: Converting DWSIM.SharedClassesCSharp ---"
echo ""

SCS_DIR="${DWSIM_ROOT}/DWSIM.SharedClassesCSharp"

# 3a. Replace project file with SDK-style version
echo "[SharedClassesCSharp] Replacing project file with SDK-style..."
cp "${TIER3_DIR}/DWSIM.SharedClassesCSharp.csproj" "${SCS_DIR}/DWSIM.SharedClassesCSharp.csproj"

# 3b. Remove packages.config
echo "[SharedClassesCSharp] Removing packages.config..."
rm -f "${SCS_DIR}/packages.config"

echo "[SharedClassesCSharp] Done."
echo ""

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo "=== Patch 04 complete ==="
echo "Converted 2 Tier 3 projects to SDK-style net8.0:"
echo "  - DWSIM.SharedClasses (VB.NET)"
echo "    * Excluded Editor/ forms (DynamicsPropertyEditor, FormCustomCalcOrder,"
echo "      FormExtraProperties, InspectorReportBar, ListViewWithReordering,"
echo "      ObjectEditorForm, WaitForm)"
echo "    * Removed DockPanel project reference"
echo "    * Removed project-level System.Windows.Forms import"
echo "    * Added #If Not HEADLESS guards to:"
echo "      - Misc/ExtensionMethods.vb (UIThread, DataGridView, Clipboard methods)"
echo "      - Misc/FOSSEEFlowsheets.vb (MessageBox.Show calls)"
echo "      - Misc/MAPI.vb (entire file - Windows MAPI P/Invoke)"
echo "      - BaseClass/SimulationObjectBaseClasses.vb (DynamicsPropertyEditor,"
echo "        GetEditingForm, Clipboard.SetText)"
echo "  - DWSIM.SharedClassesCSharp (C#)"
echo "    * Excluded ConnectionsEditor/ (WinForms UserControl)"
echo "    * Excluded FilePicker/Windows/ (WinForms dialogs + Simulate365 dep)"
echo "    * Removed Simulate365 project reference"
echo "    * Patched Solids.cs (removed unused WinForms using)"
echo "    * Patched FilePickerService.cs (null default factory for headless)"
