#!/usr/bin/env bash
# =============================================================================
# Patch 08: Tier 7 SDK-style project conversion
# Converts FlowsheetSolver and DynamicsManager from old-style .NET Framework
# 4.6.2 to SDK-style .NET 8.0.
#
# Projects converted:
#   1. DWSIM.FlowsheetSolver (VB.NET)
#      - The core flowsheet calculation engine (solver, scheduling, scripting)
#      - Removed Cudafy.NET reference (GPU library, not used in source code,
#        not compatible with .NET 8.0 / cross-platform builds)
#      - No WinForms or System.Drawing dependencies in source code
#      - Inspector usage preserved (used in FlowsheetSolver.vb, FlowsheetSolver2.vb)
#      - 7 project references preserved: Inspector, XMLSerializer, ExtensionMethods,
#        GlobalSettings, Interfaces, MathOps, SharedClasses
#      - Source files: FlowsheetSolver.vb, FlowsheetSolver2.vb, ObjectInfo.vb,
#        Script.vb, Task Schedulers/*.vb
#
#   2. DWSIM.DynamicsManager (VB.NET)
#      - Dynamic simulation manager (integrators, events, scheduling, charting)
#      - Uses OxyPlot.Core for chart model generation (GetChartModel)
#      - Upgraded OxyPlot.Core from 2.0.0-unstable1035 to 2.1.2 (stable)
#      - No WinForms or System.Drawing dependencies in source code
#      - 6 project references preserved: ExtensionMethods, Interfaces,
#        MathOps.DotNumerics, MathOps, XMLSerializer, SharedClasses
#      - Source files: Manager.vb, Integrator.vb, Schedule.vb, Event.vb,
#        EventSet.vb, CauseAndEffectItem.vb, CauseAndEffectMatrix.vb,
#        MonitoredVariable.vb
# =============================================================================
set -euo pipefail

DWSIM_ROOT="${1:?Usage: $0 <dwsim-source-root>}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TIER7_DIR="${SCRIPT_DIR}/tier7"

echo "=== Patch 08: Tier 7 FlowsheetSolver + DynamicsManager SDK-style conversion ==="
echo "DWSIM root: ${DWSIM_ROOT}"
echo ""

# ---------------------------------------------------------------------------
# Phase 1: DWSIM.FlowsheetSolver (VB.NET)
# ---------------------------------------------------------------------------
echo "--- Phase 1: Converting DWSIM.FlowsheetSolver ---"
echo ""

SOLVER_DIR="${DWSIM_ROOT}/DWSIM.FlowsheetSolver"

if [ ! -d "${SOLVER_DIR}" ]; then
    echo "ERROR: FlowsheetSolver directory not found: ${SOLVER_DIR}"
    exit 1
fi

# 1a. Replace project file with SDK-style version
echo "[FlowsheetSolver] Replacing project file with SDK-style..."
cp "${TIER7_DIR}/DWSIM.FlowsheetSolver.vbproj" "${SOLVER_DIR}/DWSIM.FlowsheetSolver.vbproj"

# 1b. Remove My Project auto-generated files (not needed in SDK-style)
echo "[FlowsheetSolver] Removing My Project auto-generated designer files..."
rm -f "${SOLVER_DIR}/My Project/Application.Designer.vb"
rm -f "${SOLVER_DIR}/My Project/Application.myapp"
rm -f "${SOLVER_DIR}/My Project/Resources.Designer.vb"
rm -f "${SOLVER_DIR}/My Project/Resources.resx"
rm -f "${SOLVER_DIR}/My Project/Settings.Designer.vb"
rm -f "${SOLVER_DIR}/My Project/Settings.settings"

# 1c. Remove app.config (assembly binding redirects not needed in .NET 8.0)
echo "[FlowsheetSolver] Removing app.config..."
rm -f "${SOLVER_DIR}/app.config"

echo "[FlowsheetSolver] Done."
echo ""

# ---------------------------------------------------------------------------
# Phase 2: DWSIM.DynamicsManager (VB.NET)
# ---------------------------------------------------------------------------
echo "--- Phase 2: Converting DWSIM.DynamicsManager ---"
echo ""

DYNAMICS_DIR="${DWSIM_ROOT}/DWSIM.DynamicsManager"

if [ ! -d "${DYNAMICS_DIR}" ]; then
    echo "ERROR: DynamicsManager directory not found: ${DYNAMICS_DIR}"
    exit 1
fi

# 2a. Replace project file with SDK-style version
echo "[DynamicsManager] Replacing project file with SDK-style..."
cp "${TIER7_DIR}/DWSIM.DynamicsManager.vbproj" "${DYNAMICS_DIR}/DWSIM.DynamicsManager.vbproj"

# 2b. Remove packages.config (NuGet refs now in project file)
echo "[DynamicsManager] Removing packages.config..."
rm -f "${DYNAMICS_DIR}/packages.config"

# 2c. Remove My Project auto-generated files (not needed in SDK-style)
echo "[DynamicsManager] Removing My Project auto-generated designer files..."
rm -f "${DYNAMICS_DIR}/My Project/Application.Designer.vb"
rm -f "${DYNAMICS_DIR}/My Project/Application.myapp"
rm -f "${DYNAMICS_DIR}/My Project/Resources.Designer.vb"
rm -f "${DYNAMICS_DIR}/My Project/Resources.resx"
rm -f "${DYNAMICS_DIR}/My Project/Settings.Designer.vb"
rm -f "${DYNAMICS_DIR}/My Project/Settings.settings"

# 2d. Remove app.config (assembly binding redirects not needed in .NET 8.0)
echo "[DynamicsManager] Removing app.config..."
rm -f "${DYNAMICS_DIR}/app.config"

echo "[DynamicsManager] Done."
echo ""

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo "=== Patch 08 complete ==="
echo "Converted 2 Tier 7 projects to SDK-style net8.0:"
echo ""
echo "  1. DWSIM.FlowsheetSolver (VB.NET)"
echo "     * Core flowsheet calculation engine"
echo "     * Removed Cudafy.NET reference (GPU library, unused in source code,"
echo "       incompatible with .NET 8.0 cross-platform builds)"
echo "     * No source code changes needed -- clean conversion"
echo "     * 7 project references: Inspector, XMLSerializer, ExtensionMethods,"
echo "       GlobalSettings, Interfaces, MathOps, SharedClasses"
echo ""
echo "  2. DWSIM.DynamicsManager (VB.NET)"
echo "     * Dynamic simulation manager (integrators, events, charts)"
echo "     * NuGet: OxyPlot.Core 2.1.2 (upgraded from 2.0.0-unstable1035)"
echo "     * No source code changes needed -- clean conversion"
echo "     * 6 project references: ExtensionMethods, Interfaces,"
echo "       MathOps.DotNumerics, MathOps, XMLSerializer, SharedClasses"
echo ""
