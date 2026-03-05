#!/bin/bash
set -euo pipefail

echo "=== DWSIM Headless Build ==="
echo ".NET SDK version: $(dotnet --version)"
echo ""

cd /src

# ---------------------------------------------------------------------------
# Phase 1: Apply all patches in order
# ---------------------------------------------------------------------------
echo "--- Phase 1: Applying patches ---"
for script in /patches/[0-9]*.sh; do
  if [ -f "$script" ]; then
    echo ""
    echo "Applying: $(basename "$script")"
    bash "$script" /src
  fi
done

echo ""
echo "--- Phase 1 complete: All patches applied ---"
echo ""

# ---------------------------------------------------------------------------
# Phase 2: NuGet restore
# ---------------------------------------------------------------------------
echo "--- Phase 2: NuGet restore ---"
dotnet restore DWSIM.Headless.slnf --verbosity minimal
echo "--- Phase 2 complete ---"
echo ""

# ---------------------------------------------------------------------------
# Phase 3: Build
# ---------------------------------------------------------------------------
echo "--- Phase 3: Building DWSIM Headless ---"
# DWSIM.sln uses "Release|x86" / "Debug|x86" configs, not "Any CPU".
# Build individual projects via the slnf without specifying platform
# to let each SDK-style project use its default (AnyCPU).
dotnet build DWSIM.Headless.slnf \
  --no-restore \
  --verbosity minimal \
  -p:DefineConstants=HEADLESS

echo "--- Phase 3 complete ---"
echo ""

# ---------------------------------------------------------------------------
# Phase 4: Copy output
# ---------------------------------------------------------------------------
echo "--- Phase 4: Collecting build output ---"
# Find the actual output directory (Debug is default when no -c specified)
AUTOMATION_OUT=""
for cfg in Debug Release; do
  if [ -d "DWSIM.Automation/bin/${cfg}/net8.0" ]; then
    AUTOMATION_OUT="DWSIM.Automation/bin/${cfg}/net8.0"
    break
  fi
done

if [ -z "$AUTOMATION_OUT" ]; then
  echo "WARNING: No build output found in DWSIM.Automation/bin/"
  ls -la DWSIM.Automation/bin/ 2>/dev/null || true
else
  echo "Build output found at: $AUTOMATION_OUT"
  OUTPUT_DIR="/output"
  if [ -d "$OUTPUT_DIR" ]; then
    cp -r "${AUTOMATION_OUT}"/* "$OUTPUT_DIR/" 2>/dev/null || true
    echo "Build artifacts copied to $OUTPUT_DIR"
  else
    echo "No /output volume mounted, skipping artifact copy"
  fi

  echo ""
  echo "Output assemblies:"
  ls -la "${AUTOMATION_OUT}"/*.dll 2>/dev/null | head -20 || echo "(no DLLs found)"
fi

# ---------------------------------------------------------------------------
# Phase 5: Smoke test
# ---------------------------------------------------------------------------
echo ""
echo "--- Phase 5: Smoke test ---"
if [ -d "/smoke-test" ] && [ -n "$AUTOMATION_OUT" ]; then
  # Copy native libraries to base output dir for P/Invoke resolution
  ARCH=$(uname -m)
  case "$ARCH" in
    x86_64)  RID="linux-x64" ;;
    aarch64) RID="linux-arm64" ;;
    armv7l)  RID="linux-arm" ;;
    *)       RID="linux-x64" ;;
  esac
  NATIVE_DIR="/src/${AUTOMATION_OUT}/runtimes/${RID}/native"
  if [ -d "$NATIVE_DIR" ]; then
    cp "$NATIVE_DIR"/*.so "/src/${AUTOMATION_OUT}/" 2>/dev/null || true
    echo "  Copied native libs from ${RID}"
  fi
  cd /smoke-test
  dotnet run --project SmokeTest.csproj -- "/src/$AUTOMATION_OUT"
  SMOKE_EXIT=$?
  cd /src
  if [ $SMOKE_EXIT -eq 0 ]; then
    echo "--- Phase 5 complete: Smoke test PASSED ---"
  else
    echo "--- Phase 5 FAILED: Smoke test returned $SMOKE_EXIT ---"
    exit $SMOKE_EXIT
  fi
else
  echo "No smoke-test directory or build output found, skipping"
fi

echo ""
echo "=== DWSIM Headless Build Complete ==="
