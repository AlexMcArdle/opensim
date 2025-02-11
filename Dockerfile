# Set environment variables
ARG COPY_MODULES=true \
    RUN_PREBUILD=true \
    RUN_COMPILE=true \
    RUN_DEPLOY=true \
    CLEANUP_DEPLOY_DIR=true \
    START_HELPER=true \
    START_REGIONS=true

# opensim-modules Stage
FROM ghcr.io/mcardle-systems/opensim-modules AS opensim-modules

# opensim-source Stage
# Use a base image with PowerShell
FROM mcr.microsoft.com/powershell:lts-alpine-3.14 AS opensim-source

# Args for this stage
ARG COPY_MODULES

# Set directories
ENV SOURCE_DIR=/source/opensim \
    MODULES_DIR=/source/opensim-modules

# Create necessary directories
RUN mkdir -p $SOURCE_DIR $MODULES_DIR

COPY . $SOURCE_DIR

COPY --from=opensim-modules /opensim-modules $MODULES_DIR

# Set the working directory
WORKDIR $SOURCE_DIR

# Copy modules if COPY_MODULES is true
RUN if [ "$COPY_MODULES" = "true" ]; then \
        existingModulesDir=$SOURCE_DIR/addon-modules; \
        rm -rf $existingModulesDir/*; \
        cp -r $MODULES_DIR/* $existingModulesDir; \
    fi


# opensim-build Stage
# Copy the artifacts from the Opensim stage
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS opensim-build

# Args for this stage
ARG RUN_PREBUILD \
    RUN_COMPILE \
    RUN_DEPLOY

# Install PowerShell
RUN apt-get update && \
    apt-get install -y wget apt-transport-https software-properties-common libgdiplus && \
    wget -q https://packages.microsoft.com/config/ubuntu/20.04/packages-microsoft-prod.deb && \
    dpkg -i packages-microsoft-prod.deb && \
    apt-get update && \
    apt-get install -y powershell

# Set directories
ENV SOURCE_DIR=/source/opensim \
    HELPER_DIR=/source/GridUtilities/GridServer/bin/Release/net8.0 \
    DEPLOY_DIR=/games/opensim

# Create necessary directories
RUN mkdir -p $SOURCE_DIR $DEPLOY_DIR

COPY --from=opensim-source $SOURCE_DIR $SOURCE_DIR

WORKDIR $SOURCE_DIR

# Run prebuild script if RUN_PREBUILD is true
RUN if [ "$RUN_PREBUILD" = "true" ]; then \
        ./runprebuild.sh; \
    fi

# Run compile script if RUN_COMPILE is true
RUN if [ "$RUN_COMPILE" = "true" ]; then \
        ./compile.sh; \
    fi

# Run deploy steps if RUN_DEPLOY is true
RUN if [ "$RUN_DEPLOY" = "true" ]; then \
        regions="Region1"; \
        binDirFiles=$SOURCE_DIR/bin/*; \
        gridDir=$DEPLOY_DIR/Grid; \
        if [ "$CLEANUP_DEPLOY_DIR" = "true" ]; then \
            rm -rf $DEPLOY_DIR/*; \
        fi; \
        mkdir -p $gridDir; \
        cp -r $binDirFiles $gridDir; \
        for region in $regions; do \
            regionDir=$DEPLOY_DIR/$region; \
            mkdir -p $regionDir; \
            cp -r $binDirFiles $regionDir; \
        done; \
    fi
