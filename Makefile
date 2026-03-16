INSTALL_TARGET_PROCESSES = AnimalCompany
TARGET = iphone:clang:16.5:14.0
ARCHS = arm64
SIGN = 0
TARGET_CODESIGN = true

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = VRXCLIENT

VyroClientV1_FILES = Menu.m
VyroClientV1_CFLAGS = -fobjc-arc -Wno-overriding-option -Wno-unused-function
VyroClientV1_FRAMEWORKS = UIKit CoreGraphics

include $(THEOS_MAKE_PATH)/tweak.mk
