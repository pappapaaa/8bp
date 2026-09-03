#!/bin/bash
set -e

SDK="${SDK:-iphoneos}"
CXX=$(xcrun --sdk "$SDK" --find clang++)
SDKROOT=$(xcrun --sdk "$SDK" --show-sdk-path)
ARCH="${ARCH:-arm64}"

# All source files – include your existing ones
SOURCES="
ModEntry_Inject.mm
OverlayManager.mm
PredictionLoop.cpp
TrajectoryOverlayView.mm
LiveDataAdapter.mm
SharedMemoryWriter.cpp
Prediction.cpp
MemoryManager.cpp
Offsets.cpp
"

$CXX -std=c++17 -O2 -shared -fPIC \
    -arch $ARCH \
    -isysroot $SDKROOT \
    -framework UIKit -framework CoreGraphics -framework QuartzCore \
    -lc++ -ldl \
    -o libKAKUMod.dylib \
    $SOURCES

echo "Built libKAKUMod.dylib for $ARCH"