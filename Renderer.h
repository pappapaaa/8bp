#pragma once
#include "IPCClient.h"
#include "config_loader.h"
#include <string>
#include <utility>
class Renderer { public: Renderer(std::string configPath,std::string endpoint); int run(); private: std::string configPath_,endpoint_; OverlayConfig config_; IPCClient ipc_; bool clickThrough_=false; void draw(const OverlayFrame&); void toggleClickThrough(void* window); };
