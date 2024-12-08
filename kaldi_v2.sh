#!/bin/bash
# Simplified Kaldi Installation Script for macOS M-chips

# Exit on error
set -e

# Check if running on macOS
if [[ "$(uname)" != "Darwin" ]]; then
  echo "This script is for macOS only."
  exit 1
fi

# Install Homebrew if not present
if ! command -v brew &> /dev/null; then
  echo "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Clone Kaldi repository
rm -rf kaldi
if [[ ! -d "kaldi" ]]; then
  git clone https://github.com/kaldi-asr/kaldi.git
fi
cd kaldi

# Set SDK Path for macOS
SDK_PATH="/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk"
if [[ ! -d "$SDK_PATH" ]]; then
  echo "SDK path $SDK_PATH not found. Exiting."
  exit 1
fi

# Export compiler flags
CXXFLAGS="-isysroot $SDK_PATH -I$SDK_PATH/usr/include -I$SDK_PATH/usr/include/c++/v1 -stdlib=libc++ -arch arm64"
LDFLAGS="-isysroot $SDK_PATH -L$SDK_PATH/usr/lib -stdlib=libc++ -arch arm64"
export CXXFLAGS
export LDFLAGS

# Build Kaldi tools
cd tools
make clean
extras/check_dependencies.sh
make -j"$(sysctl -n hw.logicalcpu)"

# Build Kaldi source
cd ../src
make clean
./configure --shared CXXFLAGS="$CXXFLAGS" LDFLAGS="$LDFLAGS"
make depend -j"$(sysctl -n hw.logicalcpu)" CXXFLAGS="$CXXFLAGS" LDFLAGS="$LDFLAGS"
make -j"$(sysctl -n hw.logicalcpu)" CXXFLAGS="$CXXFLAGS" LDFLAGS="$LDFLAGS"

# Add Kaldi to PATH
cd ..
KALDI_ROOT=$(pwd)
export PATH=$KALDI_ROOT/tools/openfst/bin:$KALDI_ROOT/src/bin:$PATH

echo "Kaldi installation completed successfully."
echo "Add the following lines to your shell profile to make the setup permanent:"
echo "export KALDI_ROOT=$KALDI_ROOT"
echo "export PATH=\$KALDI_ROOT/tools/openfst/bin:\$KALDI_ROOT/src/bin:\$PATH"
