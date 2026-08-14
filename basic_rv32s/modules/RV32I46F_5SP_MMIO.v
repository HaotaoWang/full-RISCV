`include "modules/headers/alu_src_select.vh"
`include "modules/headers/rf_wd_select.vh"

`include "modules/Program_Counter.v"
`include "modules/PC_Controller.v"
`include "modules/PC_Plus_4.v"
`include "modules/Instruction_Memory.v"
`include "modules/Instruction_Decoder.v"
`include "modules/Immediate_Generator.v"
`include "modules/Control_Unit.v"
`include "modules/Register_File.v"
`include "modules/Data_Memory.v"
`include "modules/ALU_Controller.v"
`include "modules/ALU.v"
`include "modules/Hardware_Multiplier.v"
`include "modules/Branch_Logic.v"
`include "modules/Byte_Enable_Logic.v"
`include "modules/CSR_File.v"
`include "modules/Exception_Detector.v"
`include "modules/Trap_Controller.v"
`include "modules/RV32_AXI_Adapter.v"
// DCache 等模块由 Vivado 工程文件或 test.sh 统一添加，避免头文件级联依赖问题

`include "modules/IF_ID_Register.v"
`include "modules/ID_EX_Register.v"
`include "modules/EX_MEM_Register.v"
`include "modules/MEM_WB_Register.v"

`include "modules/Hazard_Unit.v"
`include "modules/Forward_Unit.v"
`include "modules/Branch_Predictor.v"

`include "modules/MMIO_Interface.v"
`include "modules/MMU.v"

module RV32I46F5SPMMIO #(
    parameter XLEN = 32
)(
    input clk,
    input reset,
    input UART_busy,
    
    output wire [31:0] retire_instruction,
    output wire [7:0] mmio_uart_tx_data,
    output wire mmio_uart_tx_start,
    output wire [3:0] mmio_led,

    // Interrupt Inputs
    input timer_irq,
    input external_irq,

    // --- 新增：指令取指 (IF) Full AXI4 Master 接口 (用于 ICache) ---
    output        m_axi_if_awvalid,
    input         m_axi_if_awready,
    output [31:0] m_axi_if_awaddr,
    output [ 3:0] m_axi_if_awid,
    output [ 7:0] m_axi_if_awlen,
    output [ 1:0] m_axi_if_awburst,
    output [ 2:0] m_axi_if_awprot,
    output        m_axi_if_wvalid,
    input         m_axi_if_wready,
    output [31:0] m_axi_if_wdata,
    output [ 3:0] m_axi_if_wstrb,
    output        m_axi_if_wlast,
    input         m_axi_if_bvalid,
    input  [ 1:0] m_axi_if_bresp,
    input  [ 3:0] m_axi_if_bid,
    output        m_axi_if_bready,
    output        m_axi_if_arvalid,
    input         m_axi_if_arready,
    output [31:0] m_axi_if_araddr,
    output [ 3:0] m_axi_if_arid,
    output [ 7:0] m_axi_if_arlen,
    output [ 1:0] m_axi_if_arburst,
    output [ 2:0] m_axi_if_arprot,
    input         m_axi_if_rvalid,
    output        m_axi_if_rready,
    input  [31:0] m_axi_if_rdata,
    input  [ 1:0] m_axi_if_rresp,
    input  [ 3:0] m_axi_if_rid,
    input         m_axi_if_rlast,

    // --- 新增：数据访存 (MEM) Full AXI4 Master 接口 (用于 DCache) ---
    output        m_axi_mem_awvalid,
    input         m_axi_mem_awready,
    output [31:0] m_axi_mem_awaddr,
    output [ 3:0] m_axi_mem_awid,
    output [ 7:0] m_axi_mem_awlen,
    output [ 1:0] m_axi_mem_awburst,
    output [ 2:0] m_axi_mem_awprot,
    output        m_axi_mem_wvalid,
    input         m_axi_mem_wready,
    output [31:0] m_axi_mem_wdata,
    output [ 3:0] m_axi_mem_wstrb,
    output        m_axi_mem_wlast,
    input         m_axi_mem_bvalid,
    input  [ 1:0] m_axi_mem_bresp,
    input  [ 3:0] m_axi_mem_bid,
    output        m_axi_mem_bready,
    output        m_axi_mem_arvalid,
    input         m_axi_mem_arready,
    output [31:0] m_axi_mem_araddr,
    output [ 3:0] m_axi_mem_arid,
    output [ 7:0] m_axi_mem_arlen,
    output [ 1:0] m_axi_mem_arburst,
    output [ 2:0] m_axi_mem_arprot,
    input         m_axi_mem_rvalid,
    output        m_axi_mem_rready,
    input  [31:0] m_axi_mem_rdata,
    input  [ 1:0] m_axi_mem_rresp,
    input  [ 3:0] m_axi_mem_rid,
    input         m_axi_mem_rlast
);

    // MMIO Interface
    reg [31:0] mmio_uart_tx_status;
    wire mmio_uart_status_hit;
    wire [XLEN-1:0] mmio_uart_status;

    // Program Counter and  PC Plus 4
    wire [XLEN-1:0] pc;
    wire [XLEN-1:0] pc_plus_4_signal;
    wire [XLEN-1:0] next_pc;
    
    // Instruction Memory and Debug Interface
    wire [31:0] im_instruction;
    wire [31:0] dbg_instruction = 32'b00000001011110110000110000110011; //add x24 = x22 + x23 = FFFF_FFBC + ABAD_BB02 = ABADBABE
    reg [31:0] instruction;
    wire [XLEN-1:0] IF_imm;
    wire [6:0] IF_opcode;

    // ROM bypass signals (MEM stage instruction memory access) - 废弃
    wire [31:0] rom_address = 32'b0;
    wire [31:0] rom_read_data = 32'b0;

    // AXI 握手信号
    wire if_ready;
    wire if_accept;
    wire [XLEN-1:0] if_response_pc;
    wire if_valid = 1'b1;
    reg if_request_pending;
    reg if_discard_response;
    wire if_request_issue = !if_request_pending;
    wire EX_jump_execute = EX_jump && (!mem_valid || mem_ready);
    wire branch_miss_execute = branch_prediction_miss && (!mem_valid || mem_ready);
    wire control_redirect = trap_jump || (trap_done && (EX_jump_execute || branch_miss_execute));
    // The I-cache can finish an older sequential request after a branch or
    // trap has already changed PC.  A VALID response is usable only when its
    // tagged request PC still matches the architectural fetch PC; otherwise
    // discard it and retry the current PC.  Without this check an epilogue
    // instruction from before an interrupt can be replayed after mret.
    wire if_response_matches_pc = (if_response_pc == pc);
    wire if_pipeline_ready = if_ready && if_response_matches_pc &&
                             !if_discard_response && !control_redirect;
    wire mem_ready;

    // Serialize instruction fetches so redirects cannot leave stale responses
    // queued behind the new target PC.
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            if_request_pending <= 1'b0;
            if_discard_response <= 1'b0;
        end else begin
            if (if_ready)
                if_request_pending <= 1'b0;
            else if (if_request_issue && if_accept)
                if_request_pending <= 1'b1;

            if (control_redirect && if_request_pending && !if_ready)
                if_discard_response <= 1'b1;
            else if (if_ready)
                if_discard_response <= 1'b0;
        end
    end
    wire mem_valid;


    assign IF_imm = {{20{instruction[31]}}, instruction[7], instruction[30:25], instruction[11:8], 1'b0};
    assign IF_opcode = (instruction[6:0]);

    // Instruction Decoder
    wire [6:0] opcode;
    wire [2:0] funct3;
    wire [6:0] funct7;
    wire [4:0] rs1;
    wire [4:0] rs2;
	wire [4:0] rd;
    wire [19:0] raw_imm;
    
    // Immediate Generator
    wire [XLEN-1:0] imm;

    // Control Unit
    wire pc_stall;
    wire jump;
	wire branch;
	wire [1:0] alu_src_A_select;
	wire [2:0] alu_src_B_select;
    wire memory_read;
	wire memory_write;
	wire register_file_write;
	wire [2:0] register_file_write_data_select;
    wire cu_csr_write_enable;
    // CSRRS/CSRRC (and their immediate forms) are read-only when the rs1/uimm
    // field is zero.  In particular, the common `csrr rd, csr` pseudo-op must
    // not write a stale ALU value back into mepc/mcause.
    wire id_csr_write_enable = cu_csr_write_enable &&
        ((funct3 == 3'b001) || (funct3 == 3'b101) ||
         (((funct3 == 3'b010) || (funct3 == 3'b011) ||
           (funct3 == 3'b110) || (funct3 == 3'b111)) && (rs1 != 5'b0)));

    // ID阶段跳转信号
    wire ID_jump = jump;  // ID阶段的跳转信号
    wire [XLEN-1:0] ID_jump_target;  // ID阶段的跳转目标地址

    // 计算ID阶段跳转目标（JAL/JALR在ID阶段就能确定目标）
    assign ID_jump_target = (opcode == `OPCODE_JAL)  ? (ID_pc + imm) :
                            (opcode == `OPCODE_JALR) ? (read_data1 + imm) : 32'h0;

    // Branch Logic and Branch Predictor
    wire branch_taken;
    wire [XLEN-1:0] branch_target;
    wire [XLEN-1:0] branch_target_actual;

    // Register File
    reg [XLEN-1:0] register_file_write_data;
    
    // Register File
    wire [XLEN-1:0] read_data1;
    wire [XLEN-1:0] read_data2;

    // ALU Controller
    wire [3:0] alu_op;

    // ALUsrcA, srcB MUX
    reg [XLEN-1:0] src_A;
    reg [XLEN-1:0] src_B;

    // ALU
    wire [XLEN-1:0] alu_result;
    wire alu_zero;
	
    // Data Memory and Byte Enable Logic
    wire [XLEN-1:0] data_memory_read_data;
	wire [XLEN-1:0] byte_enable_logic_register_file_write_data;
    wire [XLEN-1:0] data_memory_write_data;
    wire [3:0] write_mask;

    // CSR File
    wire csr_write_enable;
    reg [11:0] csr_read_address;
    reg [11:0] csr_write_address;
    reg [XLEN-1:0] csr_write_data;
    wire [XLEN-1:0] csr_read_out;
    wire csr_ready;
    reg instruction_retired;

    // Exception_Detector
    wire trapped_raw;
    wire [3:0] trap_status_raw;
    // Precise traps must not overtake an older load/store in MEM.  This is
    // the same completion rule used by EX redirects: a response completing
    // in the current cycle is sufficient, but an unfinished transaction is
    // allowed to drain before mret/ecall/interrupt handling starts.
    wire trap_mem_complete = !mem_valid || mem_ready;
    // An asynchronous interrupt must also not overtake an older taken branch
    // or jump in EX.  If it did, the controller would save sequential ID_pc
    // as mepc while the older redirect was suppressed, resuming on the wrong
    // path after mret.  Leave the interrupt pending for one more cycle so the
    // control transfer retires first.
    wire raw_async_interrupt = (trap_status_raw == `TRAP_TIMER_INTERRUPT) ||
                               (trap_status_raw == `TRAP_EXTERNAL_INTERRUPT);
    wire older_ex_redirect = EX_jump || branch_prediction_miss;
    wire trap_control_complete = !raw_async_interrupt || !older_ex_redirect;
    wire trapped = trapped_raw && trap_mem_complete && trap_control_complete;
    wire [3:0] trap_status = trapped ? trap_status_raw : `TRAP_NONE;

    // Trap Controller
    wire trap_done;
    wire debug_mode;
    wire tc_csr_write_enable;
    wire [XLEN-1:0] trap_target;
    wire [11:0] csr_trap_address;
    wire [XLEN-1:0] csr_trap_write_data;
    wire pth_done_flush;
    
    wire [XLEN-1:0] satp_out;
    wire [XLEN-1:0] mstatus_out;
    
    wire [19:0] tlb_wvpn;
    wire [31:0] tlb_wpte;
    wire itlb_we, dtlb_we;
    
    // MMU Signals
    wire [XLEN-1:0] if_physical_address;
    wire if_page_fault;
    wire [XLEN-1:0] mem_physical_address;
    wire mem_load_page_fault;
    wire mem_store_page_fault;
    // IF_ID_Register
    wire [XLEN-1:0] ID_pc;
    wire [XLEN-1:0] ID_pc_plus_4;
    wire [31:0] ID_instruction;
    wire ID_branch_estimation;

    // ID_EX_Register
    wire [XLEN-1:0] EX_pc;
    wire [XLEN-1:0] EX_pc_plus_4;
    wire EX_branch_estimation;
    wire [31:0] EX_instruction;

    // EX_MEM_Register
    wire EX_jump;
    wire EX_memory_read;
    wire EX_memory_write;
    wire [2:0] EX_register_file_write_data_select;
    wire EX_register_write_enable;
    wire EX_csr_write_enable;
    wire EX_branch;
    wire [1:0] EX_alu_src_A_select;
    wire [2:0] EX_alu_src_B_select;
    wire [6:0] EX_opcode;
    wire [2:0] EX_funct3;
    wire [6:0] EX_funct7;
    wire [4:0] EX_rd;
    wire [19:0] EX_raw_imm;
    wire [XLEN-1:0] EX_read_data1;
    wire [XLEN-1:0] EX_read_data2;
    wire [4:0] EX_rs1;
    wire [4:0] EX_rs2;
    wire [XLEN-1:0] EX_imm;
    wire [XLEN-1:0] EX_csr_read_data;

    wire [XLEN-1:0] MEM_pc;
    wire [XLEN-1:0] MEM_pc_plus_4;
    wire [31:0] MEM_instruction;

    wire MEM_memory_read;
    wire MEM_memory_write;
    wire [2:0] MEM_register_file_write_data_select;
    wire MEM_register_write_enable;
    wire MEM_csr_write_enable;
    wire [6:0] MEM_opcode;
    wire [2:0] MEM_funct3;
    wire [4:0] MEM_rs1;
    wire [4:0] MEM_rd;
    wire [XLEN-1:0] MEM_read_data2;
    wire [XLEN-1:0] MEM_imm;
    wire [19:0] MEM_raw_imm;
    wire [XLEN-1:0] MEM_csr_read_data;
    wire [XLEN-1:0] MEM_alu_result;
    wire [XLEN-1:0] trap_value =
        (trap_status_raw == `TRAP_MISALIGNED_INSTRUCTION &&
         MEM_opcode == `OPCODE_BRANCH) ? branch_target : MEM_alu_result;

    wire [XLEN-1:0] WB_pc;
    wire [XLEN-1:0] WB_pc_plus_4;
    wire [31:0] WB_instruction;
    wire [6:0] WB_opcode;

    // MEM_WB_Register
    wire MEM_WB_flush;
    wire [2:0] WB_register_file_write_data_select;
    wire [XLEN-1:0] WB_imm;
    wire [19:0] WB_raw_imm;
    wire [XLEN-1:0] WB_csr_read_data;
    wire [XLEN-1:0] WB_alu_result;
    wire WB_register_write_enable;
    wire WB_csr_write_enable;
    wire [4:0] WB_rs1;
    wire [4:0] WB_rd;

    wire [XLEN-1:0] WB_byte_enable_logic_register_file_write_data;

    // Hazard Unit
    wire IF_ID_flush;
    wire ID_EX_flush;
    wire EX_MEM_flush;
    wire IF_ID_stall;
    wire ID_EX_stall;
    wire EX_MEM_stall;
    wire MEM_WB_stall;
    wire csr_hazard_mem;
    wire csr_hazard_wb;
    wire store_hazard_mem;
    wire store_hazard_wb;
    
    // Exception / Trap implicit wires
    wire branch_prediction_miss;
    wire standby_mode;
    wire misaligned_instruction_flush;
    wire misaligned_memory_flush;

    // Forward Unit
    wire [1:0] hazard_mem;
    wire [1:0] hazard_wb;
    wire [XLEN-1:0] csr_forward_data;
    wire [XLEN-1:0] alu_forward_source_data_a;
    wire [XLEN-1:0] alu_forward_source_data_b;
    wire [1:0] alu_forward_source_select_a;
    wire [1:0] alu_forward_source_select_b;
    reg [XLEN-1:0] alu_normal_source_a;
    reg [XLEN-1:0] alu_normal_source_b;

    reg [XLEN-1:0] retired_alu_result;
    reg [XLEN-1:0] retired_csr_read_data;

    wire [XLEN-1:0] store_forward_data;
    wire store_forward_enable;
    wire [XLEN-1:0] EX_read_data2_MUX;
    assign EX_read_data2_MUX = store_forward_enable ? store_forward_data : EX_read_data2;

    // Branch Predictor
    wire branch_estimation;
    
    wire [31:0] writeback_instruction = WB_instruction;
    assign retire_instruction = writeback_instruction;

    /* Keep all three CSR write-port signals under the same owner.  During the
       trap redirect cycles an older WB CSR instruction may still be visible;
       combining that WB write-enable with the trap controller's address/data
       corrupts the selected trap CSR (notably writing zero to mtvec). */
    wire trap_controller_owns_csr = !trap_done || trap_jump;
    wire csr_write_enable_source = trap_controller_owns_csr ?
                                   tc_csr_write_enable : WB_csr_write_enable;

    wire [XLEN-1:0] data_memory_read_data_muxed;
    assign data_memory_read_data_muxed = mmio_uart_status_hit ? mmio_uart_status : data_memory_read_data;

    ALU alu (
        .src_A(src_A),
        .src_B(src_B),
        .alu_op(alu_op),

        .alu_result(alu_result),
        .alu_zero(alu_zero)
    );

    // 新增：RV32M 硬件乘法器黑盒
    wire [31:0] mul_result;
    Hardware_Multiplier mul_inst (
        .src_A(src_A),
        .src_B(src_B),
        .mul_op(EX_funct3),
        .mul_result(mul_result)
    );

    // 结果选择器：如果是 R型指令 且 funct7 == 0000001，则选择乘法器结果
    wire is_mul_inst = (EX_opcode == 7'b0110011) && (EX_funct7 == 7'b0000001);
    wire [31:0] final_ex_result = is_mul_inst ? mul_result : alu_result;

    ALUController alu_controller (
        .opcode(EX_opcode),
	    .funct3(EX_funct3),
        .funct7_5(EX_funct7[5]),
        .imm_10(EX_imm[10]),
	
        .alu_op(alu_op)
    );

    BranchLogic branch_logic (
        .branch(EX_branch),
        .branch_estimation(EX_branch_estimation),
        .funct3(EX_funct3),
        .alu_zero(alu_zero),
        .pc(EX_pc),
        .imm(EX_imm),
    
        .branch_taken(branch_taken),
        .branch_prediction_miss(branch_prediction_miss),
        .branch_target_actual(branch_target_actual)
    );

    BranchPredictor #(.XLEN(XLEN)) branch_predictor(
        .clk(clk),
        .reset(reset),
        .IF_opcode(IF_opcode),
        .IF_pc (pc),
        .IF_imm (IF_imm),
        .EX_branch(EX_branch),
        .EX_branch_taken (branch_taken),

        .branch_estimation (branch_estimation),
        .branch_target (branch_target)
    );

    ByteEnableLogic byte_enable_logic (
        .memory_read(MEM_memory_read),
        .memory_write(MEM_memory_write),
        .funct3(MEM_funct3),
	    .register_file_read_data(MEM_read_data2),
	    .data_memory_read_data(data_memory_read_data_muxed),
	    .address(MEM_alu_result[1:0]),
	
	    .register_file_write_data(byte_enable_logic_register_file_write_data),
	    .data_memory_write_data(data_memory_write_data),
        .write_mask(write_mask)
    );

    ControlUnit control_unit (
        .write_done(1'b1),
	    .opcode(opcode),
	    .funct3(funct3),
        .trap_done(trap_done),
        .csr_ready(csr_ready),
        .IF_ID_stall(IF_ID_stall),
        .trap_jump(trap_jump),

        .pc_stall(pc_stall),
        .jump(jump),
	    .branch(branch),
	    .alu_src_A_select(alu_src_A_select),
	    .alu_src_B_select(alu_src_B_select),
	    .register_file_write(register_file_write),
	    .register_file_write_data_select(register_file_write_data_select),
	    .memory_read(memory_read),
	    .memory_write(memory_write),
        .csr_write_enable(cu_csr_write_enable)
    );

    wire [1:0] current_mode;
    wire [XLEN-1:0] medeleg;
    wire [XLEN-1:0] mideleg;
    wire timer_interrupt_pending;
    wire external_interrupt_pending;

    CSRFile #(.XLEN(XLEN)) csr_file (
        .clk(clk),
        .reset(reset),
        .trapped(trapped),
        .csr_write_enable(csr_write_enable_source),
        .csr_read_address(csr_read_address),
        .csr_write_address(csr_write_address),
        .csr_write_data(csr_write_data),
        .instruction_retired(instruction_retired),

        .csr_read_out(csr_read_out),
        .csr_ready(csr_ready),
        .current_mode(current_mode),
        .medeleg_out(medeleg),
        .mideleg_out(mideleg),
        .satp_out(satp_out),
        .mstatus_out(mstatus_out),
        
        .timer_irq(timer_irq),
        .external_irq(external_irq),
        .timer_interrupt_pending(timer_interrupt_pending),
        .external_interrupt_pending(external_interrupt_pending),
        
        .tlb_wvpn(tlb_wvpn),
        .tlb_wpte(tlb_wpte),
        .itlb_we(itlb_we),
        .dtlb_we(dtlb_we)
    );

    MMU #(.XLEN(XLEN)) mmu_inst (
        .clk(clk),
        .reset(reset),
        
        .satp(satp_out),
        .mstatus(mstatus_out),
        .current_mode(current_mode),
        
        .tlb_wvpn(tlb_wvpn),
        .tlb_wpte(tlb_wpte),
        .itlb_we(itlb_we),
        .dtlb_we(dtlb_we),

        .if_virtual_address(next_pc),
        .if_request(if_valid),
        .if_physical_address(if_physical_address),
        .if_page_fault(if_page_fault),

        .mem_virtual_address(MEM_alu_result),
        .mem_request_read(dcache_mem_rd),
        .mem_request_write(MEM_memory_write),
        .mem_physical_address(mem_physical_address),
        .mem_load_page_fault(mem_load_page_fault),
        .mem_store_page_fault(mem_store_page_fault)
    );

    // =====================================================================
    // 数据端缓存 (DCache) 与 MMIO 旁路逻辑
    // =====================================================================
    
    // RAM requests use a single-outstanding AXI bridge.  Keeping the request
    // asserted until the AXI response avoids the DCache FIFO/ack deadlock.
    wire dcache_request_active = (MEM_memory_read || MEM_memory_write) && !mmio_uart_status_hit;
    reg data_response_pending;
    reg [XLEN-1:0] data_response_q;
    wire data_axi_request = dcache_request_active && !data_response_pending;
    wire dcache_mem_rd = data_axi_request && MEM_memory_read;
    wire [3:0] dcache_mem_wr = (data_axi_request && MEM_memory_write) ? write_mask : 4'b0000;
    
    // Pipeline 需要的 mem_valid：用于告诉 HazardUnit 目前是否处于访存状态
    assign mem_valid = (MEM_memory_write || MEM_memory_read);

    wire axi_data_ready;
    wire [XLEN-1:0] axi_data_read_data;
    // AXI read data and ready are combinational outputs of the bridge.  Do
    // not let them directly release the CPU pipeline: on FPGA that makes the
    // RAM -> interconnect -> bridge -> MEM/WB path a same-cycle dependency.
    // Capture every response first and acknowledge it to MEM on the following
    // cycle, when both the data and the completion flag are registered.
    wire dcache_mem_ack = data_response_pending;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            data_response_pending <= 1'b0;
            data_response_q <= {XLEN{1'b0}};
        end else begin
            if (axi_data_ready) begin
                data_response_q <= axi_data_read_data;
                data_response_pending <= 1'b1;
            end else if (data_response_pending &&
                         (!dcache_request_active || !EX_MEM_stall)) begin
                data_response_pending <= 1'b0;
            end
        end
    end

    assign data_memory_read_data = data_response_q;
    
    // mem_ready 用于解除流水线停顿。
    // 如果是 MMIO 命中，由于采用了旁路逻辑（1个周期内直接出结果），无需等待，直接 ready = 1
    // 否则，等待 DCache 的 ack
    // A UART TX store must remain in MEM while the transmitter is occupied.
    // Reporting it complete and suppressing the write in MMIO_Interface loses
    // bytes during printf.  Status reads and all other MMIO accesses stay
    // single-cycle.
    wire mmio_uart_tx_write = MEM_memory_write &&
                              (mem_physical_address == 32'h10010000);
    wire mmio_access_ready = !mmio_uart_tx_write || !UART_busy;
    assign mem_ready = mmio_uart_status_hit ? mmio_access_ready : dcache_mem_ack;

    RV32_AXI_Adapter data_axi_adapter (
        .clk(clk),
        .reset(reset),
        .axi_awvalid(m_axi_mem_awvalid),
        .axi_awready(m_axi_mem_awready),
        .axi_awaddr(m_axi_mem_awaddr),
        .axi_awprot(m_axi_mem_awprot),
        .axi_wvalid(m_axi_mem_wvalid),
        .axi_wready(m_axi_mem_wready),
        .axi_wdata(m_axi_mem_wdata),
        .axi_wstrb(m_axi_mem_wstrb),
        .axi_bvalid(m_axi_mem_bvalid),
        .axi_bready(m_axi_mem_bready),
        .axi_arvalid(m_axi_mem_arvalid),
        .axi_arready(m_axi_mem_arready),
        .axi_araddr(m_axi_mem_araddr),
        .axi_arprot(m_axi_mem_arprot),
        .axi_rvalid(m_axi_mem_rvalid),
        .axi_rready(m_axi_mem_rready),
        .axi_rdata(m_axi_mem_rdata),
        .mem_valid(data_axi_request),
        .mem_instr(1'b0),
        .mem_addr(mem_physical_address),
        .mem_wdata(data_memory_write_data),
        .mem_wstrb(dcache_mem_wr),
        .mem_ready(axi_data_ready),
        .mem_rdata(axi_data_read_data)
    );

    assign m_axi_mem_awid = 4'd1;
    assign m_axi_mem_awlen = 8'd0;
    assign m_axi_mem_awburst = 2'b01;
    assign m_axi_mem_wlast = 1'b1;
    assign m_axi_mem_arid = 4'd1;
    assign m_axi_mem_arlen = 8'd0;
    assign m_axi_mem_arburst = 2'b01;

    ExceptionDetector exception_detector (
        .clk(clk),
        .reset(reset),
        .ID_opcode(opcode),
        .ID_funct3(funct3),
        .EX_opcode(EX_opcode),
        .EX_funct3(EX_funct3),
        .MEM_opcode(MEM_opcode),
        .MEM_funct3(MEM_funct3),
        .current_mode(current_mode),
        .raw_imm(raw_imm[11:0]),
        .EX_raw_imm(EX_raw_imm[11:0]),
        .csr_write_enable(cu_csr_write_enable),
        .alu_result(alu_result[1:0]), // for jump_target_lsbs and data_memory_address_lsbs
        .MEM_alu_result(MEM_alu_result[1:0]),
        .branch_target_lsbs(branch_target[1:0]),
        .branch_estimation(branch_estimation),
        
        .timer_interrupt_pending(timer_interrupt_pending),
        .external_interrupt_pending(external_interrupt_pending),

        .trapped(trapped_raw),
        .trap_status(trap_status_raw)
    );

    ForwardUnit forward_unit (
        .hazard_mem(hazard_mem),
        .hazard_wb(hazard_wb),
        .MEM_imm(MEM_imm),
        .MEM_alu_result(MEM_alu_result),
        .MEM_csr_read_data(MEM_csr_read_data),
        .byte_enable_logic_register_file_write_data(byte_enable_logic_register_file_write_data),
        .MEM_pc_plus_4(MEM_pc_plus_4),
        .MEM_opcode(MEM_opcode),
        .WB_opcode(WB_opcode),
        .WB_imm(WB_imm),
        .WB_alu_result(WB_alu_result),
        .WB_csr_read_data(WB_csr_read_data),
        .WB_byte_enable_logic_register_file_write_data(WB_byte_enable_logic_register_file_write_data),
        .WB_pc_plus_4(WB_pc_plus_4),
        .alu_forward_source_data_a(alu_forward_source_data_a),
        .alu_forward_source_data_b(alu_forward_source_data_b),
        .alu_forward_source_select_a(alu_forward_source_select_a),
        .alu_forward_source_select_b(alu_forward_source_select_b),

        .store_forward_data(store_forward_data),
        .store_forward_enable(store_forward_enable),

        .csr_hazard_mem(csr_hazard_mem),
        .csr_hazard_wb(csr_hazard_wb),
        .MEM_csr_write_data(MEM_alu_result),
        .WB_csr_write_data(WB_alu_result),
        .store_hazard_mem(store_hazard_mem),
        .store_hazard_wb(store_hazard_wb),
        .csr_read_data(csr_read_out),

        .csr_forward_data(csr_forward_data)
    );

    HazardUnit hazard_unit (
        .clk(clk),
        .reset(reset),
        .trap_done(trap_done),
        .standby_mode(standby_mode),
        .trap_status(trap_status),
        .misaligned_instruction_flush(misaligned_instruction_flush),
        .misaligned_memory_flush(misaligned_memory_flush),
        .pth_done_flush(pth_done_flush),
        .csr_ready(csr_ready),
        
        // AXI Handshake connect
        .if_valid(if_valid),
        .if_ready(if_pipeline_ready),
        .mem_valid(mem_valid),
        .mem_ready(mem_ready),

        .ID_rs1(rs1),
        .ID_rs2(rs2),
        .ID_raw_imm(raw_imm[11:0]),
        .ID_opcode(opcode),
        .EX_csr_write_enable(EX_csr_write_enable),
        .MEM_rd(MEM_rd),
        .MEM_opcode(MEM_opcode),
        .MEM_register_write_enable(MEM_register_write_enable),
        .MEM_csr_write_enable(MEM_csr_write_enable),
        .MEM_csr_write_address(MEM_raw_imm[11:0]),
        .WB_rd(WB_rd),
        .WB_register_write_enable(WB_register_write_enable),
        .WB_csr_write_enable(WB_csr_write_enable),
        .WB_csr_write_address(WB_raw_imm[11:0]),
        .EX_rs1(EX_rs1),
        .EX_rs2(EX_rs2),
        .EX_rd(EX_rd),
        .EX_opcode(EX_opcode),
        .EX_imm(EX_raw_imm[11:0]),
        .branch_prediction_miss(branch_miss_execute),
        .EX_jump(EX_jump_execute),
        .ID_jump(1'b0),

        .hazard_mem(hazard_mem),
        .hazard_wb(hazard_wb),
        .csr_hazard_mem(csr_hazard_mem),
        .csr_hazard_wb(csr_hazard_wb),
        //.csr_reg_hazard(csr_reg_hazard),
        .store_hazard_mem(store_hazard_mem),
        .store_hazard_wb(store_hazard_wb),

        .IF_ID_flush(IF_ID_flush),
        .ID_EX_flush(ID_EX_flush),
        .EX_MEM_flush(EX_MEM_flush),
        .MEM_WB_flush(MEM_WB_flush),
        .IF_ID_stall(IF_ID_stall),
        .ID_EX_stall(ID_EX_stall),
        .EX_MEM_stall(EX_MEM_stall),
        .MEM_WB_stall(MEM_WB_stall)
    );

    ImmediateGenerator immediate_generator (
        .raw_imm(raw_imm),
        .opcode(opcode),
        .imm(imm)
    );

    InstructionDecoder instruction_decoder (
        .instruction(ID_instruction),
        .opcode(opcode),
	    .funct3(funct3),
	    .funct7(funct7),
	    .rs1(rs1),
	    .rs2(rs2),
	    .rd(rd),
	    .raw_imm(raw_imm)
    );

    // 【已拆除旧版 InstructionMemory 和 RV32_AXI_Adapter】
    // 替换为 ultraembedded 提供的 ICache 模块
    icache #(
        .AXI_ID(0)
    ) icache_inst (
        .clk_i(clk),
        .rst_i(reset),
        
        // --- CPU 侧接口 ---
        .req_rd_i(if_request_issue),
        .req_flush_i(1'b0),
        .req_invalidate_i(1'b0),
        .req_pc_i(if_physical_address), // 使用 next_pc 经过 MMU 映射后的地址
        .req_accept_o(if_accept), // 暂不使用，CPU 会一直保持 valid 直到 ready
        .req_valid_o(if_ready),
        .req_error_o(), // 暂不处理取指错误异常
        .req_inst_o(im_instruction),
        .req_pc_o(if_response_pc),

        // --- AXI4 侧接口 ---
        .axi_awvalid_o(m_axi_if_awvalid),
        .axi_awready_i(m_axi_if_awready),
        .axi_awaddr_o(m_axi_if_awaddr),
        .axi_awid_o(m_axi_if_awid),
        .axi_awlen_o(m_axi_if_awlen),
        .axi_awburst_o(m_axi_if_awburst),
        .axi_wvalid_o(m_axi_if_wvalid),
        .axi_wready_i(m_axi_if_wready),
        .axi_wdata_o(m_axi_if_wdata),
        .axi_wstrb_o(m_axi_if_wstrb),
        .axi_wlast_o(m_axi_if_wlast),
        .axi_bvalid_i(m_axi_if_bvalid),
        .axi_bready_o(m_axi_if_bready),
        .axi_bresp_i(m_axi_if_bresp),
        .axi_bid_i(m_axi_if_bid),
        
        .axi_arvalid_o(m_axi_if_arvalid),
        .axi_arready_i(m_axi_if_arready),
        .axi_araddr_o(m_axi_if_araddr),
        .axi_arid_o(m_axi_if_arid),
        .axi_arlen_o(m_axi_if_arlen),
        .axi_arburst_o(m_axi_if_arburst),
        .axi_rvalid_i(m_axi_if_rvalid),
        .axi_rready_o(m_axi_if_rready),
        .axi_rdata_i(m_axi_if_rdata),
        .axi_rresp_i(m_axi_if_rresp),
        .axi_rid_i(m_axi_if_rid),
        .axi_rlast_i(m_axi_if_rlast)
    );

    // ICache 不输出 prot 信号，我们手动补齐 AXI4 协议要求的保护类型信号 (100 表示指令读取)
    assign m_axi_if_arprot = 3'b100;
    assign m_axi_if_awprot = 3'b000;

    reg mmio_write_pending;
    wire mmio_write_fire = MEM_memory_write && mmio_uart_status_hit &&
                           mmio_access_ready && !mmio_write_pending;

    always @(posedge clk or posedge reset) begin
        if (reset)
            mmio_write_pending <= 1'b0;
        else if (mmio_write_fire)
            mmio_write_pending <= EX_MEM_stall;
        else if (!MEM_memory_write || !mmio_uart_status_hit || !EX_MEM_stall)
            mmio_write_pending <= 1'b0;
    end

    MMIO_Interface mmio_interface (
        .clk(clk),
        .reset(reset),
        .data_memory_write_data(data_memory_write_data),
        .data_memory_address(mem_physical_address),
        .data_memory_write_enable(mmio_write_fire),
        .UART_busy(UART_busy),

        .mmio_uart_tx_data(mmio_uart_tx_data),
        .mmio_uart_status(mmio_uart_status),
        .mmio_uart_tx_start(mmio_uart_tx_start),
        .mmio_uart_status_hit(mmio_uart_status_hit),
        .mmio_led(mmio_led)
    );

    ProgramCounter program_counter (
        .clk(clk),
        .reset(reset),
        .next_pc(next_pc),
        .pc(pc)
    );

    PCPlus4 pc_plus_4 (
        .pc(pc),
        .pc_plus_4(pc_plus_4_signal)
    );

    PCController pc_controller (
        .jump(EX_jump_execute),
        .ID_jump(1'b0),
        .ID_jump_target(ID_jump_target), // ✅ 连接ID阶段跳转目标
        .branch_estimation(branch_estimation),
        .branch_prediction_miss(branch_miss_execute),
        .trapped(trapped),
	    .pc(pc),
        .jump_target(alu_result),
        .branch_target(branch_target),
        .branch_target_actual(branch_target_actual),
        .trap_target(trap_target),
        .pc_stall(pc_stall),
        .trap_jump(trap_jump),
	    .next_pc(next_pc)
    );

    RegisterFile register_file (
        .clk(clk),
        .read_reg1(rs1),
        .read_reg2(rs2),
        .write_reg(WB_rd),
        .write_data(register_file_write_data),
        .write_enable(WB_register_write_enable),
	
        .read_data1(read_data1),
        .read_data2(read_data2)
    );

    TrapController #(
        .XLEN(XLEN)
    ) trap_controller(
        .clk(clk),
        .reset(reset),
        .current_pc(pc),
        .trap_status(trap_status),
        .trap_value(trap_value),
        .ID_pc(ID_pc),
        .EX_pc(EX_pc),
        .MEM_pc(MEM_pc),
        .WB_pc(WB_pc),
        .csr_read_data(csr_read_out),
        .current_mode(current_mode),
        .medeleg(medeleg),
        .mideleg(mideleg),

        .debug_mode(debug_mode),
        .trap_target(trap_target),
        .trap_done(trap_done),
        .trap_jump(trap_jump),
        .misaligned_instruction_flush(misaligned_instruction_flush),
        .misaligned_memory_flush(misaligned_memory_flush),
        .pth_done_flush(pth_done_flush),
        .standby_mode(standby_mode),
        .csr_write_enable(tc_csr_write_enable),
        .csr_trap_address(csr_trap_address),
        .csr_trap_write_data(csr_trap_write_data)
    );


    IF_ID_Register #(.XLEN(XLEN)) if_id_register (
        .clk(clk),
		.reset(reset),
        .flush(IF_ID_flush),
        .IF_ID_stall(IF_ID_stall),

        // Signals from IF Phase
        .IF_pc(if_response_pc),
        .IF_pc_plus_4(if_response_pc + 32'd4),
        .IF_instruction(instruction),
        .IF_branch_estimation(branch_estimation),

        // Signals to ID_EX_Register and ID Phase
        .ID_pc(ID_pc),
        .ID_pc_plus_4(ID_pc_plus_4),
        .ID_instruction(ID_instruction),
        .ID_branch_estimation(ID_branch_estimation)
    );

    ID_EX_Register #(.XLEN(XLEN)) id_ex_register (
        .clk(clk),
		.reset(reset),
        .flush(ID_EX_flush),
        .ID_EX_stall(ID_EX_stall),
        
        // Signals from IF_ID_Register
        .ID_pc(ID_pc),
        .ID_pc_plus_4(ID_pc_plus_4),
        .ID_branch_estimation(ID_branch_estimation),
        .ID_instruction(ID_instruction),

        // Signals from ID Phase
        .ID_jump(jump),
        .ID_branch(branch),
        .ID_alu_src_A_select(alu_src_A_select),
        .ID_alu_src_B_select(alu_src_B_select),
        .ID_memory_read(memory_read),
        .ID_memory_write(memory_write),
        .ID_register_file_write_data_select(register_file_write_data_select),
        .ID_register_write_enable(register_file_write),
        .ID_csr_write_enable(id_csr_write_enable),
        .ID_opcode(opcode), 
        .ID_funct3(funct3),
        .ID_funct7(funct7),
        .ID_rd(rd),
        .ID_raw_imm(raw_imm),
        .ID_read_data1(read_data1),
        .ID_read_data2(read_data2),
        .ID_rs1(rs1),
        .ID_rs2(rs2),
        .ID_imm(imm),
        .ID_csr_read_data(csr_read_out),

        // Signals to EX_MEM_Register
        .EX_pc(EX_pc),
        .EX_pc_plus_4(EX_pc_plus_4),
        .EX_branch_estimation(EX_branch_estimation),
        .EX_instruction(EX_instruction),

        .EX_jump(EX_jump),
        .EX_branch(EX_branch),
        .EX_alu_src_A_select(EX_alu_src_A_select),
        .EX_alu_src_B_select(EX_alu_src_B_select),
        .EX_memory_read(EX_memory_read),
        .EX_memory_write(EX_memory_write),
        .EX_register_file_write_data_select(EX_register_file_write_data_select),
        .EX_register_write_enable(EX_register_write_enable),
        .EX_csr_write_enable(EX_csr_write_enable),
        .EX_opcode(EX_opcode),
        .EX_funct3(EX_funct3),
        .EX_funct7(EX_funct7),
        .EX_rd(EX_rd),
        .EX_raw_imm(EX_raw_imm),
        .EX_read_data1(EX_read_data1),
        .EX_read_data2(EX_read_data2),
        .EX_rs1(EX_rs1),
        .EX_rs2(EX_rs2),
        .EX_imm(EX_imm),
        .EX_csr_read_data(EX_csr_read_data)
    );

    EX_MEM_Register #(.XLEN(XLEN)) ex_mem_register (
        .clk(clk),
		.reset(reset),
        .flush(EX_MEM_flush),
        .EX_MEM_stall(EX_MEM_stall),

        // Signals from ID_EX_Register
        .EX_pc(EX_pc),
        .EX_pc_plus_4(EX_pc_plus_4),
        .EX_instruction(EX_instruction),

        .EX_memory_read(EX_memory_read),
        .EX_memory_write(EX_memory_write),
        .EX_register_file_write_data_select(EX_register_file_write_data_select),
        .EX_register_write_enable(EX_register_write_enable),
        .EX_csr_write_enable(EX_csr_write_enable),
        .EX_opcode(EX_opcode),
        .EX_funct3(EX_funct3),
        .EX_rs1(EX_rs1),
        .EX_rd(EX_rd),
        .EX_raw_imm(EX_raw_imm),
        .EX_read_data2(EX_read_data2_MUX),
        .EX_imm(EX_imm),
        .EX_csr_read_data(EX_csr_read_data),

        // Signal from EX Phase
        .EX_alu_result(final_ex_result),

        // Signals to MEM_WB_Register
        .MEM_pc(MEM_pc),
        .MEM_pc_plus_4(MEM_pc_plus_4),
        .MEM_instruction(MEM_instruction),
        .MEM_memory_read(MEM_memory_read),
        .MEM_memory_write(MEM_memory_write),
        .MEM_register_file_write_data_select(MEM_register_file_write_data_select),
        .MEM_register_write_enable(MEM_register_write_enable),
        .MEM_csr_write_enable(MEM_csr_write_enable),
        .MEM_opcode(MEM_opcode),
        .MEM_funct3(MEM_funct3),
        .MEM_rs1(MEM_rs1),
        .MEM_rd(MEM_rd),
        .MEM_raw_imm(MEM_raw_imm),
        .MEM_read_data2(MEM_read_data2),
        .MEM_imm(MEM_imm),
        .MEM_csr_read_data(MEM_csr_read_data),
        .MEM_alu_result(MEM_alu_result)
    );

    MEM_WB_Register #(.XLEN(XLEN)) mem_wb_register (
        .clk(clk),
		.reset(reset),
        .MEM_WB_stall(MEM_WB_stall),
        .flush(MEM_WB_flush),

        // Signals from EX_MEM_Register
        .MEM_pc(MEM_pc),
        .MEM_pc_plus_4(MEM_pc_plus_4),
        .MEM_instruction(MEM_instruction),

        .MEM_register_file_write_data_select(MEM_register_file_write_data_select),
        .MEM_imm(MEM_imm),
        .MEM_csr_read_data(MEM_csr_read_data),
        .MEM_alu_result(MEM_alu_result),
        .MEM_register_write_enable(MEM_register_write_enable),
        .MEM_csr_write_enable(MEM_csr_write_enable),
        .MEM_rs1(MEM_rs1),
        .MEM_rd(MEM_rd),
        .MEM_raw_imm(MEM_raw_imm),
        .MEM_opcode(MEM_opcode),

        // Signal from MEM Phase
        .MEM_byte_enable_logic_register_file_write_data(byte_enable_logic_register_file_write_data),

        // Signals to WB Phase
        .WB_pc(WB_pc),
        .WB_pc_plus_4(WB_pc_plus_4),
        .WB_instruction(WB_instruction),
        .WB_register_file_write_data_select(WB_register_file_write_data_select),
        .WB_imm(WB_imm),
        .WB_csr_read_data(WB_csr_read_data),
        .WB_alu_result(WB_alu_result),
        .WB_register_write_enable(WB_register_write_enable),
        .WB_csr_write_enable(WB_csr_write_enable),
        .WB_rs1(WB_rs1),
        .WB_rd(WB_rd),
        .WB_raw_imm(WB_raw_imm),
        .WB_opcode(WB_opcode),
        .WB_byte_enable_logic_register_file_write_data(WB_byte_enable_logic_register_file_write_data)
    );

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            retired_alu_result <= {XLEN{1'b0}};
            retired_csr_read_data <= {XLEN{1'b0}};

            instruction_retired <= 1'b0;
        end else begin
            retired_alu_result <= WB_alu_result;
            retired_csr_read_data <= WB_csr_read_data;

            if (!MEM_WB_stall && !MEM_WB_flush && 
                WB_instruction != 32'h00000013) begin
                instruction_retired <= 1'b1;
            end else begin
                instruction_retired <= 1'b0;
            end
        end
    end

    always @(*) begin
        if (EX_alu_src_A_select == `ALU_SRC_A_RD1) begin
            alu_normal_source_a = EX_read_data1;
        end
        else if (EX_alu_src_A_select == `ALU_SRC_A_PC) begin
            alu_normal_source_a = EX_pc;
        end
        else if (EX_alu_src_A_select == `ALU_SRC_A_RS1) begin
            alu_normal_source_a = {27'b0, EX_rs1};
        end
        else begin
            alu_normal_source_a = 32'b0;
        end

        if (EX_alu_src_B_select == `ALU_SRC_B_RD2) begin
            alu_normal_source_b = EX_read_data2;
        end
        else if (EX_alu_src_B_select == `ALU_SRC_B_IMM) begin
            alu_normal_source_b = EX_imm;
        end
        else if (EX_alu_src_B_select == `ALU_SRC_B_SHAMT) begin
            alu_normal_source_b = {27'b0, EX_imm[4:0]};
        end
        else if (EX_alu_src_B_select == `ALU_SRC_B_CSR) begin
            alu_normal_source_b = csr_forward_data;
        end
        else begin
            alu_normal_source_b = 32'b0;
        end

        if (trap_controller_owns_csr) begin
            csr_write_data  = csr_trap_write_data;
            csr_write_address = csr_trap_address;
            csr_read_address = csr_trap_address;
        end
        else begin
            csr_write_data = WB_alu_result;
            csr_write_address = WB_raw_imm[11:0];
            csr_read_address = raw_imm[11:0];

        end

        if (debug_mode) instruction = dbg_instruction;
        else instruction = im_instruction;

        case (WB_register_file_write_data_select)
            `RF_WD_LOAD: begin
                register_file_write_data = WB_byte_enable_logic_register_file_write_data;
            end
            `RF_WD_ALU: begin
                register_file_write_data = WB_alu_result;
            end
            `RF_WD_LUI: begin
                register_file_write_data = WB_imm;
            end
            `RF_WD_JUMP: begin
                register_file_write_data = WB_pc_plus_4;
            end
            `RF_WD_CSR: begin
                /*if (csr_reg_hazard) begin
                    register_file_write_data = retired_alu_result;
                end else */begin
                    register_file_write_data = WB_csr_read_data; 
                end
            end
            default: begin
                register_file_write_data = 32'b0;
            end
        endcase

        case (alu_forward_source_select_a)
            2'b10: src_A = alu_forward_source_data_a;
            2'b11: src_A = alu_forward_source_data_a;
            default: src_A = alu_normal_source_a;
        endcase

        case (alu_forward_source_select_b)
            2'b10: src_B = alu_forward_source_data_b;
            2'b11: src_B = alu_forward_source_data_b;
            default: src_B = alu_normal_source_b;
        endcase
    end

endmodule
