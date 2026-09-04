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
 auto optional=[&](const std::string& key,double fallback){auto i=t.o.find(key);return i==t.o.end()?fallback:i->second.n;};
 c.table.ballRadius=optional("ballRadius",c.table.ballRadius); c.table.pocketRadius=optional("pocketRadius",c.table.pocketRadius);
 c.table.ballMass=optional("ballMass",c.table.ballMass); c.table.cueBallMass=optional("cueBallMass",c.table.cueBallMass);
 c.table.friction=optional("friction",c.table.friction); c.table.rollingResistance=optional("rollingResistance",c.table.rollingResistance);
 c.table.cushionElasticity=optional("cushionElasticity",c.table.cushionElasticity); c.table.spinFriction=optional("spinFriction",c.table.spinFriction);
 for(const J&p:t.at("pockets").a)c.table.pockets.push_back({num(p,"x"),num(p,"y")});
 for(const J&bll:r.at("balls").a){BallConfig b;b.index=(int)num(bll,"index");b.position={num(bll,"x"),num(bll,"y")};c.balls.push_back(b);}
 const J&s=r.at("shot");c.shot.angle=num(s,"angle");c.shot.power=num(s,"power");const J&sp=s.at("spin");c.shot.spin={num(sp,"x"),num(sp,"y"),num(sp,"z")};return c;
}
