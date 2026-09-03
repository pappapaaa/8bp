#include "Config.h"
#include "PhysicsSimulator.h"
#include "BatchRunner.h"
#include "TrajectoryRenderer.h"
#include <iostream>
#include <fstream>
#include <string>
#include <cstdlib>
static void usage(){std::cout<<"pool_sandbox --config config.json [--headless|--ui] [--random N] [--output file]\n";}
static void writeShot(const ShotResult&r,const std::string&path){std::ofstream f(path);f<<"{\n  \"duration\": "<<r.duration<<",\n  \"settled\": "<<(r.settled?"true":"false")<<",\n  \"pocketed\": [";for(size_t i=0;i<r.pocketed.size();++i)f<<(i?",":"")<<r.pocketed[i];f<<"],\n  \"collisions\": "<<r.collisions.size()<<",\n  \"trajectory\": [\n";for(size_t i=0;i<r.trajectory.size();++i){auto&s=r.trajectory[i];f<<"    {\"time\": "<<s.time<<", \"balls\": [";for(size_t j=0;j<s.balls.size();++j){auto&b=s.balls[j];f<<(j?",":"")<<"{\"index\": "<<b.index<<",\"x\": "<<b.position.x<<",\"y\": "<<b.position.y<<",\"onTable\": "<<(b.onTable?"true":"false")<<"}";}f<<"]}"<<(i+1==r.trajectory.size()?"\n":" ,\n");}f<<"  ]\n}\n";}
int main(int argc,char**argv){try{std::string cfg="config.json",out="result.json";bool ui=false;int random=0;for(int i=1;i<argc;++i){std::string a=argv[i];if(a=="--config"&&i+1<argc)cfg=argv[++i];else if(a=="--ui")ui=true;else if(a=="--headless")ui=false;else if(a=="--random"&&i+1<argc)random=std::atoi(argv[++i]);else if(a=="--output"&&i+1<argc)out=argv[++i];else{usage();return 2;}}auto c=loadConfig(cfg);PhysicsSimulator sim(c);if(random>0){BatchRunner::run(sim,random,12345u,out);std::cout<<"Wrote "<<random<<" shots to "<<out<<"\n";}else if(ui)TrajectoryRenderer::run(sim);else{auto r=sim.runPrediction(c.shot);writeShot(r,out);std::cout<<"Wrote trajectory to "<<out<<" ("<<r.collisions.size()<<" collisions)\n";}return 0;}catch(const std::exception&e){std::cerr<<"error: "<<e.what()<<"\n";return 1;}}

