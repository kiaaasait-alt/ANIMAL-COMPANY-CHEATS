cd VRXClient
cat > Makefile << 'EOF'
export THEOS=/opt/theos
export TARGET=iphone:clang:latest:13.0
export ARCHS=arm64 arm64e

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = VRXClient

VRXClient_FILES = Sources/main.mm Sources/Menu.m
VRXClient_FRAMEWORKS = Foundation UIKit
VRXClient_LIBRARIES = substrate
VRXClient_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk
EOF
