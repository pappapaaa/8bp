#pragma once
#include "PhysicsSimulator.h"
#include <string>
class BatchRunner { public: static void run(PhysicsSimulator&,int,unsigned seed,const std::string&); };

