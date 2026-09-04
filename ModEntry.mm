// ModEntry_Inject.mm
#import <UIKit/UIKit.h>
#import "OverlayManager.h"
#include "MemoryManager.h"
#include "Prediction.h"
#include "SharedMemoryWriter.h"
#include "PredictionLoop.h"
#include <pthread.h>
#include <unistd.h>
#include <algorithm>
#include <chrono>

// Global writer
static std::shared_ptr<PoolLive::SharedMemoryWriter> g_writer;

// Active provider: check if we're in a game
static bool isGameActive() {
    return MemoryManager::MenuManager::isInGame() &&
           MemoryManager::GameManager::isValidGameState();
}

// Shot provider: read from MemoryManager
static Shot getCurrentShot() {
    Shot s;
    s.angle = MemoryManager::VisualCue::getShotAngle();
    s.power = MemoryManager::VisualCue::getShotPower();
    auto spin = MemoryManager::VisualCue::getShotSpin();
    s.spin = { spin.x, spin.y, 0.0 };
    return s;
}

// The actual prediction loop using the existing MemoryManager::updatePrediction()
// This is simpler: we call MemoryManager's own update which already uses gPrediction
static void* predictionLoop(void*) {
    // Wait for MemoryManager to be ready
    while (!MemoryManager::initialize()) {
        sleep(1);
    }
    NSLog(@"KAKU DEV: MemoryManager initialized");

    // Open shared memory
    g_writer = std::make_shared<PoolLive::SharedMemoryWriter>("/pool_trajectory_live");
    if (!g_writer->open()) {
        NSLog(@"KAKU DEV: Failed to open shared memory");
    } else {
        NSLog(@"KAKU DEV: Shared memory opened");
    }

    // Cache previous shot parameters to avoid unnecessary updates
    double lastAngle = -1.0, lastPower = -1.0;
    Point2D lastSpin = {0, 0};

    while (true) {
        if (isGameActive()) {
            double angle = MemoryManager::VisualCue::getShotAngle();
            double power = MemoryManager::VisualCue::getShotPower();
            Point2D spin = MemoryManager::VisualCue::getShotSpin();

            // Only run prediction if shot parameters changed
            if (angle != lastAngle || power != lastPower ||
                spin.x != lastSpin.x || spin.y != lastSpin.y) {
                lastAngle = angle; lastPower = power; lastSpin = spin;

                // Run the prediction (this calls gPrediction->determineShotResult)
                if (MemoryManager::updatePrediction()) {
                    // Get the result array
                    float* result = MemoryManager::getLastPredictionResult();
                    int size = MemoryManager::getLastPredictionSize();

                    // Convert to TrajectoryFrame
                    PoolLive::TrajectoryFrame frame{};
                    frame.magic = PoolLive::kMagic;
                    frame.version = PoolLive::kVersion;
                    frame.timestampNanoseconds = (uint64_t)std::chrono::duration_cast<std::chrono::nanoseconds>(
                        std::chrono::steady_clock::now().time_since_epoch()).count();

                    // Parse result array:
                    // result[0] = isTrajectoryEnabled (bool)
                    // result[1] = numberOfBalls that moved
                    // Then for each ball: ballIndex, numPositions, (x,y) pairs...
                    int index = 2;
                    uint32_t ballCount = 0;
                    if (size > 1) {
                        ballCount = (uint32_t)result[1];
                        frame.ballCount = std::min(ballCount, PoolLive::kMaxBalls);
                        for (uint32_t b = 0; b < frame.ballCount && b < ballCount; ++b) {
                            if (index + 2 <= size) {
                                int ballIdx = (int)result[index++];
                                int numPos = (int)result[index++];
                                frame.positionCounts[b] = std::min((uint32_t)numPos, PoolLive::kMaxPositions);
                                for (uint32_t p = 0; p < frame.positionCounts[b]; ++p) {
                                    if (index + 1 < size) {
                                        frame.positions[b][p][0] = result[index++];
                                        frame.positions[b][p][1] = result[index++];
                                    }
                                }
                                // predicted position is the last position if available
                                if (frame.positionCounts[b] > 0) {
                                    frame.predictedPositions[b][0] = frame.positions[b][frame.positionCounts[b]-1][0];
                                    frame.predictedPositions[b][1] = frame.positions[b][frame.positionCounts[b]-1][1];
                                }
                                // onTable: we can get from MemoryManager::Balls if needed; for now, assume true
                                frame.onTable[b] = 1;
                            }
                        }
                    }

                    // Pocket status (global from Prediction)
                    for (int i = 0; i < PoolLive::kPocketCount; ++i) {
                        frame.pocketStatus[i] = Prediction::pocketStatus[i] ? 1 : 0;
                    }

                    // Shot state: from gPrediction->guiData.shotState (if accessible)
                    // Alternatively, use the result from MemoryManager if available
                    frame.shotState = 0; // you can set based on your logic

                    // Publish
                    if (g_writer && g_writer->isOpen()) {
                        g_writer->writeFrame(frame);
                    }
                }
            }
        }
        usleep(16666); // ~60 Hz
    }
    return nullptr;
}

// Entry point
__attribute__((constructor))
static void init() {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"KAKU DEV: Mod initializing (injection mode)");

        // Start the prediction thread
        pthread_t thread;
        pthread_create(&thread, nullptr, predictionLoop, nullptr);
        pthread_detach(thread);

        // Show overlay after a delay (game needs to load)
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC),
                       dispatch_get_main_queue(), ^{
            [[OverlayManager sharedManager] start];
            NSLog(@"KAKU DEV: Overlay started");
        });
    });
}
