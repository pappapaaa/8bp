#import "OverlayManager.h"
#import "PhysicsEngine.h"
#import "TrajectoryOverlayView.h"
#import "LiveDataAdapter.h"

@interface OverlayManager () { UIWindow *_window; TrajectoryOverlayView *_overlay; BOOL _visible; UITapGestureRecognizer *_doubleTap; UILongPressGestureRecognizer *_longPress; } @end
@interface OverlayHostController : UIViewController @end
@implementation OverlayHostController
- (BOOL)prefersStatusBarHidden{return YES;}
- (UIStatusBarStyle)preferredStatusBarStyle{return UIStatusBarStyleLightContent;}
@end

@implementation OverlayManager
+ (instancetype)sharedManager { static OverlayManager*m; static dispatch_once_t once; dispatch_once(&once,^{m=[OverlayManager new];}); return m; }
+ (void)showOverlay { [[self sharedManager] show]; }
+ (void)hideOverlay { [[self sharedManager] hide]; }
+ (void)toggleOverlay { [[self sharedManager] toggle]; }
+ (BOOL)isOverlayVisible { return [self sharedManager]->_visible; }
+ (void)setupGestures { [[self sharedManager] installGestures]; }
+ (void)handleDoubleTap:(UITapGestureRecognizer*)g { if(g.state==UIGestureRecognizerStateRecognized)[self toggleOverlay]; }
+ (void)handleLongPress:(UILongPressGestureRecognizer*)g { if(g.state==UIGestureRecognizerStateBegan){UIAlertController*a=[UIAlertController alertControllerWithTitle:@"Physics Overlay" message:@"Live trajectory overlay is active." preferredStyle:UIAlertControllerStyleAlert];[a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];UIViewController*root=[UIApplication sharedApplication].keyWindow.rootViewController;[root presentViewController:a animated:YES completion:nil];} }
- (void)start { dispatch_async(dispatch_get_main_queue(),^{[self createWindowIfNeeded];[self installGestures];[self show];}); }
- (void)createWindowIfNeeded { if(_window)return;UIWindowScene*scene=nil;for(UIScene*s in UIApplication.sharedApplication.connectedScenes)if(s.activationState==UISceneActivationStateForegroundActive&&[s isKindOfClass:UIWindowScene.class]){scene=(UIWindowScene*)s;break;}if(!scene)return;NSString*path=[[NSBundle mainBundle]pathForResource:@"config" ofType:@"plist"];NSDictionary*c=[NSDictionary dictionaryWithContentsOfFile:path]?:@{};NSError*error=nil;[PhysicsEngine.sharedEngine configureWithPlistDictionary:c error:&error];if(error)NSLog(@"KAKU DEV: config %@",error);_window=[[UIWindow alloc]initWithWindowScene:scene];_window.frame=scene.screen.bounds;_window.windowLevel=UIWindowLevelAlert+1;_window.backgroundColor=UIColor.clearColor;_window.rootViewController=[OverlayHostController new];_overlay=[[TrajectoryOverlayView alloc]initWithFrame:_window.bounds configuration:c engine:PhysicsEngine.sharedEngine];_overlay.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;_overlay.liveModeEnabled=[c[@"LiveData"][@"enabled"] boolValue];[_window.rootViewController.view addSubview:_overlay];}
- (void)installGestures {if(!_window)return;UIView*host=[UIApplication sharedApplication].keyWindow.rootViewController.view;if(!host)return;_doubleTap=[[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(doubleTap:)];_doubleTap.numberOfTapsRequired=2;_doubleTap.cancelsTouchesInView=NO;[host addGestureRecognizer:_doubleTap];_longPress=[[UILongPressGestureRecognizer alloc]initWithTarget:self action:@selector(longPress:)];_longPress.minimumPressDuration=2;_longPress.cancelsTouchesInView=NO;[host addGestureRecognizer:_longPress];}
- (void)doubleTap:(UITapGestureRecognizer*)g{[[self class]handleDoubleTap:g];}
- (void)longPress:(UILongPressGestureRecognizer*)g{[[self class]handleLongPress:g];}
- (void)show{[self createWindowIfNeeded];_window.hidden=NO;_visible=YES;}
- (void)hide{_window.hidden=YES;_visible=NO;}
- (void)toggle{_visible?[self hide]:[self show];}
@end
