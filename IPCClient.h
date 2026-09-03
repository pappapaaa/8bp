#pragma once
#include "config_loader.h"
#include <atomic>
#include <mutex>
#include <string>
#include <thread>
struct OverlayBall { int index=0; OverlayPoint initialPosition,predictedPosition; std::vector<OverlayPoint> positions; bool onTable=true; };
struct OverlayFrame { std::vector<OverlayBall> balls; bool shotState=false; std::vector<bool> pocketStatus; };
class IPCClient { public: explicit IPCClient(std::string endpoint); ~IPCClient(); void start(); void stop(); bool latest(OverlayFrame&out)const; private: void worker(); bool parse(const std::string&,OverlayFrame&)const; std::string endpoint_; std::atomic<bool>running_{false}; std::thread thread_; mutable std::mutex mutex_; OverlayFrame frame_; std::atomic<bool>hasFrame_{false}; };
