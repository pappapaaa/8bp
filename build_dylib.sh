#!/usr/bin/env bash
set -euo pipefail

ROOT="${ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
SDK="${SDK:-iphoneos}"
ARCH="${ARCH:-arm64}"
OUTPUT="${OUTPUT:-$ROOT/libKAKUMod.dylib}"

CXX="${CXX:-$(xcrun --sdk "$SDK" --find clang++)}"
SDKROOT="${SDKROOT:-$(xcrun --sdk "$SDK" --show-sdk-path)}"

# All source files required by the iOS overlay dylib.
SOURCES=(
  "$ROOT/Prediction.cpp"
  "$ROOT/Config.cpp"
  "$ROOT/PhysicsSimulator.cpp"
  "$ROOT/SharedMemoryWriter.cpp"
  "$ROOT/PredictionLoop.cpp"
  "$ROOT/MemoryManager.mm"
  "$ROOT/ShotResultSnapshot.mm"
  "$ROOT/PhysicsEngine.mm"
  "$ROOT/LiveDataAdapter.mm"
  "$ROOT/TrajectoryOverlayView.mm"
  "$ROOT/OverlayManager.mm"
  "$ROOT/ModEntry.mm"
)

for source in "${SOURCES[@]}"; do
  if [[ ! -f "$source" ]]; then
    printf 'error: required source file is missing: %s\n' "$source" >&2
    exit 1
  fi
done

OBJECT_DIR="${OBJECT_DIR:-$ROOT/.build-dylib/$ARCH}"
mkdir -p "$OBJECT_DIR"
OBJECTS=()

for source in "${SOURCES[@]}"; do
  name="$(basename "$source")"
  object="$OBJECT_DIR/${name%.*}.o"
  flags=(
    -std=c++17
    -stdlib=libc++
    -O2
    -fPIC
    -fvisibility=hidden
    -arch "$ARCH"
    -isysroot "$SDKROOT"
    -I"$ROOT"
  )
  [[ "$source" == *.mm ]] && flags+=(-fobjc-arc)
  "$CXX" "${flags[@]}" -c "$source" -o "$object"
  OBJECTS+=("$object")
done

"$CXX" \
  -dynamiclib \
  -arch "$ARCH" \
  -isysroot "$SDKROOT" \
  -stdlib=libc++ \
  -framework UIKit \
  -framework CoreGraphics \
  -framework QuartzCore \
  -framework Foundation \
  -lc++ \
  -ldl \
  "${OBJECTS[@]}" \
  -o "$OUTPUT"

printf 'Built %s for %s (%s)\n' "$OUTPUT" "$SDK" "$ARCH"
