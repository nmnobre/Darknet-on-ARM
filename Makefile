# x86_64 (local) compilation set-up.
CC = $$(find $(ANDROID_NDK) -type f -name "clang")
CFLAGS  = -Wall -Wfatal-errors -Ofast
LDFLAGS = -lm -pthread
EXEC_x86_64 = darknet_x86_64

# ARMv8-A (cross) compilation (partial) set-up to be complemented by jni/Android.mk and jni/Application.mk.
# Set APP_ABI to the ABI tailored for the ARMv8-A architecture (as defined in jni/Application.mk).
NDK_BUILD = $(ANDROID_NDK)/ndk-build
APP_ABI = arm64-v8a
EXEC_ARM = darknet_aarch64

# Source code directory and files (excluding CUDA kernels for now).
SOURCE_DIR = src
SOURCE_FILES = $(wildcard $(SOURCE_DIR)/*.c)

# The defaults directories for intermediate (obj/) and final (libs/) binaries used by ndk-build.
NDK_OBJ_DIR = obj
NDK_LIBS_DIR = libs

# Remote (i.e. on the device) directories for the Symphony dynamic libraries and for darknet.
REMOTE_LIBS_DIR = /system/vendor/lib64
REMOTE_DIR = /data/local/tmp/darknet-on-arm

# Local directory for the required Symphony dynamic libraries.
LOCAL_LIBS_DIR = symphonyLibs

# Local and remote subdirectories
CFG_DIR = cfg
DATA_DIR = data
WEIGHTS_DIR = pre-trained
TOOLS_DIR = tools

# Helper script.
EXEC_SCRIPT=darknet_run


.PHONY: all
all: $(EXEC_x86_64) $(EXEC_ARM) $(EXEC_SCRIPT)

$(EXEC_x86_64): $(SOURCE_FILES)
	$(CC) $(CFLAGS) -o $(EXEC_x86_64) $(SOURCE_FILES) $(LDFLAGS)

$(EXEC_ARM): $(SOURCE_FILES)
	$(NDK_BUILD)
	mkdir -p $(LOCAL_LIBS_DIR)
	mv $(NDK_LIBS_DIR)/$(APP_ABI)/$(EXEC_ARM) .
	mv $(NDK_LIBS_DIR)/$(APP_ABI)/*.so $(LOCAL_LIBS_DIR)
	rm -rf $(NDK_LIBS_DIR) $(NDK_OBJ_DIR)

$(EXEC_SCRIPT): $(SOURCE_DIR)/$(EXEC_SCRIPT).sh
	cp $(SOURCE_DIR)/$(EXEC_SCRIPT).sh $(EXEC_SCRIPT)
	chmod 764 $(EXEC_SCRIPT)

.PHONY: install
install: $(EXEC_ARM)	
	adb shell "mkdir -p $(REMOTE_DIR)"
	adb push $(EXEC_ARM) $(REMOTE_DIR)
	adb push $(EXEC_SCRIPT) $(REMOTE_DIR)
	adb push $(TOOLS_DIR) $(REMOTE_DIR)/$(TOOLS_DIR)

	adb shell "mkdir -p $(REMOTE_DIR)/$(CFG_DIR)"
	adb shell "mkdir -p $(REMOTE_DIR)/$(DATA_DIR)"
	adb shell "mkdir -p $(REMOTE_DIR)/$(WEIGHTS_DIR)"
	if [ -z "$$(adb shell "ls $(REMOTE_DIR)/$(CFG_DIR) | grep yolo.cfg")" ]; then adb push cfg $(REMOTE_DIR)/$(CFG_DIR); fi
	if [ -z "$$(adb shell "ls $(REMOTE_DIR)/$(DATA_DIR) | grep dog.jpg")" ]; then adb push data $(REMOTE_DIR)/$(DATA_DIR); fi
	if [ -z "$$(adb shell "ls $(REMOTE_DIR)/$(WEIGHTS_DIR) | grep yolo.weights")" ]; then adb push pre-trained $(REMOTE_DIR)/$(WEIGHTS_DIR); fi

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
	rm -f $(EXEC_x86_64) $(EXEC_ARM) $(EXEC_SCRIPT) *.png
	rm -rf $(NDK_LIBS_DIR) $(NDK_OBJ_DIR) $(LOCAL_LIBS_DIR)