#!/usr/bin/env bash
# =============================================================================
# Patch 09: Tier 8 SDK-style project conversion
# Converts DWSIM.UnitOperations from old-style .NET Framework 4.6.2
# to SDK-style .NET 8.0.
#
# DWSIM.UnitOperations is the LARGEST project in the solution with ~22
# project references and HEAVY WinForms contamination. Strategy:
#
#   - EXCLUDE all EditingForms/ (WinForms UI editors, ~100 files)
#   - EXCLUDE ScintillaExtender.vb (requires ScintillaNET WinForms control)
#   - EXCLUDE ComboBoxColumnTemplates.vb (uses DataGridViewComboBoxCell)
#   - EXCLUDE Extenders/ExtensionMethods.vb (WinForms clipboard helpers)
#   - EXCLUDE PEMFC_ChamberlineKim.vb, PEMFC_LarminieDicks.vb (were <None>)
#   - Wrap 'Imports System.Windows.Forms' with #If Not HEADLESS guards
#   - Wrap 'Imports NetOffice.ExcelApi' with #If Not HEADLESS guards
#   - Wrap EditingForm field declarations (Public f As EditingForm_*)
#   - Wrap DisplayEditForm/UpdateEditForm/GetEditingForm/CloseEditForm methods
#   - Wrap standalone MessageBox.Show calls
#   - Wrap NetOffice Excel COM automation blocks in Spreadsheet.vb
#   - Wrap WeifenLuo.WinFormsUI references in Tank.vb/Vessel.vb
#
# WinForms project references REMOVED:
#   - DWSIM.Controls.DockPanel (WeifenLuo WinForms docking)
#   - DWSIM.Controls.TabStrip (WinForms tab control)
#   - DWSIM.Controls.ZedGraph (WinForms charting control)
#
# WinForms assembly references REMOVED:
#   - ScintillaNET (WinForms code editor)
#   - RichTextBoxExtended (WinForms rich text)
#   - SkiaSharp.Views.WindowsForms (WinForms SkiaSharp host)
#   - NetOffice.ExcelApi (COM Interop, Windows-only) — guarded, not removed
#   - System.Windows.Forms — guarded, not referenced
#   - unvell.ReoGrid, unvell.ReoGridEditor (WinForms spreadsheet grid)
#
# Project references KEPT (19 total):
#   DrawingTools.SkiaSharp, DrawingTools.SkiaSharp.Extended,
#   DrawingTools.Point, ExtensionMethods, ExtensionMethods.Eto,
#   FlowsheetSolver, GlobalSettings, Inspector, Interfaces,
#   MathOps, MathOps.DotNumerics, MathOps.RandomOps, MathOps.SwarmOps,
#   SharedClasses, SharedClassesCSharp, SkiaSharp.Views.Desktop,
#   Thermodynamics, Thermodynamics.ReaktoroPropertyPackage, XMLSerializer
#
# NuGet packages:
#   AutoDiff 1.2.2, DynamicLanguageRuntime 1.3.4, Eto.Forms 2.8.3,
#   GemBox.Spreadsheet 39.3.30.1215, IronPython 3.4.1, Mages 2.0.2,
#   MathNet.Numerics 5.0.0, Newtonsoft.Json 13.0.3, OxyPlot.Core 2.1.2,
#   SharpZipLib 1.4.2, SkiaSharp 2.88.9,
#   System.ComponentModel.Annotations 5.0.0, XMLUnit.Core 2.9.1
#
# Local DLL references:
#   CapeOpen, Ciloci.Flee, Cureos.Numerics, Interop.CAPEOPEN110,
#   Jolt, Jolt.Testing.GeneratedTypes, Mapack, Python.Runtime
# =============================================================================
set -euo pipefail

DWSIM_ROOT="${1:?Usage: $0 <dwsim-source-root>}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TIER8_DIR="${SCRIPT_DIR}/tier8"

echo "=== Patch 09: Tier 8 UnitOperations SDK-style conversion ==="
echo "DWSIM root: ${DWSIM_ROOT}"
echo ""

UO_DIR="${DWSIM_ROOT}/DWSIM.UnitOperations"

if [ ! -d "${UO_DIR}" ]; then
    echo "ERROR: UnitOperations directory not found: ${UO_DIR}"
    exit 1
fi

# ---------------------------------------------------------------------------
# Phase 1: Apply WinForms source patches
# Must happen BEFORE project file replacement so the file content is correct
# ---------------------------------------------------------------------------
echo "--- Phase 1: Apply WinForms source patches ---"
echo ""

bash "${TIER8_DIR}/patch-winforms-guards.sh" "${DWSIM_ROOT}"

echo ""

# ---------------------------------------------------------------------------
# Phase 2: Replace project file with SDK-style version
# ---------------------------------------------------------------------------
echo "--- Phase 2: Replacing project file with SDK-style ---"
echo ""

echo "[UnitOperations] Replacing project file with SDK-style..."
cp "${TIER8_DIR}/DWSIM.UnitOperations.vbproj" "${UO_DIR}/DWSIM.UnitOperations.vbproj"

# ---------------------------------------------------------------------------
# Phase 3: Remove obsolete files (SDK-style handles differently)
# ---------------------------------------------------------------------------
echo "--- Phase 3: Cleaning up obsolete files ---"
echo ""

# 3a. Remove packages.config (NuGet packages are now PackageReferences)
echo "[UnitOperations] Removing packages.config..."
rm -f "${UO_DIR}/packages.config"

# 3b. Remove My Project auto-generated files (not needed in SDK-style)
echo "[UnitOperations] Removing My Project auto-generated designer files..."
rm -f "${UO_DIR}/My Project/Application.Designer.vb"
rm -f "${UO_DIR}/My Project/Application.myapp"
rm -f "${UO_DIR}/My Project/Resources.Designer.vb"
rm -f "${UO_DIR}/My Project/Resources.resx"
rm -f "${UO_DIR}/My Project/Settings.Designer.vb"
rm -f "${UO_DIR}/My Project/Settings.settings"

# 3c. Remove app.config (assembly binding redirects not needed in .NET 8.0)
echo "[UnitOperations] Removing app.config..."
rm -f "${UO_DIR}/app.config"

echo ""
echo "[UnitOperations] Done."
echo ""

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo "=== Patch 09 complete ==="
echo "Converted DWSIM.UnitOperations to SDK-style net8.0:"
echo ""
echo "  EXCLUDED from compilation:"
echo "    * EditingForms/**  (~100 WinForms UI editor files + .resx)"
echo "    * Extenders/ScintillaExtender.vb (ScintillaNET dependency)"
echo "    * Extenders/ExtensionMethods.vb (WinForms clipboard helpers)"
echo "    * SupportClasses/ComboBoxColumnTemplates.vb (DataGridViewComboBoxCell)"
echo "    * PEMFC_ChamberlineKim.vb, PEMFC_LarminieDicks.vb (were <None>)"
echo ""
echo "  #If Not HEADLESS guards added to ~45 source files:"
echo "    * Imports System.Windows.Forms (22 files)"
echo "    * Imports NetOffice.ExcelApi (2 files)"
echo "    * Public f As EditingForm_* field declarations (40+ files)"
echo "    * DisplayEditForm/UpdateEditForm/GetEditingForm/CloseEditForm methods"
echo "    * MessageBox.Show calls (6 files)"
echo "    * NetOffice Excel COM automation blocks (Spreadsheet.vb)"
echo "    * WeifenLuo.WinFormsUI references (Tank.vb, Vessel.vb)"
echo ""
echo "  REMOVED project references:"
echo "    * DWSIM.Controls.DockPanel (WinForms docking)"
echo "    * DWSIM.Controls.TabStrip (WinForms tabs)"
echo "    * DWSIM.Controls.ZedGraph (WinForms charting)"
echo ""
echo "  REMOVED assembly references:"
echo "    * ScintillaNET, RichTextBoxExtended, SkiaSharp.Views.WindowsForms"
echo "    * unvell.ReoGrid, unvell.ReoGridEditor"
echo "    * stdole, WindowsBase"
echo "    * System.Windows.Forms (project-level import removed)"
echo ""
echo "  19 project references KEPT (core dependencies)"
echo "  13 NuGet packages | 8 local DLL references"
echo ""
