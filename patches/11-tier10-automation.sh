#!/usr/bin/env bash
# =============================================================================
# Patch 11: Tier 10 SDK-style project conversion
# Converts DWSIM.Automation from old-style .NET Framework 4.6.2 to SDK-style
# .NET 8.0 with headless mode (Automation3 only).
#
# DWSIM.Automation (C#):
#   - Contains 3 classes: Automation, Automation2, Automation3
#   - Plus Flowsheet2 (headless flowsheet implementation)
#
#   KEPT in HEADLESS mode:
#     * Automation3 class -- fully headless, uses Flowsheet2
#     * Flowsheet2 class -- headless flowsheet (ReoGrid parts stubbed out)
#     * AutomationInterface interface -- needed by Automation3
#
#   EXCLUDED via #if !HEADLESS:
#     * Automation class (class 1) -- uses FormMain from WinForms main app
#     * Automation2 class (class 2) -- uses Eto.Forms Application
#     * using DWSIM.UI.Desktop.Shared (only needed by Automation2)
#     * using DWSIM.SharedClassesCSharp.FilePicker.Windows (only by Automation)
#
#   ReoGrid (unvell.ReoGrid) handling in Flowsheet2.cs:
#     * ReoGrid 2.1.0 targets net462/net472 -- NOT compatible with net8.0
#     * All ReoGrid using statements guarded with #if !HEADLESS
#     * IWorkbook Spreadsheet field -> object in headless mode
#     * Spreadsheet lambdas (Load/Save/Retrieve) -> no-op stubs in headless
#     * GetSpreadsheetDataFromRange/FormatFromRange -> guarded out
#     * SetCustomSpreadsheetFunctions -> empty in headless
#     * Init() ReoGrid.CreateMemoryWorkbook -> skipped in headless
#
#   REMOVED project references:
#     * DWSIM (main WinForms app -- FormMain, FormFlowsheet)
#     * DWSIM.UI.Desktop (Eto.Forms desktop launcher)
#     * DWSIM.UI.Desktop.Shared (Eto.Forms shared UI)
#     * DWSIM.UI.Desktop.Forms (Eto.Forms forms)
#     * DWSIM.Controls.PropertyGridEx (WinForms property grid)
#     * DWSIM.Simulate365 (cloud integration)
#
#   REMOVED assembly references:
#     * System.Windows.Forms
#     * Eto.Forms (NuGet)
#     * unvell.ReoGrid (local DLL, WinForms-dependent)
#
#   KEPT project references (15 total):
#     * DWSIM.ExtensionMethods, DWSIM.FlowsheetBase, DWSIM.FlowsheetSolver
#     * DWSIM.GlobalSettings, DWSIM.Interfaces, DWSIM.Logging
#     * DWSIM.Serializers.XML, DWSIM.SharedClasses, DWSIM.SharedClassesCSharp
#     * DWSIM.Thermodynamics + GERG2008, PCSAFT, PRSRKTDep, Reaktoro
#     * DWSIM.UnitOperations
#
#   KEPT NuGet packages:
#     * iTextSharp-LGPL 4.1.6 (PDF report generation)
#     * Newtonsoft.Json 13.0.3
#     * SharpZipLib 1.4.2
#
#   KEPT local DLL references:
#     * CapeOpen.dll (from DWSIM/References/)
# =============================================================================
set -euo pipefail

DWSIM_ROOT="${1:?Usage: $0 <dwsim-source-root>}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TIER10_DIR="${SCRIPT_DIR}/tier10"

echo "=== Patch 11: Tier 10 DWSIM.Automation SDK-style conversion ==="
echo "DWSIM root: ${DWSIM_ROOT}"
echo ""

AUTO_DIR="${DWSIM_ROOT}/DWSIM.Automation"

# ---------------------------------------------------------------------------
# Validate directory exists
# ---------------------------------------------------------------------------
if [ ! -d "${AUTO_DIR}" ]; then
    echo "ERROR: Directory not found: ${AUTO_DIR}"
    exit 1
fi

# ===========================================================================
# Step 1: Apply HEADLESS source patches BEFORE project replacement
# ===========================================================================
echo "--- Step 1: Applying HEADLESS source patches ---"
echo ""

bash "${TIER10_DIR}/patch-headless-guards.sh" "${DWSIM_ROOT}"

echo ""

# ===========================================================================
# Step 2: Replace project file with SDK-style
# ===========================================================================
echo "--- Step 2: Replacing project file with SDK-style ---"
cp "${TIER10_DIR}/DWSIM.Automation.csproj" "${AUTO_DIR}/DWSIM.Automation.csproj"
echo "  Copied DWSIM.Automation.csproj"

# ===========================================================================
# Step 3: Remove packages.config (NuGet now in project file)
# ===========================================================================
echo "--- Step 3: Removing packages.config ---"
rm -f "${AUTO_DIR}/packages.config"
echo "  Removed packages.config"

# ===========================================================================
# Step 4: Remove app.config (not needed in SDK-style)
# ===========================================================================
echo "--- Step 4: Removing app.config ---"
rm -f "${AUTO_DIR}/app.config"
echo "  Removed app.config"

# ===========================================================================
# Step 5: Remove Properties/AssemblyInfo.cs if GenerateAssemblyInfo=false
#         (SDK-style with GenerateAssemblyInfo=false keeps existing AssemblyInfo)
#         Actually, we KEEP it since GenerateAssemblyInfo=false means the
#         project relies on the hand-written AssemblyInfo.
# ===========================================================================
echo "--- Step 5: Keeping Properties/AssemblyInfo.cs (GenerateAssemblyInfo=false) ---"
echo "  AssemblyInfo.cs preserved"

echo ""

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo "=== Patch 11 complete ==="
echo "Converted DWSIM.Automation to SDK-style net8.0 (headless mode):"
echo ""
echo "  #if !HEADLESS guards applied:"
echo "    Automation.cs:"
echo "      * using DWSIM.UI.Desktop.Shared"
echo "      * using DWSIM.SharedClassesCSharp.FilePicker.Windows"
echo "      * Automation class (entire class -- uses WinForms FormMain)"
echo "      * Automation2 class (entire class -- uses Eto.Forms)"
echo ""
echo "    Flowsheet2.cs:"
echo "      * ReoGrid using statements (3 lines)"
echo "      * IWorkbook Spreadsheet field (-> object stub)"
echo "      * Constructor spreadsheet lambdas (5 delegates -> no-op stubs)"
echo "      * GetSpreadsheetDataFromRange + GetSpreadsheetFormatFromRange"
echo "      * SetCustomSpreadsheetFunctions (-> empty)"
echo "      * Init() ReoGrid.CreateMemoryWorkbook (-> skipped)"
echo ""
echo "  REMOVED references (GUI-only):"
echo "    * DWSIM, DWSIM.UI.Desktop.*, DWSIM.Controls.PropertyGridEx"
echo "    * DWSIM.Simulate365, System.Windows.Forms, Eto.Forms, unvell.ReoGrid"
echo ""
echo "  KEPT: 15 project refs | 3 NuGet packages | 1 local DLL (CapeOpen)"
echo ""
