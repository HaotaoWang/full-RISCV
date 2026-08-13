# Verilog Block Overview: RV32_SoC_AXI_Top

- 解析模式: regex
- 模块数量: 64
- 可达模块数量: 26
- 顶层模块: RV32_SoC_AXI_Top

## 提示
- Pyverilog 解析失败，已回退到正则扫描：'gbk' codec can't decode byte 0xa2 in position 240: illegal multibyte sequence
- 重复模块名 ALU：D:\riscv\basic_rv32s\fpga\RV32I46F5SP_Dhrystone\RV32I46F5SP_Dhrystone.srcs\sources_1\imports\Dhry_Demo_source\ALU.v 与 D:\riscv\basic_rv32s\fpga\RV32I46F5SP_MMIO_Dhrystone\RV32I46F5SP_MMIO_Dhrystone.srcs\sources_1\imports\sources\ALU.v
- 重复模块名 ALUController：D:\riscv\basic_rv32s\fpga\RV32I46F5SP_Dhrystone\RV32I46F5SP_Dhrystone.srcs\sources_1\imports\Dhry_Demo_source\ALU_Controller.v 与 D:\riscv\basic_rv32s\fpga\RV32I46F5SP_MMIO_Dhrystone\RV32I46F5SP_MMIO_Dhrystone.srcs\sources_1\imports\sources\ALU_Controller.v
- 重复模块名 BranchLogic：D:\riscv\basic_rv32s\fpga\RV32I46F5SP_Dhrystone\RV32I46F5SP_Dhrystone.srcs\sources_1\imports\Dhry_Demo_source\Branch_Logic.v 与 D:\riscv\basic_rv32s\fpga\RV32I46F5SP_MMIO_Dhrystone\RV32I46F5SP_MMIO_Dhrystone.srcs\sources_1\imports\sources\Branch_Logic.v
- 重复模块名 BranchPredictor：D:\riscv\basic_rv32s\fpga\RV32I46F5SP_Dhrystone\RV32I46F5SP_Dhrystone.srcs\sources_1\imports\Dhry_Demo_source\Branch_Predictor.v 与 D:\riscv\basic_rv32s\fpga\RV32I46F5SP_MMIO_Dhrystone\RV32I46F5SP_MMIO_Dhrystone.srcs\sources_1\imports\sources\Branch_Predictor.v
- 重复模块名 ByteEnableLogic：D:\riscv\basic_rv32s\fpga\RV32I46F5SP_Dhrystone\RV32I46F5SP_Dhrystone.srcs\sources_1\imports\Dhry_Demo_source\Byte_Enable_Logic.v 与 D:\riscv\basic_rv32s\fpga\RV32I46F5SP_MMIO_Dhrystone\RV32I46F5SP_MMIO_Dhrystone.srcs\sources_1\imports\sources\Byte_Enable_Logic.v
- 重复模块名 ControlUnit：D:\riscv\basic_rv32s\fpga\RV32I46F5SP_Dhrystone\RV32I46F5SP_Dhrystone.srcs\sources_1\imports\Dhry_Demo_source\Control_Unit.v 与 D:\riscv\basic_rv32s\fpga\RV32I46F5SP_MMIO_Dhrystone\RV32I46F5SP_MMIO_Dhrystone.srcs\sources_1\imports\sources\Control_Unit.v
- 重复模块名 CSRFile：D:\riscv\basic_rv32s\fpga\RV32I46F5SP_Dhrystone\RV32I46F5SP_Dhrystone.srcs\sources_1\imports\Dhry_Demo_source\CSR_File.v 与 D:\riscv\basic_rv32s\fpga\RV32I46F5SP_MMIO_Dhrystone\RV32I46F5SP_MMIO_Dhrystone.srcs\sources_1\imports\sources\CSR_File.v
- 重复模块名 DataMemory：D:\riscv\basic_rv32s\fpga\RV32I46F5SP_Dhrystone\RV32I46F5SP_Dhrystone.srcs\sources_1\imports\Dhry_Demo_source\Data_Memory.v 与 D:\riscv\basic_rv32s\fpga\RV32I46F5SP_MMIO_Dhrystone\RV32I46F5SP_MMIO_Dhrystone.srcs\sources_1\imports\sources\Data_Memory.v
- 重复模块名 EX_MEM_Register：D:\riscv\basic_rv32s\fpga\RV32I46F5SP_Dhrystone\RV32I46F5SP_Dhrystone.srcs\sources_1\imports\Dhry_Demo_source\EX_MEM_Register.v 与 D:\riscv\basic_rv32s\fpga\RV32I46F5SP_MMIO_Dhrystone\RV32I46F5SP_MMIO_Dhrystone.srcs\sources_1\imports\sources\EX_MEM_Register.v
- 重复模块名 ExceptionDetector：D:\riscv\basic_rv32s\fpga\RV32I46F5SP_Dhrystone\RV32I46F5SP_Dhrystone.srcs\sources_1\imports\Dhry_Demo_source\Exception_Detector.v 与 D:\riscv\basic_rv32s\fpga\RV32I46F5SP_MMIO_Dhrystone\RV32I46F5SP_MMIO_Dhrystone.srcs\sources_1\imports\sources\Exception_Detector.v
- 重复模块名 ForwardUnit：D:\riscv\basic_rv32s\fpga\RV32I46F5SP_Dhrystone\RV32I46F5SP_Dhrystone.srcs\sources_1\imports\Dhry_Demo_source\Forward_Unit.v 与 D:\riscv\basic_rv32s\fpga\RV32I46F5SP_MMIO_Dhrystone\RV32I46F5SP_MMIO_Dhrystone.srcs\sources_1\imports\sources\Forward_Unit.v
- 重复模块名 HazardUnit：D:\riscv\basic_rv32s\fpga\RV32I46F5SP_Dhrystone\RV32I46F5SP_Dhrystone.srcs\sources_1\imports\Dhry_Demo_source\Hazard_Unit.v 与 D:\riscv\basic_rv32s\fpga\RV32I46F5SP_MMIO_Dhrystone\RV32I46F5SP_MMIO_Dhrystone.srcs\sources_1\imports\sources\Hazard_Unit.v
- 重复模块名 ID_EX_Register：D:\riscv\basic_rv32s\fpga\RV32I46F5SP_Dhrystone\RV32I46F5SP_Dhrystone.srcs\sources_1\imports\Dhry_Demo_source\ID_EX_Register.v 与 D:\riscv\basic_rv32s\fpga\RV32I46F5SP_MMIO_Dhrystone\RV32I46F5SP_MMIO_Dhrystone.srcs\sources_1\imports\sources\ID_EX_Register.v
- 重复模块名 IF_ID_Register：D:\riscv\basic_rv32s\fpga\RV32I46F5SP_Dhrystone\RV32I46F5SP_Dhrystone.srcs\sources_1\imports\Dhry_Demo_source\IF_ID_Register.v 与 D:\riscv\basic_rv32s\fpga\RV32I46F5SP_MMIO_Dhrystone\RV32I46F5SP_MMIO_Dhrystone.srcs\sources_1\imports\sources\IF_ID_Register.v
- 重复模块名 ImmediateGenerator：D:\riscv\basic_rv32s\fpga\RV32I46F5SP_Dhrystone\RV32I46F5SP_Dhrystone.srcs\sources_1\imports\Dhry_Demo_source\Immediate_Generator.v 与 D:\riscv\basic_rv32s\fpga\RV32I46F5SP_MMIO_Dhrystone\RV32I46F5SP_MMIO_Dhrystone.srcs\sources_1\imports\sources\Immediate_Generator.v
- 重复模块名 InstructionDecoder：D:\riscv\basic_rv32s\fpga\RV32I46F5SP_Dhrystone\RV32I46F5SP_Dhrystone.srcs\sources_1\imports\Dhry_Demo_source\Instruction_Decoder.v 与 D:\riscv\basic_rv32s\fpga\RV32I46F5SP_MMIO_Dhrystone\RV32I46F5SP_MMIO_Dhrystone.srcs\sources_1\imports\sources\Instruction_Decoder.v
- 重复模块名 InstructionMemory：D:\riscv\basic_rv32s\fpga\RV32I46F5SP_Dhrystone\RV32I46F5SP_Dhrystone.srcs\sources_1\imports\Dhry_Demo_source\Instruction_Memory.v 与 D:\riscv\basic_rv32s\fpga\RV32I46F5SP_MMIO_Dhrystone\RV32I46F5SP_MMIO_Dhrystone.srcs\sources_1\imports\sources\Instruction_Memory.v
- 重复模块名 MEM_WB_Register：D:\riscv\basic_rv32s\fpga\RV32I46F5SP_Dhrystone\RV32I46F5SP_Dhrystone.srcs\sources_1\imports\Dhry_Demo_source\MEM_WB_Register.v 与 D:\riscv\basic_rv32s\fpga\RV32I46F5SP_MMIO_Dhrystone\RV32I46F5SP_MMIO_Dhrystone.srcs\sources_1\imports\sources\MEM_WB_Register.v
- 重复模块名 PCController：D:\riscv\basic_rv32s\fpga\RV32I46F5SP_Dhrystone\RV32I46F5SP_Dhrystone.srcs\sources_1\imports\Dhry_Demo_source\PC_Controller.v 与 D:\riscv\basic_rv32s\fpga\RV32I46F5SP_MMIO_Dhrystone\RV32I46F5SP_MMIO_Dhrystone.srcs\sources_1\imports\sources\PC_Controller.v

## 模块清单
### ALU
- 文件: D:\riscv\basic_rv32s\modules\ALU.v
- 层级深度: 0
- 输入: src_A, src_B, alu_op
- 输出: alu_result, alu_zero
- 实例: -

### ALUController
- 文件: D:\riscv\basic_rv32s\modules\ALU_Controller.v
- 层级深度: 0
- 输入: opcode, funct3, funct7_5, imm_10
- 输出: alu_op
- 实例: -

### BranchLogic
- 文件: D:\riscv\basic_rv32s\modules\Branch_Logic.v
- 层级深度: 0
- 输入: branch, branch_estimation, alu_zero, funct3, pc, imm
- 输出: branch_taken, branch_target_actual, branch_prediction_miss
- 实例: -

### BranchPredictor
- 文件: D:\riscv\basic_rv32s\modules\Branch_Predictor.v
- 层级深度: 0
- 输入: clk, reset, IF_opcode, IF_pc, IF_imm, EX_branch, EX_branch_taken
- 输出: branch_estimation, branch_target
- 实例: end(if)

### ByteEnableLogic
- 文件: D:\riscv\basic_rv32s\modules\Byte_Enable_Logic.v
- 层级深度: 0
- 输入: memory_read, memory_write, funct3, register_file_read_data, data_memory_read_data, address
- 输出: register_file_write_data, data_memory_write_data, write_mask
- 实例: endcase(if), endcase(if), else(if)

### CSRFile
- 文件: D:\riscv\basic_rv32s\modules\CSR_File.v
- 层级深度: 0
- 输入: clk, reset, trapped, csr_write_enable, csr_read_address, csr_write_address, csr_write_data, instruction_retired, timer_irq, external_irq
- 输出: csr_read_out, csr_ready, current_mode, medeleg_out, mideleg_out, satp_out, mstatus_out, timer_interrupt_pending, external_interrupt_pending, tlb_wvpn, tlb_wpte, itlb_we, dtlb_we
- 实例: endcase(if), end(if)

### ControlUnit
- 文件: D:\riscv\basic_rv32s\modules\Control_Unit.v
- 层级深度: 0
- 输入: write_done, trap_done, csr_ready, IF_ID_stall, trap_jump, opcode, funct3
- 输出: jump, branch, alu_src_A_select, alu_src_B_select, csr_write_enable, register_file_write, register_file_write_data_select, memory_read, memory_write, pc_stall
- 实例: end(if)

### EX_MEM_Register
- 文件: D:\riscv\basic_rv32s\modules\EX_MEM_Register.v
- 层级深度: 0
- 输入: clk, reset, flush, EX_MEM_stall, EX_pc, EX_pc_plus_4, EX_instruction, EX_memory_read, EX_memory_write, EX_register_file_write_data_select, EX_register_write_enable, EX_csr_write_enable, EX_opcode, EX_funct3, EX_rs1, EX_rd, EX_read_data2, EX_imm, EX_raw_imm, EX_csr_read_data, EX_alu_result
- 输出: MEM_pc, MEM_pc_plus_4, MEM_instruction, MEM_memory_read, MEM_memory_write, MEM_register_file_write_data_select, MEM_register_write_enable, MEM_csr_write_enable, MEM_opcode, MEM_funct3, MEM_rs1, MEM_rd, MEM_read_data2, MEM_imm, MEM_raw_imm, MEM_csr_read_data, MEM_alu_result
- 实例: -

### ExceptionDetector
- 文件: D:\riscv\basic_rv32s\modules\Exception_Detector.v
- 层级深度: 0
- 输入: clk, reset, ID_opcode, EX_opcode, MEM_opcode, ID_funct3, EX_funct3, MEM_funct3, current_mode, alu_result, MEM_alu_result, raw_imm, EX_raw_imm, csr_write_enable, branch_target_lsbs, branch_estimation, timer_interrupt_pending, external_interrupt_pending
- 输出: trapped, trap_status
- 实例: else(if), else(if), else(if), else(if), else(if), else(if), endcase(if)

### ForwardUnit
- 文件: D:\riscv\basic_rv32s\modules\Forward_Unit.v
- 层级深度: 0
- 输入: hazard_mem, hazard_wb, store_hazard_mem, store_hazard_wb, MEM_imm, MEM_alu_result, MEM_csr_read_data, byte_enable_logic_register_file_write_data, MEM_pc_plus_4, MEM_opcode, WB_imm, WB_alu_result, WB_csr_read_data, WB_byte_enable_logic_register_file_write_data, WB_pc_plus_4, WB_opcode, csr_hazard_mem, csr_hazard_wb, MEM_csr_write_data, WB_csr_write_data, csr_read_data
- 输出: alu_forward_source_data_a, alu_forward_source_data_b, alu_forward_source_select_a, alu_forward_source_select_b, store_forward_data, store_forward_enable, csr_forward_data
- 实例: endcase(case), endcase(if)

### Hardware_Multiplier
- 文件: D:\riscv\basic_rv32s\modules\Hardware_Multiplier.v
- 层级深度: 0
- 输入: src_A, src_B, mul_op
- 输出: mul_result
- 实例: -

### HazardUnit
- 文件: D:\riscv\basic_rv32s\modules\Hazard_Unit.v
- 层级深度: 0
- 输入: clk, reset, trap_done, csr_ready, standby_mode, trap_status, misaligned_instruction_flush, misaligned_memory_flush, pth_done_flush, if_valid, if_ready, mem_valid, mem_ready, ID_rs1, ID_rs2, ID_raw_imm, ID_opcode, MEM_rd, MEM_opcode, MEM_register_write_enable, MEM_csr_write_enable, MEM_csr_write_address, WB_rd, WB_register_write_enable, WB_csr_write_enable, WB_csr_write_address, EX_rd, EX_opcode, EX_rs1, EX_rs2, EX_imm, EX_csr_write_enable, EX_jump, ID_jump, branch_prediction_miss
- 输出: hazard_mem, hazard_wb, csr_hazard_mem, csr_hazard_wb, store_hazard_mem, store_hazard_wb, IF_ID_flush, ID_EX_flush, EX_MEM_flush, MEM_WB_flush, IF_ID_stall, ID_EX_stall, EX_MEM_stall, MEM_WB_stall
- 实例: end(if), else(if), else(if)

### ID_EX_Register
- 文件: D:\riscv\basic_rv32s\modules\ID_EX_Register.v
- 层级深度: 0
- 输入: clk, reset, flush, ID_EX_stall, ID_pc, ID_pc_plus_4, ID_branch_estimation, ID_instruction, ID_jump, ID_branch, ID_alu_src_A_select, ID_alu_src_B_select, ID_memory_read, ID_memory_write, ID_register_file_write_data_select, ID_register_write_enable, ID_csr_write_enable, ID_opcode, ID_funct3, ID_funct7, ID_rd, ID_raw_imm, ID_read_data1, ID_read_data2, ID_rs1, ID_rs2, ID_imm, ID_csr_read_data
- 输出: EX_pc, EX_pc_plus_4, EX_branch_estimation, EX_instruction, EX_jump, EX_memory_read, EX_memory_write, EX_register_file_write_data_select, EX_register_write_enable, EX_csr_write_enable, EX_branch, EX_alu_src_A_select, EX_alu_src_B_select, EX_opcode, EX_funct3, EX_funct7, EX_rd, EX_raw_imm, EX_read_data1, EX_read_data2, EX_rs1, EX_rs2, EX_imm, EX_csr_read_data
- 实例: -

### IF_ID_Register
- 文件: D:\riscv\basic_rv32s\modules\IF_ID_Register.v
- 层级深度: 0
- 输入: clk, reset, flush, IF_ID_stall, IF_pc, IF_pc_plus_4, IF_instruction, IF_branch_estimation
- 输出: ID_pc, ID_pc_plus_4, ID_instruction, ID_branch_estimation
- 实例: -

### ImmediateGenerator
- 文件: D:\riscv\basic_rv32s\modules\Immediate_Generator.v
- 层级深度: 0
- 输入: raw_imm, opcode
- 输出: imm
- 实例: -

### InstructionDecoder
- 文件: D:\riscv\basic_rv32s\modules\Instruction_Decoder.v
- 层级深度: 0
- 输入: instruction
- 输出: opcode, funct3, funct7, rs1, rs2, rd, raw_imm
- 实例: -

### MEM_WB_Register
- 文件: D:\riscv\basic_rv32s\modules\MEM_WB_Register.v
- 层级深度: 0
- 输入: clk, reset, MEM_WB_stall, flush, MEM_pc, MEM_pc_plus_4, MEM_instruction, MEM_register_file_write_data_select, MEM_imm, MEM_raw_imm, MEM_csr_read_data, MEM_alu_result, MEM_register_write_enable, MEM_csr_write_enable, MEM_rs1, MEM_rd, MEM_opcode, MEM_byte_enable_logic_register_file_write_data
- 输出: WB_pc, WB_pc_plus_4, WB_instruction, WB_register_file_write_data_select, WB_imm, WB_raw_imm, WB_csr_read_data, WB_alu_result, WB_register_write_enable, WB_csr_write_enable, WB_rs1, WB_rd, WB_opcode, WB_byte_enable_logic_register_file_write_data
- 实例: -

### MMIO_Interface
- 文件: D:\riscv\basic_rv32s\modules\MMIO_Interface.v
- 层级深度: 0
- 输入: clk, reset, data_memory_write_data, data_memory_address, data_memory_write_enable, UART_busy
- 输出: mmio_uart_tx_data, mmio_uart_status, mmio_uart_tx_start, mmio_uart_status_hit, mmio_led
- 实例: end(if)

### MMU
- 文件: D:\riscv\basic_rv32s\modules\MMU.v
- 层级深度: 0
- 输入: clk, reset, satp, mstatus, current_mode, tlb_wvpn, tlb_wpte, itlb_we, dtlb_we, if_virtual_address, if_request, mem_virtual_address, mem_request_read, mem_request_write
- 输出: if_physical_address, if_page_fault, mem_physical_address, mem_load_page_fault, mem_store_page_fault
- 实例: else(if), else(if), else(if), else(if)

### PCController
- 文件: D:\riscv\basic_rv32s\modules\PC_Controller.v
- 层级深度: 0
- 输入: jump, ID_jump, branch_estimation, branch_prediction_miss, trapped, pc, jump_target, ID_jump_target, branch_target, branch_target_actual, trap_target, pc_stall, trap_jump
- 输出: next_pc
- 实例: else(if), else(if), else(if), else(if), else(if)

### PCPlus4
- 文件: D:\riscv\basic_rv32s\modules\PC_Plus_4.v
- 层级深度: 0
- 输入: pc
- 输出: pc_plus_4
- 实例: -

### ProgramCounter
- 文件: D:\riscv\basic_rv32s\modules\Program_Counter.v
- 层级深度: 0
- 输入: clk, reset, next_pc
- 输出: pc
- 实例: -

### RV32I46F5SPMMIO
- 文件: D:\riscv\basic_rv32s\modules\RV32I46F_5SP_MMIO.v
- 层级深度: 1
- 输入: clk, reset, UART_busy, timer_irq, external_irq, m_axi_if_awready, m_axi_if_wready, m_axi_if_bvalid, m_axi_if_bresp, m_axi_if_bid, m_axi_if_arready, m_axi_if_rvalid, m_axi_if_rdata, m_axi_if_rresp, m_axi_if_rid, m_axi_if_rlast, m_axi_mem_awready, m_axi_mem_wready, m_axi_mem_bvalid, m_axi_mem_bresp, m_axi_mem_bid, m_axi_mem_arready, m_axi_mem_rvalid, m_axi_mem_rdata, m_axi_mem_rresp, m_axi_mem_rid, m_axi_mem_rlast
- 输出: retire_instruction, mmio_uart_tx_data, mmio_uart_tx_start, mmio_led, m_axi_if_awvalid, m_axi_if_awaddr, m_axi_if_awid, m_axi_if_awlen, m_axi_if_awburst, m_axi_if_awprot, m_axi_if_wvalid, m_axi_if_wdata, m_axi_if_wstrb, m_axi_if_wlast, m_axi_if_bready, m_axi_if_arvalid, m_axi_if_araddr, m_axi_if_arid, m_axi_if_arlen, m_axi_if_arburst, m_axi_if_arprot, m_axi_if_rready, m_axi_mem_awvalid, m_axi_mem_awaddr, m_axi_mem_awid, m_axi_mem_awlen, m_axi_mem_awburst, m_axi_mem_awprot, m_axi_mem_wvalid, m_axi_mem_wdata, m_axi_mem_wstrb, m_axi_mem_wlast, m_axi_mem_bready, m_axi_mem_arvalid, m_axi_mem_araddr, m_axi_mem_arid, m_axi_mem_arlen, m_axi_mem_arburst, m_axi_mem_arprot, m_axi_mem_rready
- 实例: else(if), else(if), ALU(alu), Hardware_Multiplier(mul_inst), ALUController(alu_controller), BranchLogic(branch_logic), BranchPredictor(branch_predictor), ByteEnableLogic(byte_enable_logic), ControlUnit(control_unit), CSRFile(csr_file), MMU(mmu_inst), RV32_AXI_Adapter(data_axi_adapter), ExceptionDetector(exception_detector), ForwardUnit(forward_unit), HazardUnit(hazard_unit), ImmediateGenerator(immediate_generator), InstructionDecoder(instruction_decoder), else(if), else(if), MMIO_Interface(mmio_interface), ProgramCounter(program_counter), PCPlus4(pc_plus_4), PCController(pc_controller), RegisterFile(register_file), IF_ID_Register(if_id_register), ID_EX_Register(id_ex_register), EX_MEM_Register(ex_mem_register), MEM_WB_Register(mem_wb_register), else(if), else(if), end(if), else(if), else(if), else(if), end(if), end(if), endcase(case), endcase(case)

### RV32_AXI_Adapter
- 文件: D:\riscv\basic_rv32s\modules\RV32_AXI_Adapter.v
- 层级深度: 0
- 输入: clk, reset, axi_awready, axi_wready, axi_bvalid, axi_arready, axi_rvalid, axi_rdata, mem_valid, mem_instr, mem_addr, mem_wdata, mem_wstrb
- 输出: axi_awvalid, axi_awaddr, axi_awprot, axi_wvalid, axi_wdata, axi_wstrb, axi_bready, axi_arvalid, axi_araddr, axi_arprot, axi_rready, mem_ready, mem_rdata
- 实例: -

### RV32_SoC_AXI_Top
- 文件: D:\riscv\basic_rv32s\RV32_SoC_AXI_Top.v
- 层级深度: 2
- 输入: clk, rst, UART_busy
- 输出: mmio_uart_tx_data, mmio_uart_tx_start, retire_instruction, mmio_led
- 实例: RV32I46F5SPMMIO(cpu_core)

### RegisterFile
- 文件: D:\riscv\basic_rv32s\modules\Register_File.v
- 层级深度: 0
- 输入: clk, read_reg1, read_reg2, write_reg, write_data, write_enable
- 输出: read_data1, read_data2
- 实例: else(if), end(if), else(if)

