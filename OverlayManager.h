#import <UIKit/UIKit.h>
@interface OverlayManager : NSObject
+ (instancetype)sharedManager;
+ (void)showOverlay;
+ (void)hideOverlay;
+ (void)toggleOverlay;
+ (BOOL)isOverlayVisible;
+ (void)setupGestures;
+ (void)handleDoubleTap:(UITapGestureRecognizer *)gesture;
+ (void)handleLongPress:(UILongPressGestureRecognizer *)gesture;
- (void)start;
@end
