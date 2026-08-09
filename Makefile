TARGET := iphone:clang:latest:14.0
INSTALL_TARGET_PROCESSES := Facebook

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = FacebookFixAndTools

FacebookFixAndTools_FILES = Tweak.x
FacebookFixAndTools_CFLAGS = -fobjc-arc
FacebookFixAndTools_FRAMEWORKS = UIKit Security Foundation

include $(THEOS_MAKE_PATH)/tweak.mk
