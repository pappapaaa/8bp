#import "PhysicsEngine.h"
#import <UIKit/UIKit.h>
#include "PhysicsSimulator.h"
#include <cmath>
#include <memory>
#include <mutex>
#include "DebugLogger.h"

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
        if(table[@"ballMass"])t.ballMass=Number(table,@"ballMass",&ok); if(table[@"cueBallMass"])t.cueBallMass=Number(table,@"cueBallMass",&ok); if(table[@"friction"])t.friction=Number(table,@"friction",&ok); if(table[@"rollingResistance"])t.rollingResistance=Number(table,@"rollingResistance",&ok); if(table[@"cushionElasticity"])t.cushionElasticity=Number(table,@"cushionElasticity",&ok); if(table[@"spinFriction"])t.spinFriction=Number(table,@"spinFriction",&ok);
        std::vector<BallConfig> b; for(NSDictionary *p in pockets) { if(![p isKindOfClass:NSDictionary.class]){ok=NO;break;} t.pockets.push_back(PointFromObject(p,&ok)); }
        for(NSDictionary *item in balls){ if(![item isKindOfClass:NSDictionary.class]){ok=NO;break;} BallConfig bc; bc.index=(int)Number(item,@"index",&ok); bc.position=PointFromObject(item,&ok); b.push_back(bc); }
        if(!ok||t.width<=0||t.height<=0||b.empty()){if(error)*error=EngineError(@"invalid numeric value in config.plist");return NO;}
        auto simulator=std::make_shared<PhysicsSimulator>(SimulationConfig{t,b,Shot{}}); { std::lock_guard<std::mutex> lock(_stateMutex); _table=t; _balls=b; _simulator=simulator; _configured=YES; _latest=nil; } return YES;
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
