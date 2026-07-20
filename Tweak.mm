#import <UIKit/UIKit.h>
#import <MapKit/MapKit.h>
#import <CoreLocation/CoreLocation.h>

static UIWindow *WFOverlayWindow;

@interface WFPanelController : UIViewController <MKMapViewDelegate, UISearchBarDelegate>
@property(nonatomic,strong) MKMapView *mapView;
@property(nonatomic,strong) UILabel *coordinateLabel;
@end

@implementation WFPanelController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithRed:0.03 green:0.04 blue:0.05 alpha:1.0];

    UIView *header = [[UIView alloc] init];
    header.translatesAutoresizingMaskIntoConstraints = NO;
    header.backgroundColor = [UIColor colorWithRed:0.07 green:0.08 blue:0.09 alpha:1.0];
    [self.view addSubview:header];

    UILabel *title = [[UILabel alloc] init];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    title.text = @"WolFox GPS";
    title.textColor = UIColor.whiteColor;
    title.font = [UIFont boldSystemFontOfSize:20];
    title.textAlignment = NSTextAlignmentCenter;
    [header addSubview:title];

    UIButton *close = [UIButton buttonWithType:UIButtonTypeSystem];
    close.translatesAutoresizingMaskIntoConstraints = NO;
    [close setTitle:@"إغلاق" forState:UIControlStateNormal];
    [close setTitleColor:[UIColor colorWithRed:0.22 green:0.85 blue:0.38 alpha:1.0] forState:UIControlStateNormal];
    [close addTarget:self action:@selector(closePanel) forControlEvents:UIControlEventTouchUpInside];
    [header addSubview:close];

    UISearchBar *search = [[UISearchBar alloc] init];
    search.translatesAutoresizingMaskIntoConstraints = NO;
    search.placeholder = @"ابحث عن موقع";
    search.delegate = self;
    search.searchBarStyle = UISearchBarStyleMinimal;
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
    self.coordinateLabel.backgroundColor = [UIColor colorWithWhite:0.08 alpha:0.95];
    self.coordinateLabel.textAlignment = NSTextAlignmentCenter;
    self.coordinateLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    self.coordinateLabel.layer.cornerRadius = 14;
    self.coordinateLabel.layer.masksToBounds = YES;
    [self.view addSubview:self.coordinateLabel];

    UILongPressGestureRecognizer *press = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(selectLocation:)];
    press.minimumPressDuration = 0.45;
    [self.mapView addGestureRecognizer:press];

    [NSLayoutConstraint activateConstraints:@[
        [header.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [header.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [header.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [header.heightAnchor constraintEqualToConstant:92],
        [title.centerXAnchor constraintEqualToAnchor:header.centerXAnchor],
        [title.bottomAnchor constraintEqualToAnchor:header.bottomAnchor constant:-14],
        [close.trailingAnchor constraintEqualToAnchor:header.trailingAnchor constant:-18],
        [close.centerYAnchor constraintEqualToAnchor:title.centerYAnchor],
        [search.topAnchor constraintEqualToAnchor:header.bottomAnchor constant:6],
        [search.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:10],
        [search.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-10],
        [self.mapView.topAnchor constraintEqualToAnchor:search.bottomAnchor constant:4],
        [self.mapView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.mapView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.mapView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [self.coordinateLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:18],
        [self.coordinateLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-18],
        [self.coordinateLabel.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-18],
        [self.coordinateLabel.heightAnchor constraintEqualToConstant:48]
    ]];
}

- (void)closePanel {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)selectLocation:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan) return;
    CGPoint point = [gesture locationInView:self.mapView];
    CLLocationCoordinate2D coordinate = [self.mapView convertPoint:point toCoordinateFromView:self.mapView];
    [self.mapView removeAnnotations:self.mapView.annotations];
    MKPointAnnotation *annotation = [[MKPointAnnotation alloc] init];
    annotation.coordinate = coordinate;
    annotation.title = @"الموقع المحدد";
    [self.mapView addAnnotation:annotation];
    self.coordinateLabel.text = [NSString stringWithFormat:@"%.6f, %.6f", coordinate.latitude, coordinate.longitude];
    [[NSUserDefaults standardUserDefaults] setDouble:coordinate.latitude forKey:@"WolFoxLatitude"];
    [[NSUserDefaults standardUserDefaults] setDouble:coordinate.longitude forKey:@"WolFoxLongitude"];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
    if (searchBar.text.length == 0) return;
    MKLocalSearchRequest *request = [[MKLocalSearchRequest alloc] init];
    request.naturalLanguageQuery = searchBar.text;
    MKLocalSearch *search = [[MKLocalSearch alloc] initWithRequest:request];
    [search startWithCompletionHandler:^(MKLocalSearchResponse *response, NSError *error) {
        MKMapItem *item = response.mapItems.firstObject;
        if (!item || error) return;
        dispatch_async(dispatch_get_main_queue(), ^{
            CLLocationCoordinate2D c = item.placemark.coordinate;
            MKCoordinateRegion region = MKCoordinateRegionMakeWithDistance(c, 2500, 2500);
            [self.mapView setRegion:region animated:YES];
        });
    }];
}
@end

@interface WFFloatingButton : UIButton
@end

@implementation WFFloatingButton
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor colorWithRed:0.22 green:0.85 blue:0.38 alpha:1.0];
        self.layer.cornerRadius = 31;
        self.layer.shadowColor = UIColor.blackColor.CGColor;
        self.layer.shadowOpacity = 0.35;
        self.layer.shadowRadius = 10;
        self.layer.shadowOffset = CGSizeMake(0, 4);
        [self setTitle:@"GPS" forState:UIControlStateNormal];
        [self setTitleColor:UIColor.blackColor forState:UIControlStateNormal];
        self.titleLabel.font = [UIFont boldSystemFontOfSize:15];
        [self addTarget:self action:@selector(openPanel) forControlEvents:UIControlEventTouchUpInside];
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(moveButton:)];
        [self addGestureRecognizer:pan];
    }
    return self;
}

- (void)moveButton:(UIPanGestureRecognizer *)gesture {
    CGPoint translation = [gesture translationInView:self.superview];
    self.center = CGPointMake(self.center.x + translation.x, self.center.y + translation.y);
    [gesture setTranslation:CGPointZero inView:self.superview];
}

- (void)openPanel {
    UIViewController *root = WFOverlayWindow.rootViewController;
    while (root.presentedViewController) root = root.presentedViewController;
    WFPanelController *panel = [[WFPanelController alloc] init];
    panel.modalPresentationStyle = UIModalPresentationFullScreen;
    [root presentViewController:panel animated:YES completion:nil];
}
@end

@interface WFOverlayWindow : UIWindow
@end

@implementation WFOverlayWindow
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hit = [super hitTest:point withEvent:event];
    return hit == self.rootViewController.view ? nil : hit;
}
@end

__attribute__((constructor)) static void WolFoxGPSInit(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (WFOverlayWindow) return;
        CGRect bounds = UIScreen.mainScreen.bounds;
        WFOverlayWindow = [[WFOverlayWindow alloc] initWithFrame:bounds];
        WFOverlayWindow.windowLevel = UIWindowLevelAlert + 20;
        WFOverlayWindow.backgroundColor = UIColor.clearColor;
        UIViewController *root = [[UIViewController alloc] init];
        root.view.backgroundColor = UIColor.clearColor;
        WFOverlayWindow.rootViewController = root;
        WFFloatingButton *button = [[WFFloatingButton alloc] initWithFrame:CGRectMake(18, 160, 62, 62)];
        [root.view addSubview:button];
        WFOverlayWindow.hidden = NO;
    });
}
