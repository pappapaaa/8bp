#include "PhysicsSimulator.h"
ShotResult PhysicsSimulator::runPrediction(const Shot&s,double interval){std::lock_guard<std::mutex> lock(mutex_);Prediction p(config_.table,config_.balls);return p.simulate(s,interval);}

