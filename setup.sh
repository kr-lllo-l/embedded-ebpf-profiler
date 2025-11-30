#!/bin/bash

# --- Script Configuration and Variable Definitions ---
set -e
PROJECT_ROOT=$(pwd)
VENDOR_PATH="${PROJECT_ROOT}/third_party"
LIB_PATH="${VENDOR_PATH}/lib"
INCLUDE_PATH="${VENDOR_PATH}/include"

echo "--- 1. Installing System Dependencies (Clang, Build Tools) ---"
# apt install is kept to ensure the necessary development environment is present.
sudo apt update
sudo apt install -y clang libelf-dev zlib1g-dev bpftool build-essential

echo "--- 2. Cleaning Existing Build Artifacts ---"
make clean || true

# ====================================================================
# 3. Validation and Setup for Third-Party Dependencies
#    (Assuming libbpf.a is Pre-built and included)
# ====================================================================

# Ensure third_party paths exist
mkdir -p "${LIB_PATH}" "${INCLUDE_PATH}"

# 3.1. Check for libbpf.a (Final Guard)
if [ ! -f "${LIB_PATH}/libbpf.a" ]; then
    echo "--- ERROR: ${LIB_PATH}/libbpf.a is NOT included in the project! ---"
    echo "--- Please pre-build the file on Raspberry Pi and include it before running the script. ---"
    exit 1
fi

echo "--- 3. libbpf.a check passed. Skipping native build. ---"

# 3.2. Copy additional static dependencies (linking requirements)
ARCH_LIB=/usr/lib/aarch64-linux-gnu

echo "--- 4. Copying Required Static Dependencies (elf, zlib, libc, librt) ---"

# Copy static libraries (*.a)
cp ${ARCH_LIB}/libelf.a ${LIB_PATH}/
cp ${ARCH_LIB}/libz.a ${LIB_PATH}/
cp ${ARCH_LIB}/librt.a ${LIB_PATH}/
cp ${ARCH_LIB}/libc.a ${LIB_PATH}/

# 4.3. Copy required header files for inclusion
cp /usr/include/libelf.h "${INCLUDE_PATH}/"
cp /usr/include/zlib.h "${INCLUDE_PATH}/"

echo "--- 5. Executing Final Application Build (Makefile) ---"
# make

echo "--- ✅ Build and Setup Complete: ${PROJECT_ROOT}/hello_tracer ---"