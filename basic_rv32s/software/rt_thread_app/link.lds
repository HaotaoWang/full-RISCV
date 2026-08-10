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


  /*
   * BRAM contents are restored from the bitstream only by FPGA
   * reconfiguration, not by the board reset button.  Keep the initial .data
   * bytes in an immutable load image below 0x4000 and run .data from 0x4000.
   * startup.S copies the load image back on every reset.
   */
  __data_load_start = ALIGN(LOADADDR(.rti_fn) + SIZEOF(.rti_fn), 4);

  .data 0x00004000 : AT(__data_load_start) {
    . = ALIGN(4);
    __data_start = .;
    PROVIDE( __global_pointer$ = . + 0x800 );
    *(.data .data.*)
    *(.sdata .sdata.*)
    . = ALIGN(4);
    __data_end = .;
  } > RAM

  __data_load_end = __data_load_start + SIZEOF(.data);
  ASSERT(__data_load_end <= ADDR(.data), ".data load image overlaps runtime .data")

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
