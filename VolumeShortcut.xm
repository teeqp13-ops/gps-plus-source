#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

static NSString * const WFFloatingHiddenShortcutKey = @"WolFoxFloatingHidden";
static NSInteger gWFVolumeUpPressCount = 0;
static NSTimeInterval gWFLastVolumeUpPress = 0;

static UIView *WFFindFloatingButtonInView(UIView *view) {
    Class floatingClass = objc_getClass("WFFloatingButton");
    if (floatingClass && [view isKindOfClass:floatingClass]) return view;

    for (UIView *child in view.subviews) {
        UIView *match = WFFindFloatingButtonInView(child);
        if (match) return match;
    }
    return nil;
}

static UIView *WFFindFloatingButton(void) {
    for (UIWindow *window in UIApplication.sharedApplication.windows) {
        UIView *button = WFFindFloatingButtonInView(window);
        if (button) return button;
    }

    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if (![scene isKindOfClass:UIWindowScene.class]) continue;
            for (UIWindow *window in ((UIWindowScene *)scene).windows) {
                UIView *button = WFFindFloatingButtonInView(window);
                if (button) return button;
            }
        }
    }
    return nil;
}

static void WFToggleFloatingButtonFromVolume(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
        BOOL currentlyHidden = [defaults boolForKey:WFFloatingHiddenShortcutKey];
        BOOL shouldHide = !currentlyHidden;

        [defaults setBool:shouldHide forKey:WFFloatingHiddenShortcutKey];
        [defaults synchronize];

        UIView *button = WFFindFloatingButton();
        if (button) {
            button.hidden = shouldHide;
            button.alpha = shouldHide ? 0.0 : 1.0;
            if (!shouldHide) {
                button.transform = CGAffineTransformMakeScale(0.72, 0.72);
                [UIView animateWithDuration:0.22 animations:^{
                    button.transform = CGAffineTransformIdentity;
                }];
            }
        }

        UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
        [feedback prepare];
        [feedback impactOccurred];
    });
}

static void WFRegisterVolumeUpPress(void) {
    NSTimeInterval now = NSDate.date.timeIntervalSince1970;
    if (now - gWFLastVolumeUpPress > 1.35) gWFVolumeUpPressCount = 0;

    gWFLastVolumeUpPress = now;
    gWFVolumeUpPressCount += 1;

    if (gWFVolumeUpPressCount >= 3) {
        gWFVolumeUpPressCount = 0;
        gWFLastVolumeUpPress = 0;
        WFToggleFloatingButtonFromVolume();
    }
}

%hook SBVolumeControl
- (void)increaseVolume {
    %orig;
    WFRegisterVolumeUpPress();
}
%end
