TARGET := iphone:clang:latest:14.0
INSTALL_TARGET_PROCESSES := Instagram

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = IGAMARYT

IGAMARYT_FILES = Tweak.m
IGAMARYT_CFLAGS = -fobjc-arc
IGAMARYT_FRAMEWORKS = UIKit Security Foundation Photos AVFoundation

include $(THEOS_MAKE_PATH)/tweak.mk
