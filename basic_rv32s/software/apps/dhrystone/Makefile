APP_DIR      := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
APP_NAME     := dhrystone
APP_SRCS     := dhrystone.c dhrystone_main.c
OPT          := -O2
EXTRA_CFLAGS := -std=gnu89 -fwrapv -Wno-implicit-int -Wno-implicit-function-declaration
EXTRA_LDLIBS := -lgcc

ifneq ($(DHRY_DEBUG_EVERY),)
EXTRA_CFLAGS += -DDHRY_DEBUG_EVERY=$(DHRY_DEBUG_EVERY)
endif
ifneq ($(DHRY_RUNS),)
EXTRA_CFLAGS += -DNUMBER_OF_RUNS=$(DHRY_RUNS)
endif
ifneq ($(DHRY_FIXED_RUNS),)
EXTRA_CFLAGS += -DDHRY_FIXED_RUNS=$(DHRY_FIXED_RUNS)
endif
ifneq ($(DHRY_ENABLE_DEBUG),)
EXTRA_CFLAGS += -DDHRY_ENABLE_DEBUG=$(DHRY_ENABLE_DEBUG)
endif

include ../../runtime/common.mk
