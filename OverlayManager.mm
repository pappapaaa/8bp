#import "OverlayManager.h"
#import "PhysicsEngine.h"
#import "TrajectoryOverlayView.h"
#import "LiveDataAdapter.h"
#import <QuartzCore/QuartzCore.h>
#include "DebugLogger.h"

@interface OverlayManager () { UIWindow *_window; TrajectoryOverlayView *_overlay; UIView *_menu; BOOL _visible; UITapGestureRecognizer *_doubleTap; UILongPressGestureRecognizer *_longPress; } @end
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
+ (void)handleLongPress:(UILongPressGestureRecognizer*)g { if(g.state==UIGestureRecognizerStateBegan)[[self sharedManager] toggleMenu]; }
- (void)start { dispatch_async(dispatch_get_main_queue(),^{[self createWindowIfNeeded];[self installGestures];[self show];}); }
- (void)createWindowIfNeeded { if(_window)return;UIWindowScene*scene=nil;for(UIScene*s in UIApplication.sharedApplication.connectedScenes)if(s.activationState==UISceneActivationStateForegroundActive&&[s isKindOfClass:UIWindowScene.class]){scene=(UIWindowScene*)s;break;}if(!scene)return;NSString*path=[[NSBundle mainBundle]pathForResource:@"config" ofType:@"plist"];NSDictionary*c=[NSDictionary dictionaryWithContentsOfFile:path]?:@{};NSError*error=nil;[PhysicsEngine.sharedEngine configureWithPlistDictionary:c error:&error];if(error)NSLog(@"KAKU DEV: config %@",error);_window=[[UIWindow alloc]initWithWindowScene:scene];_window.frame=scene.screen.bounds;_window.windowLevel=UIWindowLevelAlert+1;_window.backgroundColor=UIColor.clearColor;_window.rootViewController=[OverlayHostController new];_overlay=[[TrajectoryOverlayView alloc]initWithFrame:_window.bounds configuration:c engine:PhysicsEngine.sharedEngine];_overlay.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;_overlay.liveModeEnabled=[c[@"LiveData"][@"enabled"] boolValue];[_window.rootViewController.view addSubview:_overlay];}
- (void)installGestures {if(!_window)return;UIView*host=[UIApplication sharedApplication].keyWindow.rootViewController.view;if(!host)return;_doubleTap=[[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(doubleTap:)];_doubleTap.numberOfTapsRequired=2;_doubleTap.cancelsTouchesInView=NO;[host addGestureRecognizer:_doubleTap];_longPress=[[UILongPressGestureRecognizer alloc]initWithTarget:self action:@selector(longPress:)];_longPress.minimumPressDuration=2;_longPress.cancelsTouchesInView=NO;[host addGestureRecognizer:_longPress];}
- (void)doubleTap:(UITapGestureRecognizer*)g{[[self class]handleDoubleTap:g];}
- (void)longPress:(UILongPressGestureRecognizer*)g{[[self class]handleLongPress:g];}
- (void)show{[self createWindowIfNeeded];_window.hidden=NO;_visible=YES;}
- (void)hide{_window.hidden=YES;_visible=NO;}
- (void)toggle{_visible?[self hide]:[self show];}
- (void)toggleMenu {
    if(!_window)return; if(_menu){_menu.hidden=!_menu.hidden;return;}
    _menu=[[UIView alloc]initWithFrame:CGRectMake(18,72,250,270)]; _menu.backgroundColor=[UIColor colorWithWhite:.04 alpha:.88]; _menu.layer.cornerRadius=16; _menu.layer.borderWidth=1; _menu.layer.borderColor=[UIColor colorWithWhite:1 alpha:.2].CGColor;
    [_menu addGestureRecognizer:[[UIPanGestureRecognizer alloc]initWithTarget:self action:@selector(dragMenu:)]];
    UILabel *title=[[UILabel alloc]initWithFrame:CGRectMake(16,10,220,28)]; title.text=@"Physics Debug"; title.textColor=UIColor.whiteColor; title.font=[UIFont boldSystemFontOfSize:17]; [_menu addSubview:title];
    NSArray *names=@[@"Overlay",@"Trajectories",@"Aim assist (visual)",@"Auto-shot (host hook)",@"Force Win (placeholder)"];
    for(NSUInteger i=0;i<names.count;i++){UILabel*l=[[UILabel alloc]initWithFrame:CGRectMake(16,42+i*42,165,30)];l.text=names[i];l.textColor=[UIColor colorWithWhite:1 alpha:.9];l.font=[UIFont systemFontOfSize:13];[_menu addSubview:l];UISwitch*s=[[UISwitch alloc]initWithFrame:CGRectMake(184,42+i*42,52,30)];s.tag=100+i;s.on=i<2;s.onTintColor=[UIColor colorWithRed:.16 green:.72 blue:.95 alpha:1];[s addTarget:self action:@selector(menuSwitch:) forControlEvents:UIControlEventValueChanged];[_menu addSubview:s];}
    [_window.rootViewController.view addSubview:_menu]; PoolDebug::logInfo("Debug menu opened");
}
- (void)dragMenu:(UIPanGestureRecognizer*)g{CGPoint d=[g translationInView:_window.rootViewController.view];_menu.center=CGPointMake(_menu.center.x+d.x,_menu.center.y+d.y);[g setTranslation:CGPointZero inView:_window.rootViewController.view];}
- (void)menuSwitch:(UISwitch*)s{switch(s.tag-100){case 0:s.on?[self show]:[self hide];break;case 1:_overlay.showTrajectories=s.on;[_overlay setNeedsDisplay];break;case 2:_overlay.aimAssistEnabled=s.on;[_overlay setNeedsDisplay];break;default:PoolDebug::logInfo("Gameplay hook toggles are visual-only in this debug overlay");break;}}
@end
