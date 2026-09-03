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
