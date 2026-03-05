#!/usr/bin/env bash
# =============================================================================
# Tier 6 Source Patches: Remove unused WinForms/System.Drawing imports
# from DWSIM.Drawing.SkiaSharp source files.
#
# These files have "Imports System.Windows.Forms" or "Imports System.Drawing"
# but don't actually use any types from those namespaces (they use SkiaSharp
# types instead). Removing the dead imports avoids needing those assemblies
# at compile time.
# =============================================================================
set -euo pipefail

DWSIM_ROOT="${1:?Usage: $0 <dwsim-source-root>}"

DRAWING_DIR="${DWSIM_ROOT}/DWSIM.Drawing.SkiaSharp"

echo "[Tier6-Sources] Patching source files to remove unused WinForms/Drawing imports..."

# ---------------------------------------------------------------------------
# 1. ConnectorClass.vb - Remove unused "Imports System.Windows.Forms"
#    The file imports it but never uses any WinForms types (verified: no
#    Cursor, Keys, Form, Control, MessageBox, or other WinForms type usage).
# ---------------------------------------------------------------------------
CONNECTOR_FILE="${DRAWING_DIR}/GraphicObjects/Connector/ConnectorClass.vb"
if [ -f "${CONNECTOR_FILE}" ]; then
    if grep -q "^Imports System\.Windows\.Forms" "${CONNECTOR_FILE}"; then
        echo "  [ConnectorClass.vb] Removing unused 'Imports System.Windows.Forms'"
        sed -i.bak '/^Imports System\.Windows\.Forms$/d' "${CONNECTOR_FILE}"
        rm -f "${CONNECTOR_FILE}.bak"
    else
        echo "  [ConnectorClass.vb] Already patched or import not found"
    fi
else
    echo "  [ConnectorClass.vb] WARNING: File not found at ${CONNECTOR_FILE}"
fi

# ---------------------------------------------------------------------------
# 2. RectangleGraphic.vb - Remove unused System.Drawing imports
#    The file has "Imports System.Drawing" and "Imports System.Drawing.Drawing2D"
#    but only uses SkiaSharp types (SKCanvas, SKPaint, SKRect, SKColor, etc.).
# ---------------------------------------------------------------------------
RECT_FILE="${DRAWING_DIR}/GraphicObjects/Other/RectangleGraphic.vb"
if [ -f "${RECT_FILE}" ]; then
    if grep -q "^Imports System\.Drawing$" "${RECT_FILE}"; then
        echo "  [RectangleGraphic.vb] Removing unused 'Imports System.Drawing'"
        sed -i.bak '/^Imports System\.Drawing$/d' "${RECT_FILE}"
        rm -f "${RECT_FILE}.bak"
    fi
    if grep -q "^Imports System\.Drawing\.Drawing2D$" "${RECT_FILE}"; then
        echo "  [RectangleGraphic.vb] Removing unused 'Imports System.Drawing.Drawing2D'"
        sed -i.bak '/^Imports System\.Drawing\.Drawing2D$/d' "${RECT_FILE}"
        rm -f "${RECT_FILE}.bak"
    fi
else
    echo "  [RectangleGraphic.vb] WARNING: File not found at ${RECT_FILE}"
fi

# ---------------------------------------------------------------------------
# 3. GraphicObject.vb - Fix GetIconAsBitmap interface mismatch
#    In DWSIM.Interfaces, GetIconAsBitmap() was changed from returning
#    System.Drawing.Bitmap to Object. The implementation must match.
# ---------------------------------------------------------------------------
GRAPHOBJ="${DRAWING_DIR}/GraphicObjects/Base/GraphicObject.vb"
if [ -f "${GRAPHOBJ}" ]; then
    echo "  [GraphicObject.vb] Fixing GetIconAsBitmap return type: Bitmap -> Object"
    if [ "$(uname)" = "Darwin" ]; then
        sed -i '' 's/As System\.Drawing\.Bitmap Implements IGraphicObject\.GetIconAsBitmap/As Object Implements IGraphicObject.GetIconAsBitmap/g' "${GRAPHOBJ}"
    else
        sed -i 's/As System\.Drawing\.Bitmap Implements IGraphicObject\.GetIconAsBitmap/As Object Implements IGraphicObject.GetIconAsBitmap/g' "${GRAPHOBJ}"
    fi
fi

# ---------------------------------------------------------------------------
# 4. DesignSurface.vb - Fix My.Computer.Clipboard (not available with MyType=Empty)
#    Replace My.Computer.Clipboard with direct System clipboard or wrap with guards
# ---------------------------------------------------------------------------
DESIGN_SURFACE="${DRAWING_DIR}/GraphicsSurface/DesignSurface.vb"
if [ -f "${DESIGN_SURFACE}" ]; then
    echo "  [DesignSurface.vb] Replacing My.Computer.Keyboard with False (headless)"
    # My.Computer.Keyboard.ShiftKeyDown / CtrlKeyDown — not available with MyType=Empty
    # In headless mode, no keyboard state — replace with False
    sed -i 's/My\.Computer\.Keyboard\.ShiftKeyDown/False/g' "${DESIGN_SURFACE}"
    sed -i 's/My\.Computer\.Keyboard\.CtrlKeyDown/False/g' "${DESIGN_SURFACE}"
    sed -i 's/My\.Computer\.Keyboard\.AltKeyDown/False/g' "${DESIGN_SURFACE}"
    echo "  [OK] Replaced My.Computer.Keyboard.* with False"
fi

echo "[Tier6-Sources] Source patching complete."
