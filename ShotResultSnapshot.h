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
