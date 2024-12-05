---
title: "Installation of Kaldi via a Shell script"
output: html_document
author: "Alexander Gu"
date: "2024-12-03"
---

# Kaldi Installation Script for macOS (M1)

This guide provides a shell script to install Kaldi on macOS (M1). Follow the steps below to set up Kaldi on your system.

## Prerequisites

Ensure you have the following tools installed on your Mac:

- [Homebrew](https://brew.sh/)
- Command-line tools for Xcode (`xcode-select --install`). But I do not think this is necessary since other softwares require this already.

---

## Shell Script

Create a file named `kaldi_install.sh` and add the following content:

```bash
#!/bin/bash
# kaldi_install.sh

# Install dependencies
brew install git wget automake autoconf sox libtool subversion python3 gfortran

# Clone the Kaldi repository
git clone https://github.com/kaldi-asr/kaldi.git

cd kaldi

# Set up tools
cd tools
extras/check_dependencies.sh
make -j$(sysctl -n hw.logicalcpu)

# Set up source
cd ../src
./configure --shared
make -j$(sysctl -n hw.logicalcpu)

echo "Kaldi installation complete."
echo "Add the following to your shell profile:"
echo 'export KALDI_ROOT=$(pwd)'
echo 'export PATH=$KALDI_ROOT/tools/openfst/bin:$PATH'
echo 'export PATH=$KALDI_ROOT/src/bin:$PATH'
```

# Trouble shooting
## 1. cstring not found
The error message.
```
 fatal error: 'cstring' file not found
    1 | #include <cstring>
      |          ^~~~~~~~~
```
Reason: The issue likely lies in the compiler's inability to locate the C++ standard library headers. This is a common issue on macOS, especially with the transition to Apple Silicon (arm64).</br>
Solution:
1. Prepare a simple program to check the C++ compiler settings for further use.
```
// test.cpp
#include <cstring>
#include <iostream>

int main() {
  const char* str = "Hello, World!";
  std::cout << str << std::endl;
  return 0;
}
```
and 
```
// test.sh
clang++ test.cpp -o test
./test

// Alternative
CXX_INCLUDE_PATH="$SDK_PATH/usr/include/c++/v1"
clang++ -isysroot "$SDK_PATH" -I "$CXX_INCLUDE_PATH" test.cpp -o test
./test
```
2. Check: ```clang++ --version```
3. Check: ```g++ --version```
4. First check: ```clang++ -v -E -x c++ /dev/null``` then run ```find /Library/Developer/CommandLineTools -name cstring``` to see any differences of paths containing "V1".
5. If there is a mismatch in the 4th step. One needs to change the SDKROOT. But one needs not to do so due to any unexpected outcomes. Then run ```ls /Library/Developer/CommandLineTools/SDKs/``` to choose the best SDK version. I think it should match the paths found using the command "find".
6. Run the following line by line.
```
SDK_PATH="/Library/Developer/CommandLineTools/SDKs/MacOSX15.1.sdk" // Use the SDK version 15.1 for example
clang++ -isysroot "$SDK_PATH" test.cpp -o test
// if the above line fails
CXX_INCLUDE_PATH="$SDK_PATH/usr/include/c++/v1"
clang++ -isysroot "$SDK_PATH" -I "$CXX_INCLUDE_PATH" test.cpp -o test
```
7. Finally add the lines to the original Kaldi script.

```
#!/bin/bash
# kaldi_install.sh

# Install dependencies
#brew install git wget automake autoconf sox libtool subversion python3 gfortran

# Clone the Kaldi repository
git clone https://github.com/kaldi-asr/kaldi.git

cd kaldi

# Define the SDK path
SDK_PATH="/Library/Developer/CommandLineTools/SDKs/MacOSX15.1.sdk"
CXX_INCLUDE_PATH="$SDK_PATH/usr/include/c++/v1"

# Export compiler flags to guide clang++ to the correct SDK paths
export CXXFLAGS="-isysroot $SDK_PATH -I $CXX_INCLUDE_PATH"
export LDFLAGS="-isysroot $SDK_PATH"

# Set up tools
cd tools
extras/check_dependencies.sh
make -j$(sysctl -n hw.logicalcpu)

# Set up source
cd ../src
./configure --shared
make -j$(sysctl -n hw.logicalcpu)

echo "Kaldi installation complete."
echo "Add the following to your shell profile:"
echo 'export KALDI_ROOT=$(pwd)'
echo 'export PATH=$KALDI_ROOT/tools/openfst/bin:$PATH'
echo 'export PATH=$KALDI_ROOT/src/bin:$PATH'

```
## 2. cstring not found conti.
Error message.
```
n file included from In file included from In file included from alignedspeech_test.cppasctools.cppalignedsegment_test.cpp:::182218:
:
:
In file included from In file included from In file included from ./alignedspeech_test.h./asctools.h./alignedsegment_test.h:::212121:
:
:
../core/stdinc.hIn file included from :21:10:../core/stdinc.h alignment_test.cppfatal error: :18:
In file included from :./alignment_test.h21::2110: fatal error: 'cstring' file not found
```
in the running of code ```make -j$(sysctl -n hw.logicalcpu)```.

Solution
1. Check ```echo $SDK_PATH```
2. Also check ```ls "$SDK_PATH/usr/include/c++/v1/cstring"```
3. An updated .sh file is shared in this repo.

## 3. OpenFst not installed
The error message.
```
Configuring KALDI to use OPENBLAS. // This should be correct.
Checking compiler c++ ...
Checking OpenFst library in  ...
***configure failed: Could not find file /include/fst/fst.h:
  you may not have installed OpenFst. See ../tools/INSTALL ***
Makefile:29: kaldi.mk: No such file or directory
ERROR: kaldi.mk does not exist; run ./configure first.
make: *** [kaldi.mk] Error 1
Kaldi installation complete. // This should be correct.
```
1. (not recommended due to OS versions) Use homebrew ```brew install openfst```
2. Or update the script.
```
#!/bin/bash
# kaldi_install.sh

# =========================================
# Kaldi Installation Script
# =========================================

# Exit immediately if a command exits with a non-zero status
set -e

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
brew update

# Install required packages
brew install git wget automake autoconf sox libtool subversion python3 gfortran

echo "Dependencies installed successfully."

# ---------------------------
# 2. Clone the Kaldi Repository
# ---------------------------
echo "Cloning the Kaldi repository..."

# Clone Kaldi if it doesn't already exist
if [ ! -d "kaldi" ]; then
  git clone https://github.com/kaldi-asr/kaldi.git
else
  echo "Kaldi repository already cloned. Skipping clone step."
fi

cd kaldi

# ---------------------------
# 3. Define the SDK Path
# ---------------------------
# Adjust the SDK path if you're using a different macOS or Xcode version.
SDK_PATH="/Library/Developer/CommandLineTools/SDKs/MacOSX15.1.sdk"

# Verify that the SDK path exists
if [ ! -d "$SDK_PATH" ]; then
  echo "Error: SDK path $SDK_PATH does not exist."
  echo "Available SDKs:"
  ls /Library/Developer/CommandLineTools/SDKs/
  echo "Please update the SDK_PATH variable in the script accordingly."
  exit 1
fi

echo "SDK path set to $SDK_PATH."

# ---------------------------
# 4. Export Initial Compiler Flags
# ---------------------------
echo "Exporting initial compiler flags..."

export CXXFLAGS="-isysroot $SDK_PATH -I$SDK_PATH/usr/include/c++/v1"
export LDFLAGS="-isysroot $SDK_PATH"

echo "Compiler flags exported."

# ---------------------------
# 5. Set Up and Build Kaldi Tools (Including OpenFst)
# ---------------------------
echo "Setting up Kaldi tools..."

cd tools

# Check for necessary dependencies
echo "Checking dependencies for Kaldi tools..."
extras/check_dependencies.sh

# Build the tools, including OpenFst
echo "Building Kaldi tools (this may take a while)..."
make -j$(sysctl -n hw.logicalcpu)

echo "Kaldi tools built successfully."

# ---------------------------
# 6. Update Compiler Flags to Include OpenFst Paths
# ---------------------------
echo "Updating compiler flags to include OpenFst paths..."

# Determine the absolute path to the openfst directory
OPENFST_DIR="$(pwd)/openfst"

# Verify that OpenFst was built successfully
if [ ! -d "$OPENFST_DIR" ]; then
  echo "Error: OpenFst directory $OPENFST_DIR does not exist."
  exit 1
fi

# Export updated compiler flags to include OpenFst's include and lib directories
export CXXFLAGS="$CXXFLAGS -I$OPENFST_DIR/include"
export LDFLAGS="$LDFLAGS -L$OPENFST_DIR/lib"

# Optional: If using pkg-config, set PKG_CONFIG_PATH
export PKG_CONFIG_PATH="$OPENFST_DIR/lib/pkgconfig:$PKG_CONFIG_PATH"

echo "Compiler flags updated with OpenFst paths."

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
  exit 1
fi

echo "Kaldi installation script completed."

# =========================================
# End of Script
# =========================================

```

## 4. Error: OpenFst directory .../kaldi/tools/openfst does not exist.
Error message.
```
Error: OpenFst directory .../kaldi/tools/openfst does not exist.
```
in running
```
OPENFST_DIR="$(pwd)/openfst"

# Verify that OpenFst was built successfully
if [ ! -d "$OPENFST_DIR" ]; then
  echo "Error: OpenFst directory $OPENFST_DIR does not exist."
  exit 1
fi
```
Solution.


# TODO: Line 86 of the above script fails. OpenFt building is not correct.
3. Verify the openFt installation.
If Installed via Homebrew, check for the presence of fst.h: ```ls /usr/local/include/fst/fst.h``` or for Apple Silicon Macs ```ls /opt/homebrew/include/fst/fst.h```
If Built via Kaldi's Tools: ```ls tools/openfst/include/fst/fst.h```
4. 


# MISC
[Features](https://github.com/moomoofarm1/shennong) expected to extract.
