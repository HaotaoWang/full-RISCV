`include "modules/headers/opcode.vh"
`include "modules/headers/trap.vh"

module HazardUnit (
    input clk,
    input reset, 

    input wire trap_done,
    input wire csr_ready,
    input wire standby_mode,
    input wire [3:0] trap_status,
    input wire misaligned_instruction_flush,
    input wire misaligned_memory_flush,
    input wire pth_done_flush,

    // AXI Memory Interface Handshake Signals
    input wire if_valid,
    input wire if_ready,
    input wire mem_valid,
    input wire mem_ready,

    input wire [4:0] ID_rs1,
    input wire [4:0] ID_rs2,
    input wire [11:0] ID_raw_imm,
    input wire [6:0] ID_opcode,        // 新增：用于检测 JALR Load-Use 冒险

    input wire [4:0] MEM_rd,
    input wire [6:0] MEM_opcode,       // 新增：用于检测 MEM 阶段的 Load 指令
    input wire MEM_register_write_enable,
    input wire MEM_csr_write_enable,
    input wire [11:0] MEM_csr_write_address,       // MEM_imm[11:0]

    input wire [4:0] WB_rd,
    input wire WB_register_write_enable,
    input wire WB_csr_write_enable,
    input wire [11:0] WB_csr_write_address, // WB_imm[11:0]

    input wire [4:0] EX_rd,
    input wire [6:0] EX_opcode,
    input wire [4:0] EX_rs1,
    input wire [4:0] EX_rs2,
    input wire [11:0] EX_imm,  // EX_imm[11:0]

    input wire EX_csr_write_enable,

    input wire EX_jump,
    input wire ID_jump,  // 新增：ID 阶段的跳转信�?
    input wire branch_prediction_miss,

    // to Forward Unit - ALU forwarding
    output reg [1:0] hazard_mem,
    output reg [1:0] hazard_wb,
    output wire csr_hazard_mem,
    output wire csr_hazard_wb,
    //output reg csr_reg_hazard,

    /// to Forward Unit - Store data forwarding
    output wire store_hazard_mem,
    output wire store_hazard_wb,

    output reg IF_ID_flush,
    output reg ID_EX_flush,
    output reg EX_MEM_flush,
    output reg MEM_WB_flush,
    
    output reg IF_ID_stall,
    output reg ID_EX_stall,
    output reg EX_MEM_stall,
    output reg MEM_WB_stall
);

    // Store instruction detection
    wire is_store = (EX_opcode == `OPCODE_STORE);

    // Register ALU hazard detections
    wire mem_hazard_rs1 = MEM_register_write_enable && (MEM_rd != 5'd0) && (MEM_rd == EX_rs1);
    wire mem_hazard_rs2 = MEM_register_write_enable && (MEM_rd != 5'd0) && (MEM_rd == EX_rs2);
    wire wb_hazard_rs1 = WB_register_write_enable && (WB_rd != 5'd0) && (WB_rd == EX_rs1);
    wire wb_hazard_rs2 = WB_register_write_enable && (WB_rd != 5'd0) && (WB_rd == EX_rs2);

    // Store instruction rs2 hazard detections
    assign store_hazard_mem = is_store && mem_hazard_rs2;
    assign store_hazard_wb = is_store && wb_hazard_rs2 && !mem_hazard_rs2;

    // Load-Use hazard detection (for normal instructions in EX stage)
    wire load_use_hazard = (EX_opcode == `OPCODE_LOAD) && (EX_rd != 5'd0) && ((EX_rd == ID_rs1) || (EX_rd == ID_rs2));

    // ========================================================================
    // JALR Load-Use 冒险检测
    // ========================================================================
    // JALR 在 ID 阶段就需要读取 rs1 来计算跳转目标，但如果 EX 或 MEM 阶段的
    // Load 指令正在写入 rs1，数据还没准备好，需要插入 stall
    //
    // 检测条件：
    // 1. ID 阶段是 JALR 指令
    // 2. rs1 不是 x0（x0 恒为 0，不会有冒险）
    // 3. EX 阶段的 Load 指令目标是 rs1，或
    // 4. MEM 阶段的 Load 指令目标是 rs1
    wire jalr_load_use_hazard = (ID_opcode == `OPCODE_JALR) && (ID_rs1 != 5'd0) &&
                                 (((EX_opcode == `OPCODE_LOAD) && (EX_rd == ID_rs1)) ||
                                  ((MEM_opcode == `OPCODE_LOAD) && (MEM_rd == ID_rs1)));

    // CSR hazard detection
    assign csr_hazard_mem = MEM_csr_write_enable && (MEM_csr_write_address == EX_imm);
    assign csr_hazard_wb = WB_csr_write_enable && (WB_csr_write_address == EX_imm);

    reg [4:0] retire_rd;
    reg [11:0] retire_csr_write_address;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            retire_rd <= 5'b0;
            retire_csr_write_address <= 12'b0;    
        end else begin
            retire_rd <= WB_rd;
            retire_csr_write_address <= WB_csr_write_address;
        end
        
    end 

    always @(*) begin
        // default status
        hazard_mem = 2'b00;
        hazard_wb = 2'b00;
        IF_ID_flush = 1'b0;
        ID_EX_flush = 1'b0;
        EX_MEM_flush = 1'b0;
        MEM_WB_flush = 1'b0;
        
        IF_ID_stall = 1'b0;
        ID_EX_stall = 1'b0;
        EX_MEM_stall = 1'b0;
        MEM_WB_stall = 1'b0;

        // ALU forwarding hazards
        hazard_mem[0] = mem_hazard_rs1;
        hazard_mem[1] = is_store ? 1'b0 : mem_hazard_rs2;
        hazard_wb[0] = wb_hazard_rs1 && !mem_hazard_rs1;
        hazard_wb[1] = is_store ? 1'b0 : (wb_hazard_rs2 && !mem_hazard_rs2);

        // ==========================================
        // 1. Stall Logic
        // ==========================================
        if (standby_mode) begin
            // Freeze fetch/decode and replace the trapped ID instruction with
            // a bubble while older EX/MEM/WB work drains exactly once.  This
            // is essential for the addi sp,sp,128 immediately before mret.
            IF_ID_stall = 1'b1;
            ID_EX_flush = 1'b1;
            EX_MEM_stall = 1'b0;
            MEM_WB_stall = 1'b0;
        end else if (!trap_done || !csr_ready) begin
            IF_ID_stall = 1'b1;
            ID_EX_stall = 1'b1;
            EX_MEM_stall = 1'b1;
            MEM_WB_stall = 1'b1;
        end else if (mem_valid && !mem_ready) begin
            // Data memory is busy, freeze everything
            IF_ID_stall = 1'b1;
            ID_EX_stall = 1'b1;
            EX_MEM_stall = 1'b1;
            MEM_WB_stall = 1'b1;
        end else if (jalr_load_use_hazard) begin
            // JALR Load-Use Hazard
            IF_ID_stall = 1'b1;
            ID_EX_flush = 1'b1;
        end else if (load_use_hazard) begin
            // Load-Use Hazard
            IF_ID_stall = 1'b1;
            ID_EX_flush = 1'b1;
        end else if (if_valid && !if_ready && !ID_jump) begin
            // Freeze the front end while instruction memory is busy.  On an
            // EX redirect the control-flow instruction must still advance to
            // MEM/WB; otherwise ID_EX_flush would discard the JAL before it
            // can write PC+4 into rd.
            IF_ID_stall = 1'b1;
            ID_EX_stall = 1'b1;
            EX_MEM_stall = !(EX_jump || branch_prediction_miss);
            MEM_WB_stall = !(EX_jump || branch_prediction_miss);
        end

        // ==========================================
        // 2. Flush Logic
        // ==========================================
        if (pth_done_flush) begin
            IF_ID_flush = 1'b1;
            ID_EX_flush = 1'b1;
            EX_MEM_flush = 1'b1;
            MEM_WB_flush = 1'b1;
        end
        else if (trap_done && (branch_prediction_miss || EX_jump)) begin
            IF_ID_flush = 1'b1;
            ID_EX_flush = 1'b1;
        end
        else if (trap_done && ID_jump && !IF_ID_stall) begin
            // ID jump (JAL/JALR)
            IF_ID_flush = 1'b1;
        end
    end
endmodule
