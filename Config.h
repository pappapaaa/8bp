#pragma once
#include <string>
#include <vector>
#include "Prediction.h"

struct SimulationConfig { Table table; std::vector<BallConfig> balls; Shot shot; };
SimulationConfig loadConfig(const std::string& path);

