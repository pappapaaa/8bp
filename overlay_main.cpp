#include "Renderer.h"
#include <iostream>
#include <string>
int main(int argc,char**argv){std::string config="overlay_config.json",endpoint;
#ifdef _WIN32
endpoint="\\\\.\\pipe\\trajectory";
#else
endpoint="/tmp/trajectory_pipe";
#endif
for(int i=1;i<argc;++i){std::string a=argv[i];if(a=="--config"&&i+1<argc)config=argv[++i];else if(a=="--pipe"&&i+1<argc)endpoint=argv[++i];else if(a=="--help"){std::cout<<"trajectory_overlay --config overlay_config.json --pipe endpoint\n";return 0;}else{std::cerr<<"unknown argument: "<<a<<'\n';return 2;}}try{return Renderer(config,endpoint).run();}catch(const std::exception&e){std::cerr<<"overlay error: "<<e.what()<<'\n';return 1;}}
