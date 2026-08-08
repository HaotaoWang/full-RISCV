CC = D:/riscv_gcc/bin/riscv-none-elf-gcc
OBJCOPY = D:/riscv_gcc/bin/riscv-none-elf-objcopy

CFLAGS = -march=rv32im_zicsr -mabi=ilp32 -O2 -ffunction-sections -fdata-sections -I./include -I.
LDFLAGS = -T link.lds -nostartfiles -Wl,--gc-sections -lc -lm -lgcc

C_SOURCES = $(wildcard src/*.c) board.c libcpu/cpuport.c main.c
ASM_SOURCES = libcpu/context_gcc.S startup.S

OBJS = $(C_SOURCES:.c=.o) $(ASM_SOURCES:.S=.o)

all: rtthread.hex

%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

%.o: %.S
	$(CC) $(CFLAGS) -c $< -o $@

rtthread.elf: $(OBJS)
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $(OBJS)

rtthread.hex: rtthread.elf
	$(OBJCOPY) -O binary $< rtthread.bin
	python makehex.py rtthread.bin $@
	
clean:
	rm -f $(OBJS) rtthread.elf rtthread.hex
