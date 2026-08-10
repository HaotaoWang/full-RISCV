`include "modules/headers/trap.vh"

module TrapController #(
    parameter XLEN = 32
)(
    input wire clk,
    input wire reset,
    input wire [XLEN-1:0] current_pc,
    input wire [XLEN-1:0] ID_pc,
    input wire [XLEN-1:0] EX_pc,
    input wire [XLEN-1:0] MEM_pc,
    input wire [XLEN-1:0] WB_pc,
    input wire [3:0] trap_status,      // indicates current trap type
    input wire [XLEN-1:0] csr_read_data,
    input wire [1:0] current_mode,     // 3 for M-Mode, 1 for S-Mode, 0 for U-Mode
    input wire [XLEN-1:0] medeleg,     // exception delegation register
    input wire [XLEN-1:0] mideleg,     // interrupt delegation register

    output reg [XLEN-1:0] trap_target,      // trap handler base address output
    output reg ic_clean,         // instruction cache reset signal for zifencei
    output reg debug_mode,       
    output reg csr_write_enable,
    output reg [11:0] csr_trap_address,
    output reg [XLEN-1:0] csr_trap_write_data,
    output reg trap_done,         // indicates whether PTH(Pre-Trap Hadling) FSM is done or not. if 0 = pc_stall
    output reg misaligned_instruction_flush,        // indicates whether the MISALIGNED INSTRUCTION pth is over and EX_MEM_Register should be flushed or not.
    output reg misaligned_memory_flush,
    output reg pth_done_flush,
    output reg trap_jump,
    output reg standby_mode
);

// FSM States
localparam  IDLE          = 4'b0000,
            WRITE_EPC     = 4'b0001,
            WRITE_CAUSE   = 4'b0010,
            READ_TVEC     = 4'b0011,
            GOTO_TVEC     = 4'b0100,
            
            READ_MEPC     = 4'b0101,
            RETURN_MRET   = 4'b0110,
            
            READ_SEPC     = 4'b0111,
            RETURN_SRET   = 4'b1000,

            MEM_STANDBY   = 4'b1001,
            WB_STANDBY    = 4'b1010,
            RTRE_STANDBY  = 4'b1011,
            ECALL_EPC_WRITE = 4'b1100,
            UPDATE_MODE   = 4'b1101,
            
            MRET_POP      = 4'b1110,
            SRET_POP      = 4'b1111;

// traditional FSM state architecture
reg [3:0] trap_handle_state, next_trap_handle_state;
reg [3:0] active_trap_status;
reg [XLEN-1:0] active_trap_pc;
reg debug_mode_reg; 

// A trap request is a level that may disappear while the pre-trap FSM is
// running (most notably after UPDATE_MODE clears mstatus.MIE).  Keep the cause
// and resume PC stable until the complete CSR-write/redirect sequence ends.
wire [3:0] handled_trap_status = (trap_handle_state == IDLE) ?
                                 trap_status : active_trap_status;
// ECALL is detected in ID, and asynchronous interrupts use the boundary
// after the older EX instruction.  In both cases ID_pc is the first
// uncommitted instruction.  MEM/EX exceptions keep their stage-specific
// handling below.
wire resume_from_id = (trap_status == `TRAP_ECALL) ||
                      (trap_status == `TRAP_TIMER_INTERRUPT) ||
                      (trap_status == `TRAP_EXTERNAL_INTERRUPT);
wire [XLEN-1:0] incoming_trap_pc = resume_from_id ?
                                    ((ID_pc != {XLEN{1'b0}}) ? ID_pc : current_pc) :
                                    ((EX_pc != {XLEN{1'b0}}) ? EX_pc :
                                     ((ID_pc != {XLEN{1'b0}}) ? ID_pc : current_pc));

// Exception Cause Code Mapping
reg [31:0] exception_cause;
always @(*) begin
    if (handled_trap_status == `TRAP_EBREAK) exception_cause = 32'd3;
    else if (handled_trap_status == `TRAP_ECALL) begin
        if (current_mode == 2'b11) exception_cause = 32'd11;
        else if (current_mode == 2'b01) exception_cause = 32'd9;
        else exception_cause = 32'd8;
    end
    else if (handled_trap_status == `TRAP_MISALIGNED_LOAD) exception_cause = 32'd4;
    else if (handled_trap_status == `TRAP_MISALIGNED_STORE) exception_cause = 32'd6;
    else if (handled_trap_status == `TRAP_TIMER_INTERRUPT) exception_cause = 32'h8000_0007;
    else if (handled_trap_status == `TRAP_EXTERNAL_INTERRUPT) exception_cause = 32'h8000_000B;
    else exception_cause = 32'd0; // TRAP_MISALIGNED_INSTRUCTION
end

wire is_interrupt = exception_cause[31];
wire [4:0] cause_code = exception_cause[4:0];
wire delegated_to_s = (current_mode <= 2'b01) && (is_interrupt ? mideleg[cause_code] : medeleg[cause_code]);

// FSM update logic and debug_mode register update
always @(posedge clk or posedge reset) begin
    if (reset) begin
        trap_handle_state <= IDLE;
        active_trap_status <= `TRAP_NONE;
        active_trap_pc <= {XLEN{1'b0}};
        debug_mode_reg <= 1'b0; 
    end else begin
        trap_handle_state <= next_trap_handle_state;
        if ((trap_handle_state == IDLE) && (trap_status != `TRAP_NONE)) begin
            active_trap_status <= trap_status;
            active_trap_pc <= incoming_trap_pc;
        end else if ((trap_handle_state != IDLE) && (next_trap_handle_state == IDLE)) begin
            active_trap_status <= `TRAP_NONE;
        end
        // debug_mode logics
        case (handled_trap_status)
            `TRAP_MRET: begin
                if (trap_handle_state == IDLE) begin
                    debug_mode_reg <= 1'b0;
                end
            end
            `TRAP_EBREAK: begin
                if (trap_handle_state == WRITE_CAUSE) begin
                    debug_mode_reg <= 1'b1;
                end
            end
            default: begin
                // keep debug_mode_reg
            end
        endcase
    end
end

// debug_mode register
always @(*) begin
    debug_mode = debug_mode_reg;
end

always @(*) begin
    // default outputs
    ic_clean             = 1'b0;
    csr_write_enable     = 1'b0;
    csr_trap_address     = 12'b0;
    csr_trap_write_data  = {XLEN{1'b0}};
    trap_target          = {XLEN{1'b0}};
    trap_done            = 1'b1;
    misaligned_instruction_flush = 1'b0;
    misaligned_memory_flush = 1'b0;
    pth_done_flush       = 1'b0;
    trap_jump            = 1'b0;
    standby_mode = 1'b0;
    // default next state
    next_trap_handle_state = IDLE;

    case (handled_trap_status)
        // traps that doesn't require multiple PTH FSM
        `TRAP_NONE: begin
            next_trap_handle_state = IDLE;
        end
        `TRAP_FENCEI: begin
            ic_clean = 1'b1;
            trap_done = 1'b1;
            next_trap_handle_state = IDLE;
        end

        // ────────── traps that require multiple PTH FSM ──────────
        default: begin
            case (trap_handle_state)
                IDLE: begin 
                    if (handled_trap_status == `TRAP_MRET) begin
                        // Drain the older instructions before reading mepc.
                        // In particular, rt_hw_context_switch_exit restores
                        // sp in the instruction immediately preceding mret.
                        standby_mode = 1'b1;
                        trap_done = 1'b0;
                        next_trap_handle_state = MEM_STANDBY;

                    end else if (handled_trap_status == `TRAP_SRET) begin
                        csr_trap_address = 12'h141; // sepc
                        trap_done = 1'b0;
                        next_trap_handle_state = READ_SEPC;

                    end else if (handled_trap_status == `TRAP_ECALL || handled_trap_status == `TRAP_TIMER_INTERRUPT || handled_trap_status == `TRAP_EXTERNAL_INTERRUPT) begin
                        standby_mode = 1'b1;
                        trap_done = 1'b0;
                        next_trap_handle_state = MEM_STANDBY;

                    end else begin
                        // write current pc value to EPC CSR
                        csr_write_enable = 1'b1;
                        csr_trap_address = delegated_to_s ? 12'h141 : 12'h341; // sepc or mepc
                        csr_trap_write_data = MEM_pc;
                        trap_done = 1'b0;
                        next_trap_handle_state = WRITE_EPC;
                    end
                end

                MEM_STANDBY: begin
                    standby_mode = 1'b1;
                    trap_done = 1'b0;
                    next_trap_handle_state = WB_STANDBY;
                end

                WB_STANDBY: begin
                    standby_mode = 1'b1;
                    trap_done = 1'b0;
                    next_trap_handle_state = RTRE_STANDBY;
                end

                RTRE_STANDBY: begin
                    standby_mode = 1'b1;
                    trap_done = 1'b0;
                    if (handled_trap_status == `TRAP_MRET)
                        next_trap_handle_state = READ_MEPC;
                    else
                        next_trap_handle_state = ECALL_EPC_WRITE;
                end

                ECALL_EPC_WRITE: begin
                    standby_mode = 1'b0;
                    // write current pc value to EPC CSR
                    csr_write_enable = 1'b1;
                    csr_trap_address = delegated_to_s ? 12'h141 : 12'h341; // sepc or mepc
                    csr_trap_write_data = active_trap_pc;
                    trap_done = 1'b0;
                    next_trap_handle_state = WRITE_EPC;
                end

                WRITE_EPC: begin 
                    // write cause code value
                    csr_write_enable = 1'b1;
                    csr_trap_address = delegated_to_s ? 12'h142 : 12'h342; // scause or mcause
                    csr_trap_write_data = exception_cause;
                    trap_done = 1'b0;
                    next_trap_handle_state = UPDATE_MODE;
                end
                
                UPDATE_MODE: begin
                    // tell CSR_File to update mode (via custom interface address 0x800)
                    csr_write_enable = 1'b1;
                    csr_trap_address = 12'h800; // custom current_mode change
                    csr_trap_write_data = delegated_to_s ? 32'b01 : 32'b11; // go to S-mode or M-mode
                    trap_done = 1'b0;
                    next_trap_handle_state = WRITE_CAUSE;
                end

                WRITE_CAUSE: begin
                    // Enable debug mode for EBREAK and PTH escape
                    if (handled_trap_status == `TRAP_EBREAK) begin
                        trap_done = 1'b1;
                        next_trap_handle_state = IDLE;
                    end
                    else begin
                        // ECALL, ILLEGAL/MISALIGNED_INSTRUCTION : read tvec trap handler CSR value
                        csr_write_enable = 1'b0;
                        csr_trap_address = delegated_to_s ? 12'h105 : 12'h305; // stvec or mtvec
                        trap_target = csr_read_data;
                        trap_done = 1'b0;
                        next_trap_handle_state = READ_TVEC;
                    end
                end

                READ_TVEC: begin
                    // keep tvec value output
                    csr_trap_address = delegated_to_s ? 12'h105 : 12'h305;
                    trap_target = csr_read_data;
                    if (handled_trap_status == `TRAP_MISALIGNED_INSTRUCTION) begin
                        misaligned_instruction_flush = 1'b1;
                    end else if (handled_trap_status == `TRAP_MISALIGNED_STORE || handled_trap_status == `TRAP_MISALIGNED_LOAD) begin
                        misaligned_memory_flush = 1'b1;
                    end
                    trap_done = 1'b1;
                    trap_jump = 1'b1;
                    pth_done_flush = 1'b1;
                    next_trap_handle_state = GOTO_TVEC;
                end

                GOTO_TVEC: begin
                    // keep tvec value output
                    csr_trap_address = delegated_to_s ? 12'h105 : 12'h305;
                    trap_target = csr_read_data;
                    if (handled_trap_status == `TRAP_MISALIGNED_INSTRUCTION) begin
                        misaligned_instruction_flush = 1'b1;
                    end else if (handled_trap_status == `TRAP_MISALIGNED_STORE || handled_trap_status == `TRAP_MISALIGNED_LOAD) begin
                        misaligned_memory_flush = 1'b1;
                    end
                    trap_done = 1'b1;
                    trap_jump = 1'b1;
                    pth_done_flush = 1'b1;
                    next_trap_handle_state = IDLE;
                end

                READ_MEPC: begin
                    // keep mepc value output to read PC, but first tell CSR_File to pop mode
                    csr_write_enable = 1'b1;
                    csr_trap_address = 12'h801; // custom MRET pop
                    trap_done = 1'b0;
                    next_trap_handle_state = MRET_POP;
                end
                
                MRET_POP: begin
                    csr_write_enable = 1'b0;
                    csr_trap_address = 12'h341; // mepc
                    trap_target = {csr_read_data[31:2], 2'b0};
                    trap_done = 1'b0;
                    next_trap_handle_state = RETURN_MRET;
                end

                RETURN_MRET: begin
                    csr_trap_address = 12'h341; // mepc
                    trap_target = {csr_read_data[31:2], 2'b0};
                    trap_done = 1'b1;
                    trap_jump = 1'b1;
                    pth_done_flush = 1'b1;
                    next_trap_handle_state = IDLE;
                end

                READ_SEPC: begin
                    csr_write_enable = 1'b1;
                    csr_trap_address = 12'h802; // custom SRET pop
                    trap_done = 1'b0;
                    next_trap_handle_state = SRET_POP;
                end
                
                SRET_POP: begin
                    csr_write_enable = 1'b0;
                    csr_trap_address = 12'h141; // sepc
                    trap_target = {csr_read_data[31:2], 2'b0};
                    trap_done = 1'b0;
                    next_trap_handle_state = RETURN_SRET;
                end

                RETURN_SRET: begin
                    csr_trap_address = 12'h141; // sepc
                    trap_target = {csr_read_data[31:2], 2'b0};
                    trap_done = 1'b1;
                    trap_jump = 1'b1;
                    pth_done_flush = 1'b1;
                    next_trap_handle_state = IDLE;
                end

                default: begin
                    next_trap_handle_state = IDLE;
                end
            endcase
        end
    endcase
end
endmodule
