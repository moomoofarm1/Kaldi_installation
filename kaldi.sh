#!/bin/bash
# kaldi_install.sh (should not have the folder kaldi in the same directory)
# General pipeline: download->dependency configuration/compiling->dependency checks->download main->install dependency->main configuration/compiling->verify main

# Copyright 2024-2025 Zhuojun Gu
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# =========================================
# Kaldi Installation Script
# =========================================

# This script automates the installation of Kaldi on macOS M-chips systems. 
# Remove the log and exec messages both in the terminal and in the log file.
FILE="logfile.log"
if [ -e "$FILE" ]; then
  rm "$FILE"
  echo "$FILE has been removed."
else
  echo "$FILE does not exist."
fi
exec > >(tee logfile.log) 2>&1

# The rest of your script goes here
echo "This will be logged into logfile.log."

# Exit immediately if a command exits with a non-zero status
#set -euo pipefail

# --------------------------------
# 0. Preliminary Checks
# --------------------------------
if [[ "$(uname)" != "Darwin" ]]; then
  echo "This script is intended for macOS systems only."
  exit 1
fi

# ---------------------------
# 1. Install Dependencies
# ---------------------------

echo "Checking for Homebrew installation..."
if ! command -v brew &> /dev/null; then
  echo "Homebrew not found. Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  echo "Homebrew installed successfully."
else
  echo "Homebrew is already installed."
fi

#echo "Updating Homebrew..."
# brew update || true

# List of required packages. Add or remove as necessary.
#REQUIRED_PACKAGES=(git wget automake autoconf sox libtool subversion python3 gfortran)

#echo "Checking and installing required packages..."
# for pkg in "${REQUIRED_PACKAGES[@]}"; do
#   if ! brew list --formula | grep -q "^${pkg}\$"; then
#     echo "Installing $pkg..."
#     brew cleanup
#     brew install "$pkg"
#   else
#     echo "$pkg is already installed."
#   fi
# done

#echo "All dependencies are now installed."

# ---------------------------
# 2. Clone the Kaldi Repository
# ---------------------------
echo "Cloning the Kaldi repository..."

rm -rf kaldi
if [[ ! -d "kaldi" ]]; then
  echo "Cloning the Kaldi repository..."
  git clone https://github.com/kaldi-asr/kaldi.git
  echo "Kaldi cloned successfully."
else
  echo "Kaldi repository already present. Skipping clone."
fi
cd kaldi


# ---------------------------
# 3. Define the SDK Path
# ---------------------------
# Adjust the SDK path if one is using a different macOS or Xcode version.
# One can list available SDKs with: `ls /Library/Developer/CommandLineTools/SDKs/`
SDK_PATH="/Library/Developer/CommandLineTools/SDKs/MacOSX15.1.sdk"

if [[ ! -d "$SDK_PATH" ]]; then
  echo "Error: SDK path $SDK_PATH does not exist."
  echo "Available SDKs:"
  ls /Library/Developer/CommandLineTools/SDKs/
  exit 1
fi

#CXX_INCLUDE_PATH="$SDK_PATH/usr/include/c++/v1"
CXX_INCLUDE_PATH=" \
  -I$SDK_PATH/usr/include/c++/v1 \
  -I$SDK_PATH/usr/local/include \
  -I$SDK_PATH/usr/include"
echo "Using SDK path: $SDK_PATH"

# ---------------------------
# 4. Export Initial Compiler Flags
# ---------------------------
echo "Exporting initial compiler flags..."

#export CXXFLAGS="-isysroot \"$SDK_PATH\" -I \"$CXX_INCLUDE_PATH\"" # This works for some code, might be the check dependencies.
#export LDFLAGS="-isysroot \"$SDK_PATH\""
export CXXFLAGS="-isysroot $SDK_PATH $CXX_INCLUDE_PATH -stdlib=libc++ -arch arm64"  # clang supports LLVM
export LDFLAGS="-isysroot $SDK_PATH -L$SDK_PATH/usr/lib -stdlib=libc++ -arch arm64"

echo "Compiler flags set."

# ---------------------------
# 5. Set Up and Build Kaldi Tools (Including OpenFst)
# ---------------------------

echo "Building Kaldi tools..."

cd tools

# Set environment variables for zlib (required by OpenFst)
# Export updated compiler flags to include OpenFst's include and lib directories
#OPENFST_DIR="$(pwd)/openfst-1.8.3"

echo "Setting opesfst"

cd openfst-1.8.3
make distclean || true # Clean any previous configurations.
./configure --enable-static --enable-shared CXXFLAGS="$CXXFLAGS" LDFLAGS="$LDFLAGS" #CXXFLAGS="-O2 -std=c++17" #LDFLAGS="-arch arm64"
make -j"$(sysctl -n hw.logicalcpu)" CXXFLAGS="$CXXFLAGS" LDFLAGS="$LDFLAGS"

echo "Checking dependencies for Kaldi tools..."

extras/check_dependencies.sh CXXFLAGS="$CXXFLAGS" LDFLAGS="$LDFLAGS"

echo "Cleaning previous builds..."
make clean

echo "Building Kaldi tools..."
make -j"$(sysctl -n hw.logicalcpu)" CXXFLAGS="$CXXFLAGS" LDFLAGS="$LDFLAGS";

echo "Kaldi tools built successfully."

# ---------------------------
# 6. Update Compiler Flags to Include OpenFst Paths
# ---------------------------
# The OpenFst build usually happens automatically with the tools build, but here we explicitly configure and check it.
echo "Configuring and building OpenFst..."
cd ..

# Define OpenFst version and download URL
OPENFST_VERSION="openfst-1.8.3"
OPENFST_TARBALL="${OPENFST_VERSION}.tar.gz"
OPENFST_DOWNLOAD_URL="http://www.openfst.org/twiki/pub/FST/FstDownload/${OPENFST_TARBALL}"

# Define directories
TOOLS_DIR="$(pwd)/tools"  
OPENFST_DIR="${TOOLS_DIR}/openfst"

# Create tools and OpenFst directories
mkdir -p "${TOOLS_DIR}"
mkdir -p "${OPENFST_DIR}"

# Change to tools directory
cd "${TOOLS_DIR}"

# Download OpenFst if not already downloaded
if [[ ! -f "${OPENFST_TARBALL}" ]]; then
    echo "Downloading OpenFst ${OPENFST_VERSION}..."
    wget -O "${OPENFST_TARBALL}" "${OPENFST_DOWNLOAD_URL}"
else
    echo "OpenFst tarball already exists. Skipping download."
fi

# Extract OpenFst
if [[ ! -f "${OPENFST_DIR}/configure" ]]; then
    echo "Extracting OpenFst..."
    tar -xzf "${OPENFST_TARBALL}" -C "${OPENFST_DIR}" --strip-components=1
else
    echo "OpenFst already extracted. Skipping extraction."
fi

# Change to OpenFst directory
cd "${OPENFST_DIR}"

# Ensure the configure script is executable
if [[ ! -x "./configure" ]]; then
    echo "./configure script not found or not executable in ${OPENFST_DIR}"
    exit 1
fi

# Configure with prefix to the same directory and enable shared libraries
./configure --prefix="${OPENFST_DIR}" --enable-shared

# Determine the number of CPU cores
if [[ "$OSTYPE" == "darwin"* ]]; then
    NUM_CORES=$(sysctl -n hw.logicalcpu)
else
    NUM_CORES=$(nproc)
fi

# Compile OpenFst
echo "Compiling OpenFst with ${NUM_CORES} cores..."
make -j"${NUM_CORES}" CXXFLAGS="$CXXFLAGS" LDFLAGS="$LDFLAGS"

# Install OpenFst
make install

# Verify fst.h
if [[ ! -f "${OPENFST_DIR}/include/fst/fst.h" ]]; then
    echo "Error: fst.h not found. OpenFst may not have built correctly."
    exit 1
fi

# Verify the library file (.so for Linux, .dylib for macOS)
if [[ "$OSTYPE" == "darwin"* ]]; then
    LIB_FILE="${OPENFST_DIR}/lib/libfst.dylib"
else
    LIB_FILE="${OPENFST_DIR}/lib/libfst.so"
fi

if [[ ! -f "${LIB_FILE}" ]]; then
    echo "Error: OpenFst library not found at ${LIB_FILE}. Build may have failed."
    exit 1
fi

echo "OpenFst built and installed successfully in ${OPENFST_DIR}."

# ---------------------------
# 7. Set Up and Build Kaldi Source
# ---------------------------
echo "Setting up Kaldi source..."

pwd
cd ../../src # from FST to SRC
pwd

# Clean any previous builds to avoid conflicts
echo "Cleaning previous builds if any."
make clean || true
make -j clean depend || true
make distclean || true


# Run the configuration script with shared libraries enabled
echo "Configuring Kaldi with shared libraries..."
if ! ./configure --shared; then
    echo "Error: Configuration failed. Check the output above for details."
    exit 1
fi

# Clean any previous builds to avoid conflicts
echo "Cleaning previous builds if any."
make clean || true
make -j clean depend || true
make distclean || true

echo "Configuration completed successfully."

# Install dependencies
echo "Installing dependencies..."
make depend -j"$(sysctl -n hw.logicalcpu)" CXXFLAGS="$CXXFLAGS" LDFLAGS="$LDFLAGS"

# Clean any previous builds to avoid conflicts
echo "Cleaning previous builds (if any)..."
make clean || true
make -j clean depend || true
make distclean || true

# Export Kaldi root path and add binaries to PATH
cd ../..
export KALDI_ROOT=$PWD/kaldi
[ -f $KALDI_ROOT/tools/env.sh ] && . $KALDI_ROOT/tools/env.sh
export PATH=$KALDI_ROOT/utils/:$KALDI_ROOT/src/bin/:$KALDI_ROOT/src/fstbin/:$KALDI_ROOT/src/gmmbin/:$KALDI_ROOT/src/featbin/:$KALDI_ROOT/src/lm/:$KALDI_ROOT/src/sgmmbin/:$KALDI_ROOT/src/sgmm2bin/:$KALDI_ROOT/src/fgmmbin/:$KALDI_ROOT/src/latbin/:$KALDI_ROOT/src/nnet2bin/:$KALDI_ROOT/src/nnet3bin/:$KALDI_ROOT/src/online2bin/:$KALDI_ROOT/src/rnnlmbin/:$KALDI_ROOT/src/online2bin/:$PATH
cd $KALDI_ROOT/src

# Build Kaldi using all available logical CPUs
NUM_CPUS=$(sysctl -n hw.logicalcpu)
echo "Building Kaldi using $NUM_CPUS parallel jobs (this may take a while)..."
if ! make -j"$NUM_CPUS" V=1; then
    echo "Error: Kaldi build failed. Check the build output above for details."
    exit 1
fi

# Verify build success
if [ $? -eq 0 ]; then
    echo "Kaldi built successfully."
else
    echo "Error: Kaldi build failed. Check the build output above for details."
    exit 1
fi

# ---------------------------
# 8. Final Environment Setup (Optional)
# ---------------------------
# Optionally, add Kaldi's binaries to your PATH for easier access.

echo "Adding Kaldi binaries to PATH. To make this change permanent, add the following lines to your shell profile (e.g., ~/.bashrc or ~/.zshrc):"
echo ""
echo 'export KALDI_ROOT= $KALDI_ROOT'
echo 'export PATH=$KALDI_ROOT/tools/openfst/bin:$PATH'
echo 'export PATH=$KALDI_ROOT/src/bin:$PATH'
echo ""
echo "You can execute the following commands to add them to your current session (temporary):"
echo ""
echo 'export KALDI_ROOT= $KALDI_ROOT'
echo "export PATH=\$KALDI_ROOT/tools/openfst/bin:\$PATH"
echo "export PATH=\$KALDI_ROOT/src/bin:\$PATH"
echo ""

# ---------------------------
# 9. Verification
# ---------------------------
echo "Verifying Kaldi installation..."

# Check if kaldi.mk exists
if [ -f "kaldi.mk" ]; then
  echo "Kaldi installation completed successfully."
else
  echo "Error: kaldi.mk not found. Installation may have failed."
  exit 1
fi

echo "Kaldi installation script completed."

# ---------------------------
# 10. Reset SDK_Path
# ---------------------------
echo "Do you want to reset SDK_PATH to the default after the installation? (y/n)"
read response
if [ "$response" = "y" ]; then
  export SDK_PATH="/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk"
fi

# =========================================
# End of Script
# =========================================
