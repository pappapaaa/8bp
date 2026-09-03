#include "BatchRunner.h"
#include <random>
#include <fstream>
#include <iomanip>
void BatchRunner::run(PhysicsSimulator&sim,int count,unsigned seed,const std::string&file){std::mt19937 g(seed);std::uniform_real_distribution<double>a(-3.141592653589793,3.141592653589793),p(100,700),s(-0.35,0.35);std::ofstream f(file);f<<"{\n  \"seed\": "<<seed<<",\n  \"shots\": [\n";for(int i=0;i<count;++i){Shot q{a(g),p(g),{s(g),s(g),s(g)}};auto r=sim.runPrediction(q);f<<"    {\"id\": "<<i<<", \"angle\": "<<q.angle<<", \"power\": "<<q.power<<", \"duration\": "<<r.duration<<", \"collisions\": "<<r.collisions.size()<<", \"pocketed\": [";for(size_t j=0;j<r.pocketed.size();++j)f<<(j?",":"")<<r.pocketed[j];f<<"]}"<<(i+1==count?"\n":" ,\n");}f<<"  ]\n}\n";}

