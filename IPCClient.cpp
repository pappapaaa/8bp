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
