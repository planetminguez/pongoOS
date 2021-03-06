ifndef $(HOST_OS)
	ifeq ($(OS),Windows_NT)
		HOST_OS = Windows
	else
		HOST_OS := $(shell uname -s)
	endif
endif

ifeq ($(HOST_OS),Darwin)
	EMBEDDED_CC         ?= xcrun -sdk iphoneos clang -arch arm64
	STRIP               ?= strip
	STAT                ?= stat -L -f %z
else
ifeq ($(HOST_OS),Linux)
	EMBEDDED_CC         ?= arm64-apple-ios12.0.0-clang -arch arm64
	STRIP               ?= cctools-strip
	STAT                ?= stat -L -c %s
endif
endif

PONGO_VERSION           := 2.4.1-$(shell git log -1 --pretty=format:"%H" | cut -c1-8)
ROOT                    := $(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))
SRC                     := $(ROOT)/src
AUX                     := $(ROOT)/tools
LIB                     := $(ROOT)/aarch64-none-darwin
INC                     := $(ROOT)/include
BUILD                   := $(ROOT)/build

# General options
EMBEDDED_LDFLAGS        ?= -nostdlib -static -Wl,-fatal_warnings -Wl,-dead_strip -Wl,-Z
EMBEDDED_CC_FLAGS       ?= -Wall -Wunused-label -Werror -O3 -flto -ffreestanding -U__nonnull -nostdlibinc -I$(LIB)/include $(EMBEDDED_LDFLAGS)

# Pongo options
PONGO_LDFLAGS           ?= -L$(LIB)/lib -lc -lm -lg -Wl,-preload -Wl,-no_uuid -Wl,-e,start -Wl,-order_file,$(SRC)/sym_order.txt -Wl,-image_base,0x100000000 -Wl,-sectalign,__DATA,__common,0x8  -Wl,-segalign,0x4000 
PONGO_CC_FLAGS          ?= -DPONGO_VERSION='"$(PONGO_VERSION)"' -DAUTOBOOT -DPONGO_PRIVATE=1 -I$(SRC)/lib -I$(INC) -Iapple-include -I$(INC)/linux/ -I$(SRC)/kernel -I$(SRC)/drivers -I$(SRC)/linux/libfdt -I $(LIB)/libDER $(PONGO_LDFLAGS) $(CFLAGS) -DDER_TAG_SIZE=8

STAGE3_ENTRY_C          := $(patsubst %, $(SRC)/boot/%, stage3.c clearhook.S patches.S demote_patch.S jump_to_image.S main.c)
PONGO_C                 := $(wildcard $(SRC)/kernel/*.c) $(wildcard $(SRC)/kernel/support/*.c) $(wildcard $(SRC)/dynamic/*.c) $(wildcard $(SRC)/kernel/*.S) $(wildcard $(SRC)/shell/*.c)
PONGO_DRIVERS_C         := $(wildcard $(SRC)/drivers/*/*.c) $(wildcard $(SRC)/drivers/*/*.S) $(wildcard $(SRC)/linux/*/*.c) $(wildcard $(SRC)/linux/*.c) $(wildcard $(SRC)/lib/*/*.c)

.PHONY: all clean

all: $(BUILD)/Pongo.bin | $(BUILD)

$(BUILD)/Pongo.bin: $(BUILD)/vmacho $(BUILD)/Pongo | $(BUILD)
	$(BUILD)/vmacho -f $(BUILD)/Pongo $@

$(BUILD)/Pongo: $(SRC)/boot/entry.S $(STAGE3_ENTRY_C) $(PONGO_C) $(PONGO_DRIVERS_C) | $(BUILD)
	$(EMBEDDED_CC) -o $@ $(EMBEDDED_CC_FLAGS) $(PONGO_CC_FLAGS) $(SRC)/boot/entry.S $(STAGE3_ENTRY_C) $(PONGO_C) $(PONGO_DRIVERS_C)

$(BUILD)/vmacho: $(AUX)/vmacho.c | $(BUILD)
	$(CC) -Wall -O3 -o $@ $^ $(CFLAGS)

$(BUILD):
	mkdir -p $@

clean:
	rm -rf $(BUILD)
