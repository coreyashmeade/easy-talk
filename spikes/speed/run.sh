#!/bin/zsh
# Build and run the speed/quality spike. First run downloads Parakeet v2 (~600 MB) and Qwen 3.5 4B (~2.9 GB).
# Needs Xcode's Metal Toolchain: xcodebuild -downloadComponent MetalToolchain
# Usage: ./run.sh [huggingface-model-id]
set -e
cd "$(dirname "$0")"
xcodebuild -scheme SpeedSpike -destination 'platform=macOS' -derivedDataPath .build-xc \
  -skipMacroValidation -skipPackagePluginValidation -configuration Release build | grep -E "error:|BUILD"
.build-xc/Build/Products/Release/SpeedSpike ../../tests/cleanup-cases.json out "${1:-mlx-community/Qwen3.5-4B-MLX-4bit}"
