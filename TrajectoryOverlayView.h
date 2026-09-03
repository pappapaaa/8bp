#import <UIKit/UIKit.h>
#import "PhysicsEngine.h"

NS_ASSUME_NONNULL_BEGIN
@interface TrajectoryOverlayView : UIView
@property(nonatomic, readonly) NSDictionary *configuration;
@property(nonatomic) BOOL liveModeEnabled;
- (instancetype)initWithFrame:(CGRect)frame configuration:(NSDictionary *)configuration engine:(PhysicsEngine *)engine;
- (void)reloadConfiguration:(NSDictionary *)configuration;
- (void)update;
@end
NS_ASSUME_NONNULL_END
