#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

static NSString * const WFLicenseCodeKey = @"WolFoxLicenseCode";
static NSString * const WFLicenseTokenKey = @"WolFoxLicenseToken";
static NSString * const WFLicenseExpiryKey = @"WolFoxLicenseExpiry";
static NSString * const WFLicenseNameKey = @"WolFoxLicenseName";
static NSString * const WFEnabledGateKey = @"WolFoxEnabled";
static NSString * const WFLicenseAPIURL = @"https://key.p3nd.fun/ipa";

@interface WFFloatingButton : UIButton
- (void)openPanel;
@end

static NSUserDefaults *WFDefaultsGate(void) { return NSUserDefaults.standardUserDefaults; }

static NSString *WFDeviceUUID(void) {
    NSString *saved = [WFDefaultsGate() stringForKey:@"WolFoxDeviceUUID"];
    if (saved.length) return saved;
    NSString *value = UIDevice.currentDevice.identifierForVendor.UUIDString ?: NSUUID.UUID.UUIDString;
    [WFDefaultsGate() setObject:value forKey:@"WolFoxDeviceUUID"];
    return value;
}

static BOOL WFLicenseValid(void) {
    NSString *token = [WFDefaultsGate() stringForKey:WFLicenseTokenKey];
    NSTimeInterval expiry = [WFDefaultsGate() doubleForKey:WFLicenseExpiryKey];
    return token.length > 0 && expiry > NSDate.date.timeIntervalSince1970;
}

static void WFClearLicense(void) {
    NSUserDefaults *d = WFDefaultsGate();
    [d removeObjectForKey:WFLicenseCodeKey];
    [d removeObjectForKey:WFLicenseTokenKey];
    [d removeObjectForKey:WFLicenseExpiryKey];
    [d removeObjectForKey:WFLicenseNameKey];
    [d setBool:NO forKey:WFEnabledGateKey];
}

static NSTimeInterval WFParseExpiry(id value) {
    if ([value respondsToSelector:@selector(doubleValue)]) {
        double n = [value doubleValue];
        if (n > 1000000000.0) return n;
    }
    if ([value isKindOfClass:NSString.class]) {
        NSDateFormatter *f = [[NSDateFormatter alloc] init];
        f.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
        for (NSString *format in @[@"yyyy-MM-dd HH:mm:ss", @"yyyy-MM-dd'T'HH:mm:ssZ", @"yyyy-MM-dd"]) {
            f.dateFormat = format;
            NSDate *date = [f dateFromString:value];
            if (date) return date.timeIntervalSince1970;
        }
    }
    return 0;
}

static void WFCheckCode(NSString *code, void (^done)(BOOL, NSString *)) {
    NSString *clean = [code stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (clean.length < 4) { done(NO, @"أدخل كود تفعيل صحيح"); return; }

    NSMutableURLRequest *r = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:WFLicenseAPIURL]];
    r.HTTPMethod = @"POST";
    r.timeoutInterval = 20;
    [r setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [r setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    NSDictionary *body = @{
        @"code": clean,
        @"license_code": clean,
        @"device_uuid": WFDeviceUUID(),
        @"device_id": WFDeviceUUID(),
        @"project": @"GPSPlus",
        @"platform": @"ios",
        @"app_version": @"1.1.0"
    };
    r.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];

    [[NSURLSession.sharedSession dataTaskWithRequest:r completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) { done(NO, @"تعذر الاتصال بخادم التفعيل"); return; }
            NSHTTPURLResponse *http = (NSHTTPURLResponse *)response;
            if (http.statusCode < 200 || http.statusCode >= 300 || !data.length) {
                done(NO, [NSString stringWithFormat:@"خطأ الخادم (%ld)", (long)http.statusCode]); return;
            }
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            if (![json isKindOfClass:NSDictionary.class]) { done(NO, @"استجابة الخادم غير صالحة"); return; }

            NSString *status = [[json[@"status"] description] lowercaseString];
            BOOL ok = [json[@"success"] boolValue] || [json[@"valid"] boolValue] ||
                      [status isEqualToString:@"success"] || [status isEqualToString:@"active"] ||
                      [status isEqualToString:@"valid"] || [status isEqualToString:@"ok"];
            NSDictionary *license = [json[@"license"] isKindOfClass:NSDictionary.class] ? json[@"license"] : json;
            if (!ok) {
                NSString *message = [json[@"message"] description];
                done(NO, message.length && ![message isEqualToString:@"(null)"] ? message : @"الكود غير صالح أو منتهي");
                return;
            }

            NSTimeInterval expiry = WFParseExpiry(license[@"expires_at"] ?: license[@"expiry"] ?: license[@"expire_at"]);
            if (expiry <= NSDate.date.timeIntervalSince1970) expiry = NSDate.date.timeIntervalSince1970 + 86400.0;
            NSString *token = [license[@"token"] description];
            if (!token.length || [token isEqualToString:@"(null)"]) token = [json[@"auth_token"] description];
            if (!token.length || [token isEqualToString:@"(null)"]) token = NSUUID.UUID.UUIDString;
            NSString *name = [license[@"name"] description];
            if (!name.length || [name isEqualToString:@"(null)"]) name = @"GPS Plus";

            NSUserDefaults *d = WFDefaultsGate();
            [d setObject:clean forKey:WFLicenseCodeKey];
            [d setObject:token forKey:WFLicenseTokenKey];
            [d setDouble:expiry forKey:WFLicenseExpiryKey];
            [d setObject:name forKey:WFLicenseNameKey];
            done(YES, @"تم تفعيل الأداة بنجاح");
        });
    }] resume];
}

@interface WFLicenseController : UIViewController <UITextFieldDelegate>
@property(nonatomic,strong) UITextField *codeField;
@property(nonatomic,strong) UILabel *statusLabel;
@property(nonatomic,strong) UIButton *activateButton;
@property(nonatomic,copy) void (^successBlock)(void);
@end

@implementation WFLicenseController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithRed:0.025 green:0.03 blue:0.04 alpha:1];

    UILabel *title = [[UILabel alloc] init];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    title.text = @"تفعيل WolFox GPS";
    title.textColor = UIColor.whiteColor;
    title.font = [UIFont boldSystemFontOfSize:24];
    title.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:title];

    UILabel *device = [[UILabel alloc] init];
    device.translatesAutoresizingMaskIntoConstraints = NO;
    device.text = [NSString stringWithFormat:@"معرف الجهاز\n%@", WFDeviceUUID()];
    device.textColor = UIColor.lightGrayColor;
    device.numberOfLines = 2;
    device.font = [UIFont systemFontOfSize:12];
    device.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:device];

    self.codeField = [[UITextField alloc] init];
    self.codeField.translatesAutoresizingMaskIntoConstraints = NO;
    self.codeField.placeholder = @"أدخل كود التفعيل";
    self.codeField.text = [WFDefaultsGate() stringForKey:WFLicenseCodeKey];
    self.codeField.textColor = UIColor.whiteColor;
    self.codeField.backgroundColor = [UIColor colorWithWhite:0.10 alpha:1];
    self.codeField.layer.cornerRadius = 14;
    self.codeField.textAlignment = NSTextAlignmentCenter;
    self.codeField.autocapitalizationType = UITextAutocapitalizationTypeAllCharacters;
    self.codeField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.codeField.returnKeyType = UIReturnKeyDone;
    self.codeField.delegate = self;
    [self.view addSubview:self.codeField];

    self.activateButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.activateButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.activateButton.backgroundColor = [UIColor colorWithRed:0.18 green:0.92 blue:0.40 alpha:1];
    self.activateButton.layer.cornerRadius = 14;
    [self.activateButton setTitle:@"تفعيل الكود" forState:UIControlStateNormal];
    [self.activateButton setTitleColor:UIColor.blackColor forState:UIControlStateNormal];
    self.activateButton.titleLabel.font = [UIFont boldSystemFontOfSize:17];
    [self.activateButton addTarget:self action:@selector(activatePressed) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.activateButton];

    self.statusLabel = [[UILabel alloc] init];
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusLabel.textColor = UIColor.lightGrayColor;
    self.statusLabel.numberOfLines = 0;
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:self.statusLabel];

    UIButton *close = [UIButton buttonWithType:UIButtonTypeSystem];
    close.translatesAutoresizingMaskIntoConstraints = NO;
    [close setTitle:@"إغلاق" forState:UIControlStateNormal];
    [close setTitleColor:UIColor.lightGrayColor forState:UIControlStateNormal];
    [close addTarget:self action:@selector(closePressed) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:close];

    [NSLayoutConstraint activateConstraints:@[
        [title.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:70],
        [title.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [title.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        [device.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:22],
        [device.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:24],
        [device.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-24],
        [self.codeField.topAnchor constraintEqualToAnchor:device.bottomAnchor constant:34],
        [self.codeField.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:28],
        [self.codeField.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-28],
        [self.codeField.heightAnchor constraintEqualToConstant:58],
        [self.activateButton.topAnchor constraintEqualToAnchor:self.codeField.bottomAnchor constant:18],
        [self.activateButton.leadingAnchor constraintEqualToAnchor:self.codeField.leadingAnchor],
        [self.activateButton.trailingAnchor constraintEqualToAnchor:self.codeField.trailingAnchor],
        [self.activateButton.heightAnchor constraintEqualToConstant:56],
        [self.statusLabel.topAnchor constraintEqualToAnchor:self.activateButton.bottomAnchor constant:18],
        [self.statusLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:24],
        [self.statusLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-24],
        [close.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-20],
        [close.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor]
    ]];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField { [self activatePressed]; return YES; }
- (void)closePressed { [self dismissViewControllerAnimated:YES completion:nil]; }
- (void)activatePressed {
    [self.codeField resignFirstResponder];
    self.activateButton.enabled = NO;
    self.statusLabel.textColor = UIColor.lightGrayColor;
    self.statusLabel.text = @"جاري التحقق من الكود...";
    __weak typeof(self) weakSelf = self;
    WFCheckCode(self.codeField.text, ^(BOOL ok, NSString *message) {
        weakSelf.activateButton.enabled = YES;
        weakSelf.statusLabel.text = message;
        weakSelf.statusLabel.textColor = ok ? [UIColor colorWithRed:0.18 green:0.92 blue:0.40 alpha:1] : UIColor.systemRedColor;
        if (ok) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [weakSelf dismissViewControllerAnimated:YES completion:weakSelf.successBlock];
            });
        }
    });
}
@end

static UIViewController *WFTopController(UIWindow *window) {
    UIViewController *c = window.rootViewController;
    while (c.presentedViewController) c = c.presentedViewController;
    return c;
}

%hook WFFloatingButton
- (void)openPanel {
    if (WFLicenseValid()) { %orig; return; }
    WFClearLicense();
    UIWindow *window = self.window;
    UIViewController *top = WFTopController(window);
    if (!top) return;
    WFLicenseController *license = [[WFLicenseController alloc] init];
    license.modalPresentationStyle = UIModalPresentationFullScreen;
    __weak WFFloatingButton *weakButton = self;
    license.successBlock = ^{ [weakButton openPanel]; };
    [top presentViewController:license animated:YES completion:nil];
}
%end
