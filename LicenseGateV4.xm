#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

static NSString * const WFCodeKey4 = @"WolFoxLicenseCode";
static NSString * const WFTokenKey4 = @"WolFoxLicenseToken";
static NSString * const WFExpiryKey4 = @"WolFoxLicenseExpiry";
static NSString * const WFEnabledKey4 = @"WolFoxEnabled";
static NSString * const WFActivateURL4 = @"https://key.p3nd.fun/api/activate.php";
static NSString * const WFAPISecret4 = @"6BIacWrJhm6Wpq5mEWw6QBlX_XSMXdhEonvut3NO7uU";

@interface WFFloatingButton : UIButton
- (void)openPanel;
@end

static NSUserDefaults *WFDefaults4(void) { return NSUserDefaults.standardUserDefaults; }

static NSString *WFDevice4(void) {
    NSString *value = [WFDefaults4() stringForKey:@"WolFoxDeviceUUID"];
    if (value.length) return value;
    value = UIDevice.currentDevice.identifierForVendor.UUIDString;
    if (!value.length) value = NSUUID.UUID.UUIDString;
    [WFDefaults4() setObject:value forKey:@"WolFoxDeviceUUID"];
    [WFDefaults4() synchronize];
    return value;
}

static NSString *WFText4(id value) {
    if (!value || value == NSNull.null) return @"";
    NSString *text = [value description];
    return ([text isEqualToString:@"(null)"] || [text isEqualToString:@"<null>"]) ? @"" : text;
}

static NSTimeInterval WFExpiry4(id value) {
    if ([value respondsToSelector:@selector(doubleValue)]) {
        double number = [value doubleValue];
        if (number > 1000000000000.0) number /= 1000.0;
        if (number > 1000000000.0) return number;
    }
    NSString *text = WFText4(value);
    if (text.length) {
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        formatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
        formatter.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
        for (NSString *format in @[@"yyyy-MM-dd HH:mm:ss", @"yyyy-MM-dd'T'HH:mm:ssZ", @"yyyy-MM-dd"]) {
            formatter.dateFormat = format;
            NSDate *date = [formatter dateFromString:text];
            if (date) return date.timeIntervalSince1970;
        }
    }
    return 0;
}

static BOOL WFLicenseValid4(void) {
    NSString *token = [WFDefaults4() stringForKey:WFTokenKey4];
    return token.length && [WFDefaults4() doubleForKey:WFExpiryKey4] > NSDate.date.timeIntervalSince1970;
}

static NSString *WFEncode4(NSString *value) {
    return [value stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLQueryAllowedCharacterSet] ?: @"";
}

static void WFActivate4(NSString *code, void (^done)(BOOL, NSString *)) {
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:WFActivateURL4]];
    request.HTTPMethod = @"POST";
    request.timeoutInterval = 20.0;
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [request setValue:@"application/x-www-form-urlencoded; charset=utf-8" forHTTPHeaderField:@"Content-Type"];

    NSString *device = WFDevice4();
    NSString *deviceName = UIDevice.currentDevice.name ?: @"iPhone";
    NSString *body = [NSString stringWithFormat:@"api_secret=%@&code=%@&device_uuid=%@&device_name=%@&app_version=1.4.0",
                      WFEncode4(WFAPISecret4), WFEncode4(code), WFEncode4(device), WFEncode4(deviceName)];
    request.HTTPBody = [body dataUsingEncoding:NSUTF8StringEncoding];

    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSHTTPURLResponse *http = (NSHTTPURLResponse *)response;
            if (error || !http || http.statusCode < 200 || http.statusCode >= 300 || !data.length) {
                done(NO, error ? @"تعذر الاتصال بخادم التفعيل" : [NSString stringWithFormat:@"خطأ الخادم (%ld)", (long)http.statusCode]);
                return;
            }
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            if (![json isKindOfClass:NSDictionary.class]) { done(NO, @"استجابة الخادم غير صالحة"); return; }
            NSString *status = [WFText4(json[@"status"]) lowercaseString];
            BOOL ok = [json[@"ok"] boolValue] || [json[@"success"] boolValue] || [status isEqualToString:@"active"];
            if (!ok) { done(NO, WFText4(json[@"message"]).length ? WFText4(json[@"message"]) : @"الكود غير صالح أو منتهي"); return; }
            NSDictionary *license = [json[@"license"] isKindOfClass:NSDictionary.class] ? json[@"license"] : json;
            NSTimeInterval expiry = WFExpiry4(license[@"expires_at"]);
            if (expiry <= NSDate.date.timeIntervalSince1970) { done(NO, @"تاريخ انتهاء الترخيص غير صالح"); return; }
            NSString *token = [NSString stringWithFormat:@"%@-%@", code, device];
            [WFDefaults4() setObject:code forKey:WFCodeKey4];
            [WFDefaults4() setObject:token forKey:WFTokenKey4];
            [WFDefaults4() setDouble:expiry forKey:WFExpiryKey4];
            [WFDefaults4() synchronize];
            done(YES, @"تم تفعيل الأداة بنجاح");
        });
    }];
    [task resume];
}

@interface WFLicenseControllerV4 : UIViewController <UITextFieldDelegate>
@property(nonatomic,strong) UITextField *field;
@property(nonatomic,strong) UILabel *statusLabel;
@property(nonatomic,strong) UIButton *activateButton;
@property(nonatomic,copy) void (^successBlock)(void);
@end

@implementation WFLicenseControllerV4
- (BOOL)prefersStatusBarHidden { return YES; }
- (BOOL)prefersHomeIndicatorAutoHidden { return YES; }
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.blackColor;
    UILabel *title = [[UILabel alloc] init]; title.translatesAutoresizingMaskIntoConstraints = NO; title.text = @"تفعيل WolFox GPS"; title.textColor = UIColor.whiteColor; title.font = [UIFont boldSystemFontOfSize:26]; title.textAlignment = NSTextAlignmentCenter; [self.view addSubview:title];
    UILabel *device = [[UILabel alloc] init]; device.translatesAutoresizingMaskIntoConstraints = NO; device.text = [NSString stringWithFormat:@"معرف الجهاز\n%@", WFDevice4()]; device.textColor = UIColor.grayColor; device.numberOfLines = 2; device.textAlignment = NSTextAlignmentCenter; [self.view addSubview:device];
    self.field = [[UITextField alloc] init]; self.field.translatesAutoresizingMaskIntoConstraints = NO; self.field.placeholder = @"أدخل كود التفعيل"; self.field.text = [WFDefaults4() stringForKey:WFCodeKey4]; self.field.textColor = UIColor.whiteColor; self.field.backgroundColor = [UIColor colorWithWhite:0.1 alpha:1]; self.field.layer.cornerRadius = 14; self.field.textAlignment = NSTextAlignmentCenter; self.field.delegate = self; [self.view addSubview:self.field];
    self.activateButton = [UIButton buttonWithType:UIButtonTypeSystem]; self.activateButton.translatesAutoresizingMaskIntoConstraints = NO; self.activateButton.backgroundColor = UIColor.systemGreenColor; self.activateButton.layer.cornerRadius = 14; [self.activateButton setTitle:@"تفعيل الكود" forState:UIControlStateNormal]; [self.activateButton setTitleColor:UIColor.blackColor forState:UIControlStateNormal]; [self.activateButton addTarget:self action:@selector(runActivation) forControlEvents:UIControlEventTouchUpInside]; [self.view addSubview:self.activateButton];
    self.statusLabel = [[UILabel alloc] init]; self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO; self.statusLabel.numberOfLines = 0; self.statusLabel.textAlignment = NSTextAlignmentCenter; [self.view addSubview:self.statusLabel];
    UIButton *close = [UIButton buttonWithType:UIButtonTypeSystem]; close.translatesAutoresizingMaskIntoConstraints = NO; [close setTitle:@"إغلاق" forState:UIControlStateNormal]; [close addTarget:self action:@selector(closeScreen) forControlEvents:UIControlEventTouchUpInside]; [self.view addSubview:close];
    [NSLayoutConstraint activateConstraints:@[[title.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:110],[title.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],[title.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],[device.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:26],[device.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],[device.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],[self.field.topAnchor constraintEqualToAnchor:device.bottomAnchor constant:36],[self.field.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:28],[self.field.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-28],[self.field.heightAnchor constraintEqualToConstant:58],[self.activateButton.topAnchor constraintEqualToAnchor:self.field.bottomAnchor constant:18],[self.activateButton.leadingAnchor constraintEqualToAnchor:self.field.leadingAnchor],[self.activateButton.trailingAnchor constraintEqualToAnchor:self.field.trailingAnchor],[self.activateButton.heightAnchor constraintEqualToConstant:56],[self.statusLabel.topAnchor constraintEqualToAnchor:self.activateButton.bottomAnchor constant:18],[self.statusLabel.leadingAnchor constraintEqualToAnchor:self.field.leadingAnchor],[self.statusLabel.trailingAnchor constraintEqualToAnchor:self.field.trailingAnchor],[close.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:-36],[close.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor]]];
}
- (void)closeScreen { [self dismissViewControllerAnimated:YES completion:nil]; }
- (BOOL)textFieldShouldReturn:(UITextField *)textField { [self runActivation]; return YES; }
- (void)runActivation {
    NSString *source = self.field.text ?: @"";
    NSString *code = [source stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (code.length < 4) { self.statusLabel.text = @"أدخل كود تفعيل صحيح"; self.statusLabel.textColor = UIColor.systemRedColor; return; }
    self.activateButton.enabled = NO; self.statusLabel.text = @"جاري التحقق..."; self.statusLabel.textColor = UIColor.grayColor;
    __weak typeof(self) weakSelf = self;
    WFActivate4(code, ^(BOOL ok, NSString *message) { weakSelf.activateButton.enabled = YES; weakSelf.statusLabel.text = message; weakSelf.statusLabel.textColor = ok ? UIColor.systemGreenColor : UIColor.systemRedColor; if (ok) dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.7 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ [weakSelf dismissViewControllerAnimated:YES completion:weakSelf.successBlock]; }); });
}
@end

%hook WFFloatingButton
- (void)openPanel {
    if (WFLicenseValid4()) { %orig; return; }
    [WFDefaults4() setBool:NO forKey:WFEnabledKey4];
    UIViewController *top = self.window.rootViewController;
    while (top.presentedViewController) top = top.presentedViewController;
    WFLicenseControllerV4 *controller = [[WFLicenseControllerV4 alloc] init];
    controller.modalPresentationStyle = UIModalPresentationFullScreen;
    __weak WFFloatingButton *weakButton = self;
    controller.successBlock = ^{ [weakButton openPanel]; };
    [top presentViewController:controller animated:YES completion:nil];
}
%end