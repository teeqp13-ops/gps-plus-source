TARGET := iphone:clang:latest:14.0
ARCHS := arm64 arm64e

include $(THEOS)/makefiles/common.mk

TWEAK_NAME := WolFoxGPS
WolFoxGPS_FILES := Tweak.mm
WolFoxGPS_CFLAGS := -fobjc-arc -Wno-deprecated-declarations -Wno-unused-variable -Wno-error
WolFoxGPS_FRAMEWORKS := UIKit Foundation CoreLocation MapKit QuartzCore CoreGraphics
WolFoxGPS_LIBRARIES := substrate

include $(THEOS_MAKE_PATH)/tweak.mk
