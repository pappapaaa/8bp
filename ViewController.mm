#import <UIKit/UIKit.h>
#import <math.h>
#import "TrajectoryOverlayView.h"

@interface ViewController : UIViewController
@property(nonatomic,strong) TrajectoryOverlayView *trajectoryOverlay;
@property(nonatomic,strong) UISlider *angleSlider;
@property(nonatomic,strong) UISlider *powerSlider;
@end

@implementation ViewController
- (void)viewDidLoad { [super viewDidLoad]; self.view.backgroundColor=[UIColor colorWithWhite:.12 alpha:1]; PhysicsEngine *engine=PhysicsEngine.sharedEngine; NSString *path=[[NSBundle mainBundle] pathForResource:@"config" ofType:@"plist"]; NSDictionary *plist=[NSDictionary dictionaryWithContentsOfFile:path]; NSError *error=nil; if(![engine configureWithPlistDictionary:plist error:&error]) NSLog(@"Physics config failed: %@",error.localizedDescription);
    self.trajectoryOverlay=[[TrajectoryOverlayView alloc] initWithFrame:self.view.bounds configuration:plist engine:engine];self.trajectoryOverlay.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;[self.view addSubview:self.trajectoryOverlay];
    self.angleSlider=[[UISlider alloc] initWithFrame:CGRectMake(24,self.view.bounds.size.height-76,self.view.bounds.size.width-48,30)];self.angleSlider.minimumValue=-M_PI;self.angleSlider.maximumValue=M_PI;self.angleSlider.value=0;self.angleSlider.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleTopMargin;[self.angleSlider addTarget:self action:@selector(shotParameterChanged:) forControlEvents:UIControlEventValueChanged];[self.view addSubview:self.angleSlider];
    self.powerSlider=[[UISlider alloc] initWithFrame:CGRectMake(24,self.view.bounds.size.height-42,self.view.bounds.size.width-48,30)];self.powerSlider.minimumValue=20;self.powerSlider.maximumValue=700;self.powerSlider.value=120;self.powerSlider.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleTopMargin;[self.powerSlider addTarget:self action:@selector(shotParameterChanged:) forControlEvents:UIControlEventValueChanged];[self.view addSubview:self.powerSlider];
    UITapGestureRecognizer *doubleTap=[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(toggleOverlay:)];doubleTap.numberOfTapsRequired=2;[self.view addGestureRecognizer:doubleTap];[self shotParameterChanged:nil]; }
- (void)viewDidLayoutSubviews { [super viewDidLayoutSubviews]; self.trajectoryOverlay.frame=self.view.bounds; }
- (void)shotParameterChanged:(id)sender { [PhysicsEngine.sharedEngine updateWithAngle:self.angleSlider.value power:self.powerSlider.value spinX:0 spinY:0]; }
- (void)toggleOverlay:(UITapGestureRecognizer *)gesture { self.trajectoryOverlay.hidden=!self.trajectoryOverlay.hidden; }
@end
