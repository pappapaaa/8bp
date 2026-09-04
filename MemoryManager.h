#pragma once

#include "Prediction.h"

#include <cstddef>
#include <vector>

// Mock state provider used by the debug overlay.  Production callers can push
// the latest simulator state with MemoryManager::updateData(); no process or
// external-memory reads are performed by this module.
struct SimulationState {
    bool inGame = true;
    bool validGameState = true;
    Shot shot{};
    Table table{};
    std::vector<BallSample> balls;
};

class MemoryManager {
public:
    class VisualCue {
    public:
        static double getShotAngle();
        static double getShotPower();
        static Point2D getShotSpin();
    };

    class MenuManager {
    public:
        static bool isInGame();
    };

    class GameManager {
    public:
        static bool isValidGameState();
    };

    class Balls {
    public:
        static std::vector<BallSample> getAll();
        static Point2D getPosition(int index);
        static bool isOnTable(int index);
        static std::size_t count();
    };

    static bool initialize();
    static bool updatePrediction();
    static float* getLastPredictionResult();
    static int getLastPredictionSize();

    static void updateData(const SimulationState& data);
    static SimulationState getData();

private:
    MemoryManager() = delete;
};

