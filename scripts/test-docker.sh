#!/bin/bash
set -euo pipefail

echo "=== Testing Docker Environment ==="
echo "Building Docker image..."
docker build -t dwsim-headless-build .
echo ""
echo "Testing .NET SDK availability..."
docker run --rm dwsim-headless-build dotnet --version
echo ""
echo "Testing DWSIM clone..."
docker run --rm dwsim-headless-build ls -la /src/DWSIM.sln
echo ""
echo "=== Docker environment OK ==="
