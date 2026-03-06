#!/bin/bash
# install.sh - Install DWSIM headless on bare Linux (Ubuntu/Debian)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
INSTALL_DIR="${1:-/opt/dwsim-headless}"

echo "=== DWSIM Headless Installation ==="
echo "Source: $PROJECT_ROOT"
echo "Install directory: $INSTALL_DIR"
echo ""

# --- Check prerequisites ---

command -v dotnet >/dev/null 2>&1 || {
  echo "ERROR: .NET SDK 8.0 is required."
  echo "Install: https://learn.microsoft.com/dotnet/core/install/linux"
  exit 1
}

DOTNET_VERSION=$(dotnet --version)
echo ".NET SDK version: $DOTNET_VERSION"

if [ ! -d "$PROJECT_ROOT/dwsim/DWSIM.Automation" ]; then
  echo "ERROR: DWSIM submodule not found. Run:"
  echo "  git submodule update --init"
  exit 1
fi

# --- Install system dependencies ---

echo ""
echo "--- Installing system dependencies ---"
if command -v apt-get >/dev/null 2>&1; then
  sudo apt-get update
  sudo apt-get install -y \
    libopenblas-dev \
    libgfortran5 \
    coinor-libipopt-dev \
    python3-dev \
    python3-pip \
    python3-venv \
    libfontconfig1 \
    fontconfig \
    fonts-dejavu-core
elif command -v dnf >/dev/null 2>&1; then
  sudo dnf install -y \
    openblas-devel \
    gcc-gfortran \
    python3-devel \
    python3-pip \
    fontconfig \
    dejavu-sans-fonts
else
  echo "WARNING: Unsupported package manager. Install dependencies manually:"
  echo "  libopenblas, libgfortran5, libfontconfig1, python3, python3-venv"
fi

# --- Build DWSIM ---

echo ""
echo "--- Building DWSIM headless ---"
cd "$PROJECT_ROOT/dwsim"

dotnet restore DWSIM.Headless.slnf --verbosity minimal
dotnet build DWSIM.Headless.slnf \
  --no-restore \
  --verbosity minimal \
  -p:DefineConstants=HEADLESS

# Find output directory
AUTOMATION_OUT=""
for cfg in Debug Release; do
  if [ -d "DWSIM.Automation/bin/${cfg}/net8.0" ]; then
    AUTOMATION_OUT="DWSIM.Automation/bin/${cfg}/net8.0"
    break
  fi
done

if [ -z "$AUTOMATION_OUT" ]; then
  echo "ERROR: Build output not found"
  exit 1
fi

echo "Build output: $AUTOMATION_OUT"

# Copy native libraries for current architecture
ARCH=$(uname -m)
case "$ARCH" in
  x86_64)  RID="linux-x64" ;;
  aarch64) RID="linux-arm64" ;;
  *)       RID="linux-x64" ;;
esac

NATIVE_DIR="${AUTOMATION_OUT}/runtimes/${RID}/native"
if [ -d "$NATIVE_DIR" ]; then
  cp "$NATIVE_DIR"/*.so "${AUTOMATION_OUT}/" 2>/dev/null || true
  echo "Copied native libs for ${RID}"
fi

# --- Install ---

echo ""
echo "--- Installing to $INSTALL_DIR ---"
sudo mkdir -p "$INSTALL_DIR/dwsim"
sudo cp -r "${AUTOMATION_OUT}"/* "$INSTALL_DIR/dwsim/"
sudo cp -r "$PROJECT_ROOT/python" "$INSTALL_DIR/python/"

# --- Python environment ---

echo ""
echo "--- Setting up Python environment ---"
python3 -m venv "$INSTALL_DIR/venv"
"$INSTALL_DIR/venv/bin/pip" install --no-cache-dir -r "$INSTALL_DIR/python/requirements.txt"

echo ""
echo "=== Installation complete ==="
echo ""
echo "Usage:"
echo "  source $INSTALL_DIR/venv/bin/activate"
echo "  export PYTHONPATH=$INSTALL_DIR/python:\$PYTHONPATH"
echo "  python3 -c \"from dwsim_client import DWSIMClient; c = DWSIMClient('$INSTALL_DIR/dwsim'); print(c.version)\""
