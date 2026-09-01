#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h}"
TEST_BUILD="$ROOT/.build/tests"

cd "$ROOT"
mkdir -p "$TEST_BUILD"

swiftc \
  -D PLINK_TESTING \
  -parse-as-library \
  -module-cache-path "$ROOT/.build/module-cache" \
  -framework AppKit \
  -framework ImageIO \
  -framework UniformTypeIdentifiers \
  "$ROOT/Sources/HEICDrop/main.swift" \
  "$ROOT/Tests/DestinationTests.swift" \
  -o "$TEST_BUILD/DestinationTests"

"$TEST_BUILD/DestinationTests"
