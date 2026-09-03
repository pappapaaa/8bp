#!/usr/bin/env bash
set -euo pipefail

ROOT="${ROOT:-$(cd "$(dirname "$0")" && pwd)}"
SDK="${SDK:-iphoneos}"
CONFIG="${CONFIG:-Release}"
OUT="${OUT:-$ROOT/build-ios}"
CXXFLAGS="${CXXFLAGS:--std=c++17 -O2 -fvisibility=hidden}"
SDKROOT="$(xcrun --sdk "$SDK" --show-sdk-path)"
CXX="${CXX:-$(xcrun --sdk "$SDK" --find clang++)}"
AR="${AR:-$(xcrun --sdk "$SDK" --find ar)}"
mkdir -p "$OUT/obj"

SOURCES=(
  "$ROOT/Prediction.cpp" "$ROOT/Config.cpp" "$ROOT/PhysicsSimulator.cpp"
  "$ROOT/SharedMemoryWriter.cpp" "$ROOT/PredictionLoop.cpp"
  "$ROOT/ShotResultSnapshot.mm" "$ROOT/PhysicsEngine.mm"
  "$ROOT/LiveDataAdapter.mm" "$ROOT/TrajectoryOverlayView.mm"
  "$ROOT/OverlayManager.mm" "$ROOT/ModEntry.mm"
)
OBJECTS=()
for source in "${SOURCES[@]}"; do
  base="$(basename "$source")"
  object="$OUT/obj/${base%.*}.o"
  EXTRA_FLAGS=()
  case "$source" in
    *.mm) EXTRA_FLAGS+=("-fobjc-arc") ;;
  esac
  "$CXX" -isysroot "$SDKROOT" -I"$ROOT" $CXXFLAGS "${EXTRA_FLAGS[@]}" -c "$source" -o "$object"
  OBJECTS+=("$object")
done

"$AR" -rcs "$OUT/libPoolDebugOverlay.a" "${OBJECTS[@]}"
echo "Built $OUT/libPoolDebugOverlay.a for $SDK ($CONFIG)"
