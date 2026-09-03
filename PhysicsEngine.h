#import <Foundation/Foundation.h>
#import "ShotResultSnapshot.h"

NS_ASSUME_NONNULL_BEGIN

@interface PhysicsEngine : NSObject
+ (instancetype)sharedEngine;
- (BOOL)configureWithPlistDictionary:(NSDictionary *)dictionary error:(NSError * _Nullable * _Nullable)error;
- (void)updateWithAngle:(double)angle
                  power:(double)power
                 spinX:(double)spinX
                 spinY:(double)spinY;
- (nullable ShotResultSnapshot *)getLatestResult;
@end

NS_ASSUME_NONNULL_END
