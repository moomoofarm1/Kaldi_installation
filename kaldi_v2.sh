#!/bin/bash
# Comprehensive Kaldi Installation Script for macOS M-chips

# Fail on any error
set -e

# Colorful output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Log function
log() {
    echo -e "${GREEN}[KALDI INSTALLER]${NC} $1"
}

# Error handling function
error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# Check if running on macOS
if [[ "$(uname)" != "Darwin" ]]; then
    error "This script is intended for macOS systems only."
fi

# Ensure Xcode Command Line Tools are installed
if ! xcode-select -p &> /dev/null; then
    log "Installing Xcode Command Line Tools..."
    xcode-select --install
    read -p "Press Enter after Xcode Command Line Tools installation completes"
fi

# Ensure Homebrew is installed
if ! command -v brew &> /dev/null; then
    log "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    
    # Ensure Homebrew is in PATH
    echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# Update Homebrew
brew update

# Install required dependencies
REQUIRED_PACKAGES=(
    git wget automake autoconf 
    sox libtool subversion 
    python3 gfortran 
    openblas cmake
)

log "Installing required dependencies..."
for pkg in "${REQUIRED_PACKAGES[@]}"; do
    if ! brew list --formula | grep -q "^${pkg}\$"; then
        brew install "$pkg"
    fi
done

# Set up compiler environment
export CC=clang
export CXX=clang++

# Determine SDK path
SDK_PATH=$(xcrun --show-sdk-path)
if [[ -z "$SDK_PATH" ]]; then
    error "Could not determine macOS SDK path"
fi

# Compiler and linker flags for M-chips
export CXXFLAGS="-isysroot $SDK_PATH -stdlib=libc++ -arch arm64 -I/opt/homebrew/include"
export LDFLAGS="-L/opt/homebrew/lib -isysroot $SDK_PATH -stdlib=libc++ -arch arm64"

# Create or clean Kaldi directory
if [[ -d "kaldi" ]]; then
    log "Removing existing Kaldi directory..."
    rm -rf kaldi
fi

# Clone Kaldi repository
log "Cloning Kaldi repository..."
git clone https://github.com/kaldi-asr/kaldi.git
cd kaldi

# Explicitly resolve header path issues
log "Fixing system header paths..."
mkdir -p tools/extras
cat << 'EOF' > tools/extras/fix_headers.sh
#!/bin/bash
# Find and symlink missing C++ headers
SYSTEM_HEADERS=(
    "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/c++/v1"
    "/opt/homebrew/include/c++/v1"
)

for path in "${SYSTEM_HEADERS[@]}"; do
    if [ -d "$path" ]; then
        ln -sf "$path" "$1/include/c++/v1"
        break
    fi
done
EOF
chmod +x tools/extras/fix_headers.sh

# Build tools
log "Building Kaldi tools..."
cd tools
./extras/fix_headers.sh .
./extras/check_dependencies.sh

# Build OpenFst with explicit configuration
log "Building OpenFst..."
cd openfst-1.8.3
./configure \
    --enable-static \
    --enable-shared \
    --prefix=/opt/homebrew \
    CXXFLAGS="$CXXFLAGS" \
    LDFLAGS="$LDFLAGS"
make clean
make -j"$(sysctl -n hw.logicalcpu)"
make install
cd ..

# Return to Kaldi source directory
cd ../src

# Configure Kaldi
log "Configuring Kaldi..."
./configure \
    --shared \
    --openblas-root=/opt/homebrew \
    CXXFLAGS="$CXXFLAGS" \
    LDFLAGS="$LDFLAGS"

# Build Kaldi
log "Building Kaldi..."
make depend
make -j"$(sysctl -n hw.logicalcpu)"

# Verify installation
if [ ! -f "kaldi.mk" ]; then
    error "Kaldi installation failed. kaldi.mk not found."
fi

# Set up environment variables
log "Setting up environment variables..."
KALDI_ROOT=$(pwd)/..
export KALDI_ROOT
export PATH=$KALDI_ROOT/src/bin:$KALDI_ROOT/tools/openfst/bin:$PATH

# Final success message
log "${GREEN}Kaldi installation completed successfully!${NC}"

# Provide instructions for permanent setup
echo -e "\n${YELLOW}Add the following to your shell profile (e.g., ~/.zshrc or ~/.bash_profile):${NC}"
echo "export KALDI_ROOT=$KALDI_ROOT"
echo "export PATH=\$KALDI_ROOT/src/bin:\$KALDI_ROOT/tools/openfst/bin:\$PATH"
