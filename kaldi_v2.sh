#!/bin/bash
# Simplified Kaldi Installation Script for macOS M-chips

# Check if running on macOS
if [[ "$(uname)" != "Darwin" ]]; then
    echo "This script is intended for macOS systems only."
    exit 1
fi

# Ensure Homebrew is installed
if ! command -v brew &> /dev/null; then
    echo "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Install required dependencies
REQUIRED_PACKAGES=(git wget automake autoconf sox libtool subversion python3 gfortran)
for pkg in "${REQUIRED_PACKAGES[@]}"; do
    brew list --formula | grep -q "^${pkg}\$" || brew install "$pkg"
done

# Clone Kaldi repository
if [[ ! -d "kaldi" ]]; then
    git clone https://github.com/kaldi-asr/kaldi.git
fi
cd kaldi

# Set up SDK and compiler flags for M-chips
SDK_PATH="/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk"
export CXXFLAGS="-isysroot $SDK_PATH -stdlib=libc++ -arch arm64"
export LDFLAGS="-isysroot $SDK_PATH -stdlib=libc++ -arch arm64"

# Build Kaldi tools and OpenFst
cd tools
./extras/check_dependencies.sh
make -j"$(sysctl -n hw.logicalcpu)"

# Configure and build Kaldi source
cd ../src
./configure --shared
make depend
make -j"$(sysctl -n hw.logicalcpu)"

# Set up environment variables
export KALDI_ROOT=$PWD/..
export PATH=$KALDI_ROOT/src/bin:$KALDI_ROOT/tools/openfst/bin:$PATH

# Verify installation
if [ -f "kaldi.mk" ]; then
    echo "Kaldi installation completed successfully."
else
    echo "Error: Kaldi installation failed."
    exit 1
fi

echo "Kaldi is now installed. Add the following to your shell profile:"
echo "export KALDI_ROOT=$KALDI_ROOT"
echo "export PATH=\$KALDI_ROOT/src/bin:\$KALDI_ROOT/tools/openfst/bin:\$PATH"
