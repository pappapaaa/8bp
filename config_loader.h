#pragma once
#include <array>
#include <string>
#include <vector>
struct OverlayPoint { double x=0,y=0; };
struct OverlayConfig { double tableWidth=100,tableHeight=50,ballRadius=1.5,pocketRadius=3.2; std::vector<OverlayPoint> pockets; int windowWidth=1200,windowHeight=650,windowX=-1,windowY=-1; float opacity=.88f; bool clickThrough=false; std::array<float,4> table{.08f,.35f,.19f,.92f},rail{.45f,.24f,.08f,.95f},pocket{.01f,.01f,.01f,.98f},trajectory{1,.85f,.18f,.75f},ball{.92f,.18f,.12f,1},cue{1,1,1,1},statusOn{.15f,1,.25f,1},statusOff{1,.2f,.1f,1}; };
OverlayConfig loadOverlayConfig(const std::string& path);
