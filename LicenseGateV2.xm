#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

static NSString * const WFLicenseCodeKeyV2 = @"WolFoxLicenseCode";
static NSString * const WFLicenseTokenKeyV2 = @"WolFoxLicenseToken";
static NSString * const WFLicenseExpiryKeyV2 = @"WolFoxLicenseExpiry";
static NSString * const WFEnabledGateKeyV2 = @"WolFoxEnabled";

@interface WFFloatingButton : UIButton
- (void)openPanel;
@end

static NSUserDefaults *WFDefaultsV2(void) { return [NSUserDefaults standardUserDefaults]; }

static NSString *WFDeviceUUIDV2(void) {
    NSString *saved = [WFDefaultsV2() stringForKey:@"WolFoxDeviceUUID"];
    if (saved.length > 0) return saved;
    NSString *value = UIDevice.currentDevice.identifierForVendor.UUIDString;
    if (value.length == 0) value = NSUUID.UUID.UUIDString;
    [WFDefaultsV2() setObject:value forKey:@"WolFoxDeviceUUID"];
    return value;
}

static BOOL WFLicenseValidV2(void) {
    NSString *token = [WFDefaultsV2() stringForKey:WFLicenseTokenKeyV2];
    NSTimeInterval expiry = [WFDefaultsV2() doubleForKey:WFLicenseExpiryKeyV2];
    return token.length > 0 && expiry > NSDate.date.timeIntervalSince1970;
}

static void WFClearLicenseV2(void) {
    [WFDefaultsV2() removeObjectForKey:WFLicenseCodeKeyV2];
    [WFDefaultsV2() removeObjectForKey:WFLicenseTokenKeyV2];
    [WFDefaultsV2() removeObjectForKey:WFLicenseExpiryKeyV2];
    [WFDefaultsV2() setBool:NO forKey:WFEnabledGateKeyV2];
}

static NSString *WFStringV2(id value) {
    if (!value || value == NSNull.null) return @"";
    NSString *text = [value description];
    return ([text isEqualToString:@"(null)"] || [text isEqualToString:@"<null>"]) ? @"" : text;
}

static NSTimeInterval WFExpiryV2(NSDictionary *json) {
    id value = json[@"expires_at"] ?: json[@"expiry"] ?: json[@"expire_at"] ?: json[@"end_date"];
    if ([value respondsToSelector:@selector(doubleValue)]) {
        double n = [value doubleValue];
        if (n > 1000000000000.0) n /= 1000.0;
        if (n > 1000000000.0) return n;
    }
    if ([value isKindOfClass:NSString.class]) {
        NSDateFormatter *f = [[NSDateFormatter alloc] init];
        f.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
        for (NSString *format in @[@"yyyy-MM-dd HH:mm:ss", @"yyyy-MM-dd'T'HH:mm:ssZ", @"yyyy-MM-dd"]) {
            f.dateFormat = format;
            NSDate *d = [f dateFromString:value];
            if (d) return d.timeIntervalSince1970;
        }
    }
    NSInteger days = [json[@"days"] integerValue];
    if (days <= 0) days = [json[@"duration_days"] integerValue];
    return days > 0 ? NSDate.date.timeIntervalSince1970 + days * 86400.0 : 0;
}

static NSArray<NSString *> *WFEndpointsV2(void) {
    return @[
        @"https://key.p3nd.fun/ipa/api/verify",
        @"https://key.p3nd.fun/ipa/api/activate",
        @"https://key.p3nd.fun/ipa/verify",
        @"https://key.p3nd.fun/ipa/activate",
        @"https://key.p3nd.fun/ipa/check",
        @"https://key.p3nd.fun/ipa/check.php",
        @"https://key.p3nd.fun/ipa/verify_code.php",
        @"https://key.p3nd.fun/ipa/api/verify.php",
        @"https://key.p3nd.fun/ipa/api_3R/verify.php",
        @"https://key.p3nd.fun/ipa/api.php"
    ];
}

static void WFVerifyAtIndexV2(NSString *code, NSInteger index, void (^done)(BOOL, NSString *));

static void WFHandleResponseV2(NSString *code, NSInteger index, NSData *data, NSURLResponse *response, NSError *error, void (^done)(BOOL, NSString *)) {
    NSHTTPURLResponse *http = (NSHTTPURLResponse *)response;
    if (error || !http || http.statusCode == 404 || http.statusCode == 405 || data.length == 0) {
        if (index + 1 < (NSInteger)WFEndpointsV2().count) {
            WFVerifyAtIndexV2(code, index + 1, done);
        } else {
            done(NO, @"لم يتم العثور على مسار API داخل /ipa. يلزم رابط ملف التحقق المباشر مثل verify.php");
        }
        return;
    }

    NSError *jsonError = nil;
    id object = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
    if (![object isKindOfClass:NSDictionary.class]) {
        if (index + 1 < (NSInteger)WFEndpointsV2().count) WFVerifyAtIndexV2(code, index + 1, done);
        else done(NO, @"الخادم يعيد صفحة HTML وليس استجابة JSON");
        return;
    }

    NSMutableDictionary *json = [(NSDictionary *)object mutableCopy];
    if ([json[@"data"] isKindOfClass:NSDictionary.class]) [json addEntriesFromDictionary:json[@"data"]];
    if ([json[@"result"] isKindOfClass:NSDictionary.class]) [json addEntriesFromDictionary:json[@"result"]];

    NSString *status = [WFStringV2(json[@"status"]) lowercaseString];
    BOOL ok = [json[@"success"] boolValue] || [json[@"valid"] boolValue] || [json[@"active"] boolValue] ||
              [@[@"ok", @"success", @"active", @"valid"] containsObject:status];
    if (!ok) {
        NSString *message = WFStringV2(json[@"message"] ?: json[@"error"] ?: json[@"msg"]);
        done(NO, message.length ? message : @"الكود غير صالح أو منتهي");
        return;
    }

    NSDictionary *license = [json[@"license"] isKindOfClass:NSDictionary.class] ? json[@"license"] : json;
    NSTimeInterval expiry = WFExpiryV2(license);
    if (expiry <= NSDate.date.timeIntervalSince1970) expiry = NSDate.date.timeIntervalSince1970 + 86400.0;
    NSString *token = WFStringV2(license[@"token"] ?: json[@"auth_token"] ?: json[@"access_token"]);
    if (token.length == 0) token = [NSString stringWithFormat:@"%@-%@", code, WFDeviceUUIDV2()];

    [WFDefaultsV2() setObject:code forKey:WFLicenseCodeKeyV2];
    [WFDefaultsV2() setObject:token forKey:WFLicenseTokenKeyV2];
    [WFDefaultsV2() setDouble:expiry forKey:WFLicenseExpiryKeyV2];
    [WFDefaultsV2() synchronize];
    done(YES, @"تم تفعيل الأداة بنجاح");
}

static void WFVerifyAtIndexV2(NSString *code, NSInteger index, void (^done)(BOOL, NSString *)) {
    if (index >= (NSInteger)WFEndpointsV2().count) { done(NO, @"لا يوجد مسار API صالح"); return; }
    NSURL *url = [NSURL URLWithString:WFEndpointsV2()[index]];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"POST";
    request.timeoutInterval = 15.0;
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [request setValue:@"application/x-www-form-urlencoded; charset=utf-8" forHTTPHeaderField:@"Content-Type"];
    NSString *device = WFDeviceUUIDV2();
    NSString *body = [NSString stringWithFormat:@"code=%@&key=%@&license_code=%@&device_uuid=%@&device_id=%@&udid=%@&project=GPSPlus&platform=ios", code, code, code, device, device, device];
    request.HTTPBody = [body dataUsingEncoding:NSUTF8StringEncoding];
    [[NSURLSession.sharedSession dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{ WFHandleResponseV2(code, index, data, response, error, done); });
    }] resume];
}

@interface WFLicenseControllerV2 : UIViewController <UITextFieldDelegate>
@property(nonatomic,strong) UITextField *codeField;
@property(nonatomic,strong) UILabel *statusLabel;
@property(nonatomic,strong) UIButton *activateButton;
@property(nonatomic,copy) void (^successBlock)(void);
@end

@implementation WFLicenseControllerV2
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithRed:0.02 green:0.025 blue:0.035 alpha:1.0];
    UILabel *title = [[UILabel alloc] init]; title.translatesAutoresizingMaskIntoConstraints = NO; title.text = @"تفعيل WolFox GPS"; title.textColor = UIColor.whiteColor; title.font = [UIFont boldSystemFontOfSize:24]; title.textAlignment = NSTextAlignmentCenter; [self.view addSubview:title];
    UILabel *device = [[UILabel alloc] init]; device.translatesAutoresizingMaskIntoConstraints = NO; device.text = [NSString stringWithFormat:@"معرف الجهاز\n%@", WFDeviceUUIDV2()]; device.textColor = UIColor.lightGrayColor; device.numberOfLines = 2; device.textAlignment = NSTextAlignmentCenter; device.font = [UIFont systemFontOfSize:12]; [self.view addSubview:device];
    self.codeField = [[UITextField alloc] init]; self.codeField.translatesAutoresizingMaskIntoConstraints = NO; self.codeField.placeholder = @"أدخل كود التفعيل"; self.codeField.text = [WFDefaultsV2() stringForKey:WFLicenseCodeKeyV2]; self.codeField.textColor = UIColor.whiteColor; self.codeField.backgroundColor = [UIColor colorWithWhite:0.10 alpha:1]; self.codeField.layer.cornerRadius = 14; self.codeField.textAlignment = NSTextAlignmentCenter; self.codeField.delegate = self; [self.view addSubview:self.codeField];
    self.activateButton = [UIButton buttonWithType:UIButtonTypeSystem]; self.activateButton.translatesAutoresizingMaskIntoConstraints = NO; self.activateButton.backgroundColor = [UIColor colorWithRed:0.18 green:0.92 blue:0.40 alpha:1]; self.activateButton.layer.cornerRadius = 14; [self.activateButton setTitle:@"تفعيل الكود" forState:UIControlStateNormal]; [self.activateButton setTitleColor:UIColor.blackColor forState:UIControlStateNormal]; self.activateButton.titleLabel.font = [UIFont boldSystemFontOfSize:17]; [self.activateButton addTarget:self action:@selector(activatePressed) forControlEvents:UIControlEventTouchUpInside]; [self.view addSubview:self.activateButton];
    self.statusLabel = [[UILabel alloc] init]; self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO; self.statusLabel.textColor = UIColor.lightGrayColor; self.statusLabel.numberOfLines = 0; self.statusLabel.textAlignment = NSTextAlignmentCenter; [self.view addSubview:self.statusLabel];
    UIButton *close = [UIButton buttonWithType:UIButtonTypeSystem]; close.translatesAutoresizingMaskIntoConstraints = NO; [close setTitle:@"إغلاق" forState:UIControlStateNormal]; [close setTitleColor:UIColor.lightGrayColor forState:UIControlStateNormal]; [close addTarget:self action:@selector(closePressed) forControlEvents:UIControlEventTouchUpInside]; [self.view addSubview:close];
    [NSLayoutConstraint activateConstraints:@[[title.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:70],[title.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],[title.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],[device.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:22],[device.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:24],[device.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-24],[self.codeField.topAnchor constraintEqualToAnchor:device.bottomAnchor constant:34],[self.codeField.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:28],[self.codeField.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-28],[self.codeField.heightAnchor constraintEqualToConstant:58],[self.activateButton.topAnchor constraintEqualToAnchor:self.codeField.bottomAnchor constant:18],[self.activateButton.leadingAnchor constraintEqualToAnchor:self.codeField.leadingAnchor],[self.activateButton.trailingAnchor constraintEqualToAnchor:self.codeField.trailingAnchor],[self.activateButton.heightAnchor constraintEqualToConstant:56],[self.statusLabel.topAnchor constraintEqualToAnchor:self.activateButton.bottomAnchor constant:18],[self.statusLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:24],[self.statusLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-24],[close.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-20],[close.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor]];
}
- (BOOL)textFieldShouldReturn:(UITextField *)textField { [self activatePressed]; return YES; }
- (void)closePressed { [self dismissViewControllerAnimated:YES completion:nil]; }
- (void)activatePressed {
    NSString *source = self.codeField.text ? self.codeField.text : @"";
    NSString *code = [source stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (code.length < 4) { self.statusLabel.text = @"أدخل كود تفعيل صحيح"; self.statusLabel.textColor = UIColor.systemRedColor; return; }
    [self.codeField resignFirstResponder]; self.activateButton.enabled = NO; self.statusLabel.text = @"جاري التحقق من الكود..."; self.statusLabel.textColor = UIColor.lightGrayColor;
    __weak typeof(self) weakSelf = self;
    WFVerifyAtIndexV2(code, 0, ^(BOOL ok, NSString *message) { weakSelf.activateButton.enabled = YES; weakSelf.statusLabel.text = message; weakSelf.statusLabel.textColor = ok ? UIColor.systemGreenColor : UIColor.systemRedColor; if (ok) dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.7*NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ [weakSelf dismissViewControllerAnimated:YES completion:weakSelf.successBlock]; }); });
}
@end

static UIViewController *WFTopControllerV2(UIWindow *window) { UIViewController *c = window.rootViewController; while (c.presentedViewController) c = c.presentedViewController; return c; }

%hook WFFloatingButton
- (void)openPanel {
    if (WFLicenseValidV2()) { %orig; return; }
    WFClearLicenseV2();
    UIViewController *top = WFTopControllerV2(self.window);
    if (!top) return;
    WFLicenseControllerV2 *license = [[WFLicenseControllerV2 alloc] init];
    license.modalPresentationStyle = UIModalPresentationFullScreen;
    __weak WFFloatingButton *weakButton = self;
    license.successBlock = ^{ [weakButton openPanel]; };
    [top presentViewController:license animated:YES completion:nil];
}
%end
