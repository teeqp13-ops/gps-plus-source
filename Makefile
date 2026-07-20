TARGET := iphone:clang:latest:14.0
ARCHS := arm64 arm64e

include $(THEOS)/makefiles/common.mk

TWEAK_NAME := WolFoxGPS WolFoxLocation

WolFoxGPS_FILES := Tweak.xm LicenseGateV4.xm VolumeShortcut.xm
WolFoxGPS_CFLAGS := -fobjc-arc -Wno-deprecated-declarations -Wno-unused-variable -Wno-error
WolFoxGPS_FRAMEWORKS := UIKit Foundation CoreLocation MapKit QuartzCore CoreGraphics
WolFoxGPS_LIBRARIES := substrate

WolFoxLocation_FILES := LocationHook.xm
WolFoxLocation_CFLAGS := -fobjc-arc -Wno-deprecated-declarations -Wno-unused-variable -Wno-error
WolFoxLocation_FRAMEWORKS := Foundation CoreLocation
WolFoxLocation_LIBRARIES := substrate

include $(THEOS_MAKE_PATH)/tweak.mk