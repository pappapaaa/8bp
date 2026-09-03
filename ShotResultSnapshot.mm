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
