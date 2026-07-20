#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

static NSString * const WFCodeKey = @"WolFoxLicenseCode";
static NSString * const WFTokenKey = @"WolFoxLicenseToken";
static NSString * const WFExpiryKey = @"WolFoxLicenseExpiry";
static NSString * const WFEnabledKeyGate = @"WolFoxEnabled";
static NSString * const WFActivateURL = @"https://key.p3nd.fun/api/activate.php";

@interface WFFloatingButton : UIButton
- (void)openPanel;
@end

static NSUserDefaults *WFDef(void) { return [NSUserDefaults standardUserDefaults]; }
static NSString *WFUUID(void) {
    NSString *v = [WFDef() stringForKey:@"WolFoxDeviceUUID"];
    if (v.length) return v;
    v = UIDevice.currentDevice.identifierForVendor.UUIDString ?: NSUUID.UUID.UUIDString;
    [WFDef() setObject:v forKey:@"WolFoxDeviceUUID"];
    return v;
}
static BOOL WFValid(void) {
    return [[WFDef() stringForKey:WFTokenKey] length] > 0 && [WFDef() doubleForKey:WFExpiryKey] > NSDate.date.timeIntervalSince1970;
}
static NSString *WFText(id value) {
    if (!value || value == NSNull.null) return @"";
    NSString *s = [value description];
    return [s isEqualToString:@"(null)"] ? @"" : s;
}
static NSTimeInterval WFExpiry(id value) {
    double n = [value respondsToSelector:@selector(doubleValue)] ? [value doubleValue] : 0;
    if (n > 1000000000000.0) n /= 1000.0;
    if (n > 1000000000.0) return n;
    return NSDate.date.timeIntervalSince1970 + 86400.0;
}
static void WFActivate(NSString *code, void (^done)(BOOL, NSString *)) {
    NSURL *url = [NSURL URLWithString:WFActivateURL];
    NSMutableURLRequest *r = [NSMutableURLRequest requestWithURL:url];
    r.HTTPMethod = @"POST";
    r.timeoutInterval = 20;
    [r setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [r setValue:@"application/x-www-form-urlencoded; charset=utf-8" forHTTPHeaderField:@"Content-Type"];
    NSString *uuid = WFUUID();
    NSString *body = [NSString stringWithFormat:@"code=%@&key=%@&license_code=%@&device_uuid=%@&device_id=%@&udid=%@&project=GPSPlus&platform=ios", code, code, code, uuid, uuid, uuid];
    r.HTTPBody = [body dataUsingEncoding:NSUTF8StringEncoding];
    [[NSURLSession.sharedSession dataTaskWithRequest:r completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSHTTPURLResponse *http = (NSHTTPURLResponse *)response;
            if (error || http.statusCode < 200 || http.statusCode >= 300 || !data.length) {
                done(NO, error ? @"تعذر الاتصال بخادم التفعيل" : [NSString stringWithFormat:@"خطأ الخادم (%ld)", (long)http.statusCode]); return;
            }
            id obj = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            if (![obj isKindOfClass:NSDictionary.class]) { done(NO, @"استجابة الخادم غير صالحة"); return; }
            NSMutableDictionary *json = [(NSDictionary *)obj mutableCopy];
            if ([json[@"data"] isKindOfClass:NSDictionary.class]) [json addEntriesFromDictionary:json[@"data"]];
            NSString *status = [WFText(json[@"status"]) lowercaseString];
            BOOL ok = [json[@"success"] boolValue] || [json[@"valid"] boolValue] || [json[@"active"] boolValue] || [@[@"ok",@"success",@"active",@"valid"] containsObject:status];
            if (!ok) { done(NO, WFText(json[@"message"]).length ? WFText(json[@"message"]) : @"الكود غير صالح أو منتهي"); return; }
            NSDictionary *lic = [json[@"license"] isKindOfClass:NSDictionary.class] ? json[@"license"] : json;
            NSString *token = WFText(lic[@"token"] ?: json[@"token"] ?: json[@"auth_token"]);
            if (!token.length) token = [NSString stringWithFormat:@"%@-%@", code, uuid];
            [WFDef() setObject:code forKey:WFCodeKey];
            [WFDef() setObject:token forKey:WFTokenKey];
            [WFDef() setDouble:WFExpiry(lic[@"expires_at"] ?: lic[@"expiry"] ?: lic[@"expire_at"]) forKey:WFExpiryKey];
            [WFDef() synchronize];
            done(YES, @"تم تفعيل الأداة بنجاح");
        });
    }] resume];
}

@interface WFLicenseControllerV3 : UIViewController <UITextFieldDelegate>
@property(nonatomic,strong) UITextField *field;
@property(nonatomic,strong) UILabel *status;
@property(nonatomic,strong) UIButton *button;
@property(nonatomic,copy) void (^successBlock)(void);
@end

@implementation WFLicenseControllerV3
- (void)viewDidLoad {
    [super viewDidLoad]; self.view.backgroundColor = UIColor.blackColor;
    UILabel *title = [[UILabel alloc] init]; title.translatesAutoresizingMaskIntoConstraints = NO; title.text = @"تفعيل WolFox GPS"; title.textColor = UIColor.whiteColor; title.font = [UIFont boldSystemFontOfSize:24]; title.textAlignment = NSTextAlignmentCenter; [self.view addSubview:title];
    UILabel *device = [[UILabel alloc] init]; device.translatesAutoresizingMaskIntoConstraints = NO; device.text = [NSString stringWithFormat:@"معرف الجهاز\n%@", WFUUID()]; device.textColor = UIColor.grayColor; device.numberOfLines = 2; device.textAlignment = NSTextAlignmentCenter; [self.view addSubview:device];
    self.field = [[UITextField alloc] init]; self.field.translatesAutoresizingMaskIntoConstraints = NO; self.field.text = [WFDef() stringForKey:WFCodeKey]; self.field.placeholder = @"أدخل كود التفعيل"; self.field.textColor = UIColor.whiteColor; self.field.backgroundColor = [UIColor colorWithWhite:.1 alpha:1]; self.field.layer.cornerRadius = 14; self.field.textAlignment = NSTextAlignmentCenter; self.field.delegate = self; [self.view addSubview:self.field];
    self.button = [UIButton buttonWithType:UIButtonTypeSystem]; self.button.translatesAutoresizingMaskIntoConstraints = NO; self.button.backgroundColor = UIColor.systemGreenColor; self.button.layer.cornerRadius = 14; [self.button setTitle:@"تفعيل الكود" forState:UIControlStateNormal]; [self.button setTitleColor:UIColor.blackColor forState:UIControlStateNormal]; [self.button addTarget:self action:@selector(run) forControlEvents:UIControlEventTouchUpInside]; [self.view addSubview:self.button];
    self.status = [[UILabel alloc] init]; self.status.translatesAutoresizingMaskIntoConstraints = NO; self.status.textAlignment = NSTextAlignmentCenter; self.status.numberOfLines = 0; [self.view addSubview:self.status];
    UIButton *close = [UIButton buttonWithType:UIButtonTypeSystem]; close.translatesAutoresizingMaskIntoConstraints = NO; [close setTitle:@"إغلاق" forState:UIControlStateNormal]; [close addTarget:self action:@selector(close) forControlEvents:UIControlEventTouchUpInside]; [self.view addSubview:close];
    [NSLayoutConstraint activateConstraints:@[[title.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:70],[title.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],[device.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:25],[device.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],[self.field.topAnchor constraintEqualToAnchor:device.bottomAnchor constant:35],[self.field.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:28],[self.field.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-28],[self.field.heightAnchor constraintEqualToConstant:58],[self.button.topAnchor constraintEqualToAnchor:self.field.bottomAnchor constant:18],[self.button.leadingAnchor constraintEqualToAnchor:self.field.leadingAnchor],[self.button.trailingAnchor constraintEqualToAnchor:self.field.trailingAnchor],[self.button.heightAnchor constraintEqualToConstant:56],[self.status.topAnchor constraintEqualToAnchor:self.button.bottomAnchor constant:18],[self.status.leadingAnchor constraintEqualToAnchor:self.field.leadingAnchor],[self.status.trailingAnchor constraintEqualToAnchor:self.field.trailingAnchor],[close.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-20],[close.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor]]];
}
- (void)close { [self dismissViewControllerAnimated:YES completion:nil]; }
- (BOOL)textFieldShouldReturn:(UITextField *)textField { [self run]; return YES; }
- (void)run {
    NSString *code = [self.field.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (code.length < 4) { self.status.text = @"أدخل كود تفعيل صحيح"; self.status.textColor = UIColor.systemRedColor; return; }
    self.button.enabled = NO; self.status.text = @"جاري التحقق..."; self.status.textColor = UIColor.grayColor;
    __weak typeof(self) weakSelf = self;
    WFActivate(code, ^(BOOL ok, NSString *msg) { weakSelf.button.enabled = YES; weakSelf.status.text = msg; weakSelf.status.textColor = ok ? UIColor.systemGreenColor : UIColor.systemRedColor; if (ok) dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(.7*NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ [weakSelf dismissViewControllerAnimated:YES completion:weakSelf.successBlock]; }); });
}
@end

%hook WFFloatingButton
- (void)openPanel {
    if (WFValid()) { %orig; return; }
    [WFDef() setBool:NO forKey:WFEnabledKeyGate];
    UIViewController *top = self.window.rootViewController;
    while (top.presentedViewController) top = top.presentedViewController;
    WFLicenseControllerV3 *vc = [[WFLicenseControllerV3 alloc] init]; vc.modalPresentationStyle = UIModalPresentationFullScreen;
    __weak WFFloatingButton *weakButton = self; vc.successBlock = ^{ [weakButton openPanel]; };
    [top presentViewController:vc animated:YES completion:nil];
}
%end
