#!/usr/bin/env bash
# Build the release binaries of Pasadizo's Hysteria into build/ with upstream's
# own build script (hyperbole.py build -r: -trimpath, -s -w, CGO off, and the
# version, date, commit, toolchain, platform and arch in app/cmd), then write
# build/SHA256SUMS. The version is the nearest app/v* tag (git describe), so a
# release build needs the tag and the history up to it.
#
# Usage: .github/pasadizo/build.sh [platform...]   (default: linux/amd64 linux/arm64)
set -euo pipefail

cd "$(dirname "$0")/../.."

platforms=("$@")
if [ "${#platforms[@]}" -eq 0 ]; then
	platforms=(linux/amd64 linux/arm64)
fi

rm -rf build
HY_APP_PLATFORMS="$(
	IFS=,
	echo "${platforms[*]}"
)" python3 hyperbole.py build -r

# hyperbole.py returns 0 when its environment check fails, so check the output
names=()
for platform in "${platforms[@]}"; do
	name="hysteria-${platform%/*}-${platform#*/}"
	if [ ! -s "build/$name" ]; then
		echo "build/$name was not built" >&2
		exit 1
	fi
	names+=("$name")
done

cd build
sha256sum "${names[@]}" >SHA256SUMS
cat SHA256SUMS
