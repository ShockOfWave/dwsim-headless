#!/usr/bin/env bash
# =============================================================================
# Patch 01: Tier 0 SDK-style project conversion
# Converts DWSIM.Logging, DWSIM.DrawingTools.Point,
# DWSIM.Thermodynamics.CoolPropInterface, and DWSIM.Interfaces
# from old-style .NET Framework 4.6.x to SDK-style .NET 8.0.
# =============================================================================
set -euo pipefail

DWSIM_ROOT="${1:?Usage: $0 <dwsim-source-root>}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TIER0_DIR="${SCRIPT_DIR}/tier0"

echo "=== Patch 01: Tier 0 SDK-style project conversion ==="
echo "DWSIM root: ${DWSIM_ROOT}"
echo ""

# ---------------------------------------------------------------------------
# 1. DWSIM.Logging - C# library, clean (no WinForms)
# ---------------------------------------------------------------------------
echo "[1/4] Converting DWSIM.Logging..."

# Replace the project file with SDK-style version
cp "${TIER0_DIR}/DWSIM.Logging.csproj" \
   "${DWSIM_ROOT}/DWSIM.Logging/DWSIM.Logging.csproj"

# Remove packages.config (NuGet packages are now in the .csproj via PackageReference)
rm -f "${DWSIM_ROOT}/DWSIM.Logging/packages.config"

echo "  - Replaced project file with SDK-style"
echo "  - Removed packages.config"
echo ""

# ---------------------------------------------------------------------------
# 2. DWSIM.DrawingTools.Point - VB.NET library, clean
# ---------------------------------------------------------------------------
echo "[2/4] Converting DWSIM.DrawingTools.Point..."

# Replace the project file with SDK-style version
cp "${TIER0_DIR}/DWSIM.DrawingTools.Point.vbproj" \
   "${DWSIM_ROOT}/DWSIM.DrawingTools.Point/DWSIM.DrawingTools.Point.vbproj"

# Remove the old My Project auto-generated files that conflict with SDK-style.
# SDK-style projects auto-generate assembly info and don't use the VB
# Application/Resources/Settings designer pattern.
# NOTE: We keep AssemblyInfo.vb because GenerateAssemblyInfo=false in the project.
# The Compile Remove entries in the .vbproj handle the designer files,
# but removing them entirely avoids any confusion.
rm -f "${DWSIM_ROOT}/DWSIM.DrawingTools.Point/My Project/Application.Designer.vb"
rm -f "${DWSIM_ROOT}/DWSIM.DrawingTools.Point/My Project/Application.myapp"
rm -f "${DWSIM_ROOT}/DWSIM.DrawingTools.Point/My Project/Resources.Designer.vb"
rm -f "${DWSIM_ROOT}/DWSIM.DrawingTools.Point/My Project/Resources.resx"
rm -f "${DWSIM_ROOT}/DWSIM.DrawingTools.Point/My Project/Settings.Designer.vb"
rm -f "${DWSIM_ROOT}/DWSIM.DrawingTools.Point/My Project/Settings.settings"

echo "  - Replaced project file with SDK-style"
echo "  - Removed My Project auto-generated designer files"
echo ""

# ---------------------------------------------------------------------------
# 3. DWSIM.Thermodynamics.CoolPropInterface - C# library with P/Invoke
# ---------------------------------------------------------------------------
echo "[3/4] Converting DWSIM.Thermodynamics.CoolPropInterface..."

# Replace the project file with SDK-style version
cp "${TIER0_DIR}/DWSIM.Thermodynamics.CoolPropInterface.csproj" \
   "${DWSIM_ROOT}/DWSIM.Thermodynamics.CoolPropInterface/DWSIM.Thermodynamics.CoolPropInterface.csproj"

echo "  - Replaced project file with SDK-style"
echo ""

# ---------------------------------------------------------------------------
# 4. DWSIM.Interfaces - VB.NET library (WinForms decontamination required)
# ---------------------------------------------------------------------------
echo "[4/4] Converting DWSIM.Interfaces..."

# Replace the project file with SDK-style version
cp "${TIER0_DIR}/DWSIM.Interfaces.vbproj" \
   "${DWSIM_ROOT}/DWSIM.Interfaces/DWSIM.Interfaces.vbproj"

# Remove packages.config
rm -f "${DWSIM_ROOT}/DWSIM.Interfaces/packages.config"

# Remove the old My Project auto-generated files
rm -f "${DWSIM_ROOT}/DWSIM.Interfaces/My Project/Application.Designer.vb"
rm -f "${DWSIM_ROOT}/DWSIM.Interfaces/My Project/Application.myapp"
rm -f "${DWSIM_ROOT}/DWSIM.Interfaces/My Project/Resources.Designer.vb"
rm -f "${DWSIM_ROOT}/DWSIM.Interfaces/My Project/Resources.resx"
rm -f "${DWSIM_ROOT}/DWSIM.Interfaces/My Project/Settings.Designer.vb"
rm -f "${DWSIM_ROOT}/DWSIM.Interfaces/My Project/Settings.settings"

echo "  - Replaced project file with SDK-style"
echo "  - Removed packages.config"
echo "  - Removed My Project auto-generated designer files"

# --- WinForms decontamination: replace WinForms types with Object ---

INTERFACES_DIR="${DWSIM_ROOT}/DWSIM.Interfaces"

# ISimulationObject.vb:
#   Function GetEditingForm() As System.Windows.Forms.Form
#   -> Function GetEditingForm() As Object
echo "  - Patching ISimulationObject.vb: System.Windows.Forms.Form -> Object"
sed -i.bak 's/As System\.Windows\.Forms\.Form/As Object/g' \
    "${INTERFACES_DIR}/ISimulationObject.vb"

# ISplashScreen.vb:
#   Function GetSplashScreen() As System.Windows.Forms.Form
#   -> Function GetSplashScreen() As Object
echo "  - Patching ISplashScreen.vb: System.Windows.Forms.Form -> Object"
sed -i.bak 's/As System\.Windows\.Forms\.Form/As Object/g' \
    "${INTERFACES_DIR}/ISplashScreen.vb"

# IWelcomeScreen.vb:
#   Function GetWelcomeScreen() As System.Windows.Forms.UserControl
#   -> Function GetWelcomeScreen() As Object
#   Sub SetMainForm(form As System.Windows.Forms.Form)
#   -> Sub SetMainForm(form As Object)
echo "  - Patching IWelcomeScreen.vb: System.Windows.Forms.Form -> Object, System.Windows.Forms.UserControl -> Object"
sed -i.bak \
    -e 's/As System\.Windows\.Forms\.UserControl/As Object/g' \
    -e 's/As System\.Windows\.Forms\.Form/As Object/g' \
    "${INTERFACES_DIR}/IWelcomeScreen.vb"

# IExtender.vb:
#   Sub SetMainWindow(mainwindow As System.Windows.Forms.Form)
#   -> Sub SetMainWindow(mainwindow As Object)
#   ReadOnly Property DisplayImage As System.Drawing.Bitmap
#   -> ReadOnly Property DisplayImage As Object
echo "  - Patching IExtender.vb: System.Windows.Forms.Form -> Object, System.Drawing.Bitmap -> Object"
sed -i.bak \
    -e 's/As System\.Windows\.Forms\.Form/As Object/g' \
    -e 's/As System\.Drawing\.Bitmap/As Object/g' \
    "${INTERFACES_DIR}/IExtender.vb"

# IFlowsheetSolveCallback.vb:
#   Remove "Imports System.Windows.Forms" line
#   Note: Use pattern without ^ anchor because the file may have a UTF-8 BOM
echo "  - Patching IFlowsheetSolveCallback.vb: removing Imports System.Windows.Forms"
sed -i.bak '/Imports System\.Windows\.Forms/d' \
    "${INTERFACES_DIR}/IFlowsheetSolveCallback.vb"

# IGraphicObject.vb:
#   Function GetIconAsBitmap() As System.Drawing.Bitmap
#   -> Function GetIconAsBitmap() As Object
echo "  - Patching IGraphicObject.vb: System.Drawing.Bitmap -> Object"
sed -i.bak 's/As System\.Drawing\.Bitmap/As Object/g' \
    "${INTERFACES_DIR}/IGraphicObject.vb"

# Clean up sed backup files
find "${INTERFACES_DIR}" -name '*.bak' -delete

echo ""
echo "=== Patch 01 complete ==="
echo "Converted 4 Tier 0 projects to SDK-style net8.0:"
echo "  - DWSIM.Logging"
echo "  - DWSIM.DrawingTools.Point"
echo "  - DWSIM.Thermodynamics.CoolPropInterface"
echo "  - DWSIM.Interfaces (with WinForms/System.Drawing decontamination)"
