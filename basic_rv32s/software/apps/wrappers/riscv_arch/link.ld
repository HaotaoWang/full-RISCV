OUTPUT_ARCH("riscv")
ENTRY(rvtest_entry_point)

SECTIONS
{
  . = 0x00000000;
  .text.init    : { *(.text.init) }

  /* ACT4 copies its machine-mode trap trampoline into a low scratch area
     starting at 0x1000.  Keep generated test code out of that region or the
     copy silently self-modifies the test image. */
  . = 0x00004000;
  .text.rvtest  : { *(.text.rvtest) *(.text.rvtest.*) }
  . = ALIGN(0x1000);
  .data         : { *(.data) *(.data.*) }
  .bss          : { *(.bss) *(.bss.*) *(COMMON) }
  . = ALIGN(0x1000);
  .text.rvmodel : { *(.text.rvmodel) *(.text.rvmodel.*) *(.text) *(.text.*) }
  . = ALIGN(16);
  _end = .;

  ASSERT(_end <= 0x00040000, "architecture test exceeds 256 KiB architecture-test RAM")
}
