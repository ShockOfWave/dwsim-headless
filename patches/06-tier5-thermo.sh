#!/usr/bin/env bash
# =============================================================================
# Patch 06: Tier 5 SDK-style project conversion
# Converts all 6 Thermodynamics projects from old-style .NET Framework 4.6.2
# to SDK-style .NET 8.0.
#
# Projects converted:
#   1. DWSIM.Thermodynamics (VB.NET) - THE BIG ONE
#      * 18 project references (removed DockPanel, TabStrip)
#      * Excluded EditingForms/ (WinForms UI), Excel interface (ExcelDna)
#      * Removed references: ExcelDna, RichTextBoxExtended, Scintilla.Eto,
#        IronPython.Wpf, WindowsBase, PresentationCore, unvell.ReoGrid
#      * Kept: IronPython (core), DLR, MathNet.Numerics, Eto.Forms
#      * Wrapped GetEditingForm/DisplayEditingForm with #If Not HEADLESS
#   2. DWSIM.Thermodynamics.AdvancedEOS.GERG2008 (VB.NET) - clean math
#   3. DWSIM.Thermodynamics.AdvancedEOS.PCSAFT2 (VB.NET)
#      * Excluded FormConfig (WinForms UI)
#   4. DWSIM.Thermodynamics.AdvancedEOS.PRSRKTDep (VB.NET)
#      * Excluded FormConfig (WinForms UI)
#   5. DWSIM.Thermodynamics.ThermoC (C#)
#      * References ThermoCS native DLL (Linux path)
#   6. DWSIM.Thermodynamics.ReaktoroPropertyPackage (VB.NET)
#      * Excluded FormConfig (WinForms UI)
#      * Removed Python.Runtime local reference
# =============================================================================
set -euo pipefail

DWSIM_ROOT="${1:?Usage: $0 <dwsim-source-root>}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TIER5_DIR="${SCRIPT_DIR}/tier5"

echo "=== Patch 06: Tier 5 Thermodynamics SDK-style conversion ==="
echo "DWSIM root: ${DWSIM_ROOT}"
echo ""

# ---------------------------------------------------------------------------
# Phase 1: Apply WinForms source patches
# Must happen BEFORE project file replacement so the file content is correct
# ---------------------------------------------------------------------------
echo "--- Phase 1: Apply WinForms source patches ---"
echo ""

bash "${TIER5_DIR}/patch-thermo-winforms.sh" "${DWSIM_ROOT}"

echo ""

# ---------------------------------------------------------------------------
# Phase 2: DWSIM.Thermodynamics (VB.NET) - THE BIG ONE
# ---------------------------------------------------------------------------
echo "--- Phase 2: Converting DWSIM.Thermodynamics ---"
echo ""

THERMO_DIR="${DWSIM_ROOT}/DWSIM.Thermodynamics"

# 2a. Replace project file with SDK-style version
echo "[Thermodynamics] Replacing project file with SDK-style..."
cp "${TIER5_DIR}/DWSIM.Thermodynamics.vbproj" "${THERMO_DIR}/DWSIM.Thermodynamics.vbproj"

# 2b. Remove packages.config
echo "[Thermodynamics] Removing packages.config..."
rm -f "${THERMO_DIR}/packages.config"

# 2c. Remove My Project auto-generated files
echo "[Thermodynamics] Removing My Project auto-generated designer files..."
rm -f "${THERMO_DIR}/My Project/Application.Designer.vb"
rm -f "${THERMO_DIR}/My Project/Application.myapp"
rm -f "${THERMO_DIR}/My Project/Resources.Designer.vb"
rm -f "${THERMO_DIR}/My Project/Resources.resx"
rm -f "${THERMO_DIR}/My Project/Settings.Designer.vb"
rm -f "${THERMO_DIR}/My Project/Settings.settings"

echo "[Thermodynamics] Done."
echo ""

# ---------------------------------------------------------------------------
# Phase 3: DWSIM.Thermodynamics.AdvancedEOS.GERG2008
# ---------------------------------------------------------------------------
echo "--- Phase 3: Converting GERG2008 ---"
echo ""

GERG_DIR="${DWSIM_ROOT}/DWSIM.Thermodynamics.AdvancedEOS.GERG2008"

echo "[GERG2008] Replacing project file with SDK-style..."
cp "${TIER5_DIR}/DWSIM.Thermodynamics.AdvancedEOS.GERG2008.vbproj" "${GERG_DIR}/DWSIM.Thermodynamics.AdvancedEOS.GERG2008.vbproj"

echo "[GERG2008] Removing My Project auto-generated designer files..."
rm -f "${GERG_DIR}/My Project/Application.Designer.vb"
rm -f "${GERG_DIR}/My Project/Application.myapp"
rm -f "${GERG_DIR}/My Project/Resources.Designer.vb"
rm -f "${GERG_DIR}/My Project/Resources.resx"

echo "[GERG2008] Done."
echo ""

# ---------------------------------------------------------------------------
# Phase 4: DWSIM.Thermodynamics.AdvancedEOS.PCSAFT2
# Note: folder is PCSAFT, file is PCSAFT2
# ---------------------------------------------------------------------------
echo "--- Phase 4: Converting PCSAFT2 ---"
echo ""

PCSAFT_DIR="${DWSIM_ROOT}/DWSIM.Thermodynamics.AdvancedEOS.PCSAFT"

echo "[PCSAFT2] Replacing project file with SDK-style..."
cp "${TIER5_DIR}/DWSIM.Thermodynamics.AdvancedEOS.PCSAFT2.vbproj" "${PCSAFT_DIR}/DWSIM.Thermodynamics.AdvancedEOS.PCSAFT2.vbproj"

echo "[PCSAFT2] Removing packages.config..."
rm -f "${PCSAFT_DIR}/packages.config"

echo "[PCSAFT2] Removing My Project auto-generated designer files..."
rm -f "${PCSAFT_DIR}/My Project/Application.Designer.vb"
rm -f "${PCSAFT_DIR}/My Project/Application.myapp"
rm -f "${PCSAFT_DIR}/My Project/Resources.Designer.vb"
rm -f "${PCSAFT_DIR}/My Project/Resources.resx"

echo "[PCSAFT2] Done."
echo ""

# ---------------------------------------------------------------------------
# Phase 5: DWSIM.Thermodynamics.AdvancedEOS.PRSRKTDep
# ---------------------------------------------------------------------------
echo "--- Phase 5: Converting PRSRKTDep ---"
echo ""

PRSRK_DIR="${DWSIM_ROOT}/DWSIM.Thermodynamics.AdvancedEOS.PRSRKTDep"

echo "[PRSRKTDep] Replacing project file with SDK-style..."
cp "${TIER5_DIR}/DWSIM.Thermodynamics.AdvancedEOS.PRSRKTDep.vbproj" "${PRSRK_DIR}/DWSIM.Thermodynamics.AdvancedEOS.PRSRKTDep.vbproj"

echo "[PRSRKTDep] Removing My Project auto-generated designer files..."
rm -f "${PRSRK_DIR}/My Project/Application.Designer.vb"
rm -f "${PRSRK_DIR}/My Project/Application.myapp"
rm -f "${PRSRK_DIR}/My Project/Resources.Designer.vb"
rm -f "${PRSRK_DIR}/My Project/Resources.resx"

echo "[PRSRKTDep] Done."
echo ""

# ---------------------------------------------------------------------------
# Phase 6: DWSIM.Thermodynamics.ThermoC (C#)
# ---------------------------------------------------------------------------
echo "--- Phase 6: Converting ThermoC ---"
echo ""

THERMOC_DIR="${DWSIM_ROOT}/DWSIM.Thermodynamics.ThermoC"

echo "[ThermoC] Replacing project file with SDK-style..."
cp "${TIER5_DIR}/DWSIM.Thermodynamics.ThermoC.csproj" "${THERMOC_DIR}/DWSIM.Thermodynamics.ThermoC.csproj"

echo "[ThermoC] Removing packages.config..."
rm -f "${THERMOC_DIR}/packages.config"

echo "[ThermoC] Done."
echo ""

# ---------------------------------------------------------------------------
# Phase 7: DWSIM.Thermodynamics.ReaktoroPropertyPackage
# ---------------------------------------------------------------------------
echo "--- Phase 7: Converting ReaktoroPropertyPackage ---"
echo ""

REAKTORO_DIR="${DWSIM_ROOT}/DWSIM.Thermodynamics.ReaktoroPropertyPackage"

echo "[Reaktoro] Replacing project file with SDK-style..."
cp "${TIER5_DIR}/DWSIM.Thermodynamics.ReaktoroPropertyPackage.vbproj" "${REAKTORO_DIR}/DWSIM.Thermodynamics.ReaktoroPropertyPackage.vbproj"

echo "[Reaktoro] Removing packages.config..."
rm -f "${REAKTORO_DIR}/packages.config"

echo "[Reaktoro] Removing My Project auto-generated designer files..."
rm -f "${REAKTORO_DIR}/My Project/Application.Designer.vb"
rm -f "${REAKTORO_DIR}/My Project/Application.myapp"
rm -f "${REAKTORO_DIR}/My Project/Resources.Designer.vb"
rm -f "${REAKTORO_DIR}/My Project/Resources.resx"
rm -f "${REAKTORO_DIR}/My Project/Settings.Designer.vb"
rm -f "${REAKTORO_DIR}/My Project/Settings.settings"

echo "[Reaktoro] Done."
echo ""

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo "=== Patch 06 complete ==="
echo "Converted 6 Tier 5 Thermodynamics projects to SDK-style net8.0:"
echo ""
echo "  1. DWSIM.Thermodynamics (VB.NET) - THE BIG ONE"
echo "     * Excluded EditingForms/ (all WinForms property package editors)"
echo "     * Excluded Interfaces/Excel.vb, ExcelNoAttr.vb (ExcelDna dependency)"
echo "     * Removed references: ExcelDna, RichTextBoxExtended, Scintilla.Eto,"
echo "       IronPython.Wpf, WindowsBase, PresentationCore, unvell.ReoGrid,"
echo "       DockPanel, TabStrip"
echo "     * Kept: IronPython 3.4.1, DLR 1.3.4, MathNet.Numerics 5.0.0"
echo "     * Wrapped GetEditingForm/DisplayEditingForm/DisplayGroupedEditingForm/"
echo "       DisplayFlashConfigForm with #If Not HEADLESS guards in 18+ files"
echo "     * Wrapped TextBoxStreamWriter class in ConsoleRedirection.vb"
echo ""
echo "  2. DWSIM.Thermodynamics.AdvancedEOS.GERG2008 (VB.NET)"
echo "     * Clean math project, no WinForms issues"
echo ""
echo "  3. DWSIM.Thermodynamics.AdvancedEOS.PCSAFT2 (VB.NET)"
echo "     * Excluded FormConfig.vb/Designer.vb (WinForms)"
echo "     * Wrapped GetEditingForm/DisplayEditingForm"
echo ""
echo "  4. DWSIM.Thermodynamics.AdvancedEOS.PRSRKTDep (VB.NET)"
echo "     * Excluded FormConfig.vb/Designer.vb (WinForms)"
echo "     * Wrapped methods in PengRobinsonAdvanced.vb, SRKAdvanced.vb"
echo ""
echo "  5. DWSIM.Thermodynamics.ThermoC (C#)"
echo "     * References ThermoCS.dll (Linux path)"
echo "     * Depends on DWSIM.ExtensionMethods.Eto"
echo ""
echo "  6. DWSIM.Thermodynamics.ReaktoroPropertyPackage (VB.NET)"
echo "     * Excluded FormConfig.vb/Designer.vb (WinForms)"
echo "     * Removed Python.Runtime local reference"
echo "     * Wrapped GetEditingForm/DisplayEditingForm"
echo ""
