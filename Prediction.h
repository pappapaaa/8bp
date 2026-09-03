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

