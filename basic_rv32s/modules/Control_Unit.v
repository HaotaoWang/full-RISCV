`include "modules/headers/alu_src_select.vh"
`include "modules/headers/csr.vh"
`include "modules/headers/itype.vh"
`include "modules/headers/opcode.vh"
`include "modules/headers/rf_wd_select.vh"

// 控制单元 (Control Unit) 模块
// 这是 CPU 的“大脑”。它接收译码器传来的操作码 (opcode) 和功能码 (funct3)，
// 然后像指挥家一样，输出各种控制信号来指挥其他部件（ALU、寄存器堆、内存等）应该干什么。
module ControlUnit (
	input write_done,	// 内存写入完成信号
	input trap_done,	// 异常处理完成信号
	input csr_ready,    // CSR (控制状态寄存器) 准备就绪信号
	input IF_ID_stall,  // 流水线取指/译码段阻塞信号
	input [6:0] opcode, // 从指令译码器传来的操作码 (决定了大类)
	input [2:0] funct3, // 从指令译码器传来的功能码 (决定了具体操作)
    
	output reg jump,                                 // 是否为无条件跳转指令
	output reg branch,                               // 是否为条件分支指令
	output reg [1:0] alu_src_A_select,               // ALU 的 A 端口输入选择 (如：PC 还是 寄存器1)
	output reg [2:0] alu_src_B_select,               // ALU 的 B 端口输入选择 (如：寄存器2、立即数 还是 其他)
	output reg csr_write_enable,                     // CSR 写入使能信号
	output reg register_file_write,                  // 通用寄存器堆写入使能信号
	output reg [2:0] register_file_write_data_select,// 写回寄存器的数据来源选择 (如：ALU结果、内存读出的数据等)
	output reg memory_read,                          // 数据内存读取使能
	output reg memory_write,                         // 数据内存写入使能
	output reg pc_stall                              // PC 暂停/阻塞信号 (遇到冲突或等待时停止更新 PC)
);

    always @(*) begin
        // 任何处于等待状态的情况，都需要暂停 PC 的更新
		pc_stall = (!write_done || !trap_done || !csr_ready || IF_ID_stall);
        
        // -----------------------------------------------------------
        // 初始默认状态：为了防止产生锁存器 (Latch)，在 case 语句之前
        // 先给所有的控制信号赋一个默认的“不操作”状态。
        // -----------------------------------------------------------
        jump = 1'b0;
        branch = 1'b0;
        alu_src_A_select = `ALU_SRC_A_NONE;
        alu_src_B_select = `ALU_SRC_B_NONE; 
        csr_write_enable = 1'b0;
        register_file_write = 1'b0;
        register_file_write_data_select = `RF_WD_NONE;
        memory_read = 1'b0;
        memory_write = 1'b0;


		//下面就是非常经典的11类指令，一事一议，分别对应着不同的选择器配置，其实就是一个死板的对照表而已
		case (opcode)
			`OPCODE_LUI: begin 
                // LUI (加载高位立即数)
                // 作用：将 20 位立即数的高位直接写入目标寄存器。
				jump = 0;
				branch = 0;
				alu_src_A_select = `ALU_SRC_A_NONE; // 不需要 ALU 计算
				alu_src_B_select = `ALU_SRC_B_NONE; 
				csr_write_enable = 0;
				
				register_file_write = 1;            // 需要写入寄存器
				register_file_write_data_select = `RF_WD_LUI; // 写入的数据来源是立即数生成器的 LUI 结果
				
				memory_read = 0;
				memory_write = 0;
			end
			`OPCODE_AUIPC: begin
                // AUIPC (将高位立即数加到 PC 上)
                // 作用：PC + 立即数，然后存入寄存器。常用于计算相对地址。
				jump = 0;
				branch = 0;
				
				alu_src_A_select = `ALU_SRC_A_PC;   // ALU 输入 A 是当前 PC
				alu_src_B_select = `ALU_SRC_B_IMM;  // ALU 输入 B 是立即数
				csr_write_enable = 0;
				
				register_file_write = 1;            // 将 ALU 加出来的结果写回寄存器
				register_file_write_data_select = `RF_WD_ALU;
				
				memory_read = 0;
				memory_write = 0;
			end
			`OPCODE_JAL: begin
                // JAL (无条件跳转并链接)
                // 作用：跳转到 PC+偏移量，并把下一条指令的地址 (PC+4) 保存到寄存器 (通常是返回地址寄存器 ra)。
				jump = 1;                           // 发出跳转信号
				branch = 0;
				
				alu_src_A_select = `ALU_SRC_A_PC;   // ALU 用于计算跳转目标地址：PC + 立即数
				alu_src_B_select = `ALU_SRC_B_IMM;
				csr_write_enable = 0;
				
				register_file_write = 1;            // 需要写回寄存器
				register_file_write_data_select = `RF_WD_JUMP; // 写入的数据是下一条指令的地址 (PC+4)
				
				memory_read = 0;
				memory_write = 0;
			end
			`OPCODE_JALR: begin
                // JALR (跳转并链接寄存器)
                // 作用：跳转到 寄存器值+偏移量，并把 PC+4 存起来。
				jump = 1;                           // 发出跳转信号
				branch = 0;
				
				alu_src_A_select = `ALU_SRC_A_RD1;  // ALU 用于计算目标地址：寄存器 rs1 的值 + 立即数
				alu_src_B_select = `ALU_SRC_B_IMM;
				csr_write_enable = 0;
				
				register_file_write = 1;            // 写回寄存器
				register_file_write_data_select = `RF_WD_JUMP; // 写入数据是 PC+4
				
				memory_read = 0;
				memory_write = 0;
			end
			`OPCODE_BRANCH: begin
                // B 型分支指令 (BEQ, BNE, BLT 等)
                // 作用：比较两个寄存器的值，如果条件满足则跳转。
				jump = 0;
				branch = 1;                         // 这是一个条件分支指令
				
				alu_src_A_select = `ALU_SRC_A_RD1;  // ALU 用于比较两个寄存器的值
				alu_src_B_select = `ALU_SRC_B_RD2;
				csr_write_enable = 0;
				
				register_file_write = 0;            // 分支指令不需要把结果写回寄存器
				register_file_write_data_select = `RF_WD_NONE;
				
				memory_read = 0;
				memory_write = 0;
			end
			`OPCODE_LOAD: begin
                // Load 指令 (LW, LH, LB 等)
                // 作用：从内存中读取数据存入寄存器。
				jump = 0;
				branch = 0;
				
				alu_src_A_select = `ALU_SRC_A_RD1;  // ALU 用于计算内存地址：基址寄存器 rs1 + 偏移量(立即数)
				alu_src_B_select = `ALU_SRC_B_IMM;
				csr_write_enable = 0;
				
				register_file_write = 1;            // 需要将读出的内存数据写回寄存器
				register_file_write_data_select = `RF_WD_LOAD; // 数据来源选择为 Load 出来的数据
				
				memory_read = 1;                    // 开启内存读使能
				memory_write = 0;
			end
			`OPCODE_STORE: begin
                // Store 指令 (SW, SH, SB)
                // 作用：将寄存器的值存入内存中。
				jump = 0;
				branch = 0;
				
				alu_src_A_select = `ALU_SRC_A_RD1;  // ALU 用于计算内存地址：基址寄存器 rs1 + 偏移量(立即数)
				alu_src_B_select = `ALU_SRC_B_IMM;
				csr_write_enable = 0;
				
				register_file_write = 0;            // 存内存操作，不需要写回通用寄存器
				register_file_write_data_select = `RF_WD_NONE;
				
				memory_read = 0;
				memory_write = 1;                   // 开启内存写使能
			end
			`OPCODE_ITYPE: begin
                // I 型算术逻辑指令 (ADDI, SLLI 等)
                // 作用：寄存器 1 和 立即数 进行计算。
				jump = 0;
				branch = 0;
				
				alu_src_A_select = `ALU_SRC_A_RD1;  // ALU 端口 A 是寄存器 rs1

                // 如果是移位指令，B 端口选择移位量 shamt；否则选完整的立即数 imm
				if (funct3 == `ITYPE_SRXI) begin
					alu_src_B_select = `ALU_SRC_B_SHAMT;
				end
				else begin
					alu_src_B_select = `ALU_SRC_B_IMM;
				end
				
				csr_write_enable = 0;
				
				register_file_write = 1;            // ALU 的计算结果写回寄存器
				register_file_write_data_select = `RF_WD_ALU; // 数据来源是 ALU
				
				memory_read = 0;
				memory_write = 0;
			end
			`OPCODE_RTYPE: begin
                // R 型算术逻辑指令 (ADD, SUB, AND 等)
                // 作用：寄存器 1 和 寄存器 2 进行计算。
				jump = 0;
				branch = 0;
				
				alu_src_A_select = `ALU_SRC_A_RD1;  // ALU 端口 A 是寄存器 rs1
				alu_src_B_select = `ALU_SRC_B_RD2;  // ALU 端口 B 是寄存器 rs2
				csr_write_enable = 0;
				
				register_file_write = 1;            // ALU 的计算结果写回寄存器
				register_file_write_data_select = `RF_WD_ALU; // 数据来源是 ALU
				
				memory_read = 0;
				memory_write = 0;
			end
			`OPCODE_FENCE: begin
                // FENCE 指令 (内存屏障)
                // 在这个基础版 CPU 里通常直接当作 NOP 处理。
				jump = 0;
				branch = 0;
				alu_src_A_select = `ALU_SRC_A_NONE;
				alu_src_B_select = `ALU_SRC_B_NONE;
				csr_write_enable = 0;
				register_file_write = 0;
				register_file_write_data_select = `RF_WD_NONE;
				memory_read = 0;
				memory_write = 0;
			end
			`OPCODE_ENVIRONMENT: begin
                // 系统环境及 CSR 操作指令 (ECALL, EBREAK, CSRRW 等)
				jump = 0;
				branch = 0;

				// 通过 funct3 来判断是否为 CSR 读写指令
				csr_write_enable = (funct3 == 0) ? 0 : 1;

				if (funct3 == 3'b0) begin
                    // 如果 funct3 是 0，代表是 ECALL 或 EBREAK 等纯环境调用，不做额外 ALU/寄存器操作
					alu_src_A_select = `ALU_SRC_A_NONE;
					alu_src_B_select = `ALU_SRC_B_NONE; 
					register_file_write = 0;
					register_file_write_data_select = `RF_WD_NONE;
				end
				else begin
                    // 处理 CSR 寄存器指令 (例如 CSRRW 读写控制状态寄存器)
					if (funct3 == `CSR_CSRRW || funct3 == `CSR_CSRRWI) begin
						alu_src_B_select = `ALU_SRC_B_NONE;
					end
					else begin
						alu_src_B_select = `ALU_SRC_B_CSR; // B 端口来源选 CSR 的旧值
					end

					if (funct3 == `CSR_CSRRW || funct3 == `CSR_CSRRS || funct3 == `CSR_CSRRC) begin
						alu_src_A_select = `ALU_SRC_A_RD1; // 操作数来自通用寄存器 rs1
					end
					else begin
						alu_src_A_select = `ALU_SRC_A_RS1; // 带有 'I' 结尾的 CSR 指令，操作数是指令中嵌入的立即数
					end

					register_file_write = 1;            // 需要把读出的 CSR 旧值写回到通用寄存器中
					register_file_write_data_select = `RF_WD_CSR;
				end

				memory_read = 0;
				memory_write = 0;
			end
			default: begin
                // 未知指令保护：所有信号静默
                jump = 1'b0;
                branch = 1'b0;
                alu_src_A_select = `ALU_SRC_A_NONE;
                alu_src_B_select = `ALU_SRC_B_NONE; 
                csr_write_enable = 1'b0;
                register_file_write = 1'b0;
                register_file_write_data_select = `RF_WD_NONE;
                memory_read = 1'b0;
                memory_write = 1'b0;
            end
		endcase
    end

endmodule