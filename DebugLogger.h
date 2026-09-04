#pragma once
#include <string>

namespace PoolDebug {
void logInfo(const std::string& message);
void logWarning(const std::string& message);
void logError(const std::string& message);
}
