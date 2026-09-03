#pragma once
#include "Config.h"
#include <mutex>
#include <utility>
class PhysicsSimulator { SimulationConfig config_; mutable std::mutex mutex_; public: explicit PhysicsSimulator(SimulationConfig c):config_(std::move(c)){} ShotResult runPrediction(const Shot& shot,double sampleInterval=0.02); const SimulationConfig& config()const{return config_;} };
