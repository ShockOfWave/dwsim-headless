#!/usr/bin/env bash
# =============================================================================
# Patch 03: Tier 2 SDK-style project conversion - Math libraries
# Converts 6 DWSIM math library projects from old-style .NET Framework 4.6.x
# to SDK-style .NET 8.0:
#   1. DWSIM.MathOps (VB.NET)
#   2. DWSIM.MathOps.DotNumerics (C#)
#   3. DWSIM.MathOps.RandomOps (C#)
#   4. DWSIM.MathOps.SwarmOps (C#)
#   5. DWSIM.MathOps.SimpsonIntegrator (C#)
#   6. DWSIM.MathOps.Mapack (C#)
# =============================================================================
set -euo pipefail

DWSIM_ROOT="${1:?Usage: $0 <dwsim-source-root>}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TIER2_DIR="${SCRIPT_DIR}/tier2"

echo "=== Patch 03: Tier 2 SDK-style project conversion (Math libraries) ==="
echo "DWSIM root: ${DWSIM_ROOT}"
echo ""

# ---------------------------------------------------------------------------
# 1. DWSIM.MathOps - VB.NET library
#    Dependencies: AutoDiff (NuGet), MathNet.Numerics (NuGet),
#                  LibOptimization (NuGet), Cureos.Numerics (local DLL),
#                  Mapack (local DLL), DWSIM.DrawingTools.Point (project ref)
# ---------------------------------------------------------------------------
echo "[1/6] Converting DWSIM.MathOps..."

# Replace the project file with SDK-style version
cp "${TIER2_DIR}/DWSIM.MathOps.vbproj" \
   "${DWSIM_ROOT}/DWSIM.Math/DWSIM.MathOps.vbproj"

# Remove packages.config (NuGet packages are now in the .csproj via PackageReference)
rm -f "${DWSIM_ROOT}/DWSIM.Math/packages.config"

# Remove the old My Project auto-generated files that conflict with SDK-style.
# NOTE: We keep AssemblyInfo.vb because GenerateAssemblyInfo=false in the project.
rm -f "${DWSIM_ROOT}/DWSIM.Math/My Project/Application.Designer.vb"
rm -f "${DWSIM_ROOT}/DWSIM.Math/My Project/Application.myapp"
rm -f "${DWSIM_ROOT}/DWSIM.Math/My Project/Resources.Designer.vb"
rm -f "${DWSIM_ROOT}/DWSIM.Math/My Project/Resources.resx"
rm -f "${DWSIM_ROOT}/DWSIM.Math/My Project/Settings.Designer.vb"
rm -f "${DWSIM_ROOT}/DWSIM.Math/My Project/Settings.settings"

# Remove app.config (not needed for SDK-style class libraries)
rm -f "${DWSIM_ROOT}/DWSIM.Math/app.config"

echo "  - Replaced project file with SDK-style"
echo "  - Removed packages.config"
echo "  - Removed My Project auto-generated designer files"
echo "  - NuGet: AutoDiff 1.2.2, MathNet.Numerics 5.0.0, LibOptimization 1.14.0"
echo "  - Local refs: Cureos.Numerics.dll, Mapack.dll"
echo "  - Project ref: DWSIM.DrawingTools.Point"
echo ""

# ---------------------------------------------------------------------------
# 2. DWSIM.MathOps.DotNumerics - C# library (numerical algorithms)
#    Dependencies: System.Drawing.Common (NuGet, replacing System.Drawing)
# ---------------------------------------------------------------------------
echo "[2/6] Converting DWSIM.MathOps.DotNumerics..."

cp "${TIER2_DIR}/DWSIM.MathOps.DotNumerics.csproj" \
   "${DWSIM_ROOT}/DWSIM.Math.DotNumerics/DWSIM.MathOps.DotNumerics.csproj"

echo "  - Replaced project file with SDK-style"
echo "  - NuGet: System.Drawing.Common 8.0.0 (replaces System.Drawing reference)"
echo ""

# ---------------------------------------------------------------------------
# 3. DWSIM.MathOps.RandomOps - C# library (random number generators)
#    Dependencies: none (pure framework references only)
# ---------------------------------------------------------------------------
echo "[3/6] Converting DWSIM.MathOps.RandomOps..."

cp "${TIER2_DIR}/DWSIM.MathOps.RandomOps.csproj" \
   "${DWSIM_ROOT}/DWSIM.Math.RandomOps/DWSIM.MathOps.RandomOps.csproj"

echo "  - Replaced project file with SDK-style"
echo "  - No external dependencies"
echo ""

# ---------------------------------------------------------------------------
# 4. DWSIM.MathOps.SwarmOps - C# library (swarm optimization)
#    Dependencies: DWSIM.MathOps.RandomOps (project ref)
# ---------------------------------------------------------------------------
echo "[4/6] Converting DWSIM.MathOps.SwarmOps..."

cp "${TIER2_DIR}/DWSIM.MathOps.SwarmOps.csproj" \
   "${DWSIM_ROOT}/DWSIM.Math.SwarmOps/DWSIM.MathOps.SwarmOps.csproj"

echo "  - Replaced project file with SDK-style"
echo "  - Project ref: DWSIM.MathOps.RandomOps"
echo ""

# ---------------------------------------------------------------------------
# 5. DWSIM.MathOps.SimpsonIntegrator - C# library (Simpson's rule integrator)
#    Dependencies: none
# ---------------------------------------------------------------------------
echo "[5/6] Converting DWSIM.MathOps.SimpsonIntegrator..."

cp "${TIER2_DIR}/DWSIM.MathOps.SimpsonIntegrator.csproj" \
   "${DWSIM_ROOT}/DWSIM.MathOps.SimpsonIntegrator/DWSIM.MathOps.SimpsonIntegrator.csproj"

echo "  - Replaced project file with SDK-style"
echo "  - No external dependencies"
echo ""

# ---------------------------------------------------------------------------
# 6. DWSIM.MathOps.Mapack - C# library (matrix algebra)
#    Dependencies: none
# ---------------------------------------------------------------------------
echo "[6/6] Converting DWSIM.MathOps.Mapack..."

cp "${TIER2_DIR}/DWSIM.MathOps.Mapack.csproj" \
   "${DWSIM_ROOT}/DWSIM.MathOps.Mapack/DWSIM.MathOps.Mapack.csproj"

echo "  - Replaced project file with SDK-style"
echo "  - No external dependencies"
echo ""

echo "=== Patch 03 complete ==="
echo "Converted 6 Tier 2 math library projects to SDK-style net8.0:"
echo "  - DWSIM.MathOps (VB.NET, with NuGet + local refs)"
echo "  - DWSIM.MathOps.DotNumerics (C#, with System.Drawing.Common)"
echo "  - DWSIM.MathOps.RandomOps (C#)"
echo "  - DWSIM.MathOps.SwarmOps (C#, depends on RandomOps)"
echo "  - DWSIM.MathOps.SimpsonIntegrator (C#)"
echo "  - DWSIM.MathOps.Mapack (C#)"
