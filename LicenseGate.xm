#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

static NSString * const WFLicenseCodeKey = @"WolFoxLicenseCode";
static NSString * const WFLicenseTokenKey = @"WolFoxLicenseToken";
static NSString * const WFLicenseExpiryKey = @"WolFoxLicenseExpiry";
static NSString * const WFLicenseNameKey = @"WolFoxLicenseName";
static NSString * const WFEnabledGateKey = @"WolFoxEnabled";
static NSString * const WFLicenseBaseURL = @"https://key.p3nd.fun/ipa";

@interface WFFloatingButton : UIButton
- (void)openPanel;
@end

static NSUserDefaults *WFDefaultsGate(void) {
    return NSUserDefaults.standardUserDefaults;
}

static NSString *WFDeviceUUID(void) {
    NSString *saved = [WFDefaultsGate() stringForKey:@"WolFoxDeviceUUID"];
    if (saved.length > 0) return saved;

    NSString *value = UIDevice.currentDevice.identifierForVendor.UUIDString;
    if (value.length == 0) value = NSUUID.UUID.UUIDString;
    [WFDefaultsGate() setObject:value forKey:@"WolFoxDeviceUUID"];
    return value;
}

static BOOL WFLicenseValid(void) {
    NSString *token = [WFDefaultsGate() stringForKey:WFLicenseTokenKey];
    NSTimeInterval expiry = [WFDefaultsGate() doubleForKey:WFLicenseExpiryKey];
    return token.length > 0 && expiry > NSDate.date.timeIntervalSince1970;
}

static void WFClearLicense(void) {
    NSUserDefaults *defaults = WFDefaultsGate();
    [defaults removeObjectForKey:WFLicenseCodeKey];
    [defaults removeObjectForKey:WFLicenseTokenKey];
    [defaults removeObjectForKey:WFLicenseExpiryKey];
    [defaults removeObjectForKey:WFLicenseNameKey];
    [defaults setBool:NO forKey:WFEnabledGateKey];
}

static NSTimeInterval WFParseExpiry(id value) {
    if (!value || value == NSNull.null) return 0;

    if ([value respondsToSelector:@selector(doubleValue)]) {
        double number = [value doubleValue];
        if (number > 1000000000000.0) number /= 1000.0;
        if (number > 1000000000.0) return number;
    }

    if ([value isKindOfClass:NSString.class]) {
        NSString *text = [(NSString *)value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        formatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
        formatter.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];

        NSArray *formats = @[
            @"yyyy-MM-dd HH:mm:ss",
            @"yyyy-MM-dd'T'HH:mm:ssZ",
            @"yyyy-MM-dd'T'HH:mm:ss.SSSZ",
            @"yyyy-MM-dd"
        ];

        for (NSString *format in formats) {
            formatter.dateFormat = format;
            NSDate *date = [formatter dateFromString:text];
            if (date) return date.timeIntervalSince1970;
        }
    }

    return 0;
}

static NSString *WFStringValue(id value) {
    if (!value || value == NSNull.null) return @"";
    NSString *text = [value description];
    if ([text isEqualToString:@"(null)"] || [text isEqualToString:@"<null>"]) return @"";
    return text;
}

static NSString *WFURLEncode(NSString *text) {
    NSCharacterSet *allowed = [NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~"];
    return [text stringByAddingPercentEncodingWithAllowedCharacters:allowed] ?: @"";
}

static NSDictionary *WFNormalizeJSON(id object) {
    if (![object isKindOfClass:NSDictionary.class]) return nil;
    NSDictionary *json = (NSDictionary *)object;

    id data = json[@"data"];
    if ([data isKindOfClass:NSDictionary.class]) {
        NSMutableDictionary *merged = [json mutableCopy];
        [merged addEntriesFromDictionary:(NSDictionary *)data];
        json = merged;
    }

    id result = json[@"result"];
    if ([result isKindOfClass:NSDictionary.class]) {
        NSMutableDictionary *merged = [json mutableCopy];
        [merged addEntriesFromDictionary:(NSDictionary *)result];
        json = merged;
    }

    return json;
}

static BOOL WFResponseIsSuccess(NSDictionary *json) {
    NSString *status = [WFStringValue(json[@"status"]) lowercaseString];
    NSString *state = [WFStringValue(json[@"state"]) lowercaseString];

    return [json[@"success"] boolValue] ||
           [json[@"valid"] boolValue] ||
           [json[@"active"] boolValue] ||
           [status isEqualToString:@"success"] ||
           [status isEqualToString:@"active"] ||
           [status isEqualToString:@"valid"] ||
           [status isEqualToString:@"ok"] ||
           [state isEqualToString:@"active"] ||
           [state isEqualToString:@"valid"];
}

static NSArray<NSString *> *WFActivationEndpoints(void) {
    return @[
        WFLicenseBaseURL,
        [WFLicenseBaseURL stringByAppendingString:@"/"],
        [WFLicenseBaseURL stringByAppendingString:@"/verify.php"],
        [WFLicenseBaseURL stringByAppendingString:@"/api.php"],
        [WFLicenseBaseURL stringByAppendingString:@"/api/verify.php"]
    ];
}

static void WFSendActivationAttempt(NSString *code,
                                    NSInteger endpointIndex,
                                    BOOL useJSON,
                                    void (^done)(BOOL ok, NSString *message));

static void WFHandleActivationResponse(NSString *code,
                                       NSInteger endpointIndex,
                                       BOOL useJSON,
                                       NSData *data,
                                       NSURLResponse *response,
                                       NSError *error,
                                       void (^done)(BOOL ok, NSString *message)) {
    NSHTTPURLResponse *http = (NSHTTPURLResponse *)response;
    BOOL canRetry = endpointIndex + 1 < (NSInteger)WFActivationEndpoints().count;

    if (error || !http || http.statusCode < 200 || http.statusCode >= 300 || data.length == 0) {
        if (!useJSON) {
            WFSendActivationAttempt(code, endpointIndex, YES, done);
        } else if (canRetry) {
            WFSendActivationAttempt(code, endpointIndex + 1, NO, done);
        } else {
            done(NO, error ? @"تعذر الاتصال بخادم التفعيل" : [NSString stringWithFormat:@"خطأ الخادم (%ld)", (long)http.statusCode]);
        }
        return;
    }

    NSError *jsonError = nil;
    id object = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
    NSDictionary *json = WFNormalizeJSON(object);

    if (!json) {
        NSString *plain = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        NSString *lower = [[plain stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] lowercaseString];

        if ([lower isEqualToString:@"ok"] || [lower isEqualToString:@"success"] || [lower isEqualToString:@"active"] || [lower isEqualToString:@"valid"]) {
            json = @{ @"success": @YES, @"token": NSUUID.UUID.UUIDString, @"expires_at": @(NSDate.date.timeIntervalSince1970 + 86400.0) };
        } else {
            if (!useJSON) {
                WFSendActivationAttempt(code, endpointIndex, YES, done);
            } else if (canRetry) {
                WFSendActivationAttempt(code, endpointIndex + 1, NO, done);
            } else {
                done(NO, @"رابط التفعيل يعيد صفحة أو استجابة غير صالحة، ويجب تحديد مسار API الصحيح");
            }
            return;
        }
    }

    if (!WFResponseIsSuccess(json)) {
        NSString *message = WFStringValue(json[@"message"]);
        if (message.length == 0) message = WFStringValue(json[@"error"]);
        if (message.length == 0) message = WFStringValue(json[@"msg"]);

        if (!useJSON && (http.statusCode == 404 || http.statusCode == 405)) {
            WFSendActivationAttempt(code, endpointIndex, YES, done);
            return;
        }
        if (canRetry && message.length == 0) {
            WFSendActivationAttempt(code, endpointIndex + 1, NO, done);
            return;
        }

        done(NO, message.length ? message : @"الكود غير صالح أو منتهي");
        return;
    }

    NSDictionary *license = [json[@"license"] isKindOfClass:NSDictionary.class] ? json[@"license"] : json;

    NSTimeInterval expiry = WFParseExpiry(license[@"expires_at"] ?: license[@"expiry"] ?: license[@"expire_at"] ?: license[@"expires"] ?: license[@"end_date"]);
    if (expiry <= NSDate.date.timeIntervalSince1970) {
        NSInteger days = [license[@"days"] integerValue];
        if (days <= 0) days = [license[@"duration_days"] integerValue];
        if (days > 0) expiry = NSDate.date.timeIntervalSince1970 + (days * 86400.0);
    }

    if (expiry <= NSDate.date.timeIntervalSince1970) {
        done(NO, @"الخادم لم يُرجع تاريخ انتهاء صالحًا");
        return;
    }

    NSString *token = WFStringValue(license[@"token"]);
    if (token.length == 0) token = WFStringValue(json[@"auth_token"]);
    if (token.length == 0) token = WFStringValue(json[@"access_token"]);
    if (token.length == 0) token = [NSString stringWithFormat:@"%@-%@", code, WFDeviceUUID()];

    NSString *name = WFStringValue(license[@"name"]);
    if (name.length == 0) name = WFStringValue(license[@"project_name"]);
    if (name.length == 0) name = @"GPS Plus";

    NSUserDefaults *defaults = WFDefaultsGate();
    [defaults setObject:code forKey:WFLicenseCodeKey];
    [defaults setObject:token forKey:WFLicenseTokenKey];
    [defaults setDouble:expiry forKey:WFLicenseExpiryKey];
    [defaults setObject:name forKey:WFLicenseNameKey];
    [defaults synchronize];

    done(YES, @"تم تفعيل الأداة بنجاح");
}

static void WFSendActivationAttempt(NSString *code,
                                    NSInteger endpointIndex,
                                    BOOL useJSON,
                                    void (^done)(BOOL ok, NSString *message)) {
    NSArray<NSString *> *endpoints = WFActivationEndpoints();
    if (endpointIndex < 0 || endpointIndex >= (NSInteger)endpoints.count) {
        done(NO, @"تعذر العثور على مسار API صالح");
        return;
    }

    NSURL *url = [NSURL URLWithString:endpoints[endpointIndex]];
    if (!url) {
        done(NO, @"رابط خادم التفعيل غير صالح");
        return;
    }

    NSString *device = WFDeviceUUID();
    NSDictionary *payload = @{
        @"code": code,
        @"key": code,
        @"license": code,
        @"license_code": code,
        @"device_uuid": device,
        @"device_id": device,
        @"udid": device,
        @"project": @"GPSPlus",
        @"platform": @"ios",
        @"app_version": @"1.2.0"
    };

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"POST";
    request.timeoutInterval = 20.0;
    [request setValue:@"application/json, text/plain, */*" forHTTPHeaderField:@"Accept"];
    [request setValue:@"WolFoxGPS/1.2.0 (iOS)" forHTTPHeaderField:@"User-Agent"];

    if (useJSON) {
        [request setValue:@"application/json; charset=utf-8" forHTTPHeaderField:@"Content-Type"];
        request.HTTPBody = [NSJSONSerialization dataWithJSONObject:payload options:0 error:nil];
    } else {
        NSMutableArray *parts = [NSMutableArray array];
        [payload enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *value, BOOL *stop) {
            [parts addObject:[NSString stringWithFormat:@"%@=%@", WFURLEncode(key), WFURLEncode([value description])]];
        }];
        NSString *body = [parts componentsJoinedByString:@"&"];
        [request setValue:@"application/x-www-form-urlencoded; charset=utf-8" forHTTPHeaderField:@"Content-Type"];
        request.HTTPBody = [body dataUsingEncoding:NSUTF8StringEncoding];
    }

    [[NSURLSession.sharedSession dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            WFHandleActivationResponse(code, endpointIndex, useJSON, data, response, error, done);
        });
    }] resume];
}

static void WFCheckCode(NSString *code, void (^done)(BOOL ok, NSString *message)) {
    NSString *clean = [[code ?: @""] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (clean.length < 4) {
        done(NO, @"أدخل كود تفعيل صحيح");
        return;
    }

    WFSendActivationAttempt(clean, 0, NO, done);
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
    self.view.backgroundColor = [UIColor colorWithRed:0.025 green:0.03 blue:0.04 alpha:1.0];

    UILabel *title = [[UILabel alloc] init];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    title.text = @"تفعيل WolFox GPS";
    title.textColor = UIColor.whiteColor;
    title.font = [UIFont boldSystemFontOfSize:24.0];
    title.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:title];

    UILabel *device = [[UILabel alloc] init];
    device.translatesAutoresizingMaskIntoConstraints = NO;
    device.text = [NSString stringWithFormat:@"معرف الجهاز\n%@", WFDeviceUUID()];
    device.textColor = UIColor.lightGrayColor;
    device.numberOfLines = 2;
    device.font = [UIFont systemFontOfSize:12.0];
    device.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:device];

    self.codeField = [[UITextField alloc] init];
    self.codeField.translatesAutoresizingMaskIntoConstraints = NO;
    self.codeField.placeholder = @"أدخل كود التفعيل";
    self.codeField.text = [WFDefaultsGate() stringForKey:WFLicenseCodeKey];
    self.codeField.textColor = UIColor.whiteColor;
    self.codeField.backgroundColor = [UIColor colorWithWhite:0.10 alpha:1.0];
    self.codeField.layer.cornerRadius = 14.0;
    self.codeField.textAlignment = NSTextAlignmentCenter;
    self.codeField.autocapitalizationType = UITextAutocapitalizationTypeAllCharacters;
    self.codeField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.codeField.returnKeyType = UIReturnKeyDone;
    self.codeField.delegate = self;
    [self.view addSubview:self.codeField];

    self.activateButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.activateButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.activateButton.backgroundColor = [UIColor colorWithRed:0.18 green:0.92 blue:0.40 alpha:1.0];
    self.activateButton.layer.cornerRadius = 14.0;
    [self.activateButton setTitle:@"تفعيل الكود" forState:UIControlStateNormal];
    [self.activateButton setTitleColor:UIColor.blackColor forState:UIControlStateNormal];
    self.activateButton.titleLabel.font = [UIFont boldSystemFontOfSize:17.0];
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
        [title.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:70.0],
        [title.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20.0],
        [title.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20.0],
        [device.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:22.0],
        [device.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:24.0],
        [device.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-24.0],
        [self.codeField.topAnchor constraintEqualToAnchor:device.bottomAnchor constant:34.0],
        [self.codeField.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:28.0],
        [self.codeField.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-28.0],
        [self.codeField.heightAnchor constraintEqualToConstant:58.0],
        [self.activateButton.topAnchor constraintEqualToAnchor:self.codeField.bottomAnchor constant:18.0],
        [self.activateButton.leadingAnchor constraintEqualToAnchor:self.codeField.leadingAnchor],
        [self.activateButton.trailingAnchor constraintEqualToAnchor:self.codeField.trailingAnchor],
        [self.activateButton.heightAnchor constraintEqualToConstant:56.0],
        [self.statusLabel.topAnchor constraintEqualToAnchor:self.activateButton.bottomAnchor constant:18.0],
        [self.statusLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:24.0],
        [self.statusLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-24.0],
        [close.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-20.0],
        [close.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor]
    ]];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [self activatePressed];
    return YES;
}

- (void)closePressed {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)activatePressed {
    [self.codeField resignFirstResponder];
    self.activateButton.enabled = NO;
    self.activateButton.alpha = 0.55;
    self.statusLabel.textColor = UIColor.lightGrayColor;
    self.statusLabel.text = @"جاري التحقق من الكود...";

    __weak typeof(self) weakSelf = self;
    WFCheckCode(self.codeField.text, ^(BOOL ok, NSString *message) {
        __strong typeof(weakSelf) selfRef = weakSelf;
        if (!selfRef) return;

        selfRef.activateButton.enabled = YES;
        selfRef.activateButton.alpha = 1.0;
        selfRef.statusLabel.text = message;
        selfRef.statusLabel.textColor = ok ? [UIColor colorWithRed:0.18 green:0.92 blue:0.40 alpha:1.0] : UIColor.systemRedColor;

        if (ok) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [selfRef dismissViewControllerAnimated:YES completion:selfRef.successBlock];
            });
        }
    });
}

@end

static UIViewController *WFTopController(UIWindow *window) {
    UIViewController *controller = window.rootViewController;
    while (controller.presentedViewController) controller = controller.presentedViewController;
    return controller;
}

%hook WFFloatingButton

- (void)openPanel {
    if (WFLicenseValid()) {
        %orig;
        return;
    }

    WFClearLicense();
    UIViewController *top = WFTopController(self.window);
    if (!top) return;

    WFLicenseController *licenseController = [[WFLicenseController alloc] init];
    licenseController.modalPresentationStyle = UIModalPresentationFullScreen;

    __weak WFFloatingButton *weakButton = self;
    licenseController.successBlock = ^{
        [weakButton openPanel];
    };

    [top presentViewController:licenseController animated:YES completion:nil];
}

%end
