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

@implementation WFPassThroughWindow
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hit = [super hitTest:point withEvent:event];
    UIView *rootView = self.rootViewController.view;
    return (hit == rootView) ? nil : hit;
}
@end

@implementation WFPanelController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithRed:0.025 green:0.03 blue:0.04 alpha:1.0];

    UIView *header = [[UIView alloc] init];
    header.translatesAutoresizingMaskIntoConstraints = NO;
    header.backgroundColor = [UIColor colorWithWhite:0.07 alpha:1.0];
    [self.view addSubview:header];

    UILabel *title = [[UILabel alloc] init];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    title.text = @"WolFox GPS";
    title.textColor = UIColor.whiteColor;
    title.font = [UIFont boldSystemFontOfSize:21.0];
    title.textAlignment = NSTextAlignmentCenter;
    [header addSubview:title];

    UIButton *close = [UIButton buttonWithType:UIButtonTypeSystem];
    close.translatesAutoresizingMaskIntoConstraints = NO;
    [close setTitle:@"إغلاق" forState:UIControlStateNormal];
    [close setTitleColor:[UIColor colorWithRed:0.20 green:0.90 blue:0.42 alpha:1.0] forState:UIControlStateNormal];
    [close addTarget:self action:@selector(closePanel) forControlEvents:UIControlEventTouchUpInside];
    [header addSubview:close];

    UISearchBar *search = [[UISearchBar alloc] init];
    search.translatesAutoresizingMaskIntoConstraints = NO;
    search.placeholder = @"ابحث عن موقع";
    search.delegate = self;
    search.searchBarStyle = UISearchBarStyleMinimal;
    search.keyboardType = UIKeyboardTypeDefault;
    [self.view addSubview:search];

    self.mapView = [[MKMapView alloc] init];
    self.mapView.translatesAutoresizingMaskIntoConstraints = NO;
    self.mapView.delegate = self;
    self.mapView.showsUserLocation = YES;
    [self.view addSubview:self.mapView];

    self.coordinateLabel = [[UILabel alloc] init];
    self.coordinateLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.coordinateLabel.text = @"اضغط مطولًا على الخريطة لاختيار الموقع";
    self.coordinateLabel.textColor = UIColor.whiteColor;
    self.coordinateLabel.backgroundColor = [UIColor colorWithWhite:0.06 alpha:0.94];
    self.coordinateLabel.textAlignment = NSTextAlignmentCenter;
    self.coordinateLabel.font = [UIFont systemFontOfSize:13.0 weight:UIFontWeightSemibold];
    self.coordinateLabel.layer.cornerRadius = 15.0;
    self.coordinateLabel.layer.masksToBounds = YES;
    [self.view addSubview:self.coordinateLabel];

    UILongPressGestureRecognizer *press = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(selectLocation:)];
    press.minimumPressDuration = 0.45;
    [self.mapView addGestureRecognizer:press];

    [NSLayoutConstraint activateConstraints:@[
        [header.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [header.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [header.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [header.heightAnchor constraintEqualToConstant:94.0],
        [title.centerXAnchor constraintEqualToAnchor:header.centerXAnchor],
        [title.bottomAnchor constraintEqualToAnchor:header.bottomAnchor constant:-15.0],
        [close.trailingAnchor constraintEqualToAnchor:header.trailingAnchor constant:-18.0],
        [close.centerYAnchor constraintEqualToAnchor:title.centerYAnchor],
        [search.topAnchor constraintEqualToAnchor:header.bottomAnchor constant:4.0],
        [search.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:8.0],
        [search.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-8.0],
        [self.mapView.topAnchor constraintEqualToAnchor:search.bottomAnchor constant:2.0],
        [self.mapView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.mapView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.mapView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [self.coordinateLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:18.0],
        [self.coordinateLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-18.0],
        [self.coordinateLabel.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-18.0],
        [self.coordinateLabel.heightAnchor constraintEqualToConstant:50.0]
    ]];
}

- (void)closePanel {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)selectLocation:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan) return;
    CGPoint point = [gesture locationInView:self.mapView];
    CLLocationCoordinate2D coordinate = [self.mapView convertPoint:point toCoordinateFromView:self.mapView];

    NSMutableArray *items = [NSMutableArray array];
    for (id<MKAnnotation> item in self.mapView.annotations) {
        if (![item isKindOfClass:[MKUserLocation class]]) [items addObject:item];
    }
    [self.mapView removeAnnotations:items];

    MKPointAnnotation *pin = [[MKPointAnnotation alloc] init];
    pin.coordinate = coordinate;
    pin.title = @"الموقع المحدد";
    [self.mapView addAnnotation:pin];
    self.coordinateLabel.text = [NSString stringWithFormat:@"%.6f, %.6f", coordinate.latitude, coordinate.longitude];

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setDouble:coordinate.latitude forKey:@"WolFoxLatitude"];
    [defaults setDouble:coordinate.longitude forKey:@"WolFoxLongitude"];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
    NSString *query = [searchBar.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (query.length == 0) return;

    MKLocalSearchRequest *request = [[MKLocalSearchRequest alloc] init];
    request.naturalLanguageQuery = query;
    MKLocalSearch *search = [[MKLocalSearch alloc] initWithRequest:request];
    __weak typeof(self) weakSelf = self;
    [search startWithCompletionHandler:^(MKLocalSearchResponse *response, NSError *error) {
        if (error || response.mapItems.count == 0) return;
        CLLocationCoordinate2D coordinate = response.mapItems.firstObject.placemark.coordinate;
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) selfRef = weakSelf;
            if (!selfRef) return;
            [selfRef.mapView setRegion:MKCoordinateRegionMakeWithDistance(coordinate, 2500.0, 2500.0) animated:YES];
        });
    }];
}
@end

@implementation WFFloatingButton
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor colorWithRed:0.20 green:0.90 blue:0.42 alpha:1.0];
        self.layer.cornerRadius = CGRectGetWidth(frame) / 2.0;
        self.layer.borderWidth = 2.0;
        self.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.22].CGColor;
        self.layer.shadowColor = UIColor.blackColor.CGColor;
        self.layer.shadowOpacity = 0.45;
        self.layer.shadowRadius = 12.0;
        self.layer.shadowOffset = CGSizeMake(0.0, 5.0);
        [self setTitle:@"GPS" forState:UIControlStateNormal];
        [self setTitleColor:UIColor.blackColor forState:UIControlStateNormal];
        self.titleLabel.font = [UIFont boldSystemFontOfSize:15.0];
        [self addTarget:self action:@selector(openPanel) forControlEvents:UIControlEventTouchUpInside];
        [self addGestureRecognizer:[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(moveButton:)]];
    }
    return self;
}

- (void)moveButton:(UIPanGestureRecognizer *)gesture {
    UIView *container = self.superview;
    if (!container) return;
    CGPoint translation = [gesture translationInView:container];
    CGPoint center = CGPointMake(self.center.x + translation.x, self.center.y + translation.y);
    CGFloat halfW = CGRectGetWidth(self.bounds) / 2.0;
    CGFloat halfH = CGRectGetHeight(self.bounds) / 2.0;
    center.x = MAX(halfW, MIN(CGRectGetWidth(container.bounds) - halfW, center.x));
    center.y = MAX(halfH, MIN(CGRectGetHeight(container.bounds) - halfH, center.y));
    self.center = center;
    [gesture setTranslation:CGPointZero inView:container];
}

- (void)openPanel {
    UIViewController *root = gWFOverlayWindow.rootViewController;
    if (!root) return;
    while (root.presentedViewController) root = root.presentedViewController;
    WFPanelController *panel = [[WFPanelController alloc] init];
    panel.modalPresentationStyle = UIModalPresentationFullScreen;
    [root presentViewController:panel animated:YES completion:nil];
}
@end

static UIWindowScene *WFActiveWindowScene(void) {
    if (@available(iOS 13.0, *)) {
        NSSet *scenes = UIApplication.sharedApplication.connectedScenes;
        for (UIScene *scene in scenes) {
            if ([scene isKindOfClass:[UIWindowScene class]] &&
                scene.activationState == UISceneActivationStateForegroundActive) {
                return (UIWindowScene *)scene;
            }
        }
        for (UIScene *scene in scenes) {
            if ([scene isKindOfClass:[UIWindowScene class]]) return (UIWindowScene *)scene;
        }
    }
    return nil;
}

static void WFCreateOverlayWindow(void) {
    if (gWFOverlayWindow) {
        gWFOverlayWindow.hidden = NO;
        [gWFOverlayWindow makeKeyAndVisible];
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

    gWFOverlayWindow.windowLevel = UIWindowLevelAlert + 100.0;
    gWFOverlayWindow.backgroundColor = UIColor.clearColor;
    gWFOverlayWindow.userInteractionEnabled = YES;

    UIViewController *root = [[UIViewController alloc] init];
    root.view.backgroundColor = UIColor.clearColor;
    gWFOverlayWindow.rootViewController = root;

    WFFloatingButton *button = [[WFFloatingButton alloc] initWithFrame:CGRectMake(18.0, 170.0, 64.0, 64.0)];
    button.accessibilityIdentifier = @"WolFoxGPSFloatingButton";
    [root.view addSubview:button];

    gWFOverlayWindow.hidden = NO;
    [gWFOverlayWindow makeKeyAndVisible];
}

static void WFScheduleOverlayCreation(void) {
    dispatch_async(dispatch_get_main_queue(), ^{ WFCreateOverlayWindow(); });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ WFCreateOverlayWindow(); });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ WFCreateOverlayWindow(); });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(8.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ WFCreateOverlayWindow(); });
}

__attribute__((constructor)) static void WolFoxGPSInit(void) {
    WFScheduleOverlayCreation();
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(__unused NSNotification *note) {
        WFCreateOverlayWindow();
    }];
}
