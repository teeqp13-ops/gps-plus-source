#import <UIKit/UIKit.h>
#import <MapKit/MapKit.h>
#import <CoreLocation/CoreLocation.h>

static NSString * const WFEnabledKey = @"WolFoxEnabled";
static NSString * const WFLatitudeKey = @"WolFoxLatitude";
static NSString * const WFLongitudeKey = @"WolFoxLongitude";
static NSString * const WFFavoritesKey = @"WolFoxFavorites";
static NSString * const WFHistoryKey = @"WolFoxHistory";
static NSString * const WFFloatingXKey = @"WolFoxFloatingX";
static NSString * const WFFloatingYKey = @"WolFoxFloatingY";
static NSString * const WFFloatingHiddenKey = @"WolFoxFloatingHidden";
static NSString * const WFMapTypeKey = @"WolFoxMapType";

static UIColor *WFBackgroundColor(void) { return [UIColor colorWithRed:0.025 green:0.03 blue:0.04 alpha:1.0]; }
static UIColor *WFCardColor(void) { return [UIColor colorWithRed:0.07 green:0.085 blue:0.10 alpha:1.0]; }
static UIColor *WFGreenColor(void) { return [UIColor colorWithRed:0.18 green:0.92 blue:0.40 alpha:1.0]; }
static UIColor *WFBlueColor(void) { return [UIColor colorWithRed:0.04 green:0.42 blue:0.95 alpha:1.0]; }

@interface WFPassThroughWindow : UIWindow
@end

@interface WFPanelController : UIViewController <MKMapViewDelegate, UISearchBarDelegate, UITableViewDelegate, UITableViewDataSource>
@property(nonatomic,strong) MKMapView *mapView;
@property(nonatomic,strong) UILabel *coordinateLabel;
@property(nonatomic,strong) UIButton *activateButton;
@property(nonatomic,strong) UIView *mapContainer;
@property(nonatomic,strong) UIView *listContainer;
@property(nonatomic,strong) UIView *settingsContainer;
@property(nonatomic,strong) UITableView *tableView;
@property(nonatomic,strong) NSArray *listItems;
@property(nonatomic,assign) NSInteger currentSection;
@property(nonatomic,assign) CLLocationCoordinate2D selectedCoordinate;
@property(nonatomic,strong) UISegmentedControl *mapTypeControl;
@end

@interface WFFloatingButton : UIButton
@end

static WFPassThroughWindow *gWFOverlayWindow = nil;
static WFFloatingButton *gWFFloatingButton = nil;

static NSUserDefaults *WFDefaults(void) { return [NSUserDefaults standardUserDefaults]; }

static CLLocationCoordinate2D WFStoredCoordinate(void) {
    NSUserDefaults *d = WFDefaults();
    double lat = [d doubleForKey:WFLatitudeKey];
    double lon = [d doubleForKey:WFLongitudeKey];
    if (lat == 0.0 && lon == 0.0) return CLLocationCoordinate2DMake(24.7136, 46.6753);
    return CLLocationCoordinate2DMake(lat, lon);
}

static NSDictionary *WFLocationDictionary(CLLocationCoordinate2D coordinate, NSString *name) {
    return @{ @"name": name ?: @"موقع محفوظ", @"lat": @(coordinate.latitude), @"lon": @(coordinate.longitude), @"date": @([[NSDate date] timeIntervalSince1970]) };
}

static void WFAppendHistory(CLLocationCoordinate2D coordinate, NSString *name) {
    NSMutableArray *items = [[WFDefaults() arrayForKey:WFHistoryKey] mutableCopy] ?: [NSMutableArray array];
    [items insertObject:WFLocationDictionary(coordinate, name) atIndex:0];
    while (items.count > 50) [items removeLastObject];
    [WFDefaults() setObject:items forKey:WFHistoryKey];
}

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
    self.view.backgroundColor = WFBackgroundColor();
    self.selectedCoordinate = WFStoredCoordinate();
    self.currentSection = 0;

    UIView *header = [[UIView alloc] init];
    header.translatesAutoresizingMaskIntoConstraints = NO;
    header.backgroundColor = [UIColor colorWithRed:0.055 green:0.06 blue:0.07 alpha:1.0];
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
    [closeButton setTitleColor:WFGreenColor() forState:UIControlStateNormal];
    [closeButton addTarget:self action:@selector(closePanel) forControlEvents:UIControlEventTouchUpInside];
    [header addSubview:closeButton];

    UIView *content = [[UIView alloc] init];
    content.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:content];

    UIStackView *tabs = [[UIStackView alloc] init];
    tabs.translatesAutoresizingMaskIntoConstraints = NO;
    tabs.axis = UILayoutConstraintAxisHorizontal;
    tabs.distribution = UIStackViewDistributionFillEqually;
    tabs.backgroundColor = [UIColor colorWithRed:0.045 green:0.055 blue:0.065 alpha:1.0];
    [self.view addSubview:tabs];

    NSArray *titles = @[@"الخريطة", @"المفضلة", @"السجل", @"الإعدادات"];
    for (NSInteger i = 0; i < titles.count; i++) {
        UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
        button.tag = 100 + i;
        [button setTitle:titles[i] forState:UIControlStateNormal];
        [button setTitleColor:(i == 0 ? WFGreenColor() : UIColor.lightGrayColor) forState:UIControlStateNormal];
        button.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
        [button addTarget:self action:@selector(tabPressed:) forControlEvents:UIControlEventTouchUpInside];
        [tabs addArrangedSubview:button];
    }

    [NSLayoutConstraint activateConstraints:@[
        [header.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [header.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [header.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [header.heightAnchor constraintEqualToConstant:92.0],
        [titleLabel.centerXAnchor constraintEqualToAnchor:header.centerXAnchor],
        [titleLabel.bottomAnchor constraintEqualToAnchor:header.bottomAnchor constant:-14.0],
        [closeButton.trailingAnchor constraintEqualToAnchor:header.trailingAnchor constant:-18.0],
        [closeButton.centerYAnchor constraintEqualToAnchor:titleLabel.centerYAnchor],
        [tabs.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [tabs.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [tabs.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [tabs.heightAnchor constraintEqualToConstant:78.0],
        [content.topAnchor constraintEqualToAnchor:header.bottomAnchor],
        [content.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [content.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [content.bottomAnchor constraintEqualToAnchor:tabs.topAnchor]
    ]];

    [self buildMapSectionInView:content];
    [self buildListSectionInView:content];
    [self buildSettingsSectionInView:content];
    [self showSection:0];
}

- (UIButton *)actionButton:(NSString *)title color:(UIColor *)color selector:(SEL)selector {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.backgroundColor = color;
    button.layer.cornerRadius = 12.0;
    [button setTitle:title forState:UIControlStateNormal];
    [button setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont boldSystemFontOfSize:15.0];
    [button addTarget:self action:selector forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (void)buildMapSectionInView:(UIView *)parent {
    self.mapContainer = [[UIView alloc] init];
    self.mapContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [parent addSubview:self.mapContainer];

    UISearchBar *searchBar = [[UISearchBar alloc] init];
    searchBar.translatesAutoresizingMaskIntoConstraints = NO;
    searchBar.placeholder = @"ابحث عن موقع";
    searchBar.delegate = self;
    searchBar.searchBarStyle = UISearchBarStyleMinimal;
    [self.mapContainer addSubview:searchBar];

    self.mapTypeControl = [[UISegmentedControl alloc] initWithItems:@[@"عادي", @"قمر صناعي", @"هجين"]];
    self.mapTypeControl.translatesAutoresizingMaskIntoConstraints = NO;
    self.mapTypeControl.selectedSegmentIndex = [WFDefaults() integerForKey:WFMapTypeKey];
    [self.mapTypeControl addTarget:self action:@selector(mapTypeChanged:) forControlEvents:UIControlEventValueChanged];
    [self.mapContainer addSubview:self.mapTypeControl];

    self.mapView = [[MKMapView alloc] init];
    self.mapView.translatesAutoresizingMaskIntoConstraints = NO;
    self.mapView.delegate = self;
    self.mapView.showsUserLocation = YES;
    [self.mapContainer addSubview:self.mapView];

    self.coordinateLabel = [[UILabel alloc] init];
    self.coordinateLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.coordinateLabel.textColor = UIColor.whiteColor;
    self.coordinateLabel.backgroundColor = [UIColor colorWithWhite:0.06 alpha:0.96];
    self.coordinateLabel.textAlignment = NSTextAlignmentCenter;
    self.coordinateLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    self.coordinateLabel.layer.cornerRadius = 12.0;
    self.coordinateLabel.layer.masksToBounds = YES;
    [self.mapContainer addSubview:self.coordinateLabel];

    UIButton *favorite = [self actionButton:@"★ حفظ في المفضلة" color:[UIColor colorWithRed:0.42 green:0.30 blue:0.02 alpha:1.0] selector:@selector(saveFavorite)];
    UIButton *activate = [self actionButton:@"تفعيل الموقع" color:WFBlueColor() selector:@selector(toggleActivation)];
    self.activateButton = activate;
    [self.mapContainer addSubview:favorite];
    [self.mapContainer addSubview:activate];

    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(selectLocation:)];
    longPress.minimumPressDuration = 0.4;
    [self.mapView addGestureRecognizer:longPress];

    [NSLayoutConstraint activateConstraints:@[
        [self.mapContainer.topAnchor constraintEqualToAnchor:parent.topAnchor],
        [self.mapContainer.leadingAnchor constraintEqualToAnchor:parent.leadingAnchor],
        [self.mapContainer.trailingAnchor constraintEqualToAnchor:parent.trailingAnchor],
        [self.mapContainer.bottomAnchor constraintEqualToAnchor:parent.bottomAnchor],
        [searchBar.topAnchor constraintEqualToAnchor:self.mapContainer.topAnchor constant:6],
        [searchBar.leadingAnchor constraintEqualToAnchor:self.mapContainer.leadingAnchor constant:10],
        [searchBar.trailingAnchor constraintEqualToAnchor:self.mapContainer.trailingAnchor constant:-10],
        [self.mapTypeControl.topAnchor constraintEqualToAnchor:searchBar.bottomAnchor constant:2],
        [self.mapTypeControl.leadingAnchor constraintEqualToAnchor:self.mapContainer.leadingAnchor constant:16],
        [self.mapTypeControl.trailingAnchor constraintEqualToAnchor:self.mapContainer.trailingAnchor constant:-16],
        [self.mapTypeControl.heightAnchor constraintEqualToConstant:34],
        [self.mapView.topAnchor constraintEqualToAnchor:self.mapTypeControl.bottomAnchor constant:8],
        [self.mapView.leadingAnchor constraintEqualToAnchor:self.mapContainer.leadingAnchor],
        [self.mapView.trailingAnchor constraintEqualToAnchor:self.mapContainer.trailingAnchor],
        [self.mapView.bottomAnchor constraintEqualToAnchor:self.coordinateLabel.topAnchor constant:-10],
        [self.coordinateLabel.leadingAnchor constraintEqualToAnchor:self.mapContainer.leadingAnchor constant:16],
        [self.coordinateLabel.trailingAnchor constraintEqualToAnchor:self.mapContainer.trailingAnchor constant:-16],
        [self.coordinateLabel.bottomAnchor constraintEqualToAnchor:favorite.topAnchor constant:-10],
        [self.coordinateLabel.heightAnchor constraintEqualToConstant:44],
        [favorite.leadingAnchor constraintEqualToAnchor:self.mapContainer.leadingAnchor constant:16],
        [favorite.bottomAnchor constraintEqualToAnchor:self.mapContainer.bottomAnchor constant:-12],
        [favorite.heightAnchor constraintEqualToConstant:48],
        [activate.trailingAnchor constraintEqualToAnchor:self.mapContainer.trailingAnchor constant:-16],
        [activate.bottomAnchor constraintEqualToAnchor:self.mapContainer.bottomAnchor constant:-12],
        [activate.heightAnchor constraintEqualToConstant:48],
        [favorite.trailingAnchor constraintEqualToAnchor:activate.leadingAnchor constant:-10],
        [favorite.widthAnchor constraintEqualToAnchor:activate.widthAnchor]
    ]];

    [self applyMapType];
    [self displayCoordinate:self.selectedCoordinate center:YES];
    [self refreshActivationButton];
}

- (void)buildListSectionInView:(UIView *)parent {
    self.listContainer = [[UIView alloc] init];
    self.listContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [parent addSubview:self.listContainer];
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableView.backgroundColor = WFBackgroundColor();
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    [self.listContainer addSubview:self.tableView];
    [NSLayoutConstraint activateConstraints:@[
        [self.listContainer.topAnchor constraintEqualToAnchor:parent.topAnchor],
        [self.listContainer.leadingAnchor constraintEqualToAnchor:parent.leadingAnchor],
        [self.listContainer.trailingAnchor constraintEqualToAnchor:parent.trailingAnchor],
        [self.listContainer.bottomAnchor constraintEqualToAnchor:parent.bottomAnchor],
        [self.tableView.topAnchor constraintEqualToAnchor:self.listContainer.topAnchor],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.listContainer.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.listContainer.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.listContainer.bottomAnchor]
    ]];
}

- (void)buildSettingsSectionInView:(UIView *)parent {
    self.settingsContainer = [[UIView alloc] init];
    self.settingsContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [parent addSubview:self.settingsContainer];

    UIStackView *stack = [[UIStackView alloc] init];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 12;
    [self.settingsContainer addSubview:stack];

    [stack addArrangedSubview:[self settingsRow:@"تفعيل تغيير الموقع" key:WFEnabledKey selector:@selector(settingSwitchChanged:) tag:201]];
    [stack addArrangedSubview:[self settingsRow:@"إخفاء الأيقونة العائمة" key:WFFloatingHiddenKey selector:@selector(settingSwitchChanged:) tag:202]];

    UIButton *resetPosition = [self actionButton:@"إعادة موضع الأيقونة" color:WFCardColor() selector:@selector(resetFloatingPosition)];
    UIButton *clearHistory = [self actionButton:@"مسح السجل" color:WFCardColor() selector:@selector(clearHistory)];
    UIButton *clearFavorites = [self actionButton:@"مسح المفضلة" color:[UIColor colorWithRed:0.55 green:0.12 blue:0.12 alpha:1.0] selector:@selector(clearFavorites)];
    [stack addArrangedSubview:resetPosition];
    [stack addArrangedSubview:clearHistory];
    [stack addArrangedSubview:clearFavorites];
    [resetPosition.heightAnchor constraintEqualToConstant:52].active = YES;
    [clearHistory.heightAnchor constraintEqualToConstant:52].active = YES;
    [clearFavorites.heightAnchor constraintEqualToConstant:52].active = YES;

    UILabel *info = [[UILabel alloc] init];
    info.text = @"WolFox GPS\nاضغط مطولًا على الخريطة لاختيار موقع، ثم فعّل الموقع.";
    info.textColor = UIColor.lightGrayColor;
    info.numberOfLines = 0;
    info.textAlignment = NSTextAlignmentCenter;
    info.font = [UIFont systemFontOfSize:13];
    [stack addArrangedSubview:info];

    [NSLayoutConstraint activateConstraints:@[
        [self.settingsContainer.topAnchor constraintEqualToAnchor:parent.topAnchor],
        [self.settingsContainer.leadingAnchor constraintEqualToAnchor:parent.leadingAnchor],
        [self.settingsContainer.trailingAnchor constraintEqualToAnchor:parent.trailingAnchor],
        [self.settingsContainer.bottomAnchor constraintEqualToAnchor:parent.bottomAnchor],
        [stack.topAnchor constraintEqualToAnchor:self.settingsContainer.topAnchor constant:20],
        [stack.leadingAnchor constraintEqualToAnchor:self.settingsContainer.leadingAnchor constant:16],
        [stack.trailingAnchor constraintEqualToAnchor:self.settingsContainer.trailingAnchor constant:-16]
    ]];
}

- (UIView *)settingsRow:(NSString *)title key:(NSString *)key selector:(SEL)selector tag:(NSInteger)tag {
    UIView *row = [[UIView alloc] init];
    row.backgroundColor = WFCardColor();
    row.layer.cornerRadius = 14;
    UILabel *label = [[UILabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.text = title;
    label.textColor = UIColor.whiteColor;
    UISwitch *toggle = [[UISwitch alloc] init];
    toggle.translatesAutoresizingMaskIntoConstraints = NO;
    toggle.on = [WFDefaults() boolForKey:key];
    toggle.tag = tag;
    [toggle addTarget:self action:selector forControlEvents:UIControlEventValueChanged];
    [row addSubview:label];
    [row addSubview:toggle];
    [NSLayoutConstraint activateConstraints:@[
        [row.heightAnchor constraintEqualToConstant:60],
        [label.leadingAnchor constraintEqualToAnchor:row.leadingAnchor constant:16],
        [label.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [toggle.trailingAnchor constraintEqualToAnchor:row.trailingAnchor constant:-16],
        [toggle.centerYAnchor constraintEqualToAnchor:row.centerYAnchor]
    ]];
    return row;
}

- (void)tabPressed:(UIButton *)sender {
    NSInteger section = sender.tag - 100;
    for (NSInteger i = 0; i < 4; i++) {
        UIButton *button = [self.view viewWithTag:100 + i];
        [button setTitleColor:(i == section ? WFGreenColor() : UIColor.lightGrayColor) forState:UIControlStateNormal];
    }
    [self showSection:section];
}

- (void)showSection:(NSInteger)section {
    self.currentSection = section;
    self.mapContainer.hidden = section != 0;
    self.listContainer.hidden = !(section == 1 || section == 2);
    self.settingsContainer.hidden = section != 3;
    if (section == 1) self.listItems = [WFDefaults() arrayForKey:WFFavoritesKey] ?: @[];
    if (section == 2) self.listItems = [WFDefaults() arrayForKey:WFHistoryKey] ?: @[];
    [self.tableView reloadData];
}

- (void)closePanel { [self dismissViewControllerAnimated:YES completion:nil]; }

- (void)selectLocation:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan) return;
    CGPoint point = [gesture locationInView:self.mapView];
    CLLocationCoordinate2D coordinate = [self.mapView convertPoint:point toCoordinateFromView:self.mapView];
    self.selectedCoordinate = coordinate;
    [self displayCoordinate:coordinate center:NO];
}

- (void)displayCoordinate:(CLLocationCoordinate2D)coordinate center:(BOOL)center {
    NSMutableArray *remove = [NSMutableArray array];
    for (id<MKAnnotation> annotation in self.mapView.annotations) if (![annotation isKindOfClass:MKUserLocation.class]) [remove addObject:annotation];
    [self.mapView removeAnnotations:remove];
    MKPointAnnotation *pin = [[MKPointAnnotation alloc] init];
    pin.coordinate = coordinate;
    pin.title = @"الموقع المحدد";
    [self.mapView addAnnotation:pin];
    self.coordinateLabel.text = [NSString stringWithFormat:@"%.6f, %.6f", coordinate.latitude, coordinate.longitude];
    if (center) [self.mapView setRegion:MKCoordinateRegionMakeWithDistance(coordinate, 18000, 18000) animated:NO];
}

- (void)toggleActivation {
    BOOL enabled = ![WFDefaults() boolForKey:WFEnabledKey];
    [WFDefaults() setBool:enabled forKey:WFEnabledKey];
    [WFDefaults() setDouble:self.selectedCoordinate.latitude forKey:WFLatitudeKey];
    [WFDefaults() setDouble:self.selectedCoordinate.longitude forKey:WFLongitudeKey];
    if (enabled) WFAppendHistory(self.selectedCoordinate, @"موقع مفعّل");
    [self refreshActivationButton];
}

- (void)refreshActivationButton {
    BOOL enabled = [WFDefaults() boolForKey:WFEnabledKey];
    self.activateButton.backgroundColor = enabled ? WFGreenColor() : WFBlueColor();
    [self.activateButton setTitle:(enabled ? @"إيقاف الموقع" : @"تفعيل الموقع") forState:UIControlStateNormal];
}

- (void)saveFavorite {
    NSMutableArray *favorites = [[WFDefaults() arrayForKey:WFFavoritesKey] mutableCopy] ?: [NSMutableArray array];
    NSString *name = [NSString stringWithFormat:@"موقع %lu", (unsigned long)(favorites.count + 1)];
    [favorites insertObject:WFLocationDictionary(self.selectedCoordinate, name) atIndex:0];
    [WFDefaults() setObject:favorites forKey:WFFavoritesKey];
}

- (void)mapTypeChanged:(UISegmentedControl *)sender {
    [WFDefaults() setInteger:sender.selectedSegmentIndex forKey:WFMapTypeKey];
    [self applyMapType];
}

- (void)applyMapType {
    NSInteger type = [WFDefaults() integerForKey:WFMapTypeKey];
    self.mapView.mapType = type == 1 ? MKMapTypeSatellite : (type == 2 ? MKMapTypeHybrid : MKMapTypeStandard);
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
    NSString *query = [searchBar.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (!query.length) return;
    MKLocalSearchRequest *request = [[MKLocalSearchRequest alloc] init];
    request.naturalLanguageQuery = query;
    MKLocalSearch *search = [[MKLocalSearch alloc] initWithRequest:request];
    __weak typeof(self) weakSelf = self;
    [search startWithCompletionHandler:^(MKLocalSearchResponse *response, NSError *error) {
        if (error || !response.mapItems.count) return;
        MKMapItem *item = response.mapItems.firstObject;
        dispatch_async(dispatch_get_main_queue(), ^{
            weakSelf.selectedCoordinate = item.placemark.coordinate;
            [weakSelf displayCoordinate:weakSelf.selectedCoordinate center:YES];
        });
    }];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return self.listItems.count; }
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *identifier = @"WFCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:identifier];
    NSDictionary *item = self.listItems[indexPath.row];
    cell.backgroundColor = WFCardColor();
    cell.textLabel.textColor = UIColor.whiteColor;
    cell.detailTextLabel.textColor = UIColor.lightGrayColor;
    cell.textLabel.text = item[@"name"] ?: @"موقع";
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%.6f, %.6f", [item[@"lat"] doubleValue], [item[@"lon"] doubleValue]];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *item = self.listItems[indexPath.row];
    self.selectedCoordinate = CLLocationCoordinate2DMake([item[@"lat"] doubleValue], [item[@"lon"] doubleValue]);
    [self showSection:0];
    [self displayCoordinate:self.selectedCoordinate center:YES];
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath { return YES; }
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)style forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (style != UITableViewCellEditingStyleDelete) return;
    NSString *key = self.currentSection == 1 ? WFFavoritesKey : WFHistoryKey;
    NSMutableArray *items = [[WFDefaults() arrayForKey:key] mutableCopy] ?: [NSMutableArray array];
    [items removeObjectAtIndex:indexPath.row];
    [WFDefaults() setObject:items forKey:key];
    self.listItems = items;
    [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
}

- (void)settingSwitchChanged:(UISwitch *)sender {
    if (sender.tag == 201) {
        [WFDefaults() setBool:sender.on forKey:WFEnabledKey];
        [self refreshActivationButton];
    } else if (sender.tag == 202) {
        [WFDefaults() setBool:sender.on forKey:WFFloatingHiddenKey];
        gWFFloatingButton.hidden = sender.on;
    }
}
- (void)resetFloatingPosition {
    [WFDefaults() removeObjectForKey:WFFloatingXKey];
    [WFDefaults() removeObjectForKey:WFFloatingYKey];
    gWFFloatingButton.frame = CGRectMake(18, 150, 66, 66);
}
- (void)clearHistory { [WFDefaults() removeObjectForKey:WFHistoryKey]; }
- (void)clearFavorites { [WFDefaults() removeObjectForKey:WFFavoritesKey]; }

@end

@implementation WFFloatingButton
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = WFGreenColor();
        self.layer.cornerRadius = CGRectGetWidth(frame) / 2.0;
        self.layer.borderWidth = 2.0;
        self.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.25].CGColor;
        self.layer.shadowColor = UIColor.blackColor.CGColor;
        self.layer.shadowOpacity = 0.5;
        self.layer.shadowRadius = 12;
        self.layer.shadowOffset = CGSizeMake(0, 5);
        [self setTitle:@"GPS" forState:UIControlStateNormal];
        [self setTitleColor:UIColor.blackColor forState:UIControlStateNormal];
        self.titleLabel.font = [UIFont boldSystemFontOfSize:15];
        [self addTarget:self action:@selector(openPanel) forControlEvents:UIControlEventTouchUpInside];
        [self addGestureRecognizer:[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(moveButton:)]];
    }
    return self;
}
- (void)moveButton:(UIPanGestureRecognizer *)gesture {
    UIView *container = self.superview;
    if (!container) return;
    CGPoint t = [gesture translationInView:container];
    CGPoint next = CGPointMake(self.center.x + t.x, self.center.y + t.y);
    CGFloat hw = CGRectGetWidth(self.bounds)/2.0, hh = CGRectGetHeight(self.bounds)/2.0;
    next.x = MAX(hw, MIN(CGRectGetWidth(container.bounds)-hw, next.x));
    next.y = MAX(hh, MIN(CGRectGetHeight(container.bounds)-hh, next.y));
    self.center = next;
    [gesture setTranslation:CGPointZero inView:container];
    if (gesture.state == UIGestureRecognizerStateEnded) {
        [WFDefaults() setDouble:self.center.x forKey:WFFloatingXKey];
        [WFDefaults() setDouble:self.center.y forKey:WFFloatingYKey];
    }
}
- (void)openPanel {
    UIViewController *controller = gWFOverlayWindow.rootViewController;
    while (controller.presentedViewController) controller = controller.presentedViewController;
    WFPanelController *panel = [[WFPanelController alloc] init];
    panel.modalPresentationStyle = UIModalPresentationFullScreen;
    [controller presentViewController:panel animated:YES completion:nil];
}
@end

static UIWindowScene *WFActiveWindowScene(void) {
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in UIApplication.sharedApplication.connectedScenes)
            if ([scene isKindOfClass:UIWindowScene.class] && scene.activationState == UISceneActivationStateForegroundActive) return (UIWindowScene *)scene;
        for (UIScene *scene in UIApplication.sharedApplication.connectedScenes)
            if ([scene isKindOfClass:UIWindowScene.class]) return (UIWindowScene *)scene;
    }
    return nil;
}

static void WFCreateOverlayWindow(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (gWFOverlayWindow && gWFFloatingButton.superview) {
            gWFOverlayWindow.hidden = NO;
            gWFFloatingButton.hidden = [WFDefaults() boolForKey:WFFloatingHiddenKey];
            return;
        }
        CGRect bounds = UIScreen.mainScreen.bounds;
        UIWindowScene *scene = WFActiveWindowScene();
        if (@available(iOS 13.0, *)) if (scene) gWFOverlayWindow = [[WFPassThroughWindow alloc] initWithWindowScene:scene];
        if (!gWFOverlayWindow) gWFOverlayWindow = [[WFPassThroughWindow alloc] initWithFrame:bounds];
        gWFOverlayWindow.frame = bounds;
        gWFOverlayWindow.windowLevel = UIWindowLevelAlert + 1000.0;
        gWFOverlayWindow.backgroundColor = UIColor.clearColor;
        UIViewController *root = [[UIViewController alloc] init];
        root.view.frame = bounds;
        root.view.backgroundColor = UIColor.clearColor;
        gWFOverlayWindow.rootViewController = root;
        double x = [WFDefaults() doubleForKey:WFFloatingXKey];
        double y = [WFDefaults() doubleForKey:WFFloatingYKey];
        gWFFloatingButton = [[WFFloatingButton alloc] initWithFrame:CGRectMake(18, 150, 66, 66)];
        if (x > 0 && y > 0) gWFFloatingButton.center = CGPointMake(x, y);
        gWFFloatingButton.hidden = [WFDefaults() boolForKey:WFFloatingHiddenKey];
        [root.view addSubview:gWFFloatingButton];
        gWFOverlayWindow.hidden = NO;
        [gWFOverlayWindow makeKeyAndVisible];
    });
}

static void WFScheduleOverlay(void) {
    WFCreateOverlayWindow();
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5*NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ WFCreateOverlayWindow(); });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4.0*NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ WFCreateOverlayWindow(); });
}

%hook CLLocation
- (CLLocationCoordinate2D)coordinate {
    if ([WFDefaults() boolForKey:WFEnabledKey]) return WFStoredCoordinate();
    return %orig;
}
%end

%hook SpringBoard
- (void)applicationDidFinishLaunching:(id)application {
    %orig;
    WFScheduleOverlay();
}
%end

%ctor {
    @autoreleasepool {
        %init;
        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(__unused NSNotification *note) { WFScheduleOverlay(); }];
    }
}
