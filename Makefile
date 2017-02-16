CC = gcc
CFLAGS  = -Wall -Ofast
LDFLAGS = -lm -pthread
TARGET_x86_64 = darknet_x86_64

NDK_BUILD = $(ANDROID_NDK)/ndk-build
TARGET_ARM = darknet_arm
REMOTE_DIR = /data/local/tmp/darknet-on-arm

SOURCE = $(wildcard src/*.c)
SYMPHONY_LIBS_DIR = SymphonyLibs

.PHONY: all
all: $(TARGET_x86_64) $(TARGET_ARM)

$(TARGET_x86_64): $(SOURCE)
	$(CC) $(CFLAGS) -o $(TARGET_x86_64) $(SOURCE) $(LDFLAGS)

$(TARGET_ARM): $(SOURCE)
	$(NDK_BUILD)
	cp ./libs/armeabi-v7a/$(TARGET_ARM) .
	mkdir -p $(SYMPHONY_LIBS_DIR)
	cp ./libs/armeabi-v7a/*.so $(SYMPHONY_LIBS_DIR)
	$(RM) -r libs/ obj/

.PHONY: install
install: $(TARGET_ARM)
	adb shell "mkdir -p $(REMOTE_DIR)"
	adb push $(TARGET_ARM) $(REMOTE_DIR)

	adb shell "mkdir -p $(REMOTE_DIR)/cfg"
	adb shell "mkdir -p $(REMOTE_DIR)/data"
	adb shell "mkdir -p $(REMOTE_DIR)/pre-trained"
	if [ -z "$$(adb shell "ls $(REMOTE_DIR)/cfg | grep yolo.cfg")" ]; then adb push cfg $(REMOTE_DIR)/cfg; fi
	if [ -z "$$(adb shell "ls $(REMOTE_DIR)/data | grep dog.jpg")" ]; then adb push data $(REMOTE_DIR)/data; fi
	if [ -z "$$(adb shell "ls $(REMOTE_DIR)/pre-trained | grep yolo.weights")" ]; then adb push pre-trained $(REMOTE_DIR)/pre-trained; fi

.PHONY: clean
clean:
	$(RM) $(TARGET_x86_64) $(TARGET_ARM) predictions.*
	$(RM) -r $(SYMPHONY_LIBS_DIR) libs/ obj/