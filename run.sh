#!/bin/bash

# Script to run the Paroli TTS server

# Get the directory where the script is located (project root)
PROJECT_ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
BUILD_DIR="$PROJECT_ROOT_DIR/build"

# Change to the build directory
cd "$BUILD_DIR"

if [ $? -ne 0 ]; then
    echo "Error: Could not change to build directory: $BUILD_DIR" >&2
    exit 1
fi

if [ ! -f ./paroli-server ]; then
    echo "Error: paroli-server not found in $BUILD_DIR. Please build the project first." >&2
    exit 1
fi

echo "Starting Paroli server from $BUILD_DIR..."

# Paths to models are now relative to the build directory
# Assuming 'streaming-piper' is a subdirectory or symlink within 'build'
# or that paroli-server can find them relative to its own location if not CWD.
sudo ./paroli-server \
    --encoder streaming-piper/ljspeech/encoder.onnx \
    --decoder streaming-piper/ljspeech/decoder.rknn \
    -c streaming-piper/ljspeech/config.json \
    --ip 0.0.0.0 \
    --port 8848

EXIT_CODE=$?
echo "Paroli server stopped with exit code $EXIT_CODE."