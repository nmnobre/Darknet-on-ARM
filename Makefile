# x86_64 (local) compilation set-up.
CC = gcc
CFLAGS  = -Wall -Wfatal-errors -Ofast
LDFLAGS = -lm -pthread
EXEC_x86_64 = darknet_x86_64

# ARMv7-A (cross) compilation (partial) set-up to be complemented by jni/Android.mk and jni/Application.mk.
# Set APP_ABI to the ABI tailored for the ARMv7-A architecture (as defined in jni/Application.mk).
NDK_BUILD = $(ANDROID_NDK)/ndk-build
APP_ABI = armeabi-v7a
EXEC_ARM = darknet_arm

# Source code files (excluding CUDA kernels for now).
SOURCE = $(wildcard src/*.c)

# The defaults directories for intermediate (obj/) and final (libs/) binaries used by ndk-build.
NDK_OBJ_DIR = obj
NDK_LIBS_DIR = libs

# Remote (i.e. on the device) directories for the Symphony dynamic libraries and for darknet.
REMOTE_LIBS_DIR = /system/vendor/lib
REMOTE_DIR = /data/local/tmp/darknet-on-arm

# Local directory for the required Symphony dynamic libraries.
LOCAL_LIBS_DIR = symphonyLibs

.PHONY: all
all: $(EXEC_x86_64) $(EXEC_ARM)

$(EXEC_x86_64): $(SOURCE)
	$(CC) $(CFLAGS) -o $(EXEC_x86_64) $(SOURCE) $(LDFLAGS)

$(EXEC_ARM): $(SOURCE)
	$(NDK_BUILD)
	mkdir -p $(LOCAL_LIBS_DIR)
	mv ./$(NDK_LIBS_DIR)/$(APP_ABI)/$(EXEC_ARM) .
	mv ./$(NDK_LIBS_DIR)/$(APP_ABI)/*.so $(LOCAL_LIBS_DIR)
	rm -rf $(NDK_LIBS_DIR) $(NDK_OBJ_DIR)

.PHONY: install
install: $(EXEC_ARM)	
	adb shell "mkdir -p $(REMOTE_DIR)"
	adb push $(EXEC_ARM) $(REMOTE_DIR)

	adb shell "mkdir -p $(REMOTE_DIR)/cfg"
	adb shell "mkdir -p $(REMOTE_DIR)/data"
	adb shell "mkdir -p $(REMOTE_DIR)/pre-trained"
	if [ -z "$$(adb shell "ls $(REMOTE_DIR)/cfg | grep yolo.cfg")" ]; then adb push cfg $(REMOTE_DIR)/cfg; fi
	if [ -z "$$(adb shell "ls $(REMOTE_DIR)/data | grep dog.jpg")" ]; then adb push data $(REMOTE_DIR)/data; fi
	if [ -z "$$(adb shell "ls $(REMOTE_DIR)/pre-trained | grep yolo.weights")" ]; then adb push pre-trained $(REMOTE_DIR)/pre-trained; fi

	# Upload Symphony libraries requires remounting the /system partition read/write.
	# In turn, this requires root permissions which are requested (+ brief timeout to
	# wait for the adbd daemon to restart) and then dismissed at the end. 
	adb root
	sleep 2
	adb remount
	adb push $(LOCAL_LIBS_DIR) $(REMOTE_LIBS_DIR)
	adb shell "setprop service.adb.root 0; setprop ctl.restart adbd"

.PHONY: clean
clean:
	rm -f $(EXEC_x86_64) $(EXEC_ARM) *.png
	rm -rf $(NDK_LIBS_DIR) $(NDK_OBJ_DIR) $(LOCAL_LIBS_DIR)