OUTPUT_ARCH( "riscv" )
ENTRY( _start )

MEMORY
{
  RAM (rwx) : ORIGIN = 0x00000000, LENGTH = 64K
}

SECTIONS
{
  .text : {
    *(.init)
    *(.text .text.*)
    *(.rodata .rodata.*)
    *(.srodata .srodata.*)
  } > RAM

  /* Keep RT-Thread's automatic initialization table with --gc-sections. */
  .rti_fn : {
    . = ALIGN(4);
    KEEP(*(SORT_BY_NAME(.rti_fn.*)))
    . = ALIGN(4);
  } > RAM


  .data : {
    . = ALIGN(4);
    PROVIDE( __global_pointer$ = . + 0x800 );
    *(.data .data.*)
    *(.sdata .sdata.*)
  } > RAM

  .bss : {
    . = ALIGN(4);
    __bss_start = .;
    *(.bss .bss.*)
    *(.sbss .sbss.*)
    *(COMMON)
    . = ALIGN(4);
    __bss_end = .;
  } > RAM

  /* Provide _end for RT-Thread heap initialization */
  . = ALIGN(8);
  PROVIDE( _end = . );
  PROVIDE( end = . );

  /* Reserve 4K stack for main/interrupts at the end of RAM */
  .stack ORIGIN(RAM) + LENGTH(RAM) - 4K : {
    . = ALIGN(8);
    PROVIDE( _sp = . + 4K );
  } > RAM
}
