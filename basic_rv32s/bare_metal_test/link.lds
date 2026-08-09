OUTPUT_ARCH( "riscv" )
ENTRY( _start )

MEMORY
{
  RAM (xrw) : ORIGIN = 0x00000000, LENGTH = 64K
}

SECTIONS
{
  .text : {
    *(.text*)
    *(.rodata*)
  } > RAM

  .data : {
    *(.data*)
    *(.sdata*)
  } > RAM

  .bss : {
    __bss_start = .;
    *(.bss*)
    *(.sbss*)
    __bss_end = .;
  } > RAM
}
