---
title: "Installation of Kaldi via a Shell script"
output: html_document
author: "Alexander Gu"
date: "2024-11-03"
---

# Kaldi Installation Script for macOS (M1)

This guide provides a shell script to install Kaldi on macOS (M1). Follow the steps below to set up Kaldi on your system.

## Prerequisites

Ensure you have the following tools installed on your Mac:

- [Homebrew](https://brew.sh/)
- Command-line tools for Xcode (`xcode-select --install`)

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

```
 fatal error: 'cstring' file not found
    1 | #include <cstring>
      |          ^~~~~~~~~
```
1. Check: <font color="red">clang++ --version</font>
2. Check: <font color="red">g++ --version</font>
