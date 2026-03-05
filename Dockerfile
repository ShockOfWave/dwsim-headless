# ============================================================
# Stage 1: Build DWSIM headless
# ============================================================
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build

RUN apt-get update && apt-get install -y \
    libopenblas-dev \
    libgfortran5 \
    coinor-libipopt-dev \
    python3-dev \
    libfontconfig1 \
    fontconfig \
    fonts-dejavu-core \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src

# Copy DWSIM sources from submodule (pinned to specific commit)
COPY dwsim/ /src/

# Copy patches (including tier subdirectories) and scripts
COPY patches/ /patches/

# Make all shell scripts executable
RUN find /patches -name '*.sh' -exec chmod +x {} +

COPY scripts/ /scripts/
RUN chmod +x /scripts/*.sh

COPY smoke-test/ /smoke-test/

# Build everything (patches + compile + smoke test)
RUN /scripts/build.sh

# ============================================================
# Stage 2: Runtime image with Python + DWSIM DLLs
# ============================================================
FROM mcr.microsoft.com/dotnet/runtime:8.0 AS runtime

RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    python3-venv \
    libopenblas0 \
    libgfortran5 \
    libfontconfig1 \
    fontconfig \
    fonts-dejavu-core \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy built DWSIM DLLs from build stage
COPY --from=build /src/DWSIM.Automation/bin/Debug/net8.0/ /app/dwsim/

# Copy Python integration
COPY python/ /app/python/

# Set up Python venv and install pythonnet
RUN python3 -m venv /app/venv && \
    /app/venv/bin/pip install --no-cache-dir -r /app/python/requirements.txt

ENV PATH="/app/venv/bin:$PATH"
ENV PYTHONPATH="/app/python:$PYTHONPATH"
ENV DWSIM_DLL_DIR="/app/dwsim"

CMD ["python3", "-c", "from dwsim_client import DWSIMClient; c = DWSIMClient('/app/dwsim'); print('DWSIM Version:', c.version); print('Compounds:', len(c.available_compounds)); print('Property Packages:', len(c.available_property_packages))"]
