OUTPUT_ARCH(riscv)
ENTRY(_start)

MEMORY
{
    RAM (rwx) : ORIGIN = 0x00000000, LENGTH = 64K
}

SECTIONS
{
    . = ORIGIN(RAM);
    .text :
    {
        KEEP(*(.init))
        *(.text*)
        *(.rodata*)
    } > RAM

    .data : { *(.data*) } > RAM
    .bss (NOLOAD) :
    {
        *(.bss*)
        *(COMMON)
    } > RAM
}
