#ifndef BASIC_RV32S_RVMODEL_MACROS_H
#define BASIC_RV32S_RVMODEL_MACROS_H

#define RVMODEL_DATA_SECTION

/*
 * The UART is the architectural-test console.  EOT (0x04) and ENQ (0x05)
 * are consumed by the RTL testbench as pass-path and fail-path terminators.
 */
#define RVMODEL_HALT_PASS                 \
  li x5, 0x10000000                    ; \
  li x6, 0x04                          ; \
  sw x6, 0(x5)                         ; \
1: j 1b

#define RVMODEL_HALT_FAIL                 \
  li x5, 0x10000000                    ; \
  li x6, 0x05                          ; \
  sw x6, 0(x5)                         ; \
1: j 1b

#define RVMODEL_IO_INIT(_R1, _R2, _R3)

#define RVMODEL_IO_WRITE_STR(_R1, _R2, _R3, _STR_PTR) \
1:                                                     ; \
  lbu  _R1, 0(_STR_PTR)                                ; \
  beqz _R1, 3f                                         ; \
  li   _R2, 0x10000000                                 ; \
  sw   _R1, 0(_R2)                                     ; \
  addi _STR_PTR, _STR_PTR, 1                           ; \
  j 1b                                                 ; \
3:

#define RVMODEL_INTERRUPT_LATENCY 20
#define RVMODEL_MTVEC_ALIGN 4
#define RVMODEL_TIMER_INT_SOON_DELAY 100
#define RVMODEL_MTIME_ADDRESS 0x02000000
#define RVMODEL_MTIMECMP_ADDRESS 0x02000008

#define RVMODEL_SET_MEXT_INT(_R1, _R2)
#define RVMODEL_CLR_MEXT_INT(_R1, _R2)
#define RVMODEL_SET_MSW_INT(_R1, _R2)
#define RVMODEL_CLR_MSW_INT(_R1, _R2)
#define RVMODEL_SET_SEXT_INT(_R1, _R2)
#define RVMODEL_CLR_SEXT_INT(_R1, _R2)
#define RVMODEL_SET_SSW_INT(_R1, _R2)
#define RVMODEL_CLR_SSW_INT(_R1, _R2)

#endif
