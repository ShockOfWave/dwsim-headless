#!/usr/bin/env bash
# =============================================================================
# Patch 07: Tier 6 SDK-style project conversion
# Converts all 3 SkiaSharp Drawing projects from old-style .NET Framework 4.6.x
# to SDK-style .NET 8.0.
#
# Projects converted:
#   1. DWSIM.DrawingTools.SkiaSharp (VB.NET)
#      - The main flowsheet drawing library
#      - Excluded HTMLTextGraphic.vb (HtmlRenderer.WinForms + GDI+ interop)
#      - Removed unused WinForms/System.Drawing imports from source files
#      - Removed references: SkiaSharp.Views.WindowsForms, HtmlRenderer.WinForms,
#        OpenTK, OpenTK.GLControl, System.Windows.Forms
#      - Kept: SkiaSharp 2.88.9, SkiaSharp.Extended 2.0.0, MathNet.Numerics 5.0.0,
#        System.Drawing.Common 8.0.0 (for GetIconAsBitmap interface impl),
#        MSAGL (AutomaticGraphLayout) local DLLs
#      - 7 project references preserved
#
#   2. DWSIM.DrawingTools.SkiaSharp.Extended (C#)
#      - OxyPlot chart rendering on SkiaSharp canvas
#      - No WinForms dependencies
#      - Upgraded OxyPlot.Core from 2.0.0-unstable1035 to 2.1.2 (stable)
#      - 4 project references preserved
#
#   3. DWSIM.SkiaSharp.Views.Desktop (C#)
#      - Custom SkiaSharp-to-System.Drawing bridge (extension methods)
#      - Excluded SKControl.cs (inherits System.Windows.Forms.Control)
#      - Excluded SKGLControl.cs (inherits OpenTK.GLControl)
#      - Excluded Gles.cs, SKGLDrawable.cs (OpenGL P/Invoke interop)
#      - Kept Extensions.cs (ToSKBitmap, ToSKImage, etc. - used by UnitOperations)
#      - Kept SKPaintSurfaceEventArgs.cs, SKPaintGLSurfaceEventArgs.cs
#      - Defines __DESKTOP__ to enable System.Drawing.Bitmap conversions
# =============================================================================
set -euo pipefail

DWSIM_ROOT="${1:?Usage: $0 <dwsim-source-root>}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TIER6_DIR="${SCRIPT_DIR}/tier6"

echo "=== Patch 07: Tier 6 SkiaSharp Drawing SDK-style conversion ==="
echo "DWSIM root: ${DWSIM_ROOT}"
echo ""

# ---------------------------------------------------------------------------
# Phase 1: Apply source patches
# Must happen BEFORE project file replacement so the file content is correct
# ---------------------------------------------------------------------------
echo "--- Phase 1: Apply source patches ---"
echo ""

bash "${TIER6_DIR}/patch-drawing-sources.sh" "${DWSIM_ROOT}"

echo ""

# ---------------------------------------------------------------------------
# Phase 2: DWSIM.DrawingTools.SkiaSharp (VB.NET) - main drawing library
# ---------------------------------------------------------------------------
echo "--- Phase 2: Converting DWSIM.DrawingTools.SkiaSharp ---"
echo ""

DRAWING_DIR="${DWSIM_ROOT}/DWSIM.Drawing.SkiaSharp"

# 2a. Replace project file with SDK-style version
echo "[DrawingTools.SkiaSharp] Replacing project file with SDK-style..."
cp "${TIER6_DIR}/DWSIM.DrawingTools.SkiaSharp.vbproj" "${DRAWING_DIR}/DWSIM.DrawingTools.SkiaSharp.vbproj"

# 2b. Remove packages.config (NuGet refs now in project file)
echo "[DrawingTools.SkiaSharp] Removing packages.config..."
rm -f "${DRAWING_DIR}/packages.config"

# 2c. Remove My Project auto-generated files
echo "[DrawingTools.SkiaSharp] Removing My Project auto-generated designer files..."
rm -f "${DRAWING_DIR}/My Project/Application.Designer.vb"
rm -f "${DRAWING_DIR}/My Project/Application.myapp"
rm -f "${DRAWING_DIR}/My Project/Resources.Designer.vb"
rm -f "${DRAWING_DIR}/My Project/Resources.resx"
rm -f "${DRAWING_DIR}/My Project/Settings.Designer.vb"
rm -f "${DRAWING_DIR}/My Project/Settings.settings"

# 2d. Remove app.config (assembly binding redirects not needed)
echo "[DrawingTools.SkiaSharp] Removing app.config..."
rm -f "${DRAWING_DIR}/app.config"

# 2e. Remove OpenTK config (no longer using OpenTK)
echo "[DrawingTools.SkiaSharp] Removing OpenTK.dll.config..."
rm -f "${DRAWING_DIR}/OpenTK.dll.config"

echo "[DrawingTools.SkiaSharp] Done."
echo ""

# ---------------------------------------------------------------------------
# Phase 3: DWSIM.DrawingTools.SkiaSharp.Extended (C#)
# ---------------------------------------------------------------------------
echo "--- Phase 3: Converting DWSIM.DrawingTools.SkiaSharp.Extended ---"
echo ""

EXTENDED_DIR="${DWSIM_ROOT}/DWSIM.DrawingTools.SkiaSharp.Extended"

# 3a. Replace project file with SDK-style version
echo "[DrawingTools.Extended] Replacing project file with SDK-style..."
cp "${TIER6_DIR}/DWSIM.DrawingTools.SkiaSharp.Extended.csproj" "${EXTENDED_DIR}/DWSIM.DrawingTools.SkiaSharp.Extended.csproj"

# 3b. Remove packages.config
echo "[DrawingTools.Extended] Removing packages.config..."
rm -f "${EXTENDED_DIR}/packages.config"

# 3c. Remove app.config
echo "[DrawingTools.Extended] Removing app.config..."
rm -f "${EXTENDED_DIR}/app.config"

echo "[DrawingTools.Extended] Done."
echo ""

# ---------------------------------------------------------------------------
# Phase 4: DWSIM.SkiaSharp.Views.Desktop (C#)
# ---------------------------------------------------------------------------
echo "--- Phase 4: Converting DWSIM.SkiaSharp.Views.Desktop ---"
echo ""

VIEWS_DIR="${DWSIM_ROOT}/DWSIM.SkiaSharp.Views.Desktop"

# 4a. Replace project file with SDK-style version
echo "[SkiaSharp.Views.Desktop] Replacing project file with SDK-style..."
cp "${TIER6_DIR}/DWSIM.SkiaSharp.Views.Desktop.csproj" "${VIEWS_DIR}/DWSIM.SkiaSharp.Views.Desktop.csproj"

# 4b. Remove packages.config
echo "[SkiaSharp.Views.Desktop] Removing packages.config..."
rm -f "${VIEWS_DIR}/packages.config"

# 4c. Remove app.config
echo "[SkiaSharp.Views.Desktop] Removing app.config..."
rm -f "${VIEWS_DIR}/app.config"

# 4d. Remove OpenTK config
echo "[SkiaSharp.Views.Desktop] Removing OpenTK.dll.config..."
rm -f "${VIEWS_DIR}/OpenTK.dll.config"

echo "[SkiaSharp.Views.Desktop] Done."
echo ""

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo "=== Patch 07 complete ==="
echo "Converted 3 Tier 6 SkiaSharp Drawing projects to SDK-style net8.0:"
echo ""
echo "  1. DWSIM.DrawingTools.SkiaSharp (VB.NET)"
echo "     * Main flowsheet drawing library (shapes, connectors, tables, gauges)"
echo "     * Excluded HTMLTextGraphic.vb (HtmlRenderer.WinForms dependency)"
echo "     * Removed dead imports: System.Windows.Forms from ConnectorClass.vb,"
echo "       System.Drawing/Drawing2D from RectangleGraphic.vb"
echo "     * NuGet: SkiaSharp 2.88.9, SkiaSharp.Extended 2.0.0, MathNet 5.0.0,"
echo "       System.Drawing.Common 8.0.0"
echo "     * Local DLLs: MSAGL (AutomaticGraphLayout, AutomaticGraphLayout.Drawing)"
echo ""
echo "  2. DWSIM.DrawingTools.SkiaSharp.Extended (C#)"
echo "     * OxyPlot chart rendering on SkiaSharp canvas"
echo "     * No WinForms dependencies -- clean conversion"
echo "     * NuGet: SkiaSharp 2.88.9, OxyPlot.Core 2.1.2"
echo ""
echo "  3. DWSIM.SkiaSharp.Views.Desktop (C#)"
echo "     * System.Drawing <-> SkiaSharp extension methods bridge"
echo "     * Excluded: SKControl.cs (WinForms), SKGLControl.cs (OpenTK),"
echo "       Gles.cs (OpenGL P/Invoke), SKGLDrawable.cs (OpenGL)"
echo "     * Kept: Extensions.cs (ToSKBitmap, ToSKImage, etc.),"
echo "       SKPaintSurfaceEventArgs.cs, SKPaintGLSurfaceEventArgs.cs"
echo "     * NuGet: SkiaSharp 2.88.9, System.Drawing.Common 8.0.0"
echo ""
