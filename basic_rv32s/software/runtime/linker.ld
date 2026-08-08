OUTPUT_ARCH(riscv)
ENTRY(_start)

MEMORY {
    RAM (rwx) : ORIGIN = 0x00000000, LENGTH = 64K
}

SECTIONS {
    .text : {
        . = ALIGN(4);
        *(.text.init)
        *(.text*)
        . = ALIGN(4);
    } > RAM

    .rodata : {
        . = ALIGN(4);
        *(.rodata*)
        *(.srodata*)
        *(.eh_frame*)
        . = ALIGN(4);
    } > RAM

    .data : {
        . = ALIGN(4);
        _data_start = .;
        *(.data*)
        *(.sdata*)
        . = ALIGN(4);
        _data_end = .;
    } > RAM
    _data_load_start = LOADADDR(.data);

    .bss (NOLOAD) : {
        . = ALIGN(4);
        _bss_start = .;
        *(.sbss*)
        *(.bss*)
        *(COMMON)
        . = ALIGN(4);
        _bss_end = .;
        _end = .;
    } > RAM

    _stack_top = ORIGIN(RAM) + LENGTH(RAM);
}
