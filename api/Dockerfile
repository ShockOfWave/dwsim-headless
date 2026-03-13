# DWSIM Thermodynamic Engine - Multi-stage Docker build
# Build context: repository root (../)
# Stage 1: Build DWSIM from dwsim submodule
# Stage 2: Build ASP.NET Core API
# Stage 3: Runtime image

ARG DOTNET_SDK_IMAGE=mcr.microsoft.com/dotnet/sdk:8.0
ARG DOTNET_ASPNET_IMAGE=mcr.microsoft.com/dotnet/aspnet:8.0

# ============ Stage 1: Build DWSIM DLLs ============
FROM ${DOTNET_SDK_IMAGE} AS dwsim-build

ARG NUGET_SOURCE_URL=""

RUN apt-get update && apt-get install -y --no-install-recommends \
    libopenblas-dev \
    libgfortran5 \
    libfontconfig1 \
    fonts-dejavu-core \
    python3 \
    && rm -rf /var/lib/apt/lists/*

# Configure NuGet proxy source if provided (for CI environments without direct internet)
RUN if [ -n "$NUGET_SOURCE_URL" ]; then \
      dotnet nuget disable source nuget.org || true; \
      dotnet nuget add source "$NUGET_SOURCE_URL" -n nexus-proxy; \
    fi

COPY dwsim /src
COPY scripts /scripts
COPY smoke-test /smoke-test

RUN mkdir -p /output && chmod +x /scripts/build.sh && /scripts/build.sh

# ============ Stage 2: Build API ============
FROM ${DOTNET_SDK_IMAGE} AS api-build

ARG NUGET_SOURCE_URL=""

# Configure NuGet proxy source if provided
RUN if [ -n "$NUGET_SOURCE_URL" ]; then \
      dotnet nuget disable source nuget.org || true; \
      dotnet nuget add source "$NUGET_SOURCE_URL" -n nexus-proxy; \
    fi

WORKDIR /src
COPY api/src/ .
COPY --from=dwsim-build /output /app/dwsim

RUN dotnet publish DwsimService.csproj -c Release -o /app/api

# ============ Stage 2b: Run tests (optional) ============
FROM api-build AS test

WORKDIR /tests
COPY api/tests/ .

ENV DWSIM_DLL_PATH=/app/dwsim

RUN dotnet restore DwsimService.Tests.csproj
RUN dotnet test DwsimService.Tests.csproj --no-restore -c Release --logger "console;verbosity=normal"

# ============ Stage 3: Runtime ============
FROM ${DOTNET_ASPNET_IMAGE} AS runtime

RUN apt-get update && apt-get install -y --no-install-recommends \
    libopenblas0 \
    libgfortran5 \
    libfontconfig1 \
    fonts-dejavu-core \
    curl \
    && rm -rf /var/lib/apt/lists/*

COPY --from=dwsim-build /output /app/dwsim
COPY --from=api-build /app/api /app/api

# Copy native libs (SkiaSharp, etc.) to the DLL directory for P/Invoke resolution
RUN ARCH=$(uname -m) && \
    case "$ARCH" in x86_64) RID="linux-x64";; aarch64) RID="linux-arm64";; *) RID="linux-x64";; esac && \
    if [ -d "/app/dwsim/runtimes/${RID}/native" ]; then \
        cp /app/dwsim/runtimes/${RID}/native/*.so /app/dwsim/ 2>/dev/null || true; \
    fi

ENV ASPNETCORE_URLS=http://+:8003 \
    DWSIM_DLL_PATH=/app/dwsim \
    DWSIM_POOL_SIZE=4

EXPOSE 8003

HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD curl -f http://localhost:8003/health || exit 1

ENTRYPOINT ["dotnet", "/app/api/DwsimService.dll"]
