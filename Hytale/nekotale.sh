#!/bin/bash
# Hytale Server Launcher - Unified startup script
# Handles: auto-updates, downloads, memory management, AOT cache

set -e

# ============================================
# FUNCTIONS
# ============================================

find_assets_file() {
    local ASSETS_FILE=""
    
    if [ -f "./assets.zip" ]; then
        ASSETS_FILE="./assets.zip"
    elif [ -f "./Assets.zip" ]; then
        ASSETS_FILE="./Assets.zip"
    elif [ -f "./PathToAssets.zip" ]; then
        ASSETS_FILE="./PathToAssets.zip"
    else
        ASSETS_FILE=$(find . -maxdepth 1 -name "*.zip" -type f | head -n 1)
    fi
    
    echo "$ASSETS_FILE"
}

setup_downloader_credentials() {
    # If local credentials exist, use them (downloader auto-refreshes)
    if [ -f ".hytale-downloader-credentials.json" ]; then
        return 0
    fi

    # Otherwise, seed from panel if available
    if [ -n "${HYTALE_DOWNLOADER_CREDENTIALS}" ]; then
        echo "Seeding downloader credentials from panel..."
        echo "${HYTALE_DOWNLOADER_CREDENTIALS}" > .hytale-downloader-credentials.json
        return 0
    fi

    return 1
}

download_server_files() {
    echo "==================================="
    echo "DOWNLOADING HYTALE SERVER"
    echo "==================================="
    echo ""

    # Try to set up credentials from panel first
    if setup_downloader_credentials; then
        echo "Using panel-configured credentials..."
    elif [ -f ".hytale-downloader-credentials.json" ]; then
        echo "Using saved downloader credentials..."
    else
        echo "Downloading server and assets..."
        echo "You will need to authenticate with your Hytale account."
        echo ""
        echo "Please watch for the authentication URL and code below:"
        echo "(This is a ONE-TIME setup - credentials will be saved)"
    fi
    echo ""

    ./hytale-downloader -patchline "${PATCHLINE:-release}" -download-path hytale-download.zip -skip-update-check
    
    echo ""
    echo "Extracting files..."
    unzip -q -o hytale-download.zip
    
    # Check if files are in a Server subdirectory and move them
    if [ -d "Server" ] && [ -f "Server/HytaleServer.jar" ]; then
        echo "Moving files from Server/ directory..."
        mv Server/* . 2>/dev/null || true
        rmdir Server 2>/dev/null || true
    fi
    
    if [ -f "HytaleServer.jar" ]; then
        echo "Download complete!"
        
        # Fix timestamps to current time (AOT cache needs matching timestamps)
        echo "Fixing file timestamps for AOT compatibility..."
        touch HytaleServer.jar
        if [ -f "HytaleServer.aot" ]; then
            touch HytaleServer.aot
        fi
        
        # Save version to file for future comparisons
        VERSION=$(./hytale-downloader -print-version -patchline "${PATCHLINE:-release}" 2>/dev/null || echo "unknown")
        echo "$VERSION" > .version
        echo "Installed version: $VERSION"
    else
        echo "ERROR: HytaleServer.jar not found after download"
        echo "Directory contents:"
        ls -la
        exit 1
    fi
    
    rm hytale-download.zip
    echo ""
}

start_server() {
    echo "==================================="
    echo "STARTING HYTALE SERVER"
    echo "==================================="
    echo ""
    
    # Verify server files exist
    if [ ! -f "./HytaleServer.jar" ]; then
        echo "ERROR: HytaleServer.jar not found!"
        echo "Please reinstall the server."
        exit 1
    fi
    
    # Find assets file
    ASSETS_FILE=$(find_assets_file)
    if [ -z "$ASSETS_FILE" ]; then
        echo "ERROR: No assets file found!"
        echo "Cannot start server without assets."
        exit 1
    fi
    
    # Memory management - reserve space for non-heap memory
    RESERVED_MB=768
    MAX_HEAP=$((${SERVER_MEMORY:-2048} - ${RESERVED_MB}))
    if [ $MAX_HEAP -lt 512 ]; then
        MAX_HEAP=512
    fi
    
    # Check for AOT cache
    AOT_FLAG=""
    if [ -f "HytaleServer.aot" ]; then
        AOT_FLAG="-XX:AOTCache=HytaleServer.aot"
    fi
    
    # Display startup info
    echo "Configuration:"
    echo "  Assets: $ASSETS_FILE"
    echo "  Bind address: 0.0.0.0:${SERVER_PORT:-5520}"
    echo "  Auth mode: ${AUTH_MODE:-authenticated}"
    if [ "${HYTALE_ALLOW_OP}" = "1" ]; then
        echo "  Operators: enabled"
    fi
    if [ "${DISABLE_SENTRY}" = "1" ]; then
        echo "  Sentry: disabled (no crash reporting)"
    fi
    echo ""
    echo "Memory Configuration:"
    echo "  Container limit: ${SERVER_MEMORY:-2048}MB"
    echo "  Reserved (non-heap): ${RESERVED_MB}MB"
    echo "  Java heap (-Xmx): ${MAX_HEAP}MB"
    if [ -n "$AOT_FLAG" ]; then
        echo "  AOT cache: enabled (faster boot)"
    else
        echo "  AOT cache: not found (slower first boot)"
    fi
    echo ""
    
    if [ "${ENABLE_BACKUPS}" = "1" ]; then
        echo "Backups: enabled (every ${BACKUP_FREQUENCY:-30} min, max ${BACKUP_MAX_COUNT:-5})"
        echo ""
    fi

    # Check for pre-configured authentication tokens
    if [ -n "${HYTALE_SERVER_SESSION_TOKEN}" ] && [ -n "${HYTALE_SERVER_IDENTITY_TOKEN}" ]; then
        echo "==================================="
        echo "AUTHENTICATION: PRE-CONFIGURED"
        echo "==================================="
        echo "Session and identity tokens detected."
        echo "Server will authenticate automatically!"
        echo "==================================="
        echo ""
    else
        echo "==================================="
        echo "AUTHENTICATE YOUR SERVER"
        echo "==================================="
        echo "After server starts, run in console:"
        echo "  /auth login device"
        echo ""
        echo "Then follow the URL and code shown."
        echo "Players cannot connect until authenticated!"
        echo "==================================="
        echo ""
    fi
    
    # Build Java command
    JAVA_ARGS="-Xms128M -Xmx${MAX_HEAP}M"
    
    # Container and memory optimizations
    JAVA_ARGS="$JAVA_ARGS -XX:+UseContainerSupport"
    JAVA_ARGS="$JAVA_ARGS -XX:MaxRAMPercentage=75.0"
    JAVA_ARGS="$JAVA_ARGS -XX:MaxMetaspaceSize=256M"
    
    # AOT cache for faster boot (JEP-514)
    if [ -n "$AOT_FLAG" ]; then
        JAVA_ARGS="$JAVA_ARGS $AOT_FLAG"
    fi
    
    # GC optimizations
    JAVA_ARGS="$JAVA_ARGS -XX:+UseG1GC"
    JAVA_ARGS="$JAVA_ARGS -XX:+ParallelRefProcEnabled"
    JAVA_ARGS="$JAVA_ARGS -XX:MaxGCPauseMillis=200"
    JAVA_ARGS="$JAVA_ARGS -XX:+UnlockExperimentalVMOptions"
    JAVA_ARGS="$JAVA_ARGS -XX:+DisableExplicitGC"
    
    # Java module access (required by Hytale)
    JAVA_ARGS="$JAVA_ARGS --enable-native-access=ALL-UNNAMED"
    JAVA_ARGS="$JAVA_ARGS --add-opens java.base/sun.nio.ch=ALL-UNNAMED"
    JAVA_ARGS="$JAVA_ARGS --add-opens java.base/java.io=ALL-UNNAMED"
    
    # Server JAR and assets
    JAVA_ARGS="$JAVA_ARGS -jar HytaleServer.jar"
    JAVA_ARGS="$JAVA_ARGS --assets \"$ASSETS_FILE\""
    JAVA_ARGS="$JAVA_ARGS --bind 0.0.0.0:${SERVER_PORT:-5520}"
    
    # Optional parameters
    if [ -n "${AUTH_MODE}" ]; then
        JAVA_ARGS="$JAVA_ARGS --auth-mode ${AUTH_MODE}"
    fi
    
    if [ "${ENABLE_BACKUPS}" = "1" ]; then
        JAVA_ARGS="$JAVA_ARGS --backup"
        if [ -n "${BACKUP_FREQUENCY}" ]; then
            JAVA_ARGS="$JAVA_ARGS --backup-frequency ${BACKUP_FREQUENCY}"
        fi
        if [ -n "${BACKUP_MAX_COUNT}" ]; then
            JAVA_ARGS="$JAVA_ARGS --backup-max-count ${BACKUP_MAX_COUNT}"
        fi
    fi
    
    if [ "${ACCEPT_EARLY_PLUGINS}" = "1" ]; then
        JAVA_ARGS="$JAVA_ARGS --accept-early-plugins"
    fi
    
    # Disable Sentry crash tracking (useful for plugin development)
    if [ "${DISABLE_SENTRY}" = "1" ]; then
        JAVA_ARGS="$JAVA_ARGS --disable-sentry"
    fi
    
    # Allow operator permissions
    if [ "${HYTALE_ALLOW_OP}" = "1" ]; then
        JAVA_ARGS="$JAVA_ARGS --allow-op"
    fi

    # Pass authentication tokens if configured
    if [ -n "${HYTALE_SERVER_SESSION_TOKEN}" ] && [ -n "${HYTALE_SERVER_IDENTITY_TOKEN}" ]; then
        JAVA_ARGS="$JAVA_ARGS --session-token \"${HYTALE_SERVER_SESSION_TOKEN}\""
        JAVA_ARGS="$JAVA_ARGS --identity-token \"${HYTALE_SERVER_IDENTITY_TOKEN}\""
    fi

    # Start server (exec replaces shell with Java process)
    eval exec java $JAVA_ARGS
}

# ============================================
# MAIN EXECUTION
# ============================================

echo "==================================="
echo "Hytale Server Launcher"
echo "==================================="
echo ""

# Check if downloader exists
if [ ! -f "./hytale-downloader" ]; then
    echo "ERROR: hytale-downloader not found!"
    echo "Please reinstall the server."
    exit 1
fi

# Handle AUTO_UPDATE setting
if [ "${AUTO_UPDATE}" = "1" ]; then
    echo "Auto-update: enabled"
    echo ""
    
    # First time setup - download if needed
    if [ ! -f "./HytaleServer.jar" ]; then
        download_server_files
    else
        # Check for updates
        echo "Checking for updates..."
        
        # Get current installed version
        CURRENT_VERSION="unknown"
        if [ -f ".version" ]; then
            CURRENT_VERSION=$(cat .version)
        fi
        echo "Installed version: ${CURRENT_VERSION}"
        
        # Get latest available version (without downloading)
        echo "Checking latest version..."
        LATEST_VERSION=$(./hytale-downloader -print-version -patchline "${PATCHLINE:-release}" 2>/dev/null || echo "unknown")
        echo "Latest version: ${LATEST_VERSION}"
        echo ""
        
        # Compare versions
        if [ "$CURRENT_VERSION" = "$LATEST_VERSION" ] && [ "$CURRENT_VERSION" != "unknown" ]; then
            echo "✓ Server is up to date! Skipping download."
            echo ""
        else
            if [ "$CURRENT_VERSION" = "unknown" ]; then
                echo "→ No version file found, downloading to verify..."
            else
                echo "→ New version available! Updating..."
            fi
            echo ""
            download_server_files
        fi
    fi
else
    echo "Auto-update: disabled"
    echo ""
    
    # Verify server files exist
    if [ ! -f "./HytaleServer.jar" ]; then
        echo "ERROR: Server files not found!"
        echo "Please enable AUTO_UPDATE=1 for first-time setup."
        exit 1
    fi
fi

# Start the server
start_server
