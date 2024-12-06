#!/bin/bash
# kaldi_install.sh

# =========================================
# Kaldi Installation Script
# =========================================

# Exit immediately if a command exits with a non-zero status
#set -e

# ---------------------------
# 1. Install Dependencies
# ---------------------------
echo "Installing dependencies via Homebrew..."

# Check if Homebrew is installed; install if not
if ! command -v brew &> /dev/null; then
  echo "Homebrew not found. Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
  echo "Homebrew is already installed."
fi

# Update Homebrew
# brew update

# Install required packages
# brew uninstall git wget automake autoconf sox libtool subversion gfortran
#brew cleanup
#brew reinstall git wget automake autoconf sox libtool subversion python3 gfortran

echo "Dependencies installed successfully."

# ---------------------------
# 2. Clone the Kaldi Repository
# ---------------------------
#echo "Cloning the Kaldi repository..."

# Clone Kaldi if it doesn't already exist
if [ ! -d "kaldi" ]; then
  mkdir kaldi
  git clone https://github.com/kaldi-asr/kaldi.git
else
  echo "Kaldi repository already cloned. Skipping clone step."
fi

cd kaldi

# ---------------------------
# 3. Define the SDK Path
# ---------------------------
# Adjust the SDK path if you're using a different macOS or Xcode version.

#SDK_PATH=${SDK_PATH:-/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk}
SDK_PATH="/Library/Developer/CommandLineTools/SDKs/MacOSX15.1.sdk"
CXX_INCLUDE_PATH="$SDK_PATH/usr/include/c++/v1"

# Verify that the SDK path exists
# if [ ! -d "$SDK_PATH" ]; then
#   echo "Error: SDK path $SDK_PATH does not exist."
#   echo "Available SDKs:"
#   ls /Library/Developer/CommandLineTools/SDKs/
#   echo "Please update the SDK_PATH variable in the script accordingly."
#   exit 1
# fi

echo "SDK path set to $SDK_PATH temporarily."

# ---------------------------
# 4. Export Initial Compiler Flags
# ---------------------------
echo "Exporting initial compiler flags..."

#export CXXFLAGS="-isysroot \"$SDK_PATH\" -I \"$CXX_INCLUDE_PATH\"" # This works for some code, might be the check dependencies.
#export LDFLAGS="-isysroot \"$SDK_PATH\""
export CXXFLAGS="-isysroot \"$SDK_PATH\" -I \"$CXX_INCLUDE_PATH\" -stdlib=libc++" # LLVM
export LDFLAGS="-isysroot \"$SDK_PATH\" -L \"$SDK_PATH/usr/lib\""

echo "Compiler flags exported."

# ---------------------------
# 5. Set Up and Build Kaldi Tools (Including OpenFst)
# ---------------------------
echo "Setting up Kaldi tools..."

cd tools

# Check for necessary dependencies
# Designate the postion of dependency zlib
export CPLUS_INCLUDE_PATH=$(brew --prefix zlib)/include
export LIBRARY_PATH=$(brew --prefix zlib)/lib
export PKG_CONFIG_PATH=$(brew --prefix zlib)/lib/pkgconfig


# Check for necessary dependencies
echo "Checking dependencies for Kaldi tools..."
extras/check_dependencies.sh

# Clean and rebuild
make clean

# Build the tools, including OpenFst

echo "Building Kaldi tools (this may take a while)..."
make -j$(sysctl -n hw.logicalcpu)
# make -j$(sysctl -n hw.logicalcpu) > build_log.txt 2>&1 # provide detailed error logs

echo "Kaldi tools built successfully."


# TODO: 111111!!!!!
# ---------------------------
# 6. Update Compiler Flags to Include OpenFst Paths
# ---------------------------
echo "Updating compiler flags to include OpenFst paths..."


cd ./kaldi/tools/openfst-1.8.3
./configure --prefix=$(pwd) --enable-shared
make
make install
ls $(pwd)/include/fst/fst.h
ls $(pwd)/lib/libfst.*

# Determine the absolute path to the openfst directory
OPENFST_DIR="$(pwd)/openfst"

# Verify that OpenFst was built successfully
if [ ! -d "$OPENFST_DIR" ]; then
  echo "Error: OpenFst directory $OPENFST_DIR does not exist."
  #exit 1
fi

# Export updated compiler flags to include OpenFst's include and lib directories
export CXXFLAGS="$CXXFLAGS -I$OPENFST_DIR/include"
export LDFLAGS="$LDFLAGS -L$OPENFST_DIR/lib"

# Optional: If using pkg-config, set PKG_CONFIG_PATH
export PKG_CONFIG_PATH="$OPENFST_DIR/lib/pkgconfig:$PKG_CONFIG_PATH"

echo "Compiler flags updated with OpenFst paths."

exit

# ---------------------------
# 7. Set Up and Build Kaldi Source
# ---------------------------
echo "Setting up Kaldi source..."

cd ../src

# Clean any previous builds to avoid conflicts
echo "Cleaning previous builds (if any)..."
make clean || true

# Run the configuration script with shared libraries enabled
echo "Configuring Kaldi..."
./configure --shared

# Build Kaldi using all available logical CPUs
echo "Building Kaldi (this may take a while)..."
make -j$(sysctl -n hw.logicalcpu)

echo "Kaldi built successfully."

# ---------------------------
# 8. Final Environment Setup (Optional)
# ---------------------------
# Optionally, add Kaldi's binaries to your PATH for easier access.

echo "Adding Kaldi binaries to PATH. To make this change permanent, add the following lines to your shell profile (e.g., ~/.bashrc or ~/.zshrc):"
echo ""
echo 'export KALDI_ROOT='$(pwd)/..
echo 'export PATH=$KALDI_ROOT/tools/openfst/bin:$PATH'
echo 'export PATH=$KALDI_ROOT/src/bin:$PATH'
echo ""
echo "You can execute the following commands to add them to your current session (temporary):"
echo ""
echo "export KALDI_ROOT=$(pwd)/.."
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
  #exit 1
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
