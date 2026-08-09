`include "modules/headers/csr.vh"

module CSRFile #(
    parameter XLEN = 32
)(
    input clk,                            // clock signal
    input reset,                          // reset signal
    input trapped,
    input csr_write_enable,               // write enable signal
    input [11:0] csr_read_address,        // address to read
    input [11:0] csr_write_address,       // address to write
    input [XLEN-1:0] csr_write_data,      // data to write
    input instruction_retired,
    
    // Interrupt Inputs
    input timer_irq,
    input external_irq,

    output reg [XLEN-1:0] csr_read_out,   // data from CSR Unit
    output reg csr_ready,                 // signal to stall the process while accessing the CSR until it outputs the desired value.
    output reg [1:0] current_mode,        // 3 for M-Mode, 1 for S-Mode, 0 for U-Mode
    
    output wire [XLEN-1:0] medeleg_out,   // delegation info
    output wire [XLEN-1:0] mideleg_out,   // interrupt delegation info
    output wire [XLEN-1:0] satp_out,      // SATP info for MMU
    output wire [XLEN-1:0] mstatus_out,   // mstatus info for MMU (SUM, MXR)
    
    output wire timer_interrupt_pending,
    output wire external_interrupt_pending,

    // TLB Backdoor
    output reg [19:0] tlb_wvpn,
    output reg [31:0] tlb_wpte,
    output reg itlb_we,
    output reg dtlb_we
    );

    wire [XLEN-1:0] mvendorid = 32'h52_56_4B_43;    // "RVKC" ; "R"ISC-"V", "K"HWL & "C"hoiCube84.
    wire [XLEN-1:0] marchid   = 32'h34_36_53_35;    // "46S5" ; "46"F arch based "S"uper scalar "5"-Stage Pipeline Architecture.
    wire [XLEN-1:0] mimpid    = 32'h34_36_49_31;    // "46I1" ; "46" instructions RISC-V RV32"I" Revision "1".
    wire [XLEN-1:0] mhartid   = 32'h52_4B_43_30;    // "RKC0" ; "R"oad to "K"AIST "C"ore 0.
    wire [XLEN-1:0] misa      = 32'h40000100;    // MXL = 32; misa[31:30] = 01. RV32"I"; misa[8] = 1.

    // mstatus fields
    reg MIE, MPIE, SIE, SPIE, SPP, SUM, MXR;
    reg [1:0] MPP;
    wire [XLEN-1:0] mstatus = {12'b0, MXR, SUM, 1'b0, 2'b0, 2'b0, MPP, 2'b0, SPP, MPIE, 1'b0, SPIE, 1'b0, MIE, 1'b0, SIE, 1'b0};
    assign mstatus_out = mstatus;
    // sstatus is a restricted view of mstatus
    wire [XLEN-1:0] sstatus = {23'b0, SPP, 2'b0, SPIE, 3'b0, SIE, 1'b0};

    // M-Mode Registers
    reg [XLEN-1:0] mtvec;
    reg [XLEN-1:0] mepc;
    reg [XLEN-1:0] mcause;
    reg [XLEN-1:0] mtval;
    reg [XLEN-1:0] mscratch;
    reg [XLEN-1:0] medeleg;
    reg [XLEN-1:0] mideleg;
    
    reg [XLEN-1:0] mie;
    reg [XLEN-1:0] mip_reg; // software writable parts of mip

    wire [XLEN-1:0] mip = {mip_reg[31:12], external_irq, mip_reg[10:8], timer_irq, mip_reg[6:0]}; // MEIP = 11, MTIP = 7
    
    assign medeleg_out = medeleg;
    assign mideleg_out = mideleg;
    
    assign timer_interrupt_pending = MIE & mie[7] & timer_irq;
    assign external_interrupt_pending = MIE & mie[11] & external_irq;

    // S-Mode Registers
    reg [XLEN-1:0] stvec;
    reg [XLEN-1:0] sepc;
    reg [XLEN-1:0] scause;
    reg [XLEN-1:0] stval;
    reg [XLEN-1:0] sscratch;
    reg [XLEN-1:0] satp;
    assign satp_out = satp;

    reg [63:0] mcycle;
    reg [63:0] minstret;

    reg csr_processing;
    reg [XLEN-1:0] csr_read_data;

    wire csr_access;
    wire valid_csr_address;

    assign csr_access = valid_csr_address;
    assign valid_csr_address = (csr_read_address == 12'hB00) || // mcycle
                               (csr_read_address == 12'hB02) || // minstret
                               (csr_read_address == 12'hB80) || // mcycleh
                               (csr_read_address == 12'hB82) || // minstreth
                               (csr_read_address == 12'hF11) || // mvendorid
                               (csr_read_address == 12'hF12) || // marchid  
                               (csr_read_address == 12'hF13) || // mimpid
                               (csr_read_address == 12'hF14) || // mhartid
                               (csr_read_address == 12'h300) || // mstatus
                               (csr_read_address == 12'h301) || // misa
                               (csr_read_address == 12'h302) || // medeleg
                               (csr_read_address == 12'h303) || // mideleg
                               (csr_read_address == 12'h304) || // mie
                               (csr_read_address == 12'h305) || // mtvec
                               (csr_read_address == 12'h340) || // mscratch
                               (csr_read_address == 12'h341) || // mepc
                               (csr_read_address == 12'h342) || // mcause
                               (csr_read_address == 12'h343) || // mtval
                               (csr_read_address == 12'h344) || // mip
                               (csr_read_address == 12'h100) || // sstatus
                               (csr_read_address == 12'h105) || // stvec
                               (csr_read_address == 12'h140) || // sscratch
                               (csr_read_address == 12'h141) || // sepc
                               (csr_read_address == 12'h142) || // scause
                               (csr_read_address == 12'h143) || // stval
                               (csr_read_address == 12'h180);   // satp



    localparam [XLEN-1:0] DEFAULT_mtvec  = 32'h00001000;
    localparam [XLEN-1:0] DEFAULT_mepc   = {XLEN{1'b0}};
    localparam [XLEN-1:0] DEFAULT_mcause = {XLEN{1'b0}};
    localparam [63:0] DEFAULT_mcycle = 64'b0;
    localparam [63:0] DEFAULT_minstret = 64'b0;

    // Read Operation.
    always @(*) begin
      case (csr_read_address)
        12'hB00: csr_read_data = mcycle[XLEN-1:0];
        12'hB02: csr_read_data = minstret[XLEN-1:0];
        12'hB80: csr_read_data = mcycle[63:32];
        12'hB82: csr_read_data = minstret[63:32];
        12'hF11: csr_read_data = mvendorid;
        12'hF12: csr_read_data = marchid;
        12'hF13: csr_read_data = mimpid;
        12'hF14: csr_read_data = mhartid;
        12'h300: csr_read_data = mstatus;
        12'h301: csr_read_data = misa;
        12'h302: csr_read_data = medeleg;
        12'h303: csr_read_data = mideleg;
        12'h304: csr_read_data = mie;
        12'h305: csr_read_data = mtvec;
        12'h340: csr_read_data = mscratch;
        12'h341: csr_read_data = mepc;
        12'h342: csr_read_data = mcause;
        12'h343: csr_read_data = mtval;
        12'h344: csr_read_data = mip;
        12'h100: csr_read_data = sstatus;
        12'h105: csr_read_data = stvec;
        12'h140: csr_read_data = sscratch;
        12'h141: csr_read_data = sepc;
        12'h142: csr_read_data = scause;
        12'h143: csr_read_data = stval;
        12'h180: csr_read_data = satp;
        default: csr_read_data = {XLEN{1'b0}};
      endcase

      if (reset) begin
        csr_ready = 1'b1;
      end else begin
        if (csr_access && !csr_processing) begin
          csr_ready = 1'b0;
        end else if (csr_processing) begin
          csr_ready = 1'b1;
        end else begin
          csr_ready = 1'b1;
        end
      end
    end

    // Reset Operation
    always @(posedge clk or posedge reset) begin
      if (reset) begin
        mtvec   <= DEFAULT_mtvec;
        mepc    <= DEFAULT_mepc;
        mcause  <= DEFAULT_mcause;
        mtval   <= {XLEN{1'b0}};
        mscratch <= {XLEN{1'b0}};
        medeleg <= {XLEN{1'b0}};
        mideleg <= {XLEN{1'b0}};
        mie     <= {XLEN{1'b0}};
        mip_reg <= {XLEN{1'b0}};
        
        stvec   <= {XLEN{1'b0}};
        sepc    <= {XLEN{1'b0}};
        scause  <= {XLEN{1'b0}};
        stval   <= {XLEN{1'b0}};
        sscratch <= {XLEN{1'b0}};
        satp    <= {XLEN{1'b0}};
        
        MIE <= 1'b0; MPIE <= 1'b0; SIE <= 1'b0; SPIE <= 1'b0; SPP <= 1'b0; MPP <= 2'b11; SUM <= 1'b0; MXR <= 1'b0;
        current_mode <= 2'b11; // Start in M-Mode
        
        tlb_wvpn <= 20'b0;
        tlb_wpte <= 32'b0;
        itlb_we <= 1'b0;
        dtlb_we <= 1'b0;

        mcycle  <= DEFAULT_mcycle;
        minstret <= DEFAULT_minstret;

        csr_processing <= 1'b0;
        csr_read_out <= {XLEN{1'b0}};
      end else begin
        mcycle <= mcycle + 1;
        
        if (instruction_retired) begin
          minstret <= minstret + 1;
        end

        // Defaults for single-cycle WE signals
        itlb_we <= 1'b0;
        dtlb_we <= 1'b0;

        if (csr_access && !csr_processing) begin
          csr_processing <= 1'b1;
          csr_read_out <= csr_read_data;
        end else if (csr_processing) begin
          csr_processing <= 1'b0;
          csr_read_out <= csr_read_data;
        end else if (csr_write_enable) begin
          csr_read_out <= csr_read_data;
        end

        // Write Operation
        if ((trapped && csr_write_enable) || (csr_write_enable)) begin
        case (csr_write_address)
          12'h300: begin // mstatus
              MIE <= csr_write_data[3];
              MPIE <= csr_write_data[7];
              MPP <= csr_write_data[12:11];
              SIE <= csr_write_data[1];
              SPIE <= csr_write_data[5];
              SPP <= csr_write_data[8];
              SUM <= csr_write_data[18];
              MXR <= csr_write_data[19];
          end
          12'h302: medeleg <= csr_write_data;
          12'h303: mideleg <= csr_write_data;
          12'h304: mie <= csr_write_data;
          12'h305: begin mtvec <= csr_write_data; $display("[%0t] CSR_File: mtvec = 0x%08x", $time, csr_write_data); end
          12'h340: mscratch <= csr_write_data;
          12'h341: mepc   <= csr_write_data;
          12'h342: mcause <= csr_write_data;
          12'h343: mtval  <= csr_write_data;
          12'h344: mip_reg <= csr_write_data;
          12'h100: begin // sstatus
              SIE <= csr_write_data[1];
              SPIE <= csr_write_data[5];
              SPP <= csr_write_data[8];
          end
          12'h105: stvec  <= csr_write_data;
          12'h140: sscratch <= csr_write_data;
          12'h141: sepc   <= csr_write_data;
          12'h142: scause <= csr_write_data;
          12'h143: stval  <= csr_write_data;
          12'h180: satp   <= csr_write_data;
          
          // Custom interface for Trap Controller to change current_mode
          12'h800: begin
              if (csr_write_data[1:0] == 2'b11) begin // Trapping to M-Mode
                  MPP <= current_mode;
                  MPIE <= MIE;
                  MIE <= 1'b0;
              end else if (csr_write_data[1:0] == 2'b01) begin // Trapping to S-Mode
                  SPP <= current_mode[0];
                  SPIE <= SIE;
                  SIE <= 1'b0;
              end
              current_mode <= csr_write_data[1:0];
          end
          12'h801: begin // Custom interface for MRET pop
              current_mode <= MPP;              // Pop MPP
              MPP <= 2'b00;                     // MPP defaults to U-mode
              MIE <= MPIE;                      // MIE = MPIE
              MPIE <= 1'b1;                     // MPIE = 1
          end
          12'h802: begin // Custom interface for SRET pop
              current_mode <= {1'b0, SPP};      // Pop SPP
              SPP <= 1'b0;                      // SPP defaults to U-mode
              SIE <= SPIE;                      // SIE = SPIE
              SPIE <= 1'b1;                     // SPIE = 1
          end
          
          12'h803: tlb_wvpn <= csr_write_data[19:0];
          12'h804: begin
              tlb_wpte <= csr_write_data;
              itlb_we <= 1'b1;
          end
          12'h805: begin
              tlb_wpte <= csr_write_data;
              dtlb_we <= 1'b1;
          end
          
          default: ;
        endcase
        end
      end
    end


endmodule