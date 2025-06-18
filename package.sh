#!/bin/bash

set -e # Exit immediately if a command exits with a non-zero status.

PROJECT_ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
RELEASE_NAME="paroli-tts-$(date +%Y%m%d).zip"
STAGING_DIR_NAME="paroli-release-staging" # Just the name, not the full path yet
STAGING_DIR="$PROJECT_ROOT_DIR/$STAGING_DIR_NAME"

echo "Starting Paroli packaging process..."
echo "Project root: $PROJECT_ROOT_DIR"
echo "Release file will be: $PROJECT_ROOT_DIR/$RELEASE_NAME"
echo "Staging directory: $STAGING_DIR"

# Clean up previous attempts
if [ -d "$STAGING_DIR" ]; then
    echo "Removing old staging directory: $STAGING_DIR"
    rm -rf "$STAGING_DIR"
fi
if [ -f "$PROJECT_ROOT_DIR/$RELEASE_NAME" ]; then
    echo "Removing old release file: $PROJECT_ROOT_DIR/$RELEASE_NAME"
    rm -f "$PROJECT_ROOT_DIR/$RELEASE_NAME"
fi

mkdir -p "$STAGING_DIR"
echo "Created staging directory."

# --- Copy source code and project files ---
echo "Copying source code and project files..."

# Top-level files and essential scripts
cp "$PROJECT_ROOT_DIR/CMakeLists.txt" "$STAGING_DIR/"
cp "$PROJECT_ROOT_DIR/install_paroli.sh" "$STAGING_DIR/"
cp "$PROJECT_ROOT_DIR/reset.sh" "$STAGING_DIR/"
cp "$PROJECT_ROOT_DIR/run.sh" "$STAGING_DIR/"
cp "$PROJECT_ROOT_DIR/README.md" "$STAGING_DIR/"

# Source directories
if [ -d "$PROJECT_ROOT_DIR/src" ]; then
    cp -r "$PROJECT_ROOT_DIR/src" "$STAGING_DIR/"
else
    echo "Warning: 'src' directory not found at $PROJECT_ROOT_DIR/src."
fi

if [ -d "$PROJECT_ROOT_DIR/include" ]; then
    cp -r "$PROJECT_ROOT_DIR/include" "$STAGING_DIR/"
else
    echo "Warning: 'include' directory not found at $PROJECT_ROOT_DIR/include."
fi

# paroli-server subdirectory (contains its own sources, CMakeLists.txt, docs)
if [ -d "$PROJECT_ROOT_DIR/paroli-server" ]; then
    cp -r "$PROJECT_ROOT_DIR/paroli-server" "$STAGING_DIR/"
else
    echo "Warning: 'paroli-server' directory not found at $PROJECT_ROOT_DIR/paroli-server. This might be critical if it contains main sources."
fi

# --- Copy runtime dependencies ---
echo "Copying runtime dependencies..."
if [ -d "$PROJECT_ROOT_DIR/piper_phonemize" ]; then
    cp -r "$PROJECT_ROOT_DIR/piper_phonemize" "$STAGING_DIR/"
else
    echo "Warning: 'piper_phonemize' directory not found at $PROJECT_ROOT_DIR/piper_phonemize. This is a runtime dependency."
fi

if [ -d "$PROJECT_ROOT_DIR/paroli_rknn_dependencies" ]; then
    cp -r "$PROJECT_ROOT_DIR/paroli_rknn_dependencies" "$STAGING_DIR/"
else
    echo "Warning: 'paroli_rknn_dependencies' directory not found at $PROJECT_ROOT_DIR/paroli_rknn_dependencies. Needed for RKNN support."
fi

# --- Copy built artifacts and models from the build directory ---
BUILD_DIR_SOURCE="$PROJECT_ROOT_DIR/build"
STAGING_BUILD_DIR="$STAGING_DIR/build" # Recreate a 'build' dir in staging for consistency
mkdir -p "$STAGING_BUILD_DIR"

echo "Copying built artifacts and models from $BUILD_DIR_SOURCE..."

# Executable
if [ -f "$BUILD_DIR_SOURCE/paroli-server" ]; then
    cp "$BUILD_DIR_SOURCE/paroli-server" "$STAGING_BUILD_DIR/"
else
    echo "Error: Main executable '$BUILD_DIR_SOURCE/paroli-server' not found. Please build the project first."
    echo "Cleaning up staging directory due to error."
    rm -rf "$STAGING_DIR" 
    exit 1
fi

# Models (streaming-piper)
if [ -d "$BUILD_DIR_SOURCE/streaming-piper" ]; then
    cp -r "$BUILD_DIR_SOURCE/streaming-piper" "$STAGING_BUILD_DIR/"
else
    echo "Warning: Models directory '$BUILD_DIR_SOURCE/streaming-piper' not found."
fi

# espeak-ng-data
if [ -d "$BUILD_DIR_SOURCE/espeak-ng-data" ]; then
    cp -r "$BUILD_DIR_SOURCE/espeak-ng-data" "$STAGING_BUILD_DIR/"
else
    echo "Warning: '$BUILD_DIR_SOURCE/espeak-ng-data' not found."
fi


# --- Create the zip file ---
echo "Creating zip file: $RELEASE_NAME..."
# Change to project root to ensure paths in zip are relative to STAGING_DIR_NAME
cd "$PROJECT_ROOT_DIR" 
zip -r "$RELEASE_NAME" "$STAGING_DIR_NAME"

# --- Clean up ---
echo "Cleaning up staging directory..."
rm -rf "$STAGING_DIR"

echo ""
echo "Packaging complete!"
echo "Release file: $PROJECT_ROOT_DIR/$RELEASE_NAME"
echo "Done."