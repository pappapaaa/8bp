# Complete Codebase

This document is a self-contained copy of the current workspace. Every file is embedded below; the only omitted file is this document itself.

## BatchRunner.cpp

```cpp
#include "BatchRunner.h"
#include <random>
#include <fstream>
#include <iomanip>
void BatchRunner::run(PhysicsSimulator&sim,int count,unsigned seed,const std::string&file){std::mt19937 g(seed);std::uniform_real_distribution<double>a(-3.141592653589793,3.141592653589793),p(100,700),s(-0.35,0.35);std::ofstream f(file);f<<"{\n  \"seed\": "<<seed<<",\n  \"shots\": [\n";for(int i=0;i<count;++i){Shot q{a(g),p(g),{s(g),s(g),s(g)}};auto r=sim.runPrediction(q);f<<"    {\"id\": "<<i<<", \"angle\": "<<q.angle<<", \"power\": "<<q.power<<", \"duration\": "<<r.duration<<", \"collisions\": "<<r.collisions.size()<<", \"pocketed\": [";for(size_t j=0;j<r.pocketed.size();++j)f<<(j?",":"")<<r.pocketed[j];f<<"]}"<<(i+1==count?"\n":" ,\n");}f<<"  ]\n}\n";}



```

## BatchRunner.h

```cpp
#pragma once
#include "PhysicsSimulator.h"
#include <string>
class BatchRunner { public: static void run(PhysicsSimulator&,int,unsigned seed,const std::string&); };



```

## build_module.sh

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="${ROOT:-$(cd "$(dirname "$0")" && pwd)}"
SDK="${SDK:-iphoneos}"
CONFIG="${CONFIG:-Release}"
OUT="${OUT:-$ROOT/build-ios}"
CXXFLAGS="${CXXFLAGS:--std=c++17 -O2 -fvisibility=hidden}"
SDKROOT="$(xcrun --sdk "$SDK" --show-sdk-path)"
CXX="${CXX:-$(xcrun --sdk "$SDK" --find clang++)}"
AR="${AR:-$(xcrun --sdk "$SDK" --find ar)}"
mkdir -p "$OUT/obj"

SOURCES=(
  "$ROOT/Prediction.cpp" "$ROOT/Config.cpp" "$ROOT/PhysicsSimulator.cpp"
  "$ROOT/SharedMemoryWriter.cpp" "$ROOT/PredictionLoop.cpp"
  "$ROOT/ShotResultSnapshot.mm" "$ROOT/PhysicsEngine.mm"
  "$ROOT/LiveDataAdapter.mm" "$ROOT/TrajectoryOverlayView.mm"
  "$ROOT/OverlayManager.mm" "$ROOT/ModEntry.mm"
)
OBJECTS=()
for source in "${SOURCES[@]}"; do
  base="$(basename "$source")"
  object="$OUT/obj/${base%.*}.o"
  EXTRA_FLAGS=()
  case "$source" in
    *.mm) EXTRA_FLAGS+=("-fobjc-arc") ;;
  esac
  "$CXX" -isysroot "$SDKROOT" -I"$ROOT" $CXXFLAGS "${EXTRA_FLAGS[@]}" -c "$source" -o "$object"
  OBJECTS+=("$object")
done

"$AR" -rcs "$OUT/libPoolDebugOverlay.a" "${OBJECTS[@]}"
echo "Built $OUT/libPoolDebugOverlay.a for $SDK ($CONFIG)"


```

## CMakeLists.txt

```text
cmake_minimum_required(VERSION 3.16)
project(pool_physics_sandbox LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
option(POOL_ENABLE_SFML "Build the optional SFML visualizer" OFF)
option(POOL_BUILD_OVERLAY "Build the GLFW/OpenGL trajectory overlay" ON)

add_executable(pool_sandbox
    main.cpp Config.cpp Prediction.cpp PhysicsSimulator.cpp BatchRunner.cpp
    TrajectoryRenderer.cpp)
target_include_directories(pool_sandbox PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})
if (POOL_ENABLE_SFML)
    find_package(SFML 2.5 COMPONENTS graphics window system REQUIRED)
    target_compile_definitions(pool_sandbox PRIVATE POOL_ENABLE_SFML=1)
    target_link_libraries(pool_sandbox PRIVATE sfml-graphics sfml-window sfml-system)
endif()

if (POOL_BUILD_OVERLAY)
    find_package(OpenGL REQUIRED)
    find_package(glfw3 3.3 REQUIRED)
    add_executable(trajectory_overlay
        overlay_main.cpp Renderer.cpp IPCClient.cpp config_loader.cpp)
    target_include_directories(trajectory_overlay PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})
    if (TARGET glfw)
        target_link_libraries(trajectory_overlay PRIVATE glfw OpenGL::GL)
    else()
        target_link_libraries(trajectory_overlay PRIVATE glfw3::glfw OpenGL::GL)
    endif()
endif()


```

## config_loader.cpp

```cpp
#include "config_loader.h"
#include <cctype>
#include <cstdlib>
#include <fstream>
#include <map>
#include <sstream>
#include <stdexcept>
namespace { struct J{enum T{N,Num,B,Str,Obj,Arr}t=N;double n=0;bool b=false;std::string s;std::map<std::string,J>o;std::vector<J>a;const J&at(const std::string&k)const{auto i=o.find(k);if(i==o.end())throw std::runtime_error("missing JSON key: "+k);return i->second;}};
class P{const std::string&x;size_t i=0;void ws(){while(i<x.size()&&std::isspace((unsigned char)x[i]))++i;}J val(){ws();if(i>=x.size())throw std::runtime_error("unexpected JSON end");if(x[i]=='{')return obj();if(x[i]=='[')return arr();if(x[i]=='\"')return str();if(x.compare(i,4,"true")==0){i+=4;J z;z.t=J::B;z.b=true;return z;}if(x.compare(i,5,"false")==0){i+=5;J z;z.t=J::B;return z;}if(x.compare(i,4,"null")==0){i+=4;return{};}char*e=nullptr;double n=std::strtod(x.c_str()+i,&e);if(e==x.c_str()+i)throw std::runtime_error("invalid JSON value");i=(size_t)(e-x.c_str());J z;z.t=J::Num;z.n=n;return z;}J str(){J z;z.t=J::Str;++i;while(i<x.size()&&x[i]!='\"'){if(x[i]=='\\'&&i+1<x.size())++i;z.s+=x[i++];}if(i==x.size())throw std::runtime_error("unterminated JSON string");++i;return z;}J arr(){J z;z.t=J::Arr;++i;ws();if(i<x.size()&&x[i]==']'){++i;return z;}for(;;){z.a.push_back(val());ws();if(i<x.size()&&x[i]==']'){++i;return z;}if(i>=x.size()||x[i++]!=',')throw std::runtime_error("expected JSON comma");}}J obj(){J z;z.t=J::Obj;++i;ws();if(i<x.size()&&x[i]=='}'){++i;return z;}for(;;){ws();J k=str();ws();if(i>=x.size()||x[i++]!=':')throw std::runtime_error("expected JSON colon");z.o[k.s]=val();ws();if(i<x.size()&&x[i]=='}'){++i;return z;}if(i>=x.size()||x[i++]!=',')throw std::runtime_error("expected JSON comma");}}public:explicit P(const std::string&s):x(s){}J parse(){return val();}};
float f(const J&j){return(float)j.n;}std::array<float,4> color(const J&j){std::array<float,4>c{0,0,0,1};for(size_t i=0;i<j.a.size()&&i<4;++i)c[i]=f(j.a[i]);return c;}}
OverlayConfig loadOverlayConfig(const std::string&path){std::ifstream in(path);if(!in)throw std::runtime_error("cannot open overlay config: "+path);std::stringstream ss;ss<<in.rdbuf();std::string raw=ss.str();J r=P(raw).parse();OverlayConfig c;const J&t=r.at("table");c.tableWidth=f(t.at("width"));c.tableHeight=f(t.at("height"));c.ballRadius=f(t.at("ballRadius"));c.pocketRadius=f(t.at("pocketRadius"));for(const J&p:t.at("pockets").a)c.pockets.push_back({p.at("x").n,p.at("y").n});const J&w=r.at("window");c.windowWidth=(int)w.at("width").n;c.windowHeight=(int)w.at("height").n;c.windowX=(int)w.at("x").n;c.windowY=(int)w.at("y").n;c.opacity=f(w.at("opacity"));c.clickThrough=w.at("clickThrough").b;const J&co=r.at("colors");c.table=color(co.at("table"));c.rail=color(co.at("rail"));c.pocket=color(co.at("pocket"));c.trajectory=color(co.at("trajectory"));c.ball=color(co.at("ball"));c.cue=color(co.at("cue"));c.statusOn=color(co.at("statusOn"));c.statusOff=color(co.at("statusOff"));return c;}


```

## config_loader.h

```cpp
#pragma once
#include <array>
#include <string>
#include <vector>
struct OverlayPoint { double x=0,y=0; };
struct OverlayConfig { double tableWidth=100,tableHeight=50,ballRadius=1.5,pocketRadius=3.2; std::vector<OverlayPoint> pockets; int windowWidth=1200,windowHeight=650,windowX=-1,windowY=-1; float opacity=.88f; bool clickThrough=false; std::array<float,4> table{.08f,.35f,.19f,.92f},rail{.45f,.24f,.08f,.95f},pocket{.01f,.01f,.01f,.98f},trajectory{1,.85f,.18f,.75f},ball{.92f,.18f,.12f,1},cue{1,1,1,1},statusOn{.15f,1,.25f,1},statusOff{1,.2f,.1f,1}; };
OverlayConfig loadOverlayConfig(const std::string& path);


```

## Config.cpp

```cpp
#include "Config.h"
#include <fstream>
#include <sstream>
#include <stdexcept>
#include <cctype>
#include <map>
#include <cstdlib>

namespace {
struct J { enum T{N,B,Num,Str,Obj,Arr} t=N; double n=0; std::string s; std::map<std::string,J> o; std::vector<J> a;
 const J& at(const std::string& k) const { auto i=o.find(k); if(i==o.end()) throw std::runtime_error("missing JSON key: "+k); return i->second; }
};
class P { const std::string& x; size_t i=0; void ws(){while(i<x.size()&&std::isspace((unsigned char)x[i]))++i;}
 J val(){ws(); if(i>=x.size()) throw std::runtime_error("unexpected end of JSON"); if(x[i]=='{')return obj(); if(x[i]=='[')return arr(); if(x[i]=='\"')return str(); if(x.compare(i,4,"null")==0){i+=4;return{};} if(x.compare(i,4,"true")==0){i+=4;J z;z.t=J::B;z.n=1;return z;} if(x.compare(i,5,"false")==0){i+=5;J z;z.t=J::B;return z;} char* e=nullptr; double n=std::strtod(x.c_str()+i,&e); if(e==x.c_str()+i)throw std::runtime_error("invalid JSON value"); i=(size_t)(e-x.c_str()); J z;z.t=J::Num;z.n=n;return z;}
 J str(){J z;z.t=J::Str;++i;while(i<x.size()&&x[i]!='\"'){if(x[i]=='\\'&&i+1<x.size())++i;z.s+=x[i++];}if(i>=x.size())throw std::runtime_error("unterminated string");++i;return z;}
 J arr(){J z;z.t=J::Arr;++i;ws();if(i<x.size()&&x[i]==']'){++i;return z;}for(;;){z.a.push_back(val());ws();if(i<x.size()&&x[i]==']'){++i;return z;}if(i>=x.size()||x[i++]!=',')throw std::runtime_error("expected array comma");}}
 J obj(){J z;z.t=J::Obj;++i;ws();if(i<x.size()&&x[i]=='}'){++i;return z;}for(;;){ws();J k=str();ws();if(i>=x.size()||x[i++]!=':')throw std::runtime_error("expected colon");z.o[k.s]=val();ws();if(i<x.size()&&x[i]=='}'){++i;return z;}if(i>=x.size()||x[i++]!=',')throw std::runtime_error("expected object comma");}}
 public: explicit P(const std::string& s):x(s){} J parse(){return val();}
};
double num(const J& j,const std::string& k){return j.at(k).n;}
}
SimulationConfig loadConfig(const std::string& path){
 std::ifstream f(path);if(!f)throw std::runtime_error("cannot open config: "+path);std::stringstream b;b<<f.rdbuf();J r=P(b.str()).parse();SimulationConfig c;
 const J&t=r.at("table");c.table.width=num(t,"width");c.table.height=num(t,"height");
 for(const J&p:t.at("pockets").a)c.table.pockets.push_back({num(p,"x"),num(p,"y")});
 for(const J&bll:r.at("balls").a){BallConfig b;b.index=(int)num(bll,"index");b.position={num(bll,"x"),num(bll,"y")};c.balls.push_back(b);}
 const J&s=r.at("shot");c.shot.angle=num(s,"angle");c.shot.power=num(s,"power");const J&sp=s.at("spin");c.shot.spin={num(sp,"x"),num(sp,"y"),num(sp,"z")};return c;
}


```

## Config.h

```cpp
#pragma once
#include <string>
#include <vector>
#include "Prediction.h"

struct SimulationConfig { Table table; std::vector<BallConfig> balls; Shot shot; };
SimulationConfig loadConfig(const std::string& path);



```

## config.json

```json
{
  "table": { "width": 100.0, "height": 50.0,
    "pockets": [{"x":0,"y":0},{"x":50,"y":0},{"x":100,"y":0},{"x":0,"y":50},{"x":50,"y":50},{"x":100,"y":50}] },
  "balls": [
    {"index":0,"classification":"cue","x":25,"y":25},
    {"index":1,"classification":"solid","x":55,"y":25},
    {"index":2,"classification":"solid","x":58,"y":23},
    {"index":3,"classification":"stripe","x":58,"y":27}
  ],
  "shot": { "angle": 0.0, "power": 120.0, "spin": {"x":0.0,"y":0.0,"z":0.0} }
}


```

## config.plist

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>table</key><dict>
    <key>width</key><real>100.0</real><key>height</key><real>50.0</real>
    <key>ballRadius</key><real>1.5</real><key>pocketRadius</key><real>3.2</real>
    <key>pockets</key><array>
      <dict><key>x</key><real>0</real><key>y</key><real>0</real></dict>
      <dict><key>x</key><real>50</real><key>y</key><real>0</real></dict>
      <dict><key>x</key><real>100</real><key>y</key><real>0</real></dict>
      <dict><key>x</key><real>0</real><key>y</key><real>50</real></dict>
      <dict><key>x</key><real>50</real><key>y</key><real>50</real></dict>
      <dict><key>x</key><real>100</real><key>y</key><real>50</real></dict>
    </array>
  </dict>
  <key>balls</key><array>
    <dict><key>index</key><integer>0</integer><key>x</key><real>25</real><key>y</key><real>25</real></dict>
    <dict><key>index</key><integer>1</integer><key>x</key><real>55</real><key>y</key><real>25</real></dict>
    <dict><key>index</key><integer>2</integer><key>x</key><real>58</real><key>y</key><real>23</real></dict>
    <dict><key>index</key><integer>3</integer><key>x</key><real>58</real><key>y</key><real>27</real></dict>
  </array>
  <key>mapping</key><dict><key>scaleFactor</key><real>0</real><key>translationX</key><real>20</real><key>translationY</key><real>40</real></dict>
  <key>colors</key><dict>
    <key>table</key><string>#155C32E8</string><key>rail</key><string>#733D14F2</string><key>pocket</key><string>#080808FA</string>
    <key>trajectory</key><string>#FFE033BF</string><key>ball</key><string>#EB2E1FFF</string><key>cue</key><string>#FFFFFFFF</string>
    <key>statusOn</key><string>#26FF40FF</string><key>statusOff</key><string>#FF3326FF</string>
  </dict>
  <key>LiveData</key><dict>
    <key>enabled</key><false/>
    <key>sharedMemoryName</key><string>/pool_trajectory_live</string>
    <key>bufferSize</key><integer>65536</integer>
    <key>staleAfterMilliseconds</key><integer>1000</integer>
  </dict>
</dict>
</plist>


```

## IOS_INTEGRATION.md

```markdown
# iOS integration

## Files to add to Xcode

Add these files to the application target:

- `PhysicsEngine.h/.mm`
- `ShotResultSnapshot.h/.mm`
- `TrajectoryOverlayView.h/.mm`
- `ViewController.mm`
- `config.plist`

Add the existing C++ engine sources or its static library. The wrapper currently targets this repository's public C++ types from `Prediction.h`, `Config.h`, and `PhysicsSimulator.h`.

## Xcode settings

Set:

- `Compile Sources As`: `Objective-C++` for `.mm` files.
- `C++ Language Dialect`: `C++17`.
- `C++ Standard Library`: ` libc++`.
- `Header Search Paths`: directory containing the C++ engine headers.
- `Library Search Paths`: directory containing the static library.
- `Other Linker Flags`: `-lc++` and the engine library, for example `-lPoolPhysics`.
- `Info.plist`: no special permissions are required for the in-process engine.

No bridging header is required. Objective-C++ files import the C++ headers directly, while UIKit-facing headers expose only Objective-C classes.

Ensure the static library includes the active iOS architectures (`arm64` device and the simulator architecture used by the project). If the library is a prebuilt archive, use an XCFramework when distributing across device and simulator builds.

## View controller wiring

The supplied `ViewController.mm` creates the engine, loads `config.plist` from the application bundle, configures the overlay, and adds it above the main view. It also creates angle and power sliders and sends updates through the engine's serial physics queue.

The overlay defaults to `userInteractionEnabled = NO`, so the application's controls receive touches. A double-tap toggles its visibility.

## Snapshot/threading model

`PhysicsEngine` has:

- A serial Grand Central Dispatch queue for simulations.
- A mutex protecting the simulator pointer and latest snapshot.
- Immutable `ShotResultSnapshot` objects returned to the main/UI thread.

The UI never reads C++ vectors directly. A completed simulation is converted to Foundation arrays on the physics queue and published atomically under the mutex.

## Coordinate mapping

The plist's `mapping` dictionary contains:

- `scaleFactor`: pixels per world unit; `0` automatically fits the table to the view.
- `translationX` and `translationY`: screen-space origin.

The table, pockets, trajectories, and balls all use the same world-to-screen transform.



```

## IPA_REFERENCE_NOTES.md

```markdown
# Reference inspection notes

The supplied IPA was inspected as an archive only. The bundle contains:

- `tableBase*.png/.plist` with table-hole, corner-hole, center-hole, and table-line assets.
- `tableCushions*.png/.plist` with separate top/side rebound regions.
- `ball0` through `ball15` assets plus `ball1000/1001` variants.
- Distinct sound assets for weak/strong cue collisions and cushion collisions.
- `GamePowerGauge`, spin-wheel, and cue-related UI resources.

No readable physics source implementation was present in the bundle inventory. The standalone harness therefore uses the reference asset organization as a geometry/modeling guide while keeping all simulation code independent of the app bundle. Table coordinates are normalized to the configured `width` and `height`, with ball radius, pocket radius, cushion restitution, rolling drag, collision events, spin curvature, and deterministic sampling exposed in the native simulator.



```

## IPCClient.cpp

```cpp
#include "IPCClient.h"
#include <chrono>
#include <cctype>
#include <cstdlib>
#include <map>
#include <thread>
#include <utility>
#ifdef _WIN32
#define NOMINMAX
#include <windows.h>
#else
#include <cstdio>
#include <sys/socket.h>
#include <sys/un.h>
#include <unistd.h>
#endif
namespace { struct J { enum T{N,Num,B,Str,Obj,Arr} t=N; double n=0; bool b=false; std::string s; std::map<std::string,J> o; std::vector<J> a; const J* get(const std::string&k)const{auto i=o.find(k);return i==o.end()?nullptr:&i->second;} };
class P { const std::string&x; size_t i=0; void w(){while(i<x.size()&&std::isspace((unsigned char)x[i]))++i;} J v(){w();if(i>=x.size())throw 1;if(x[i]=='{')return O();if(x[i]=='[')return A();if(x[i]=='\"')return S();if(x.compare(i,4,"true")==0){i+=4;J z;z.t=J::B;z.b=true;return z;}if(x.compare(i,5,"false")==0){i+=5;J z;z.t=J::B;return z;}char*e=nullptr;double n=std::strtod(x.c_str()+i,&e);if(e==x.c_str()+i)throw 1;i=(size_t)(e-x.c_str());J z;z.t=J::Num;z.n=n;return z;}J S(){J z;z.t=J::Str;++i;while(i<x.size()&&x[i]!='\"'){if(x[i]=='\\'&&i+1<x.size())++i;z.s+=x[i++];}if(i>=x.size())throw 1;++i;return z;}J A(){J z;z.t=J::Arr;++i;w();if(i<x.size()&&x[i]==']'){++i;return z;}for(;;){z.a.push_back(v());w();if(i<x.size()&&x[i]==']'){++i;return z;}if(i>=x.size()||x[i++]!=',')throw 1;}}J O(){J z;z.t=J::Obj;++i;w();if(i<x.size()&&x[i]=='}'){++i;return z;}for(;;){J k=S();w();if(i>=x.size()||x[i++]!=':')throw 1;z.o[k.s]=v();w();if(i<x.size()&&x[i]=='}'){++i;return z;}if(i>=x.size()||x[i++]!=',')throw 1;}}public:explicit P(const std::string&s):x(s){}J parse(){return v();}}; }
IPCClient::IPCClient(std::string e):endpoint_(std::move(e)){} IPCClient::~IPCClient(){stop();}
void IPCClient::start(){if(!running_.exchange(true))thread_=std::thread(&IPCClient::worker,this);} void IPCClient::stop(){if(running_.exchange(false)&&thread_.joinable())thread_.join();}
bool IPCClient::latest(OverlayFrame&out)const{if(!hasFrame_)return false;std::lock_guard<std::mutex>g(mutex_);out=frame_;return true;}
bool IPCClient::parse(const std::string&line,OverlayFrame&out)const{try{J r=P(line).parse();if(const J*j=r.get("shotState"))out.shotState=j->b;if(const J*j=r.get("pocketStatus"))for(const J&q:j->a)out.pocketStatus.push_back(q.b);const J*bs=r.get("balls");if(!bs)return false;for(const J&q:bs->a){OverlayBall b;b.index=(int)q.get("index")->n;auto point=[](const J*j){return OverlayPoint{j->get("x")->n,j->get("y")->n};};if(const J*j=q.get("initialPosition"))b.initialPosition=point(j);if(const J*j=q.get("predictedPosition"))b.predictedPosition=point(j);if(const J*j=q.get("onTable"))b.onTable=j->b;if(const J*j=q.get("positions"))for(const J&p:j->a)b.positions.push_back(point(&p));out.balls.push_back(std::move(b));}return true;}catch(...){return false;}}
void IPCClient::worker(){while(running_){std::string pending;
#ifdef _WIN32
HANDLE h=CreateFileA(endpoint_.c_str(),GENERIC_READ,0,nullptr,OPEN_EXISTING,0,nullptr);if(h==INVALID_HANDLE_VALUE){std::this_thread::sleep_for(std::chrono::milliseconds(250));continue;}char buf[8192];DWORD n=0,available=0;while(running_){if(!PeekNamedPipe(h,nullptr,0,nullptr,&available,nullptr)){break;}if(!available){std::this_thread::sleep_for(std::chrono::milliseconds(16));continue;}if(!ReadFile(h,buf,sizeof(buf),&n,nullptr)||!n)break;pending.append(buf,n);size_t p;while((p=pending.find('\n'))!=std::string::npos){OverlayFrame f;if(parse(pending.substr(0,p),f)){std::lock_guard<std::mutex>g(mutex_);frame_=std::move(f);hasFrame_=true;}pending.erase(0,p+1);}}CloseHandle(h);
#else
int fd=socket(AF_UNIX,SOCK_STREAM,0);if(fd<0){std::this_thread::sleep_for(std::chrono::milliseconds(250));continue;}sockaddr_un a{};a.sun_family=AF_UNIX;std::snprintf(a.sun_path,sizeof(a.sun_path),"%s",endpoint_.c_str());if(connect(fd,(sockaddr*)&a,sizeof(a))<0){close(fd);std::this_thread::sleep_for(std::chrono::milliseconds(250));continue;}char buf[8192];ssize_t n;while(running_&&(n=recv(fd,buf,sizeof(buf),0))>0){pending.append(buf,(size_t)n);size_t p;while((p=pending.find('\n'))!=std::string::npos){OverlayFrame f;if(parse(pending.substr(0,p),f)){std::lock_guard<std::mutex>g(mutex_);frame_=std::move(f);hasFrame_=true;}pending.erase(0,p+1);}}close(fd);
#endif
}}


```

## IPCClient.h

```cpp
#pragma once
#include "config_loader.h"
#include <atomic>
#include <mutex>
#include <string>
#include <thread>
struct OverlayBall { int index=0; OverlayPoint initialPosition,predictedPosition; std::vector<OverlayPoint> positions; bool onTable=true; };
struct OverlayFrame { std::vector<OverlayBall> balls; bool shotState=false; std::vector<bool> pocketStatus; };
class IPCClient { public: explicit IPCClient(std::string endpoint); ~IPCClient(); void start(); void stop(); bool latest(OverlayFrame&out)const; private: void worker(); bool parse(const std::string&,OverlayFrame&)const; std::string endpoint_; std::atomic<bool>running_{false}; std::thread thread_; mutable std::mutex mutex_; OverlayFrame frame_; std::atomic<bool>hasFrame_{false}; };


```

## LIVE_DATA_INTEGRATION.md

```markdown
# Live data adapter

The iOS overlay now supports two data sources selected by `config.plist`:

- `LiveData.enabled = false`: the existing `PhysicsEngine` drives the overlay.
- `LiveData.enabled = true`: `LiveDataAdapter` reads the shared-memory frame and the drawing layer remains unchanged.

## Shared-memory protocol

`SharedMemoryWriter.h` is the protocol definition shared by the producer and reader. The fixed frame contains:

- Magic and version fields.
- A seqlock sequence number.
- Nanosecond timestamp.
- Up to 16 balls.
- Up to 480 positions per ball in the default 64 KB frame.
- Predicted positions and on-table flags.
- Six pocket-status bytes.
- Shot-state byte.

The writer publishes an odd sequence before copying and an even sequence after copying. The reader copies only when the sequence is even and unchanged before and after the copy. This prevents the UI from observing a partially written frame without requiring a process-shared mutex.

## Producer usage

```cpp
#include "SharedMemoryWriter.h"

PoolLive::SharedMemoryWriter writer("/pool_trajectory_live");
if (writer.open()) {
    PoolLive::TrajectoryFrame frame{};
    frame.magic = PoolLive::kMagic;
    frame.version = PoolLive::kVersion;
    frame.ballCount = 1;
    frame.positionCounts[0] = 2;
    frame.positions[0][0][0] = 25.0f;
    frame.positions[0][0][1] = 25.0f;
    frame.positions[0][1][0] = 40.0f;
    frame.positions[0][1][1] = 25.0f;
    frame.predictedPositions[0][0] = 40.0f;
    frame.predictedPositions[0][1] = 25.0f;
    frame.onTable[0] = 1;
    frame.shotState = 1;
    writer.writeFrame(frame);
}
```

The iOS reader uses `shm_open` and `mmap` with the configured name. The reader retains the last valid snapshot. Before the first valid frame it returns an empty snapshot, so the overlay draws only its configured table layer and status state.

## Xcode integration

Add these files to the app target:

- `LiveDataAdapter.h/.mm`
- `SharedMemoryWriter.h/.cpp` for producer targets only
- The previously added snapshot and overlay files

Compile the Objective-C++ files as Objective-C++, use C++17 and `libc++`, and include the directory containing `PhysicsSimulator.h` and `Prediction.h`.

Set the plist section like this:

```xml
<key>LiveData</key>
<dict>
    <key>enabled</key><true/>
    <key>sharedMemoryName</key><string>/pool_trajectory_live</string>
    <key>bufferSize</key><integer>65536</integer>
</dict>
```

Set `enabled` to `false` to return to simulated mode. The overlay view's rendering code is the same in both modes.


```

## LiveDataAdapter.h

```cpp
#import <Foundation/Foundation.h>
#import "ShotResultSnapshot.h"

NS_ASSUME_NONNULL_BEGIN
@interface LiveDataAdapter : NSObject
+ (instancetype)sharedAdapter;
- (BOOL)configureWithDictionary:(NSDictionary *)dictionary error:(NSError * _Nullable * _Nullable)error;
- (void)startReading;
- (void)stopReading;
- (ShotResultSnapshot *)getLatestSnapshot;
- (BOOL)isLiveDataAvailable;
@end
NS_ASSUME_NONNULL_END


```

## LiveDataAdapter.mm

```objective-cpp
#import "LiveDataAdapter.h"
#include "SharedMemoryWriter.h"
#include <algorithm>
#include <atomic>
#include <chrono>
#include <cstring>
#include <fcntl.h>
#include <map>
#include <memory>
#include <mutex>
#include <sys/mman.h>
#include <sys/stat.h>
#include <thread>
#include <unistd.h>

static NSError *LiveError(NSString *s){return [NSError errorWithDomain:@"PoolLiveData" code:1 userInfo:@{NSLocalizedDescriptionKey:s}];}
static uint64_t LiveNowMs(){return (uint64_t)std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::steady_clock::now().time_since_epoch()).count();}
@interface LiveDataAdapter(){std::mutex _mutex;std::thread _thread;std::atomic<bool> _running;std::atomic<bool> _available;std::atomic<uint64_t> _lastReceiveMs;NSString *_name;NSUInteger _bufferSize;NSUInteger _staleAfterMs;void *_mapping;int _fd;ShotResultSnapshot *_latest;}@end
@implementation LiveDataAdapter
+(instancetype)sharedAdapter{static LiveDataAdapter*a;static dispatch_once_t once;dispatch_once(&once,^{a=[LiveDataAdapter new];});return a;}
-(instancetype)init{if((self=[super init])){_running=false;_available=false;_lastReceiveMs=0;_staleAfterMs=1000;_mapping=nullptr;_fd=-1;_bufferSize=sizeof(PoolLive::TrajectoryFrame);}return self;}
-(BOOL)configureWithDictionary:(NSDictionary*)dictionary error:(NSError**)error{NSDictionary*d=dictionary[@"LiveData"];if(![d isKindOfClass:NSDictionary.class]){if(error)*error=LiveError(@"Missing LiveData dictionary");return NO;}NSString*n=d[@"sharedMemoryName"];NSNumber*s=d[@"bufferSize"];if(![n isKindOfClass:NSString.class]||!s){if(error)*error=LiveError(@"LiveData requires sharedMemoryName and bufferSize");return NO;}if(_running)[self stopReading];_name=[n copy];_bufferSize=MAX((NSUInteger)s.unsignedIntegerValue,sizeof(PoolLive::TrajectoryFrame));_staleAfterMs=MAX((NSUInteger)[d[@"staleAfterMilliseconds"] unsignedIntegerValue],(NSUInteger)1);return YES;}
-(void)startReading{if(_running.exchange(true))return;_thread=std::thread([self]{[self readLoop];});}
-(void)stopReading{if(!_running.exchange(false))return;if(_thread.joinable())_thread.join();if(_mapping){munmap(_mapping,_bufferSize);_mapping=nullptr;}if(_fd>=0){close(_fd);_fd=-1;}_available=false;}
-(BOOL)isLiveDataAvailable{return _available.load()&&LiveNowMs()-_lastReceiveMs.load()<=_staleAfterMs;}
-(ShotResultSnapshot*)getLatestSnapshot{if(![self isLiveDataAvailable])return [[ShotResultSnapshot alloc]initWithBalls:@[] pocketedBallIndices:@[] pocketStatus:@[] shotState:NO settled:NO duration:0 collisionCount:0];std::lock_guard<std::mutex>g(_mutex);return _latest?[_latest copy]:[[ShotResultSnapshot alloc]initWithBalls:@[] pocketedBallIndices:@[] pocketStatus:@[] shotState:NO settled:NO duration:0 collisionCount:0];}
-(void)readLoop{while(_running){if(!_mapping){_fd=shm_open(_name.UTF8String,O_RDONLY,0600);if(_fd<0){std::this_thread::sleep_for(std::chrono::milliseconds(100));continue;}_mapping=mmap(nullptr,_bufferSize,PROT_READ,MAP_SHARED,_fd,0);if(_mapping==MAP_FAILED){_mapping=nullptr;close(_fd);_fd=-1;std::this_thread::sleep_for(std::chrono::milliseconds(100));continue;}}
        auto*frame=static_cast<const PoolLive::TrajectoryFrame*>(_mapping);PoolLive::TrajectoryFrame copy{};uint64_t before=__atomic_load_n(&frame->sequence,__ATOMIC_ACQUIRE);if(before&&!(before&1)&&frame->magic==PoolLive::kMagic&&frame->version==PoolLive::kVersion){std::memcpy(&copy,frame,sizeof(copy));uint64_t after=__atomic_load_n(&frame->sequence,__ATOMIC_ACQUIRE);if(before==after&&!(after&1)){NSMutableArray*balls=[NSMutableArray array];uint32_t count=std::min(copy.ballCount,PoolLive::kMaxBalls);for(uint32_t i=0;i<count;++i){uint32_t points=std::min(copy.positionCounts[i],PoolLive::kMaxPositions);NSMutableArray*positions=[NSMutableArray arrayWithCapacity:points];for(uint32_t j=0;j<points;++j)[positions addObject:[NSValue valueWithCGPoint:CGPointMake(copy.positions[i][j][0],copy.positions[i][j][1])]];CGPoint predicted=CGPointMake(copy.predictedPositions[i][0],copy.predictedPositions[i][1]);if(points&&copy.predictedPositions[i][0]==0&&copy.predictedPositions[i][1]==0)predicted=positions.lastObject.CGPointValue;[balls addObject:[[BallTrajectorySnapshot alloc]initWithIndex:i positions:positions predictedPosition:predicted onTable:copy.onTable[i]!=0]];}NSMutableArray*status=[NSMutableArray arrayWithCapacity:6];for(int i=0;i<6;++i)[status addObject:@(copy.pocketStatus[i]!=0)];ShotResultSnapshot*s=[[ShotResultSnapshot alloc]initWithBalls:balls pocketedBallIndices:@[] pocketStatus:status shotState:copy.shotState!=0 settled:YES duration:0 collisionCount:0];{std::lock_guard<std::mutex>g(_mutex);_latest=s;}_lastReceiveMs=LiveNowMs();_available=true;}}std::this_thread::sleep_for(std::chrono::milliseconds(8));}}
-(void)dealloc{[self stopReading];}
@end


```

## main.cpp

```cpp
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



```

## ModEntry.mm

```objective-cpp
#import <UIKit/UIKit.h>
#import "OverlayManager.h"

static void KAKUStartInAppModule(void) { dispatch_async(dispatch_get_main_queue(),^{ NSLog(@"KAKU DEV: starting in-app physics overlay"); [[OverlayManager sharedManager] start]; }); }
__attribute__((constructor)) static void KAKUModuleConstructor(void) { dispatch_async(dispatch_get_main_queue(),^{ dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(1.0*NSEC_PER_SEC)),dispatch_get_main_queue(),^{ KAKUStartInAppModule(); }); }); }


```

## MODULE_README.md

```markdown
# Pool debug overlay module

This module is the in-app orchestration layer for the existing simulator and live shared-memory adapter. It is intended to be added to an iOS application that owns the physics engine and its data providers.

## Components

- `ModEntry.mm` schedules startup on the main queue after launch.
- `OverlayManager` creates a transparent alert-level `UIWindow`, installs the overlay, and owns gesture controls.
- `PredictionLoop` is a callback-driven C++17 worker running at approximately 60 Hz. The host supplies `ActiveProvider` and `ShotProvider` callbacks, so the module remains decoupled from any particular view controller or data model.
- `TrajectoryOverlayView` remains the renderer and can use `LiveDataAdapter` through its `liveModeEnabled` property.
- `LiveDataAdapter` consumes the fixed binary seqlock frame defined by `SharedMemoryWriter.h`.

## Integrating into an app

Add the module `.mm` and `.cpp` files to the application target, set C++ language dialect to C++17, and use `libc++`. Add `config.plist` to the application bundle. The constructor schedules `OverlayManager` startup on the main queue; normal app lifecycle code can also call:

```objc
[[OverlayManager sharedManager] start];
```

For live mode, set `LiveData.enabled` to `true` in the plist. The overlay then reads `LiveDataAdapter` snapshots and clears after the configured stale interval.

## Starting the prediction loop

Create `PredictionLoop` from the app-owned `PhysicsSimulator` and `SharedMemoryWriter`, then supply callbacks for app-owned active state and shot parameters:

```cpp
auto loop = std::make_unique<PredictionLoop>(
    [] { return appState.isSimulationActive(); },
    [] { return appState.currentShot(); },
    simulator,
    writer);
loop->start();
```

The loop only publishes when the shot changes. It preserves the previous values and sleeps against a steady-clock deadline to avoid cumulative timing drift.

## Build

The supplied script builds a normal iOS static library; it does not alter or inject into another application:

```bash
chmod +x build_module.sh
SDK=iphonesimulator ./build_module.sh
SDK=iphoneos ./build_module.sh
```

The app target should link the resulting `libPoolDebugOverlay.a` and the iOS frameworks already used by the app (`UIKit`, `CoreGraphics`, and `QuartzCore`). For device and simulator distribution, package the two builds as an XCFramework.

## Gestures

- Double-tap toggles overlay visibility.
- Press and hold for two seconds opens the placeholder control alert.
- Gesture recognizers use `cancelsTouchesInView = NO`.



```

## OVERLAY_BUILD.md

```markdown
# Trajectory overlay build and protocol

## Linux

Install GLFW 3.x and OpenGL development packages, then build:

```bash
cmake -S . -B build -DPOOL_BUILD_OVERLAY=ON
cmake --build build --target trajectory_overlay -j
./build/trajectory_overlay --config overlay_config.json --pipe /tmp/trajectory_pipe
```

The endpoint is a Unix-domain stream socket. The producer sends one complete JSON object per line. The overlay reconnects automatically if the producer restarts.

## Windows

Install GLFW 3.x and an OpenGL development toolchain, then configure from a Visual Studio developer prompt:

```powershell
cmake -S . -B build -DPOOL_BUILD_OVERLAY=ON
cmake --build build --config Release --target trajectory_overlay
build\Release\trajectory_overlay.exe --config overlay_config.json --pipe "\\.\pipe\trajectory"
```

The Windows endpoint is a byte-mode named pipe. The overlay reconnects automatically when the pipe is unavailable.

## Controls

- `R`: reload `overlay_config.json`.
- `T`: toggle click-through on Windows. Linux keeps the window interactive because compositor-specific input-region APIs differ.

## Producer message

Send newline-delimited JSON matching the simulator shape. `positions` is the polyline drawn for each ball; `predictedPosition` is the displayed ball location; `shotState` controls the green/red status indicator; and `pocketStatus` controls the small indicators in the configured pockets.


```

## overlay_config.json

```json
{
  "table": { "width": 100.0, "height": 50.0, "ballRadius": 1.5, "pocketRadius": 3.2,
    "pockets": [{"x":0,"y":0},{"x":50,"y":0},{"x":100,"y":0},{"x":0,"y":50},{"x":50,"y":50},{"x":100,"y":50}] },
  "window": { "width": 1200, "height": 650, "x": -1, "y": -1, "opacity": 0.88, "clickThrough": false },
  "colors": { "table": [0.08,0.35,0.19,0.92], "rail": [0.45,0.24,0.08,0.95], "pocket": [0.01,0.01,0.01,0.98], "trajectory": [1.0,0.85,0.18,0.75], "ball": [0.92,0.18,0.12,1.0], "cue": [1.0,1.0,1.0,1.0], "statusOn": [0.15,1.0,0.25,1.0], "statusOff": [1.0,0.2,0.1,1.0] }
}


```

## overlay_main.cpp

```cpp
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


```

## OverlayManager.h

```cpp
#import <UIKit/UIKit.h>
@interface OverlayManager : NSObject
+ (instancetype)sharedManager;
+ (void)showOverlay;
+ (void)hideOverlay;
+ (void)toggleOverlay;
+ (BOOL)isOverlayVisible;
+ (void)setupGestures;
+ (void)handleDoubleTap:(UITapGestureRecognizer *)gesture;
+ (void)handleLongPress:(UILongPressGestureRecognizer *)gesture;
- (void)start;
@end


```

## OverlayManager.mm

```objective-cpp
#import "OverlayManager.h"
#import "PhysicsEngine.h"
#import "TrajectoryOverlayView.h"
#import "LiveDataAdapter.h"

@interface OverlayManager () { UIWindow *_window; TrajectoryOverlayView *_overlay; BOOL _visible; UITapGestureRecognizer *_doubleTap; UILongPressGestureRecognizer *_longPress; } @end
@interface OverlayHostController : UIViewController @end
@implementation OverlayHostController
- (BOOL)prefersStatusBarHidden{return YES;}
- (UIStatusBarStyle)preferredStatusBarStyle{return UIStatusBarStyleLightContent;}
@end

@implementation OverlayManager
+ (instancetype)sharedManager { static OverlayManager*m; static dispatch_once_t once; dispatch_once(&once,^{m=[OverlayManager new];}); return m; }
+ (void)showOverlay { [[self sharedManager] show]; }
+ (void)hideOverlay { [[self sharedManager] hide]; }
+ (void)toggleOverlay { [[self sharedManager] toggle]; }
+ (BOOL)isOverlayVisible { return [self sharedManager]->_visible; }
+ (void)setupGestures { [[self sharedManager] installGestures]; }
+ (void)handleDoubleTap:(UITapGestureRecognizer*)g { if(g.state==UIGestureRecognizerStateRecognized)[self toggleOverlay]; }
+ (void)handleLongPress:(UILongPressGestureRecognizer*)g { if(g.state==UIGestureRecognizerStateBegan){UIAlertController*a=[UIAlertController alertControllerWithTitle:@"Physics Overlay" message:@"Live trajectory overlay is active." preferredStyle:UIAlertControllerStyleAlert];[a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];UIViewController*root=[UIApplication sharedApplication].keyWindow.rootViewController;[root presentViewController:a animated:YES completion:nil];} }
- (void)start { dispatch_async(dispatch_get_main_queue(),^{[self createWindowIfNeeded];[self installGestures];[self show];}); }
- (void)createWindowIfNeeded { if(_window)return;UIWindowScene*scene=nil;for(UIScene*s in UIApplication.sharedApplication.connectedScenes)if(s.activationState==UISceneActivationStateForegroundActive&&[s isKindOfClass:UIWindowScene.class]){scene=(UIWindowScene*)s;break;}if(!scene)return;NSString*path=[[NSBundle mainBundle]pathForResource:@"config" ofType:@"plist"];NSDictionary*c=[NSDictionary dictionaryWithContentsOfFile:path]?:@{};NSError*error=nil;[PhysicsEngine.sharedEngine configureWithPlistDictionary:c error:&error];if(error)NSLog(@"KAKU DEV: config %@",error);_window=[[UIWindow alloc]initWithWindowScene:scene];_window.frame=scene.screen.bounds;_window.windowLevel=UIWindowLevelAlert+1;_window.backgroundColor=UIColor.clearColor;_window.rootViewController=[OverlayHostController new];_overlay=[[TrajectoryOverlayView alloc]initWithFrame:_window.bounds configuration:c engine:PhysicsEngine.sharedEngine];_overlay.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;_overlay.liveModeEnabled=[c[@"LiveData"][@"enabled"] boolValue];[_window.rootViewController.view addSubview:_overlay];}
- (void)installGestures {if(!_window)return;UIView*host=[UIApplication sharedApplication].keyWindow.rootViewController.view;if(!host)return;_doubleTap=[[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(doubleTap:)];_doubleTap.numberOfTapsRequired=2;_doubleTap.cancelsTouchesInView=NO;[host addGestureRecognizer:_doubleTap];_longPress=[[UILongPressGestureRecognizer alloc]initWithTarget:self action:@selector(longPress:)];_longPress.minimumPressDuration=2;_longPress.cancelsTouchesInView=NO;[host addGestureRecognizer:_longPress];}
- (void)doubleTap:(UITapGestureRecognizer*)g{[[self class]handleDoubleTap:g];}
- (void)longPress:(UILongPressGestureRecognizer*)g{[[self class]handleLongPress:g];}
- (void)show{[self createWindowIfNeeded];_window.hidden=NO;_visible=YES;}
- (void)hide{_window.hidden=YES;_visible=NO;}
- (void)toggle{_visible?[self hide]:[self show];}
@end


```

## PhysicsEngine.h

```cpp
#import <Foundation/Foundation.h>
#import "ShotResultSnapshot.h"

NS_ASSUME_NONNULL_BEGIN

@interface PhysicsEngine : NSObject
+ (instancetype)sharedEngine;
- (BOOL)configureWithPlistDictionary:(NSDictionary *)dictionary error:(NSError * _Nullable * _Nullable)error;
- (void)updateWithAngle:(double)angle
                  power:(double)power
                 spinX:(double)spinX
                 spinY:(double)spinY;
- (nullable ShotResultSnapshot *)getLatestResult;
@end

NS_ASSUME_NONNULL_END


```

## PhysicsEngine.mm

```objective-cpp
#import "PhysicsEngine.h"
#include "PhysicsSimulator.h"
#include <cmath>
#include <memory>
#include <mutex>

static NSError *EngineError(NSString *message) { return [NSError errorWithDomain:@"PoolPhysicsEngine" code:1 userInfo:@{NSLocalizedDescriptionKey:message}]; }
static double Number(NSDictionary *d, NSString *key, BOOL *ok) { id v=d[key]; if (![v respondsToSelector:@selector(doubleValue)]) { *ok=NO; return 0; } return [v doubleValue]; }
static Point2D PointFromObject(NSDictionary *d, BOOL *ok) { return {Number(d,@"x",ok),Number(d,@"y",ok)}; }

@interface PhysicsEngine () { std::mutex _stateMutex; std::shared_ptr<PhysicsSimulator> _simulator; ShotResultSnapshot *_latest; dispatch_queue_t _queue; Table _table; std::vector<BallConfig> _balls; BOOL _configured; } @end

@implementation PhysicsEngine
+ (instancetype)sharedEngine { static PhysicsEngine *engine; static dispatch_once_t once; dispatch_once(&once, ^{ engine=[PhysicsEngine new]; }); return engine; }
- (instancetype)init { if ((self=[super init])) { _queue=dispatch_queue_create("com.internal.pool.physics", DISPATCH_QUEUE_SERIAL); _configured=NO; } return self; }
- (BOOL)configureWithPlistDictionary:(NSDictionary *)root error:(NSError **)error {
    @try {
        NSDictionary *table=root[@"table"]; NSArray *pockets=table[@"pockets"]; NSArray *balls=root[@"balls"]; BOOL ok=YES;
        if (![table isKindOfClass:NSDictionary.class]||![pockets isKindOfClass:NSArray.class]||![balls isKindOfClass:NSArray.class]) ok=NO;
        if (!ok) { if(error)*error=EngineError(@"config.plist requires table, pockets, and balls"); return NO; }
        Table t; t.width=Number(table,@"width",&ok); t.height=Number(table,@"height",&ok); if(table[@"ballRadius"])t.ballRadius=Number(table,@"ballRadius",&ok); if(table[@"pocketRadius"])t.pocketRadius=Number(table,@"pocketRadius",&ok);
        std::vector<BallConfig> b; for(NSDictionary *p in pockets) { if(![p isKindOfClass:NSDictionary.class]){ok=NO;break;} t.pockets.push_back(PointFromObject(p,&ok)); }
        for(NSDictionary *item in balls){ if(![item isKindOfClass:NSDictionary.class]){ok=NO;break;} BallConfig bc; bc.index=(int)Number(item,@"index",&ok); bc.position=PointFromObject(item,&ok); b.push_back(bc); }
        if(!ok||t.width<=0||t.height<=0||b.empty()){if(error)*error=EngineError(@"invalid numeric value in config.plist");return NO;}
        auto simulator=std::make_shared<PhysicsSimulator>(SimulationConfig{t,b,Shot{}}); { std::lock_guard<std::mutex> lock(_stateMutex); _table=t; _balls=b; _simulator=simulator; _configured=YES; _latest.reset(); } return YES;
    } @catch(NSException *e) { if(error)*error=EngineError(e.reason ?: @"config error"); return NO; }
}
- (void)updateWithAngle:(double)angle power:(double)power spinX:(double)spinX spinY:(double)spinY {
    std::shared_ptr<PhysicsSimulator> sim; { std::lock_guard<std::mutex> lock(_stateMutex); sim=_simulator; }
    if(!sim) return; dispatch_async(_queue, ^{ Shot shot; shot.angle=angle; shot.power=power; shot.spin={spinX,spinY,0}; ShotResult result=sim->runPrediction(shot); NSMutableArray *balls=[NSMutableArray array];
        for(const auto &sample:result.trajectory.empty()?std::vector<TrajectorySample>{}:std::vector<TrajectorySample>{result.trajectory.back()}) { for(const auto &b:sample.balls) { NSMutableArray *positions=[NSMutableArray array]; for(const auto &p:result.trajectory){ for(const auto &bp:p.balls) if(bp.index==b.index) { [positions addObject:[NSValue valueWithCGPoint:CGPointMake(bp.position.x,bp.position.y)]]; break; } } [balls addObject:[[BallTrajectorySnapshot alloc] initWithIndex:b.index positions:positions predictedPosition:CGPointMake(b.position.x,b.position.y) onTable:b.onTable]]; } }
        NSMutableArray *pocketStatus=[NSMutableArray arrayWithCapacity:6]; for(int i=0;i<6;++i)[pocketStatus addObject:@NO]; NSMutableArray *pocketed=[NSMutableArray array]; for(int id:result.pocketed){[pocketed addObject:@(id)];} ShotResultSnapshot *snapshot=[[ShotResultSnapshot alloc] initWithBalls:balls pocketedBallIndices:pocketed pocketStatus:pocketStatus shotState:result.settled settled:result.settled duration:result.duration collisionCount:result.collisions.size()]; { std::lock_guard<std::mutex> lock(self->_stateMutex); self->_latest=snapshot; } });
}
- (ShotResultSnapshot *)getLatestResult { std::lock_guard<std::mutex> lock(_stateMutex); return _latest ? [_latest copy] : nil; }
@end


```

## PhysicsSimulator.cpp

```cpp
#include "PhysicsSimulator.h"
ShotResult PhysicsSimulator::runPrediction(const Shot&s,double interval){std::lock_guard<std::mutex> lock(mutex_);Prediction p(config_.table,config_.balls);return p.simulate(s,interval);}



```

## PhysicsSimulator.h

```cpp
#pragma once
#include "Config.h"
#include <mutex>
#include <utility>
class PhysicsSimulator { SimulationConfig config_; mutable std::mutex mutex_; public: explicit PhysicsSimulator(SimulationConfig c):config_(std::move(c)){} ShotResult runPrediction(const Shot& shot,double sampleInterval=0.02); const SimulationConfig& config()const{return config_;} };


```

## Prediction.cpp

```cpp
#include "Prediction.h"
#include <cmath>
#include <algorithm>
#include <stdexcept>
namespace { double len(Point2D a){return std::hypot(a.x,a.y);} Point2D add(Point2D a,Point2D b){return{a.x+b.x,a.y+b.y};} Point2D mul(Point2D a,double k){return{a.x*k,a.y*k};} }
Prediction::Prediction(const Table&t,const std::vector<BallConfig>&b):table_(t),initial_(b){}
ShotResult Prediction::simulate(const Shot& shot,double si){
 struct B{int id;Point2D p,v;Vector3D spin;bool on=true;}; std::vector<B> bs;for(auto&x:initial_)bs.push_back({x.index,x.position,{0,0},{0,0,0},true});
 auto cue=std::find_if(bs.begin(),bs.end(),[](const B&b){return b.id==0;});if(cue==bs.end())throw std::runtime_error("config has no cue ball (index 0)");
 cue->v={std::cos(shot.angle)*shot.power,std::sin(shot.angle)*shot.power};cue->spin=shot.spin;ShotResult out;double t=0,next=0;const double dt=0.004;const double stop=0.35;
 auto sample=[&](){TrajectorySample s;s.time=t;for(auto&b:bs)s.balls.push_back({b.id,b.p,b.on});out.trajectory.push_back(std::move(s));};sample();
 for(int step=0;step<250000&&t<60;++step){t+=dt; bool moving=false;
  for(auto&b:bs)if(b.on){double speed=len(b.v);Point2D tangent={-b.v.y,b.v.x};double curve=0.0009*shot.spin.z*speed; b.v=add(b.v,mul(tangent,curve*dt));b.p=add(b.p,mul(b.v,dt));double damp=std::pow(0.985,dt*60.0);b.v=mul(b.v,damp);b.spin.z*=0.999;
   if(b.p.x<table_.ballRadius||b.p.x>table_.width-table_.ballRadius){b.p.x=std::clamp(b.p.x,table_.ballRadius,table_.width-table_.ballRadius);b.v.x*=-0.92;out.collisions.push_back({t,"cushion",b.id,-1,b.p});}
   if(b.p.y<table_.ballRadius||b.p.y>table_.height-table_.ballRadius){b.p.y=std::clamp(b.p.y,table_.ballRadius,table_.height-table_.ballRadius);b.v.y*=-0.92;out.collisions.push_back({t,"cushion",b.id,-1,b.p});}
   for(auto&p:table_.pockets)if(len({b.p.x-p.x,b.p.y-p.y})<table_.pocketRadius){b.on=false;b.v={0,0};out.pocketed.push_back(b.id);out.collisions.push_back({t,"pocket",b.id,-1,p});break;} if(len(b.v)>0.05)moving=true;}
  for(size_t i=0;i<bs.size();++i)for(size_t j=i+1;j<bs.size();++j)if(bs[i].on&&bs[j].on){Point2D d={bs[j].p.x-bs[i].p.x,bs[j].p.y-bs[i].p.y};double dist=len(d),minD=2*table_.ballRadius;if(dist>0&&dist<minD){Point2D n=mul(d,1/dist);double rel=(bs[i].v.x-bs[j].v.x)*n.x+(bs[i].v.y-bs[j].v.y)*n.y;if(rel>0){bs[i].v=add(bs[i].v,mul(n,-rel));bs[j].v=add(bs[j].v,mul(n,rel));}double push=(minD-dist)/2;bs[i].p=add(bs[i].p,mul(n,-push));bs[j].p=add(bs[j].p,mul(n,push));out.collisions.push_back({t,"ball",bs[i].id,bs[j].id,bs[i].p});}}
  if(t>=next){sample();next+=si;}if(!moving){out.settled=true;break;}
 }out.duration=t;legacy_.clear();for(auto&s:out.trajectory)for(auto&b:s.balls){legacy_.push_back((float)b.position.x);legacy_.push_back((float)b.position.y);}return out;
}
float* Prediction::getShotResult(){return legacy_.empty()?nullptr:legacy_.data();}int Prediction::getShotResultSize()const{return(int)legacy_.size();}
bool Prediction::determineShotResult(double a,double p,const Point2D&spin){Vector3D s{spin.x,spin.y,0};simulate({a,p,s});return true;}


```

## Prediction.h

```cpp
#pragma once
#include <vector>
#include <string>

struct Point2D { double x=0,y=0; };
struct Vector3D { double x=0,y=0,z=0; };
struct BallConfig { int index=0; Point2D position; };
struct Table { double width=100,height=50; double ballRadius=1.5,pocketRadius=3.2; std::vector<Point2D> pockets; };
struct Shot { double angle=0,power=0; Vector3D spin; };
struct BallSample { int index; Point2D position; bool onTable; };
struct TrajectorySample { double time; std::vector<BallSample> balls; };
struct CollisionEvent { double time; std::string type; int a=-1,b=-1; Point2D position; };
struct ShotResult { bool settled=false; double duration=0; std::vector<TrajectorySample> trajectory; std::vector<CollisionEvent> collisions; std::vector<int> pocketed; };

class Prediction {
public:
 Prediction(const Table& table, const std::vector<BallConfig>& balls);
 ShotResult simulate(const Shot& shot, double sampleInterval=0.02);
 float* getShotResult(); int getShotResultSize() const;
 bool determineShotResult(double angle,double power,const Point2D& spin);
private: Table table_; std::vector<BallConfig> initial_; std::vector<float> legacy_;
};



```

## PredictionLoop.cpp

```cpp
#include "PredictionLoop.h"
#include <chrono>
#include <algorithm>
#include <cmath>
#include <cstring>
#include <memory>
#include <utility>
PredictionLoop::PredictionLoop(ActiveProvider a,ShotProvider s,std::shared_ptr<PhysicsSimulator>p,std::shared_ptr<PoolLive::SharedMemoryWriter>w):active_(std::move(a)),shot_(std::move(s)),simulator_(std::move(p)),writer_(std::move(w)){}
PredictionLoop::~PredictionLoop(){stop();}
void PredictionLoop::start(){if(!running_.exchange(true))thread_=std::thread(&PredictionLoop::run,this);}
void PredictionLoop::stop(){if(running_.exchange(false)&&thread_.joinable())thread_.join();}
void PredictionLoop::run(){Shot previous{};bool havePrevious=false;auto next=std::chrono::steady_clock::now();while(running_){next+=std::chrono::milliseconds(16);if(active_&&active_()&&simulator_&&writer_&&writer_->isOpen()){Shot current=shot_?shot_():Shot{};bool changed=!havePrevious||std::abs(current.angle-previous.angle)>1e-9||std::abs(current.power-previous.power)>1e-6||std::abs(current.spin.x-previous.spin.x)>1e-6||std::abs(current.spin.y-previous.spin.y)>1e-6||std::abs(current.spin.z-previous.spin.z)>1e-6;if(changed){ShotResult result=simulator_->runPrediction(current);PoolLive::TrajectoryFrame frame{};frame.magic=PoolLive::kMagic;frame.version=PoolLive::kVersion;frame.timestampNanoseconds=(uint64_t)std::chrono::duration_cast<std::chrono::nanoseconds>(std::chrono::steady_clock::now().time_since_epoch()).count();if(!result.trajectory.empty()){const auto&last=result.trajectory.back();frame.ballCount=(uint32_t)std::min<size_t>(last.balls.size(),PoolLive::kMaxBalls);for(uint32_t i=0;i<frame.ballCount;++i){frame.positionCounts[i]=0;for(const auto&sample:result.trajectory){for(const auto&b:sample.balls)if(b.index==(int)i&&frame.positionCounts[i]<PoolLive::kMaxPositions){frame.positions[i][frame.positionCounts[i]++]={(float)b.position.x,(float)b.position.y};break;}}frame.predictedPositions[i]={(float)last.balls[i].position.x,(float)last.balls[i].position.y};frame.onTable[i]=last.balls[i].onTable?1:0;}}frame.shotState=result.settled?1:0;for(const auto&event:result.collisions)if(event.type=="pocket"){for(uint32_t i=0;i<PoolLive::kPocketCount;++i){if(i<6)frame.pocketStatus[i]=1;break;}}writer_->writeFrame(frame);previous=current;havePrevious=true;}}std::this_thread::sleep_until(next);if(std::chrono::steady_clock::now()>next+std::chrono::milliseconds(100))next=std::chrono::steady_clock::now();}}


```

## PredictionLoop.h

```cpp
#pragma once
#include "Prediction.h"
#include "SharedMemoryWriter.h"
#include <atomic>
#include <functional>
#include <memory>
#include <thread>

class PredictionLoop {
public:
    using ActiveProvider = std::function<bool()>;
    using ShotProvider = std::function<Shot()>;
    PredictionLoop(ActiveProvider active, ShotProvider shot, std::shared_ptr<PhysicsSimulator> simulator, std::shared_ptr<PoolLive::SharedMemoryWriter> writer);
    ~PredictionLoop();
    void start();
    void stop();
private:
    void run();
    ActiveProvider active_; ShotProvider shot_; std::shared_ptr<PhysicsSimulator> simulator_; std::shared_ptr<PoolLive::SharedMemoryWriter> writer_; std::atomic<bool> running_{false}; std::thread thread_;
};


```

## README.md

```markdown
# Pool Physics Sandbox

Standalone C++17 harness for deterministic pool-shot simulation. It has no game-client, process-memory, or platform-specific dependencies.

## Build

```powershell
cmake -S . -B build
cmake --build build --config Release
```

Headless single shot:

```powershell
build\Release\pool_sandbox.exe --config config.json --headless --output result.json
```

Batch run:

```powershell
build\Release\pool_sandbox.exe --config config.json --random 1000 --output batch.json
```

The batch seed is fixed to `12345` for reproducibility. The simulator uses a fixed integration step, elastic equal-mass ball collisions, cushion restitution, rolling drag, spin-induced lateral curvature, and pocket capture.

For the optional SFML window, install SFML 2.5+ and configure with `-DPOOL_ENABLE_SFML=ON`. Left-click on the table to aim from the cue ball; click distance controls power. Without SFML, `--ui` prints a compact trajectory preview.


```

## Renderer.cpp

```cpp
#include "Renderer.h"
#include <GLFW/glfw3.h>
#ifdef _WIN32
#define GLFW_EXPOSE_NATIVE_WIN32
#include <GLFW/glfw3native.h>
#include <windows.h>
#endif
#include <algorithm>
#include <cmath>
#include <iostream>
#include <stdexcept>
namespace { void color(const std::array<float,4>&c){glColor4f(c[0],c[1],c[2],c[3]);} }
Renderer::Renderer(std::string c,std::string e):configPath_(std::move(c)),endpoint_(std::move(e)),ipc_(endpoint_){config_=loadOverlayConfig(configPath_);clickThrough_=config_.clickThrough;}
static void circle(double x,double y,double r){glBegin(GL_TRIANGLE_FAN);glVertex2d(x,y);for(int i=0;i<=32;++i){double a=i*6.283185307/32;glVertex2d(x+std::cos(a)*r,y+std::sin(a)*r);}glEnd();}
static void rounded(double w,double h,double r){glBegin(GL_LINE_STRIP);for(int k=0;k<4;++k){double cx=k==0?r:k==1?w-r:k==2?w-r:r,cy=k<2?r:h-r;for(int i=0;i<=12;++i){double a=(k*1.570796326)+i*1.570796326/12;glVertex2d(cx+std::cos(a)*r,cy+std::sin(a)*r);}}glEnd();}
static void digit(int n,double x,double y,double s){static const int mask[10]={63,6,91,79,102,109,125,7,127,111};int m=mask[std::clamp(n,0,9)];const double q=s*.55;auto seg=[&](int bit,double x1,double y1,double x2,double y2){if(m&(1<<bit)){glVertex2d(x+x1*s,y+y1*s);glVertex2d(x+x2*s,y+y2*s);}};glBegin(GL_LINES);seg(0,.1,0,.9,0);seg(1,.9,0,.9,1);seg(2,.9,1,.9,2);seg(3,.1,2,.9,2);seg(4,.1,1,.1,2);seg(5,.1,0,.1,1);seg(6,.1,1,.9,1);glEnd();(void)q;}
void Renderer::draw(const OverlayFrame&f){double W=config_.tableWidth,H=config_.tableHeight;glClearColor(0,0,0,0);glClear(GL_COLOR_BUFFER_BIT);glLineWidth(2);color(config_.rail);rounded(W,H,.9);glLineWidth(1);
 color(config_.table);glBegin(GL_QUADS);glVertex2d(0,0);glVertex2d(W,0);glVertex2d(W,H);glVertex2d(0,H);glEnd();for(const auto&p:config_.pockets){color(config_.pocket);circle(p.x,p.y,config_.pocketRadius);}
 for(const auto&b:f.balls){if(b.positions.size()>1){color(config_.trajectory);glBegin(GL_LINE_STRIP);for(const auto&p:b.positions)glVertex2d(p.x,p.y);glEnd();}if(b.onTable){color(b.index==0?config_.cue:config_.ball);circle(b.predictedPosition.x,b.predictedPosition.y,config_.ballRadius);color(config_.rail);digit(std::abs(b.index)%10,b.predictedPosition.x-config_.ballRadius*.4,b.predictedPosition.y-config_.ballRadius*.65,config_.ballRadius*.8);}}
 color(f.shotState?config_.statusOn:config_.statusOff);circle(W*.5,H*.03,config_.ballRadius*.55);for(size_t i=0;i<f.pocketStatus.size()&&i<config_.pockets.size();++i){color(f.pocketStatus[i]?config_.statusOn:config_.statusOff);circle(config_.pockets[i].x,config_.pockets[i].y,config_.ballRadius*.25);}}
void Renderer::toggleClickThrough(void*ptr){
#ifdef _WIN32
 HWND h=glfwGetWin32Window(static_cast<GLFWwindow*>(ptr));LONG s=GetWindowLong(h,GWL_EXSTYLE);SetWindowLong(h,GWL_EXSTYLE,s^(WS_EX_TRANSPARENT|WS_EX_LAYERED));
#else
 (void)ptr;
#endif
 clickThrough_=!clickThrough_;
}
int Renderer::run(){if(!glfwInit())throw std::runtime_error("GLFW initialization failed");glfwWindowHint(GLFW_DECORATED,GLFW_FALSE);glfwWindowHint(GLFW_FLOATING,GLFW_TRUE);glfwWindowHint(GLFW_TRANSPARENT_FRAMEBUFFER,GLFW_TRUE);GLFWwindow*w=glfwCreateWindow(config_.windowWidth,config_.windowHeight,"Trajectory Overlay",nullptr,nullptr);if(!w){glfwTerminate();throw std::runtime_error("cannot create transparent GLFW window");}glfwSetWindowOpacity(w,config_.opacity);if(config_.windowX>=0&&config_.windowY>=0)glfwSetWindowPos(w,config_.windowX,config_.windowY);glfwMakeContextCurrent(w);glfwSwapInterval(1);glOrtho(0,config_.tableWidth,config_.tableHeight,0,-1,1);glEnable(GL_BLEND);glBlendFunc(GL_SRC_ALPHA,GL_ONE_MINUS_SRC_ALPHA);ipc_.start();OverlayFrame frame;bool previousT=false;while(!glfwWindowShouldClose(w)){if(ipc_.latest(frame))draw(frame);else{glClearColor(0,0,0,0);glClear(GL_COLOR_BUFFER_BIT);}if(glfwGetKey(w,GLFW_KEY_R)==GLFW_PRESS){try{config_=loadOverlayConfig(configPath_);glfwSetWindowOpacity(w,config_.opacity);}catch(const std::exception&e){std::cerr<<e.what()<<'\n';}}bool tDown=glfwGetKey(w,GLFW_KEY_T)==GLFW_PRESS;if(tDown&&!previousT)toggleClickThrough(w);previousT=tDown;glfwSwapBuffers(w);glfwPollEvents();}ipc_.stop();glfwDestroyWindow(w);glfwTerminate();return 0;}


```

## Renderer.h

```cpp
#pragma once
#include "IPCClient.h"
#include "config_loader.h"
#include <string>
#include <utility>
class Renderer { public: Renderer(std::string configPath,std::string endpoint); int run(); private: std::string configPath_,endpoint_; OverlayConfig config_; IPCClient ipc_; bool clickThrough_=false; void draw(const OverlayFrame&); void toggleClickThrough(void* window); };


```

## SharedMemoryWriter.cpp

```cpp
#include "SharedMemoryWriter.h"
#include <algorithm>
#include <cstring>
#include <utility>
#ifdef _WIN32
#include <windows.h>
#else
#include <fcntl.h>
#include <sys/mman.h>
#include <unistd.h>
#endif
namespace PoolLive {
SharedMemoryWriter::SharedMemoryWriter(std::string n,std::size_t s):name_(std::move(n)),bufferSize_(std::max(s,sizeof(TrajectoryFrame))){}
SharedMemoryWriter::~SharedMemoryWriter(){close();}
bool SharedMemoryWriter::open(){
#ifdef _WIN32
    (void)name_; return false;
#else
    if(isOpen())return true; fd_=shm_open(name_.c_str(),O_CREAT|O_RDWR,0600);if(fd_<0)return false;if(ftruncate(fd_,(off_t)bufferSize_)!=0){::close(fd_);fd_=-1;return false;}mapping_=mmap(nullptr,bufferSize_,PROT_READ|PROT_WRITE,MAP_SHARED,fd_,0);if(mapping_==MAP_FAILED){mapping_=nullptr;::close(fd_);fd_=-1;return false;}std::memset(mapping_,0,bufferSize_);return true;
#endif
}
void SharedMemoryWriter::close(){
#ifdef _WIN32
#else
    if(mapping_){munmap(mapping_,bufferSize_);mapping_=nullptr;}if(fd_>=0){::close(fd_);fd_=-1;}
#endif
}
bool SharedMemoryWriter::isOpen()const{return mapping_!=nullptr;}
bool SharedMemoryWriter::writeFrame(const TrajectoryFrame&input){if(!isOpen()||input.magic!=kMagic||input.version!=kVersion)return false;auto*out=static_cast<TrajectoryFrame*>(mapping_);uint64_t old=__atomic_load_n(&out->sequence,__ATOMIC_ACQUIRE);uint64_t begin=(old%2)?old+1:old+1;__atomic_store_n(&out->sequence,begin,__ATOMIC_RELEASE);TrajectoryFrame copy=input;copy.sequence=begin;std::memcpy(out,&copy,sizeof(copy));__atomic_store_n(&out->sequence,begin+1,__ATOMIC_RELEASE);return true;}
}


```

## SharedMemoryWriter.h

```cpp
#pragma once
#include <cstddef>
#include <cstdint>
#include <string>

namespace PoolLive {
constexpr uint32_t kMagic = 0x504F4F4Cu; // POOL
constexpr uint32_t kVersion = 1;
constexpr uint32_t kMaxBalls = 16;
constexpr uint32_t kMaxPositions = 480;
constexpr uint32_t kPocketCount = 6;

#pragma pack(push, 1)
struct TrajectoryFrame {
    uint32_t magic;
    uint32_t version;
    uint64_t sequence; // odd while being written, even when stable
    uint64_t timestampNanoseconds;
    uint32_t ballCount;
    uint32_t positionCounts[kMaxBalls];
    float positions[kMaxBalls][kMaxPositions][2];
    float predictedPositions[kMaxBalls][2];
    uint8_t onTable[kMaxBalls];
    uint8_t pocketStatus[kPocketCount];
    uint8_t shotState;
    uint8_t reserved[7];
};
#pragma pack(pop)

static_assert(sizeof(TrajectoryFrame) <= 65536, "TrajectoryFrame exceeds the default shared buffer");

class SharedMemoryWriter {
public:
    explicit SharedMemoryWriter(std::string name, std::size_t bufferSize = sizeof(TrajectoryFrame));
    ~SharedMemoryWriter();
    bool open();
    void close();
    bool isOpen() const;
    bool writeFrame(const TrajectoryFrame& frame);
private:
    std::string name_;
    std::size_t bufferSize_;
    int fd_ = -1;
    void* mapping_ = nullptr;
};
}


```

## ShotResultSnapshot.h

```cpp
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

@interface BallTrajectorySnapshot : NSObject <NSCopying>
@property(nonatomic, readonly) NSInteger index;
@property(nonatomic, readonly) NSArray<NSValue *> *positions;
@property(nonatomic, readonly) CGPoint predictedPosition;
@property(nonatomic, readonly) BOOL onTable;
- (instancetype)initWithIndex:(NSInteger)index
                     positions:(NSArray<NSValue *> *)positions
             predictedPosition:(CGPoint)predictedPosition
                       onTable:(BOOL)onTable;
@end

@interface ShotResultSnapshot : NSObject <NSCopying>
@property(nonatomic, readonly) NSArray<BallTrajectorySnapshot *> *balls;
@property(nonatomic, readonly) NSArray<NSNumber *> *pocketedBallIndices;
@property(nonatomic, readonly) NSArray<NSNumber *> *pocketStatus;
@property(nonatomic, readonly) BOOL shotState;
@property(nonatomic, readonly) BOOL settled;
@property(nonatomic, readonly) NSTimeInterval duration;
@property(nonatomic, readonly) NSUInteger collisionCount;
- (instancetype)initWithBalls:(NSArray<BallTrajectorySnapshot *> *)balls
           pocketedBallIndices:(NSArray<NSNumber *> *)pocketedBallIndices
                  pocketStatus:(NSArray<NSNumber *> *)pocketStatus
                      shotState:(BOOL)shotState
                         settled:(BOOL)settled
                         duration:(NSTimeInterval)duration
                  collisionCount:(NSUInteger)collisionCount;
@end

NS_ASSUME_NONNULL_END


```

## ShotResultSnapshot.mm

```objective-cpp
#import "ShotResultSnapshot.h"

@implementation BallTrajectorySnapshot
- (instancetype)initWithIndex:(NSInteger)i positions:(NSArray<NSValue *> *)p predictedPosition:(CGPoint)q onTable:(BOOL)t {
    if ((self = [super init])) { _index=i; _positions=[p copy]; _predictedPosition=q; _onTable=t; }
    return self;
}
- (id)copyWithZone:(NSZone *)zone { return self; }
@end

@implementation ShotResultSnapshot
- (instancetype)initWithBalls:(NSArray<BallTrajectorySnapshot *> *)b pocketedBallIndices:(NSArray<NSNumber *> *)p pocketStatus:(NSArray<NSNumber *> *)s shotState:(BOOL)st settled:(BOOL)se duration:(NSTimeInterval)d collisionCount:(NSUInteger)c {
    if ((self = [super init])) { _balls=[b copy]; _pocketedBallIndices=[p copy]; _pocketStatus=[s copy]; _shotState=st; _settled=se; _duration=d; _collisionCount=c; }
    return self;
}
- (id)copyWithZone:(NSZone *)zone { return self; }
@end


```

## TrajectoryOverlayView.h

```cpp
#import <UIKit/UIKit.h>
#import "PhysicsEngine.h"

NS_ASSUME_NONNULL_BEGIN
@interface TrajectoryOverlayView : UIView
@property(nonatomic, readonly) NSDictionary *configuration;
@property(nonatomic) BOOL liveModeEnabled;
- (instancetype)initWithFrame:(CGRect)frame configuration:(NSDictionary *)configuration engine:(PhysicsEngine *)engine;
- (void)reloadConfiguration:(NSDictionary *)configuration;
- (void)update;
@end
NS_ASSUME_NONNULL_END


```

## TrajectoryOverlayView.mm

```objective-cpp
#import "TrajectoryOverlayView.h"
#import "LiveDataAdapter.h"
#import <QuartzCore/QuartzCore.h>

static UIColor *ColorFromValue(id value, UIColor *fallback) {
    if ([value isKindOfClass:NSString.class]) {
        NSString *hex=[value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if ([hex hasPrefix:@"#"]) hex=[hex substringFromIndex:1]; unsigned long n=0; [[NSScanner scannerWithString:hex] scanHexLongLong:&n];
        CGFloat r,g,b,a=1; if(hex.length==6){r=((n>>16)&255)/255.0;g=((n>>8)&255)/255.0;b=(n&255)/255.0;}else if(hex.length==8){r=((n>>24)&255)/255.0;g=((n>>16)&255)/255.0;b=((n>>8)&255)/255.0;a=(n&255)/255.0;}else return fallback; return [UIColor colorWithRed:r green:g blue:b alpha:a];
    }
    if ([value isKindOfClass:NSArray.class] && [value count]>=3) { NSArray *v=value; CGFloat r=[v[0] doubleValue],g=[v[1] doubleValue],b=[v[2] doubleValue],a=[v count]>3?[v[3] doubleValue]:1; if(r>1||g>1||b>1){r/=255;g/=255;b/=255;} return [UIColor colorWithRed:r green:g blue:b alpha:a]; }
    return fallback;
}

@interface TrajectoryOverlayView () { CADisplayLink *_displayLink; PhysicsEngine *_engine; LiveDataAdapter *_liveAdapter; BOOL _liveMode; NSDictionary *_configuration; CGFloat _scale; CGPoint _translation; CGFloat _tableWidth,_tableHeight,_ballRadius,_pocketRadius; NSArray *_pockets; UIColor *_tableColor,*_railColor,*_pocketColor,*_trajectoryColor,*_ballColor,*_cueColor,*_statusOn,*_statusOff; } @end

@implementation TrajectoryOverlayView
- (instancetype)initWithFrame:(CGRect)frame configuration:(NSDictionary *)configuration engine:(PhysicsEngine *)engine { if((self=[super initWithFrame:frame])){_engine=engine;self.backgroundColor=UIColor.clearColor;self.opaque=NO;self.userInteractionEnabled=NO;NSDictionary*live=configuration[@"LiveData"];_liveMode=[live[@"enabled"] boolValue];if(_liveMode){_liveAdapter=LiveDataAdapter.sharedAdapter;NSError*error=nil;if(![_liveAdapter configureWithDictionary:configuration error:&error])NSLog(@"Live adapter config failed: %@",error.localizedDescription);else[_liveAdapter startReading];}[self applyConfiguration:configuration];_displayLink=[CADisplayLink displayLinkWithTarget:self selector:@selector(displayTick:)];[_displayLink addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];}return self; }
- (void)dealloc { [_displayLink invalidate]; if(_liveMode)[_liveAdapter stopReading]; }
- (NSDictionary *)configuration{return [_configuration copy];}
- (BOOL)liveModeEnabled{return _liveMode;}
- (void)setLiveModeEnabled:(BOOL)live { _liveMode=live; if(live){_liveAdapter=LiveDataAdapter.sharedAdapter;NSError*error=nil;if([_liveAdapter configureWithDictionary:_configuration error:&error])[_liveAdapter startReading];else NSLog(@"Live adapter config failed: %@",error.localizedDescription);}else[_liveAdapter stopReading];[self setNeedsDisplay]; }
- (void)applyConfiguration:(NSDictionary *)c { _configuration=[c copy];NSDictionary*t=c[@"table"];_tableWidth=[t[@"width"] doubleValue];_tableHeight=[t[@"height"] doubleValue];_ballRadius=[t[@"ballRadius"] doubleValue];_pocketRadius=[t[@"pocketRadius"] doubleValue];_pockets=t[@"pockets"]?:@[];NSDictionary*m=c[@"mapping"]?:@{};_scale=[m[@"scaleFactor"] doubleValue];if(_scale<=0)_scale=MIN(self.bounds.size.width/_tableWidth,self.bounds.size.height/_tableHeight);_translation=CGPointMake([m[@"translationX"] doubleValue],[m[@"translationY"] doubleValue]);NSDictionary*col=c[@"colors"]?:@{};_tableColor=ColorFromValue(col[@"table"],[UIColor colorWithRed:.08 green:.35 blue:.19 alpha:.9]);_railColor=ColorFromValue(col[@"rail"],[UIColor colorWithRed:.45 green:.24 blue:.08 alpha:.95]);_pocketColor=ColorFromValue(col[@"pocket"],UIColor.blackColor);_trajectoryColor=ColorFromValue(col[@"trajectory"],[UIColor yellowColor]);_ballColor=ColorFromValue(col[@"ball"],[UIColor redColor]);_cueColor=ColorFromValue(col[@"cue"],UIColor.whiteColor);_statusOn=ColorFromValue(col[@"statusOn"],[UIColor greenColor]);_statusOff=ColorFromValue(col[@"statusOff"],[UIColor redColor]);[self setNeedsDisplay];}
- (void)reloadConfiguration:(NSDictionary *)configuration{[self applyConfiguration:configuration];}
- (void)displayTick:(CADisplayLink *)link{[self update];}
- (void)update{[self setNeedsDisplay];}
- (CGPoint)screenPoint:(CGPoint)p{return CGPointMake(_translation.x+p.x*_scale,_translation.y+p.y*_scale);}
- (void)drawRect:(CGRect)rect { CGContextRef ctx=UIGraphicsGetCurrentContext();CGContextSaveGState(ctx);CGContextSetAllowsAntialiasing(ctx,YES);UIBezierPath*table=[UIBezierPath bezierPathWithRoundedRect:CGRectMake(_translation.x,_translation.y,_tableWidth*_scale,_tableHeight*_scale) cornerRadius:10];[_tableColor setFill];[table fill];[_railColor setStroke];table.lineWidth=5;[table stroke];
    for(NSDictionary*p in _pockets){CGPoint q=[self screenPoint:CGPointMake([p[@"x"] doubleValue],[p[@"y"] doubleValue])];UIBezierPath*b=[UIBezierPath bezierPathWithOvalInRect:CGRectMake(q.x-_pocketRadius*_scale,q.y-_pocketRadius*_scale,2*_pocketRadius*_scale,2*_pocketRadius*_scale)];[_pocketColor setFill];[b fill];}
    ShotResultSnapshot*snapshot=_liveMode?[_liveAdapter getLatestSnapshot]:[_engine getLatestResult];if(!snapshot){CGContextRestoreGState(ctx);return;}
    for(BallTrajectorySnapshot*b in snapshot.balls){NSArray<NSValue*>*ps=b.positions;if(ps.count>1){UIBezierPath*path=[UIBezierPath bezierPath];[path moveToPoint:[self screenPoint:ps.firstObject.CGPointValue]];for(NSUInteger i=1;i<ps.count;i++){CGPoint a=[self screenPoint:ps[i-1].CGPointValue],z=[self screenPoint:ps[i].CGPointValue];CGPoint mid=CGPointMake((a.x+z.x)/2,(a.y+z.y)/2);[path addQuadCurveToPoint:z controlPoint:mid];}[_trajectoryColor setStroke];path.lineWidth=2;[path stroke];}if(b.onTable){CGPoint q=[self screenPoint:b.predictedPosition];UIBezierPath*ball=[UIBezierPath bezierPathWithOvalInRect:CGRectMake(q.x-_ballRadius*_scale,q.y-_ballRadius*_scale,2*_ballRadius*_scale,2*_ballRadius*_scale)];[(b.index==0?_cueColor:_ballColor) setFill];[ball fill];NSString*label=[NSString stringWithFormat:@"%ld",(long)b.index];NSDictionary*attrs=@{NSFontAttributeName:[UIFont boldSystemFontOfSize:MAX(9,_ballRadius*_scale)],NSForegroundColorAttributeName:_railColor};CGSize size=[label sizeWithAttributes:attrs];[label drawAtPoint:CGPointMake(q.x-size.width/2,q.y-size.height/2) withAttributes:attrs];}}
    UIColor*status=snapshot.shotState?_statusOn:_statusOff;[status setFill];UIBezierPath*indicator=[UIBezierPath bezierPathWithOvalInRect:CGRectMake(self.bounds.size.width-34,14,20,20)];[indicator fill];NSString*text=snapshot.shotState?@"OK":@"FOUL";[text drawAtPoint:CGPointMake(self.bounds.size.width-70,14) withAttributes:@{NSFontAttributeName:[UIFont boldSystemFontOfSize:12],NSForegroundColorAttributeName:status}];for(NSUInteger i=0;i<snapshot.pocketStatus.count&&i<_pockets.count;i++){NSDictionary*p=_pockets[i];CGPoint q=[self screenPoint:CGPointMake([p[@"x"] doubleValue],[p[@"y"] doubleValue])];[(snapshot.pocketStatus[i].boolValue?_statusOn:_statusOff) setFill];UIBezierPath*dot=[UIBezierPath bezierPathWithOvalInRect:CGRectMake(q.x-3,q.y-3,6,6)];[dot fill];}CGContextRestoreGState(ctx);}
@end


```

## TrajectoryRenderer.cpp

```cpp
#include "TrajectoryRenderer.h"
#include <iostream>
#include <algorithm>
#include <cmath>
#ifdef POOL_ENABLE_SFML
#include <SFML/Graphics.hpp>
#endif
int TrajectoryRenderer::run(PhysicsSimulator&sim){
#ifdef POOL_ENABLE_SFML
 sf::RenderWindow w(sf::VideoMode(1000,550),"Pool Physics Sandbox");
 const auto& cfg=sim.config(); Shot shot=cfg.shot; ShotResult result=sim.runPrediction(shot);
 auto screen=[&](Point2D p){return sf::Vector2f(20.f+float(p.x/cfg.table.width*960.f),20.f+float(p.y/cfg.table.height*510.f));};
 auto world=[&](sf::Vector2i p){return Point2D{(p.x-20)/960.0*cfg.table.width,(p.y-20)/510.0*cfg.table.height};};
 while(w.isOpen()){
  sf::Event e;while(w.pollEvent(e)){
   if(e.type==sf::Event::Closed)w.close();
   if(e.type==sf::Event::MouseButtonPressed&&e.mouseButton.button==sf::Mouse::Left){
    auto cue=std::find_if(cfg.balls.begin(),cfg.balls.end(),[](const BallConfig&b){return b.index==0;});
    if(cue!=cfg.balls.end()){Point2D d=world({e.mouseButton.x,e.mouseButton.y});shot.angle=std::atan2(d.y-cue->position.y,d.x-cue->position.x);shot.power=std::clamp(std::hypot(d.x-cue->position.x,d.y-cue->position.y)*12.0,20.0,700.0);result=sim.runPrediction(shot);}}
  }
  w.setTitle("Pool Physics Sandbox | angle="+std::to_string(shot.angle)+" power="+std::to_string(shot.power)+" collisions="+std::to_string(result.collisions.size()));
  w.clear(sf::Color(22,92,53));sf::RectangleShape rail({960,510});rail.setPosition(20,20);rail.setFillColor(sf::Color(35,125,73));rail.setOutlineThickness(10);rail.setOutlineColor(sf::Color(90,50,20));w.draw(rail);
  for(const auto&p:cfg.table.pockets){sf::CircleShape pocket(float(cfg.table.pocketRadius/cfg.table.width*960));pocket.setOrigin(pocket.getRadius(),pocket.getRadius());pocket.setPosition(screen(p));pocket.setFillColor(sf::Color(12,12,12));w.draw(pocket);}
  for(size_t bi=0;bi<cfg.balls.size();++bi){sf::VertexArray line(sf::LineStrip);for(const auto&s:result.trajectory)for(const auto&b:s.balls)if(b.index==cfg.balls[bi].index&&b.on)line.append(sf::Vertex(screen(b.position),sf::Color(240,220,100,110)));w.draw(line);}
  if(!result.trajectory.empty())for(const auto&b:result.trajectory.back().balls)if(b.onTable){sf::CircleShape ball(float(cfg.table.ballRadius/cfg.table.width*960));ball.setOrigin(ball.getRadius(),ball.getRadius());ball.setPosition(screen(b.position));ball.setFillColor(b.index==0?sf::Color::White:sf::Color(220,80,60));w.draw(ball);}
  w.display();
 }return 0;
#else
 auto r=sim.runPrediction(sim.config().shot);std::cout<<"UI was requested, but SFML is disabled. Built-in trajectory preview:\n";for(size_t i=0;i<r.trajectory.size();i+=std::max<size_t>(1,r.trajectory.size()/20)){auto&b=r.trajectory[i].balls.front();std::cout<<b.position.x<<","<<b.position.y<<"\n";}return 0;
#endif
}


```

## TrajectoryRenderer.h

```cpp
#pragma once
#include "PhysicsSimulator.h"
class TrajectoryRenderer { public: static int run(PhysicsSimulator&); };



```

## ViewController.mm

```objective-cpp
#import <UIKit/UIKit.h>
#import <math.h>
#import "TrajectoryOverlayView.h"

@interface ViewController : UIViewController
@property(nonatomic,strong) TrajectoryOverlayView *trajectoryOverlay;
@property(nonatomic,strong) UISlider *angleSlider;
@property(nonatomic,strong) UISlider *powerSlider;
@end

@implementation ViewController
- (void)viewDidLoad { [super viewDidLoad]; self.view.backgroundColor=[UIColor colorWithWhite:.12 alpha:1]; PhysicsEngine *engine=PhysicsEngine.sharedEngine; NSString *path=[[NSBundle mainBundle] pathForResource:@"config" ofType:@"plist"]; NSDictionary *plist=[NSDictionary dictionaryWithContentsOfFile:path]; NSError *error=nil; if(![engine configureWithPlistDictionary:plist error:&error]) NSLog(@"Physics config failed: %@",error.localizedDescription);
    self.trajectoryOverlay=[[TrajectoryOverlayView alloc] initWithFrame:self.view.bounds configuration:plist engine:engine];self.trajectoryOverlay.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;[self.view addSubview:self.trajectoryOverlay];
    self.angleSlider=[[UISlider alloc] initWithFrame:CGRectMake(24,self.view.bounds.size.height-76,self.view.bounds.size.width-48,30)];self.angleSlider.minimumValue=-M_PI;self.angleSlider.maximumValue=M_PI;self.angleSlider.value=0;self.angleSlider.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleTopMargin;[self.angleSlider addTarget:self action:@selector(shotParameterChanged:) forControlEvents:UIControlEventValueChanged];[self.view addSubview:self.angleSlider];
    self.powerSlider=[[UISlider alloc] initWithFrame:CGRectMake(24,self.view.bounds.size.height-42,self.view.bounds.size.width-48,30)];self.powerSlider.minimumValue=20;self.powerSlider.maximumValue=700;self.powerSlider.value=120;self.powerSlider.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleTopMargin;[self.powerSlider addTarget:self action:@selector(shotParameterChanged:) forControlEvents:UIControlEventValueChanged];[self.view addSubview:self.powerSlider];
    UITapGestureRecognizer *doubleTap=[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(toggleOverlay:)];doubleTap.numberOfTapsRequired=2;[self.view addGestureRecognizer:doubleTap];[self shotParameterChanged:nil]; }
- (void)viewDidLayoutSubviews { [super viewDidLayoutSubviews]; self.trajectoryOverlay.frame=self.view.bounds; }
- (void)shotParameterChanged:(id)sender { [PhysicsEngine.sharedEngine updateWithAngle:self.angleSlider.value power:self.powerSlider.value spinX:0 spinY:0]; }
- (void)toggleOverlay:(UITapGestureRecognizer *)gesture { self.trajectoryOverlay.hidden=!self.trajectoryOverlay.hidden; }
@end


```

