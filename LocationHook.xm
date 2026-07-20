#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

static NSString * const WFPreferencesDomain = @"com.apple.springboard";
static NSString * const WFEnabledKeyShared = @"WolFoxEnabled";
static NSString * const WFLatitudeKeyShared = @"WolFoxLatitude";
static NSString * const WFLongitudeKeyShared = @"WolFoxLongitude";

static id WFSharedPreference(NSString *key) {
    return (__bridge_transfer id)CFPreferencesCopyAppValue((__bridge CFStringRef)key,
                                                            (__bridge CFStringRef)WFPreferencesDomain);
}

static BOOL WFLocationEnabled(void) {
    id value = WFSharedPreference(WFEnabledKeyShared);
    return [value respondsToSelector:@selector(boolValue)] && [value boolValue];
}

static CLLocationCoordinate2D WFFakeCoordinate(void) {
    id latitudeValue = WFSharedPreference(WFLatitudeKeyShared);
    id longitudeValue = WFSharedPreference(WFLongitudeKeyShared);
    double latitude = [latitudeValue respondsToSelector:@selector(doubleValue)] ? [latitudeValue doubleValue] : 0.0;
    double longitude = [longitudeValue respondsToSelector:@selector(doubleValue)] ? [longitudeValue doubleValue] : 0.0;
    if (latitude < -90.0 || latitude > 90.0 || longitude < -180.0 || longitude > 180.0) {
        return kCLLocationCoordinate2DInvalid;
    }
    return CLLocationCoordinate2DMake(latitude, longitude);
}

static CLLocation *WFFakeLocationFromLocation(CLLocation *original) {
    if (!WFLocationEnabled()) return original;
    CLLocationCoordinate2D coordinate = WFFakeCoordinate();
    if (!CLLocationCoordinate2DIsValid(coordinate)) return original;

    CLLocationDistance altitude = original ? original.altitude : 0.0;
    CLLocationAccuracy horizontalAccuracy = original ? MAX(original.horizontalAccuracy, 5.0) : 5.0;
    CLLocationAccuracy verticalAccuracy = original ? MAX(original.verticalAccuracy, 5.0) : 5.0;
    CLLocationDirection course = original ? original.course : -1.0;
    CLLocationSpeed speed = original ? original.speed : 0.0;
    NSDate *timestamp = [NSDate date];

    return [[CLLocation alloc] initWithCoordinate:coordinate
                                        altitude:altitude
                              horizontalAccuracy:horizontalAccuracy
                                verticalAccuracy:verticalAccuracy
                                          course:course
                                           speed:speed
                                       timestamp:timestamp];
}

%hook CLLocation
- (CLLocationCoordinate2D)coordinate {
    if (WFLocationEnabled()) {
        CLLocationCoordinate2D coordinate = WFFakeCoordinate();
        if (CLLocationCoordinate2DIsValid(coordinate)) return coordinate;
    }
    return %orig;
}
%end

%hook CLLocationManager
- (CLLocation *)location {
    CLLocation *original = %orig;
    return WFFakeLocationFromLocation(original);
}
%end
