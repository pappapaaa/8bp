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
