#!/usr/bin/env bash
# =============================================================================
# Patch 05: Tier 4 SDK-style project conversion
# Converts DWSIM.ExtensionMethods (VB.NET), DWSIM.ExtensionMethods.Eto (C#),
# and DWSIM.Inspector (VB.NET) from old-style .NET Framework 4.6.2 to
# SDK-style .NET 8.0.
#
# Strategy:
#   ExtensionMethods:
#     - Exclude WinForms-only files (DataGridView.vb, DropDownWidth.vb, Form.vb)
#     - Wrap mixed-use WinForms code in General.vb with #If Not HEADLESS guards
#     - Keep computational files (General.vb, OxyPlotExtensions.vb,
#       SIMDExtenders.vb, SimplexExtender.vb)
#     - OxyPlot.Core via NuGet, Ciloci.Flee via local HintPath
#
#   ExtensionMethods.Eto:
#     - Cross-platform Eto.Forms UI helpers (needed by Inspector, FlowsheetBase)
#     - Keep all files, add Eto.Forms + OxyPlot.Core NuGet
#
#   Inspector:
#     - Exclude all WinForms windows (Window.vb, Window2.vb, Loading.vb + designers)
#     - Exclude Eto UI windows (Window_Eto.vb, Window2_Eto.vb) - depend on WebView
#     - Keep Inspector.vb (data structures: Host, InspectorItem, InspectorExtensions)
#     - Remove DockPanel, WebView2, SkiaSharp references
#     - Remove unused System.Drawing import from Inspector.vb
# =============================================================================
set -euo pipefail

DWSIM_ROOT="${1:?Usage: $0 <dwsim-source-root>}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TIER4_DIR="${SCRIPT_DIR}/tier4"

echo "=== Patch 05: Tier 4 Extensions + Inspector SDK-style conversion ==="
echo "DWSIM root: ${DWSIM_ROOT}"
echo ""

# ---------------------------------------------------------------------------
# Phase 1: Apply source patches
# Must happen BEFORE project file replacement so the file content is correct
# ---------------------------------------------------------------------------
echo "--- Phase 1: Apply source patches ---"
echo ""

bash "${TIER4_DIR}/patch-extensionmethods-winforms.sh" "${DWSIM_ROOT}"
bash "${TIER4_DIR}/patch-inspector-sources.sh" "${DWSIM_ROOT}"

echo ""

# ---------------------------------------------------------------------------
# Phase 2: DWSIM.ExtensionMethods (VB.NET)
# ---------------------------------------------------------------------------
echo "--- Phase 2: Converting DWSIM.ExtensionMethods ---"
echo ""

EM_DIR="${DWSIM_ROOT}/DWSIM.ExtensionMethods"

# 2a. Replace project file with SDK-style version
echo "[ExtensionMethods] Replacing project file with SDK-style..."
cp "${TIER4_DIR}/DWSIM.ExtensionMethods.vbproj" "${EM_DIR}/DWSIM.ExtensionMethods.vbproj"

# 2b. Remove packages.config (NuGet packages are now PackageReferences)
echo "[ExtensionMethods] Removing packages.config..."
rm -f "${EM_DIR}/packages.config"

# 2c. Remove My Project auto-generated files that conflict with SDK-style
echo "[ExtensionMethods] Removing My Project auto-generated designer files..."
rm -f "${EM_DIR}/My Project/Application.Designer.vb"
rm -f "${EM_DIR}/My Project/Application.myapp"
rm -f "${EM_DIR}/My Project/Resources.Designer.vb"
rm -f "${EM_DIR}/My Project/Resources.resx"
rm -f "${EM_DIR}/My Project/Settings.Designer.vb"
rm -f "${EM_DIR}/My Project/Settings.settings"

echo "[ExtensionMethods] Done."
echo ""

# ---------------------------------------------------------------------------
# Phase 3: DWSIM.ExtensionMethods.Eto (C#)
# ---------------------------------------------------------------------------
echo "--- Phase 3: Converting DWSIM.ExtensionMethods.Eto ---"
echo ""

ETO_DIR="${DWSIM_ROOT}/DWSIM.ExtensionMethods.Eto"

# 3a. Replace project file with SDK-style version
echo "[ExtensionMethods.Eto] Replacing project file with SDK-style..."
cp "${TIER4_DIR}/DWSIM.ExtensionMethods.Eto.csproj" "${ETO_DIR}/DWSIM.ExtensionMethods.Eto.csproj"

# 3b. Remove packages.config
echo "[ExtensionMethods.Eto] Removing packages.config..."
rm -f "${ETO_DIR}/packages.config"

echo "[ExtensionMethods.Eto] Done."
echo ""

# ---------------------------------------------------------------------------
# Phase 4: DWSIM.Inspector (VB.NET)
# ---------------------------------------------------------------------------
echo "--- Phase 4: Converting DWSIM.Inspector ---"
echo ""

INS_DIR="${DWSIM_ROOT}/DWSIM.Inspector"

# 4a. Replace project file with SDK-style version
echo "[Inspector] Replacing project file with SDK-style..."
cp "${TIER4_DIR}/DWSIM.Inspector.vbproj" "${INS_DIR}/DWSIM.Inspector.vbproj"

# 4b. Remove packages.config
echo "[Inspector] Removing packages.config..."
rm -f "${INS_DIR}/packages.config"

# 4c. Remove My Project auto-generated files that conflict with SDK-style
echo "[Inspector] Removing My Project auto-generated designer files..."
rm -f "${INS_DIR}/My Project/Application.Designer.vb"
rm -f "${INS_DIR}/My Project/Application.myapp"
rm -f "${INS_DIR}/My Project/Resources.Designer.vb"
rm -f "${INS_DIR}/My Project/Resources.resx"
rm -f "${INS_DIR}/My Project/Settings.Designer.vb"
rm -f "${INS_DIR}/My Project/Settings.settings"

echo "[Inspector] Done."
echo ""

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo "=== Patch 05 complete ==="
echo "Converted 3 Tier 4 projects to SDK-style net8.0:"
echo "  - DWSIM.ExtensionMethods (VB.NET)"
echo "    * Excluded WinForms files: DataGridView.vb, DropDownWidth.vb, Form.vb"
echo "    * Added #If Not HEADLESS guards to General.vb:"
echo "      - ValidateCellForDouble (DataGridView cell validation)"
echo "      - UIThread / UIThreadInvoke (Control.BeginInvoke)"
echo "      - GetUnits / GetValue (GridItem extensions)"
echo "      - DropDownWidth / DropDownHeight (ListView + TextRenderer)"
echo "      - PasteData / PasteData2 / GetNextVisibleCol (Clipboard + DataGridView)"
echo "    * OxyPlot.Core 2.1.2 via NuGet"
echo "    * Ciloci.Flee via local HintPath"
echo "  - DWSIM.ExtensionMethods.Eto (C#)"
echo "    * Cross-platform Eto.Forms UI helpers - all files kept"
echo "    * Eto.Forms 2.8.3 + OxyPlot.Core 2.1.2 via NuGet"
echo "  - DWSIM.Inspector (VB.NET)"
echo "    * Excluded WinForms: Window.vb, Window2.vb, Loading.vb + designers"
echo "    * Excluded Eto windows: Window_Eto.vb, Window2_Eto.vb (WebView dep)"
echo "    * Kept Inspector.vb (Host, InspectorItem data structures)"
echo "    * Removed unused System.Drawing import"
echo "    * Removed refs: DockPanel, WebView2, SkiaSharp, SharedClassesCSharp"
echo "    * HtmlAgilityPack 1.11.70 via NuGet"
