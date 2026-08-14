APP_DIR       := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
COREMARK_DIR  := $(APP_DIR)../../coremark/
RUNTIME_DIR   := $(APP_DIR)../../../runtime/
BUILD_DIR     := $(APP_DIR)../../../build/coremark

APP_NAME      := coremark
APP_SRCS      := core_main.c core_list_join.c core_matrix.c core_state.c core_util.c core_portme.c
APP_SRC_DIRS  := $(APP_DIR) $(COREMARK_DIR)
INCS          := -I$(APP_DIR) -I$(COREMARK_DIR) -I$(RUNTIME_DIR)
OPT           := -O2
ARCH                := rv32im_zicsr_zifencei
COREMARK_ITERATIONS ?= 3000
COREMARK_CPU_HZ     ?= 50000000
EXTRA_CFLAGS  := -DPERFORMANCE_RUN=1 -DITERATIONS=$(COREMARK_ITERATIONS) -DCOREMARK_CPU_HZ=$(COREMARK_CPU_HZ)ULL
EXTRA_LDLIBS  := -lgcc

include ../../../runtime/common.mk
