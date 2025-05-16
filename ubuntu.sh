#!/bin/bash
set -o pipefail

# Logging functions
log_message() {
    local message="$1"
    if [[ -n "${message// }" ]]; then
        echo "[LAUNCHER_LOGGER] [MODEL_INSTALL_LLAMA] --message \"$message\""
    fi
}

log_error() {
    local message="$1"
    if [[ -n "${message// }" ]]; then
        echo "[LAUNCHER_LOGGER] [MODEL_INSTALL_LLAMA] --error \"$message\"" >&2
    fi
}

# Step 1: Search python package in /user
PYTHON_VERSIONS=()
for py in /usr/bin/python*; do
    # Skip -config files
    if [[ "$py" == *"-config" ]]; then
        continue
    fi
    if [ -f "$py" ] && [ -x "$py" ]; then
        # Extract version number and check if it's > 3.11
        version=$($py -V 2>&1 | grep -oP '\d+\.\d+')
        if (( $(echo "$version > 3.11" | bc -l) )); then
            PYTHON_VERSIONS+=("$py")
        fi
    fi
done

if [ ${#PYTHON_VERSIONS[@]} -eq 0 ]; then
    log_error "No Python installation found in /usr/bin with version > 3.11"
    exit 1
fi

# Sort versions to get the latest
IFS=$'\n' PYTHON_VERSIONS=($(sort -V <<<"${PYTHON_VERSIONS[*]}"))
unset IFS

# Use the latest version
PYTHON_CMD="${PYTHON_VERSIONS[-1]}"
log_message "Using Python version > 3.11 at $PYTHON_CMD"

# Step 2: Install all required packages at once
log_message "Installing required packages..."
if command -v apt-get &> /dev/null; then
    sudo apt-get update && sudo apt-get install -y pigz cmake libcurl4-openssl-dev
elif command -v yum &> /dev/null; then
    sudo yum install -y pigz cmake libcurl-openssl-dev
elif command -v dnf &> /dev/null; then
    sudo dnf install -y pigz cmake libcurl-openssl-dev
else
    log_error "No supported package manager found (apt-get, yum, or dnf)"
    exit 1
fi
log_message "All required packages installed successfully"

# Step 3: Build llama.cpp from source
if [ ! -f "llama.cpp/build/bin/llama-cli" ]; then
    log_message "Building llama.cpp from source..."
    # Remove existing directory if it exists
    if [ -d "llama.cpp" ]; then
        log_message "Removing existing llama.cpp directory..."
        rm -rf llama.cpp
    fi
    git clone https://github.com/ggerganov/llama.cpp
    cd llama.cpp
    # Remove existing build directory if it exists
    if [ -d "build" ]; then
        log_message "Removing existing build directory..."
        rm -rf build
    fi
    mkdir build
    cd build
    cmake -DLLAMA_METAL=OFF ..
    cmake --build . --config Release
    cd ../..
else
    log_message "llama.cpp binary already exists, skipping build"
fi

# Step 4: Create and activate virtual environment
log_message "Creating virtual environment 'local_ai'..."
"$PYTHON_CMD" -m venv local_ai || handle_error $? "Failed to create virtual environment"

log_message "Activating virtual environment..."
source local_ai/bin/activate || handle_error $? "Failed to activate virtual environment"
log_message "Virtual environment activated."
