#!/bin/bash
set -e # Exit immediately if a command exits with a non-zero status.

echo "Starting Paroli Installation Script..."

# Ensure the script is run with sudo privileges for apt and make install commands later
if [ "$(id -u)" -ne 0 ]; then
  echo "This script requires superuser privileges for some operations (apt, make install)."
  echo "Please run with sudo: sudo ./install_paroli.sh"
  # exit 1 # Commented out to allow running parts without sudo if user prefers, though some steps will fail.
fi

LUNA_VOICE_ROOT_DIR=$(pwd)
echo "Assuming Paroli project root is: $LUNA_VOICE_ROOT_DIR"

echo "Updating package lists..."
sudo apt update

echo "Installing system dependencies (xtensor, spdlog, fmt, soxr, jsoncpp, uuid, g++, opus, espeak-ng, ogg)..."
# libspdlog-dev is listed twice in README, apt should handle it.
sudo apt install -y xtensor-dev libspdlog-dev libspdlog-dev libfmt-dev libsoxr-dev libjsoncpp-dev uuid-dev g++ libopus-dev libespeak-ng-dev libogg-dev

echo "Installing piper-phonemize..."
PIPER_PHONEMIZE_TAR="piper-phonemize_linux_aarch64.tar.gz"
PIPER_PHONEMIZE_EXTRACTED_DIR="$LUNA_VOICE_ROOT_DIR/piper_phonemize"
if [ ! -d "$PIPER_PHONEMIZE_EXTRACTED_DIR" ]; then
    echo "Downloading piper-phonemize..."
    wget https://github.com/rhasspy/piper-phonemize/releases/download/2023.11.14-4/$PIPER_PHONEMIZE_TAR
    echo "Extracting piper-phonemize..."
    tar -xvzf $PIPER_PHONEMIZE_TAR
    echo "Removing $PIPER_PHONEMIZE_TAR..."
    rm -f $PIPER_PHONEMIZE_TAR
    # Assuming tar extracts to a folder named 'piper_phonemize' or similar based on common tarball structures for this project
    # If the tarball extracts with a different top-level folder name, adjust $PIPER_PHONEMIZE_EXTRACTED_DIR or rename the folder.
    # For example, if it extracts to 'piper-phonemize_linux_aarch64', you might want to: mv piper-phonemize_linux_aarch64 piper_phonemize
else
    echo "piper_phonemize directory already exists at $PIPER_PHONEMIZE_EXTRACTED_DIR. Skipping download and extraction."
fi

echo "Installing Drogon framework..."
if [ ! -d "$LUNA_VOICE_ROOT_DIR/drogon" ]; then
    git clone https://github.com/drogonframework/drogon
    cd "$LUNA_VOICE_ROOT_DIR/drogon"
    git submodule update --init
    mkdir -p build && cd build
    cmake ..
    make -j$(nproc)
    echo "Installing Drogon (requires sudo)..."
    sudo make install
    cd "$LUNA_VOICE_ROOT_DIR" # Go back to luna1-voice root
else
    echo "Drogon directory already exists. Skipping clone and build. You might need to update or build it manually if needed."
    cd "$LUNA_VOICE_ROOT_DIR" 
fi

echo "Installing libopusenc from source (for Ubuntu 22.04 compatibility)..."
if [ ! -d "$LUNA_VOICE_ROOT_DIR/libopusenc" ]; then
    git clone https://gitlab.xiph.org/xiph/libopusenc.git
    cd "$LUNA_VOICE_ROOT_DIR/libopusenc"
    sudo apt install -y autoconf libtool opus-tools
    ./autogen.sh
    ./configure
    make -j$(nproc)
    echo "Installing libopusenc (requires sudo)..."
    sudo make install
    cd "$LUNA_VOICE_ROOT_DIR" # Go back to luna1-voice root
else
    echo "libopusenc directory already exists. Skipping clone and build. You might need to update or build it manually if needed."
    cd "$LUNA_VOICE_ROOT_DIR"
fi

echo "Setting up local RKNN directory in project folder..."
LOCAL_RKNN_DIR="$LUNA_VOICE_ROOT_DIR/paroli_rknn_dependencies"
LOCAL_RKNN_LIB_DIR="$LOCAL_RKNN_DIR/lib"
LOCAL_RKNN_INCLUDE_DIR="$LOCAL_RKNN_DIR/include"

echo "RKNN files will be placed in: $LOCAL_RKNN_DIR"
mkdir -p "$LOCAL_RKNN_LIB_DIR"
mkdir -p "$LOCAL_RKNN_INCLUDE_DIR"

echo "Downloading RKNN libraries to $LOCAL_RKNN_DIR..."
RKNN_BASE_URL="https://raw.githubusercontent.com/rockchip-linux/rknn-toolkit2/refs/heads/master/rknpu2/runtime/Linux/librknn_api"

echo "Downloading librknnrt.so to $LOCAL_RKNN_LIB_DIR..."
wget -O "$LOCAL_RKNN_LIB_DIR/librknnrt.so" "${RKNN_BASE_URL}/aarch64/librknnrt.so"

echo "Downloading RKNN headers to $LOCAL_RKNN_INCLUDE_DIR..."
wget -O "$LOCAL_RKNN_INCLUDE_DIR/rknn_api.h" "${RKNN_BASE_URL}/include/rknn_api.h"
wget -O "$LOCAL_RKNN_INCLUDE_DIR/rknn_custom_op.h" "${RKNN_BASE_URL}/include/rknn_custom_op.h"
wget -O "$LOCAL_RKNN_INCLUDE_DIR/rknn_matmul_api.h" "${RKNN_BASE_URL}/include/rknn_matmul_api.h"

echo "Preparing to build Paroli..."
mkdir -p "$LUNA_VOICE_ROOT_DIR/build"
cd "$LUNA_VOICE_ROOT_DIR/build"

# IMPORTANT: Set this to your ONNXRuntime installation directory!
# Example: ONNXRUNTIME_DIR="/opt/onnxruntime-linux-aarch64-1.15.1"
# The README specified '~/piper_phonemize' which is unlikely to be correct for ONNXRuntime.
ONNXRUNTIME_DIR="$LUNA_VOICE_ROOT_DIR/piper_phonemize"

if [ ! -d "$ONNXRUNTIME_DIR/lib" ] || [ ! -d "$ONNXRUNTIME_DIR/include" ]; then # Basic check for lib/include subdirs
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    echo "ERROR: ONNXRuntime directory not found or incomplete at $ONNXRUNTIME_DIR" 
    echo "Please set the ONNXRUNTIME_DIR variable in this script to your ONNXRuntime path."
    echo "You may need to download ONNXRuntime from https://github.com/microsoft/onnxruntime/releases"
    echo "Ensure it contains 'lib' and 'include' subdirectories."
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    # exit 1 # Allow script to continue so CMake can give its specific error
fi

if [ ! -d "$PIPER_PHONEMIZE_EXTRACTED_DIR/include/piper-phonemize" ]; then
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    echo "ERROR: piper-phonemize include directory not found at $PIPER_PHONEMIZE_EXTRACTED_DIR/include/piper-phonemize"
    echo "Please ensure piper-phonemize was downloaded and extracted correctly into $PIPER_PHONEMIZE_EXTRACTED_DIR"
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    # exit 1
fi

echo "Running CMake for Paroli..."
echo "Using ONNXRuntime from: $ONNXRUNTIME_DIR"
echo "Using Piper Phonemize from: $PIPER_PHONEMIZE_EXTRACTED_DIR"

# IMPORTANT: Paroli's main CMakeLists.txt will need to be updated to find these local RKNN libraries.
# This might involve setting CMAKE_PREFIX_PATH to include $LOCAL_RKNN_DIR, e.g., in the cmake command below:
# -DCMAKE_PREFIX_PATH="$LOCAL_RKNN_DIR" 
# Or by modifying find_library and find_path calls for RKNN within Paroli's CMakeLists.txt.
# Also, RPATH might need adjustment for the executables to find librknnrt.so in $LOCAL_RKNN_LIB_DIR at runtime.

# Pass the RKNN root (now in parent's subdir or local rknn/) to CMake
cmake .. \
    -DORT_ROOT="$ONNXRUNTIME_DIR" \
    -DRKNN_ROOT_DIR="$LOCAL_RKNN_DIR" \
    -DPIPER_PHONEMIZE_ROOT="$PIPER_PHONEMIZE_EXTRACTED_DIR" \
    -DCMAKE_BUILD_TYPE=Release \
    -DUSE_RKNN=ON

echo "Building Paroli..."
make -j$(nproc)

echo "Copying espeak-ng-data..."
cp -r "$PIPER_PHONEMIZE_EXTRACTED_DIR/share/espeak-ng-data" .

echo "Downloading RKNN voice models..."
if [ ! -d "streaming-piper" ]; then
    git clone https://huggingface.co/marty1885/streaming-piper
else
    echo "streaming-piper directory already exists in build folder. Skipping clone."
fi

cd "$LUNA_VOICE_ROOT_DIR"
echo "---------------------------------------------------------------------"
echo "Paroli Installation and Build Script Finished."
echo "---------------------------------------------------------------------"
echo "IMPORTANT: Review any error messages above."
echo "IF ONNXRUNTIME_DIR was not set correctly, CMake/build likely failed."
echo "  Please edit this script ('install_paroli.sh') to set the correct ONNXRUNTIME_DIR path."

echo "
To run Paroli server (example from build directory):
  cd "$LUNA_VOICE_ROOT_DIR/build"
  sudo ./paroli-server --encoder streaming-piper/ljspeech/encoder.onnx --decoder streaming-piper/ljspeech/decoder.rknn -c streaming-piper/ljspeech/config.json --ip 0.0.0.0 --port 8848
"
echo "Make sure the script is executable: chmod +x install_paroli.sh"
echo "Then run with: sudo ./install_paroli.sh (if not already run with sudo)"
