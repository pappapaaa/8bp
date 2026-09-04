#include "Prediction.h"
#include <cmath>
#include <algorithm>
#include <stdexcept>
namespace { double len(Point2D a){return std::hypot(a.x,a.y);} Point2D add(Point2D a,Point2D b){return{a.x+b.x,a.y+b.y};} Point2D mul(Point2D a,double k){return{a.x*k,a.y*k};} }
Prediction::Prediction(const Table&t,const std::vector<BallConfig>&b):table_(t),initial_(b){}
bool Prediction::pocketStatus[Prediction::kPocketCount] = {};
ShotResult Prediction::simulate(const Shot& shot,double si){
 struct B{int id;Point2D p,v;Vector3D spin;bool on=true;}; std::vector<B> bs;for(auto&x:initial_)bs.push_back({x.index,x.position,{0,0},{0,0,0},true});
 auto cue=std::find_if(bs.begin(),bs.end(),[](const B&b){return b.id==0;});if(cue==bs.end())throw std::runtime_error("config has no cue ball (index 0)");
 cue->v={std::cos(shot.angle)*shot.power,std::sin(shot.angle)*shot.power};cue->spin=shot.spin;ShotResult out;double t=0,next=0;const double dt=0.004;const double stop=0.35;
 auto sample=[&](){TrajectorySample s;s.time=t;for(auto&b:bs)s.balls.push_back({b.id,b.p,b.on});out.trajectory.push_back(std::move(s));};sample();
 for(int step=0;step<250000&&t<60;++step){t+=dt; bool moving=false;
  for(auto&b:bs)if(b.on){double speed=len(b.v);Point2D tangent={-b.v.y,b.v.x};double curve=0.0009*shot.spin.z*speed; b.v=add(b.v,mul(tangent,curve*dt));b.p=add(b.p,mul(b.v,dt));double damp=std::pow(std::clamp(table_.rollingResistance-table_.friction,0.90,0.99999),dt*60.0);b.v=mul(b.v,damp);b.spin.z*=std::pow(table_.spinFriction,dt*60.0);
   if(b.p.x<table_.ballRadius||b.p.x>table_.width-table_.ballRadius){b.p.x=std::clamp(b.p.x,table_.ballRadius,table_.width-table_.ballRadius);b.v.x*=-table_.cushionElasticity;out.collisions.push_back({t,"cushion",b.id,-1,b.p});}
   if(b.p.y<table_.ballRadius||b.p.y>table_.height-table_.ballRadius){b.p.y=std::clamp(b.p.y,table_.ballRadius,table_.height-table_.ballRadius);b.v.y*=-table_.cushionElasticity;out.collisions.push_back({t,"cushion",b.id,-1,b.p});}
   for(auto&p:table_.pockets)if(len({b.p.x-p.x,b.p.y-p.y})<table_.pocketRadius){b.on=false;b.v={0,0};out.pocketed.push_back(b.id);out.collisions.push_back({t,"pocket",b.id,-1,p});break;} if(len(b.v)>0.05)moving=true;}
  for(size_t i=0;i<bs.size();++i)for(size_t j=i+1;j<bs.size();++j)if(bs[i].on&&bs[j].on){Point2D d={bs[j].p.x-bs[i].p.x,bs[j].p.y-bs[i].p.y};double dist=len(d),minD=2*table_.ballRadius;if(dist>0&&dist<minD){Point2D n=mul(d,1/dist);double rel=(bs[i].v.x-bs[j].v.x)*n.x+(bs[i].v.y-bs[j].v.y)*n.y;if(rel>0){double m1=bs[i].id==0?table_.cueBallMass:table_.ballMass;double m2=bs[j].id==0?table_.cueBallMass:table_.ballMass;double impulse=2*rel/(m1+m2);bs[i].v=add(bs[i].v,mul(n,-impulse*m2));bs[j].v=add(bs[j].v,mul(n,impulse*m1));}double push=(minD-dist)/2;bs[i].p=add(bs[i].p,mul(n,-push));bs[j].p=add(bs[j].p,mul(n,push));out.collisions.push_back({t,"ball",bs[i].id,bs[j].id,bs[i].p});}}
  if(t>=next){sample();next+=si;}if(!moving){out.settled=true;break;}
 }out.duration=t;legacy_.clear();for(auto&s:out.trajectory)for(auto&b:s.balls){legacy_.push_back((float)b.position.x);legacy_.push_back((float)b.position.y);}return out;
}
float* Prediction::getShotResult(){return legacy_.empty()?nullptr:legacy_.data();}int Prediction::getShotResultSize()const{return(int)legacy_.size();}
bool Prediction::determineShotResult(double a,double p,const Point2D&spin){
 Vector3D s{spin.x,spin.y,0};
 ShotResult result=simulate({a,p,s});
 std::fill(std::begin(pocketStatus),std::end(pocketStatus),false);
 for(int index:result.pocketed)if(index>=0&&index<kPocketCount)pocketStatus[index]=true;
 return true;
}
