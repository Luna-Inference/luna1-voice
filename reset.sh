#!/bin/bash

# This script attempts to reset the Paroli project environment by removing
# build artifacts, downloaded dependencies, and potentially system-installed components.

# WARNING: This script performs destructive operations. Review carefully and use at your own risk.
# It is recommended to back up any important data before running this script.

LUNA_VOICE_ROOT_DIR=$(pwd)

echo "---------------------------------------------------------------------"
echo "Paroli Project Reset Script"
echo "---------------------------------------------------------------------"
echo "This script will attempt to:"
echo "1. Remove local build directories: build/, piper_phonemize/, paroli_rknn_dependencies/"
echo "2. Remove cloned dependency source directories: drogon/, libopusenc/"
echo "3. Optionally attempt to uninstall system-wide Drogon and libopusenc."
echo "4. Optionally remove system-wide RKNN library and headers."
echo "---------------------------------------------------------------------"
echo "Project root assumed to be: $LUNA_VOICE_ROOT_DIR"
echo "---------------------------------------------------------------------"

read -p "ARE YOU SURE you want to proceed? This cannot be undone. (yes/NO): " CONFIRMATION
if [[ "$CONFIRMATION" != "yes" ]]; then
    echo "Reset cancelled by user."
    exit 0
fi

echo ""
echo "Step 1: Removing local build directories and downloaded content..."

# Local build directory
if [ -d "$LUNA_VOICE_ROOT_DIR/build" ]; then
    echo "Removing $LUNA_VOICE_ROOT_DIR/build..."
    rm -rf "$LUNA_VOICE_ROOT_DIR/build"
else
    echo "$LUNA_VOICE_ROOT_DIR/build not found."
fi

# Piper phonemize directory
if [ -d "$LUNA_VOICE_ROOT_DIR/piper_phonemize" ]; then
    echo "Removing $LUNA_VOICE_ROOT_DIR/piper_phonemize..."
    rm -rf "$LUNA_VOICE_ROOT_DIR/piper_phonemize"
else
    echo "$LUNA_VOICE_ROOT_DIR/piper_phonemize not found."
fi

# Paroli RKNN dependencies directory
if [ -d "$LUNA_VOICE_ROOT_DIR/paroli_rknn_dependencies" ]; then
    echo "Removing $LUNA_VOICE_ROOT_DIR/paroli_rknn_dependencies..."
    rm -rf "$LUNA_VOICE_ROOT_DIR/paroli_rknn_dependencies"
else
    echo "$LUNA_VOICE_ROOT_DIR/external_libs not found."
fi

echo ""
echo "Step 2: Removing cloned dependency source directories and optionally uninstalling..."

# Drogon source directory
if [ -d "$LUNA_VOICE_ROOT_DIR/drogon" ]; then
    read -p "Do you want to attempt to uninstall system-wide Drogon (sudo make uninstall from its build dir)? (yes/NO): " UNINSTALL_DROGON
    if [[ "$UNINSTALL_DROGON" == "yes" ]]; then
        if [ -d "$LUNA_VOICE_ROOT_DIR/drogon/build" ]; then
            echo "Attempting to uninstall Drogon (requires sudo)..."
            cd "$LUNA_VOICE_ROOT_DIR/drogon/build"
            if sudo make uninstall; then
                echo "Drogon uninstall attempted."
            else
                echo "Drogon uninstall command failed or 'uninstall' target not available."
            fi
            cd "$LUNA_VOICE_ROOT_DIR"
        else
            echo "Drogon build directory ($LUNA_VOICE_ROOT_DIR/drogon/build) not found. Cannot attempt uninstall."
        fi
    fi
    echo "Removing $LUNA_VOICE_ROOT_DIR/drogon source directory..."
    rm -rf "$LUNA_VOICE_ROOT_DIR/drogon"
else
    echo "$LUNA_VOICE_ROOT_DIR/drogon source directory not found."
fi

# libopusenc source directory
if [ -d "$LUNA_VOICE_ROOT_DIR/libopusenc" ]; then
    read -p "Do you want to attempt to uninstall system-wide libopusenc (sudo make uninstall)? (yes/NO): " UNINSTALL_OPUSENC
    if [[ "$UNINSTALL_OPUSENC" == "yes" ]]; then
        echo "Attempting to uninstall libopusenc (requires sudo)..."
        cd "$LUNA_VOICE_ROOT_DIR/libopusenc"
        if sudo make uninstall; then
            echo "libopusenc uninstall attempted."
        else
            echo "libopusenc uninstall command failed or 'uninstall' target not available."
        fi
        cd "$LUNA_VOICE_ROOT_DIR"
    fi
    echo "Removing $LUNA_VOICE_ROOT_DIR/libopusenc source directory..."
    rm -rf "$LUNA_VOICE_ROOT_DIR/libopusenc"
else
    echo "$LUNA_VOICE_ROOT_DIR/libopusenc source directory not found."
fi

echo ""
echo "Step 3: Optionally removing system-wide RKNN files..."
read -p "Do you want to remove RKNN library and headers from system paths (/usr/lib, /usr/include)? (yes/NO): " REMOVE_SYS_RKNN
if [[ "$REMOVE_SYS_RKNN" == "yes" ]]; then
    echo "Removing /usr/lib/librknnrt.so (requires sudo)..."
    sudo rm -f /usr/lib/librknnrt.so
    echo "Removing RKNN headers from /usr/include/ (requires sudo)..."
    sudo rm -f /usr/include/rknn_api.h
    sudo rm -f /usr/include/rknn_custom_op.h
    sudo rm -f /usr/include/rknn_matmul_api.h
    echo "System RKNN files removal attempted."
else
    echo "Skipping removal of system RKNN files."
fi

echo ""
echo "---------------------------------------------------------------------"
echo "Paroli Project Reset Script Finished."
echo "---------------------------------------------------------------------"
echo "Remember to manually remove any apt-installed packages if desired."
echo "Example: sudo apt remove xtensor-dev libspdlog-dev ..."
echo "After saving this script, make it executable: chmod +x reset.sh"
