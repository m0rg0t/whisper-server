#!/bin/bash
set -euo pipefail

# Build only the macOS arm64 slice of the official, pinned Apple framework recipe.
# CoreML fallback, Metal, embedded shaders and Accelerate retain upstream settings.
repo_root=$(cd "$(dirname "$0")/.." && pwd)
source_dir=${1:-"$repo_root/.build/vendor/whisper.cpp"}
expected_revision=927cfce34f31707e17f2bff35c349632fb9e2c3a
if [[ $(git -C "$source_dir" rev-parse HEAD) != "$expected_revision" ]]; then
    echo "Expected official whisper.cpp v1.9.4 revision $expected_revision" >&2
    exit 1
fi
git -C "$source_dir" diff --quiet HEAD --

python3 - "$source_dir" <<'PY'
from pathlib import Path
import sys
root = Path(sys.argv[1])
source = (root / 'build-xcframework.sh').read_text()
start = 'echo "Building for iOS simulator..."'
mac = 'echo "Building for macOS..."'
end = 'echo "Building for visionOS..."'
for marker in (start, mac, end):
    if source.count(marker) != 1:
        raise SystemExit('Pinned vendor build recipe no longer matches expected markers')
# Keep the official helpers and macOS build options; omit all other platform builds.
prelude = source.split(start)[0].replace('archs="arm64 x86_64"', 'archs="arm64"')
mac_build = mac + source.split(mac)[1].split(end)[0]
mac_build = mac_build.replace('"arm64;x86_64"', '"arm64"')
finish = '''
setup_framework_structure "build-macos" ${MACOS_MIN_OS_VERSION} "macos"
combine_static_libraries "build-macos" "Release" "macos" "false"
xcodebuild -create-xcframework \\
    -framework "$(pwd)/build-macos/framework/whisper.framework" \\
    -debug-symbols "$(pwd)/build-macos/dSYMs/whisper.dSYM" \\
    -output "$(pwd)/build-apple/whisper.xcframework"
'''
(root / '.maintenance-build-macos.sh').write_text(prelude + mac_build + finish)
PY

cd "$source_dir"
bash .maintenance-build-macos.sh
