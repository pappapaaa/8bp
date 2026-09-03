#pragma once
#include "Prediction.h"
#include "SharedMemoryWriter.h"
#include <atomic>
#include <functional>
#include <memory>
#include <thread>

class PredictionLoop {
public:
    using ActiveProvider = std::function<bool()>;
    using ShotProvider = std::function<Shot()>;
    PredictionLoop(ActiveProvider active, ShotProvider shot, std::shared_ptr<PhysicsSimulator> simulator, std::shared_ptr<PoolLive::SharedMemoryWriter> writer);
    ~PredictionLoop();
    void start();
    void stop();
private:
    void run();
    ActiveProvider active_; ShotProvider shot_; std::shared_ptr<PhysicsSimulator> simulator_; std::shared_ptr<PoolLive::SharedMemoryWriter> writer_; std::atomic<bool> running_{false}; std::thread thread_;
};
