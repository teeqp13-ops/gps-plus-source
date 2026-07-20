#import <UIKit/UIKit.h>
#import <MapKit/MapKit.h>
#import <CoreLocation/CoreLocation.h>

@interface WFPassThroughWindow : UIWindow
@end

@interface WFPanelController : UIViewController <MKMapViewDelegate, UISearchBarDelegate>
@property(nonatomic, strong) MKMapView *mapView;
@property(nonatomic, strong) UILabel *coordinateLabel;
@end

@interface WFFloatingButton : UIButton
@end

static WFPassThroughWindow *gWFOverlayWindow = nil;
static WFFloatingButton *gWFFloatingButton = nil;

@implementation WFPassThroughWindow
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hitView = [super hitTest:point withEvent:event];
    UIView *rootView = self.rootViewController.view;
    return (hitView == rootView) ? nil : hitView;
}
@end

@implementation WFPanelController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithRed:0.025 green:0.03 blue:0.04 alpha:1.0];

    UIView *header = [[UIView alloc] init];
    header.translatesAutoresizingMaskIntoConstraints = NO;
    header.backgroundColor = [UIColor colorWithRed:0.06 green:0.07 blue:0.08 alpha:1.0];
    [self.view addSubview:header];

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.text = @"WolFox GPS";
    titleLabel.textColor = UIColor.whiteColor;
    titleLabel.font = [UIFont boldSystemFontOfSize:20.0];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    [header addSubview:titleLabel];

    UIButton *closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    closeButton.translatesAutoresizingMaskIntoConstraints = NO;
    [closeButton setTitle:@"إغلاق" forState:UIControlStateNormal];
    [closeButton setTitleColor:[UIColor colorWithRed:0.20 green:0.92 blue:0.42 alpha:1.0] forState:UIControlStateNormal];
    [closeButton addTarget:self action:@selector(closePanel) forControlEvents:UIControlEventTouchUpInside];
    [header addSubview:closeButton];

    UISearchBar *searchBar = [[UISearchBar alloc] init];
    searchBar.translatesAutoresizingMaskIntoConstraints = NO;
    searchBar.placeholder = @"ابحث عن موقع";
    searchBar.delegate = self;
    searchBar.searchBarStyle = UISearchBarStyleMinimal;
    [self.view addSubview:searchBar];

    self.mapView = [[MKMapView alloc] init];
    self.mapView.translatesAutoresizingMaskIntoConstraints = NO;
    self.mapView.delegate = self;
    self.mapView.showsUserLocation = YES;
    [self.view addSubview:self.mapView];

    self.coordinateLabel = [[UILabel alloc] init];
    self.coordinateLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.coordinateLabel.text = @"اضغط مطولًا على الخريطة لاختيار الموقع";
    self.coordinateLabel.textColor = UIColor.whiteColor;
    self.coordinateLabel.backgroundColor = [UIColor colorWithWhite:0.06 alpha:0.96];
    self.coordinateLabel.textAlignment = NSTextAlignmentCenter;
    self.coordinateLabel.font = [UIFont systemFontOfSize:13.0 weight:UIFontWeightMedium];
    self.coordinateLabel.layer.cornerRadius = 14.0;
    self.coordinateLabel.layer.masksToBounds = YES;
    [self.view addSubview:self.coordinateLabel];

    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(selectLocation:)];
    longPress.minimumPressDuration = 0.45;
    [self.mapView addGestureRecognizer:longPress];

    [NSLayoutConstraint activateConstraints:@[
        [header.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [header.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [header.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [header.heightAnchor constraintEqualToConstant:92.0],
        [titleLabel.centerXAnchor constraintEqualToAnchor:header.centerXAnchor],
        [titleLabel.bottomAnchor constraintEqualToAnchor:header.bottomAnchor constant:-14.0],
        [closeButton.trailingAnchor constraintEqualToAnchor:header.trailingAnchor constant:-18.0],
        [closeButton.centerYAnchor constraintEqualToAnchor:titleLabel.centerYAnchor],
        [searchBar.topAnchor constraintEqualToAnchor:header.bottomAnchor constant:6.0],
        [searchBar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:10.0],
        [searchBar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-10.0],
        [self.mapView.topAnchor constraintEqualToAnchor:searchBar.bottomAnchor constant:4.0],
        [self.mapView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.mapView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.mapView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [self.coordinateLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:18.0],
        [self.coordinateLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-18.0],
        [self.coordinateLabel.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-18.0],
        [self.coordinateLabel.heightAnchor constraintEqualToConstant:48.0]
    ]];
}

- (void)closePanel {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)selectLocation:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan) return;

    CGPoint point = [gesture locationInView:self.mapView];
    CLLocationCoordinate2D coordinate = [self.mapView convertPoint:point toCoordinateFromView:self.mapView];

    NSMutableArray *removable = [NSMutableArray array];
    for (id<MKAnnotation> annotation in self.mapView.annotations) {
        if (![annotation isKindOfClass:[MKUserLocation class]]) [removable addObject:annotation];
    }
    [self.mapView removeAnnotations:removable];

    MKPointAnnotation *annotation = [[MKPointAnnotation alloc] init];
    annotation.coordinate = coordinate;
    annotation.title = @"الموقع المحدد";
    [self.mapView addAnnotation:annotation];

    self.coordinateLabel.text = [NSString stringWithFormat:@"%.6f, %.6f", coordinate.latitude, coordinate.longitude];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setDouble:coordinate.latitude forKey:@"WolFoxLatitude"];
    [defaults setDouble:coordinate.longitude forKey:@"WolFoxLongitude"];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
    NSString *query = [searchBar.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (query.length == 0) return;

    MKLocalSearchRequest *request = [[MKLocalSearchRequest alloc] init];
    request.naturalLanguageQuery = query;
    MKLocalSearch *localSearch = [[MKLocalSearch alloc] initWithRequest:request];
    __weak typeof(self) weakSelf = self;
    [localSearch startWithCompletionHandler:^(MKLocalSearchResponse *response, NSError *error) {
        if (error || response.mapItems.count == 0) return;
        CLLocationCoordinate2D coordinate = response.mapItems.firstObject.placemark.coordinate;
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            MKCoordinateRegion region = MKCoordinateRegionMakeWithDistance(coordinate, 2500.0, 2500.0);
            [strongSelf.mapView setRegion:region animated:YES];
        });
    }];
}
@end

@implementation WFFloatingButton
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor colorWithRed:0.20 green:0.92 blue:0.42 alpha:1.0];
        self.layer.cornerRadius = CGRectGetWidth(frame) / 2.0;
        self.layer.borderWidth = 2.0;
        self.layer.borderColor = UIColor.whiteColor.CGColor;
        self.layer.shadowColor = UIColor.blackColor.CGColor;
        self.layer.shadowOpacity = 0.55;
        self.layer.shadowRadius = 12.0;
        self.layer.shadowOffset = CGSizeMake(0.0, 5.0);
        [self setTitle:@"GPS" forState:UIControlStateNormal];
        [self setTitleColor:UIColor.blackColor forState:UIControlStateNormal];
        self.titleLabel.font = [UIFont boldSystemFontOfSize:15.0];
        self.accessibilityLabel = @"WolFox GPS";
        [self addTarget:self action:@selector(openPanel) forControlEvents:UIControlEventTouchUpInside];
        [self addGestureRecognizer:[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(moveButton:)]];
    }
    return self;
}

- (void)moveButton:(UIPanGestureRecognizer *)gesture {
    UIView *container = self.superview;
    if (!container) return;
    CGPoint translation = [gesture translationInView:container];
    CGPoint next = CGPointMake(self.center.x + translation.x, self.center.y + translation.y);
    CGFloat halfW = CGRectGetWidth(self.bounds) / 2.0;
    CGFloat halfH = CGRectGetHeight(self.bounds) / 2.0;
    next.x = MAX(halfW, MIN(CGRectGetWidth(container.bounds) - halfW, next.x));
    next.y = MAX(halfH, MIN(CGRectGetHeight(container.bounds) - halfH, next.y));
    self.center = next;
    [gesture setTranslation:CGPointZero inView:container];
}

- (void)openPanel {
    UIViewController *controller = gWFOverlayWindow.rootViewController;
    if (!controller) return;
    while (controller.presentedViewController) controller = controller.presentedViewController;
    WFPanelController *panel = [[WFPanelController alloc] init];
    panel.modalPresentationStyle = UIModalPresentationFullScreen;
    [controller presentViewController:panel animated:YES completion:nil];
}
@end

static UIWindowScene *WFActiveWindowScene(void) {
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if ([scene isKindOfClass:UIWindowScene.class] && scene.activationState == UISceneActivationStateForegroundActive) {
                return (UIWindowScene *)scene;
            }
        }
        for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if ([scene isKindOfClass:UIWindowScene.class]) return (UIWindowScene *)scene;
        }
    }
    return nil;
}

static void WFCreateOverlayWindow(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (gWFOverlayWindow && gWFFloatingButton.superview) {
            gWFOverlayWindow.hidden = NO;
            [gWFOverlayWindow bringSubviewToFront:gWFOverlayWindow.rootViewController.view];
            return;
        }

        CGRect bounds = UIScreen.mainScreen.bounds;
        if (@available(iOS 13.0, *)) {
            UIWindowScene *scene = WFActiveWindowScene();
            if (scene) {
                gWFOverlayWindow = [[WFPassThroughWindow alloc] initWithWindowScene:scene];
                gWFOverlayWindow.frame = bounds;
            }
        }
        if (!gWFOverlayWindow) gWFOverlayWindow = [[WFPassThroughWindow alloc] initWithFrame:bounds];

        gWFOverlayWindow.windowLevel = UIWindowLevelAlert + 1000.0;
        gWFOverlayWindow.backgroundColor = UIColor.clearColor;
        gWFOverlayWindow.userInteractionEnabled = YES;

        UIViewController *root = [[UIViewController alloc] init];
        root.view.frame = bounds;
        root.view.backgroundColor = UIColor.clearColor;
        gWFOverlayWindow.rootViewController = root;

        gWFFloatingButton = [[WFFloatingButton alloc] initWithFrame:CGRectMake(18.0, 150.0, 66.0, 66.0)];
        [root.view addSubview:gWFFloatingButton];

        gWFOverlayWindow.hidden = NO;
        [gWFOverlayWindow makeKeyAndVisible];
    });
}

static void WFScheduleOverlay(void) {
    WFCreateOverlayWindow();
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ WFCreateOverlayWindow(); });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ WFCreateOverlayWindow(); });
}

%hook SpringBoard
- (void)applicationDidFinishLaunching:(id)application {
    %orig;
    WFScheduleOverlay();
}
%end

%ctor {
    @autoreleasepool {
        %init;
        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
                                                          object:nil
                                                           queue:NSOperationQueue.mainQueue
                                                      usingBlock:^(__unused NSNotification *note) {
            WFScheduleOverlay();
        }];
    }
}
