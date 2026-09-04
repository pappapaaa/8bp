#import "MemoryManager.h"

#include <algorithm>
#include <iterator>
#include <memory>
#include <mutex>

namespace {
std::mutex stateMutex;
SimulationState simulationState;
std::unique_ptr<Prediction> gPrediction;
std::vector<float> lastPredictionResult;
bool initialized = false;

std::vector<BallConfig> configuredBalls(const SimulationState& data);
void ensureDefaultBalls(SimulationState& data);

bool initializeLocked() {
    if (initialized) {
        return true;
    }
    ensureDefaultBalls(simulationState);
    gPrediction = std::make_unique<Prediction>(
        simulationState.table, configuredBalls(simulationState));
    initialized = true;
    return true;
}

std::vector<BallConfig> configuredBalls(const SimulationState& data) {
    std::vector<BallConfig> balls;
    balls.reserve(data.balls.size());
    for (const BallSample& ball : data.balls) {
        if (ball.onTable) {
            balls.push_back({ball.index, ball.position});
        }
    }
    return balls;
}

void ensureDefaultBalls(SimulationState& data) {
    if (!data.balls.empty()) {
        return;
    }
    data.balls.push_back({0, {data.table.width * 0.25, data.table.height * 0.5}, true});
}
} // namespace

bool MemoryManager::initialize() {
    std::lock_guard<std::mutex> lock(stateMutex);
    return initializeLocked();
}

bool MemoryManager::updatePrediction() {
    std::lock_guard<std::mutex> lock(stateMutex);
    if (!initializeLocked()) {
        return false;
    }

    const Point2D spin{simulationState.shot.spin.x, simulationState.shot.spin.y};
    const bool succeeded = gPrediction->determineShotResult(
        simulationState.shot.angle, simulationState.shot.power, spin);
    if (!succeeded) {
        lastPredictionResult.clear();
        return false;
    }

    const int size = gPrediction->getShotResultSize();
    const float* result = gPrediction->getShotResult();
    if (result != nullptr && size > 0) {
        lastPredictionResult.assign(result, result + size);
    } else {
        lastPredictionResult.clear();
    }
    return true;
}

float* MemoryManager::getLastPredictionResult() {
    std::lock_guard<std::mutex> lock(stateMutex);
    return lastPredictionResult.empty() ? nullptr : lastPredictionResult.data();
}

int MemoryManager::getLastPredictionSize() {
    std::lock_guard<std::mutex> lock(stateMutex);
    return static_cast<int>(lastPredictionResult.size());
}

void MemoryManager::updateData(const SimulationState& data) {
    std::lock_guard<std::mutex> lock(stateMutex);
    simulationState = data;
    ensureDefaultBalls(simulationState);
    gPrediction = std::make_unique<Prediction>(
        simulationState.table, configuredBalls(simulationState));
    lastPredictionResult.clear();
    initialized = true;
}

SimulationState MemoryManager::getData() {
    std::lock_guard<std::mutex> lock(stateMutex);
    return simulationState;
}

double MemoryManager::VisualCue::getShotAngle() {
    std::lock_guard<std::mutex> lock(stateMutex);
    return simulationState.shot.angle;
}

double MemoryManager::VisualCue::getShotPower() {
    std::lock_guard<std::mutex> lock(stateMutex);
    return simulationState.shot.power;
}

Point2D MemoryManager::VisualCue::getShotSpin() {
    std::lock_guard<std::mutex> lock(stateMutex);
    return {simulationState.shot.spin.x, simulationState.shot.spin.y};
}

bool MemoryManager::MenuManager::isInGame() {
    std::lock_guard<std::mutex> lock(stateMutex);
    return simulationState.inGame;
}

bool MemoryManager::GameManager::isValidGameState() {
    std::lock_guard<std::mutex> lock(stateMutex);
    return simulationState.validGameState && !simulationState.balls.empty();
}

std::vector<BallSample> MemoryManager::Balls::getAll() {
    std::lock_guard<std::mutex> lock(stateMutex);
    return simulationState.balls;
}

Point2D MemoryManager::Balls::getPosition(int index) {
    std::lock_guard<std::mutex> lock(stateMutex);
    const auto it = std::find_if(simulationState.balls.begin(), simulationState.balls.end(),
                                 [index](const BallSample& ball) { return ball.index == index; });
    return it == simulationState.balls.end() ? Point2D{} : it->position;
}

bool MemoryManager::Balls::isOnTable(int index) {
    std::lock_guard<std::mutex> lock(stateMutex);
    const auto it = std::find_if(simulationState.balls.begin(), simulationState.balls.end(),
                                 [index](const BallSample& ball) { return ball.index == index; });
    return it != simulationState.balls.end() && it->onTable;
}

std::size_t MemoryManager::Balls::count() {
    std::lock_guard<std::mutex> lock(stateMutex);
    return simulationState.balls.size();
}
