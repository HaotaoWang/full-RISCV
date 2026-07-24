`include "modules/headers/opcode.vh"

// 译码器模块：
// 将 32 位机器码指令拆解开，告诉后续的运算单元：“我们要用到几号寄存器、做什么运算、立即数是多少”
module InstructionDecoder (
	input [31:0] instruction,       // 输入：从指令内存(Instruction Memory)取出来的 32 位原始机器码
    
    output reg [6:0] opcode,        // 输出：操作码（最低7位，决定了这是一条什么大类的指令）
	output reg [2:0] funct3,        // 输出：功能码（决定了具体是哪种操作，如加法还是减法）
	output reg [6:0] funct7,        // 输出：辅助功能码（和 funct3 配合使用）
	output reg [4:0] rs1,           // 输出：源寄存器 1 的编号 (0~31)
	output reg [4:0] rs2,           // 输出：源寄存器 2 的编号 (0~31)
	output reg [4:0] rd,            // 输出：目标寄存器的编号 (0~31)
	output reg [19:0] raw_imm       // 输出：未经过符号扩展的原始立即数（常数字段拼接）
);

	// 无论什么版式的指令，它的最低 7 位永远是 Opcode（操作码）。
	// 译码器第一步就是先把这 7 位切下来，看看这到底是一条什么大类的指令。
	wire [6:0] opcode_wire = instruction[6:0];

    always @(*) begin
		opcode = opcode_wire;
        case (opcode)
			`OPCODE_LUI, `OPCODE_AUIPC: begin // U-type (长立即数指令，如 LUI 将立即数放入高 20 位)
                rd = instruction[11:7];       // 目标寄存器
				raw_imm = instruction[31:12]; // U型指令拥有 20 位的长立即数
				
				// 优秀的工程细节：哪怕当前指令用不到这些字段，也要强制清零！
				// 否则在组合逻辑中会生成不必要的锁存器(Latch)，导致电路逻辑混乱且极其消耗资源。
				funct3 = 3'b000;
				rs1 = 5'b00000;
				rs2 = 5'b00000;
				funct7 = 7'b0000000;
            end
			
			`OPCODE_JAL: begin // J-type (无条件跳转指令，如 JAL)
				rd = instruction[11:7];

				raw_imm = {instruction[31], instruction[19:12], instruction[20], instruction[30:21]};

				// 1. 为什么被打散？
				// 为了尽可能复用硬件引脚连线（例如保证符号位总是在 [31]，imm[10:1] 尽量复用 [30:21]）。
				// 
				// 2. 为什么没有第 0 位？
				// 因为 RISC-V 的指令长度对齐到偶数边界，所有的跳转目标地址必定是偶数。
				// 既然 imm[0] 永远是 0，指令中干脆就“省掉”不存它了！
				// 这样腾出来的 1 个比特位，可以让 20 位的空间表达出 21 位的跳跃范围（直接翻倍到 +/- 1MB）。+/—最高位符号位决定，还剩20位刚好就是1MB
				// 后续在计算目标地址时，硬件会在末尾自动补 0（即整体左移 1 位）。
				// 
				// 【具体的位对应关系】：
				// 拼接后的 raw_imm[19:0] 依次对应着真实立即数 imm 的 [20:1]：
				// raw_imm[19]    <- instruction[31]    (对应真实立即数 imm 的第 20 位，符号位)
				// raw_imm[18:11] <- instruction[19:12] (对应真实立即数 imm 的第 19 到 12 位)
				// raw_imm[10]    <- instruction[20]    (对应真实立即数 imm 的第 11 位)
				// raw_imm[9:0]   <- instruction[30:21] (对应真实立即数 imm 的第 10 到 1 位)
				
				funct3 = 3'b000;
				rs1 = 5'b00000;
				rs2 = 5'b00000;
				funct7 = 7'b0000000;
			end

			`OPCODE_BRANCH: begin // B-type (条件分支指令，如 BEQ, BNE)
				funct3 = instruction[14:12];
				rs1 = instruction[19:15];
				rs2 = instruction[24:20];
				// B型指令的立即数同样被打散，用于表示跳转的相对地址偏移量
				// 显式加上 8'b0 补齐 20 位，避免位宽不匹配的警告
				raw_imm = {8'b0, instruction[31], instruction[7], instruction[30:25], instruction[11:8]};
				
				rd = 5'b00000;
				funct7 = 7'b0000000;
			end
			
			`OPCODE_JALR, `OPCODE_LOAD, `OPCODE_ITYPE, `OPCODE_FENCE, `OPCODE_ENVIRONMENT: begin // I-type (寄存器-立即数指令，如 ADDI, LW)
				rd = instruction[11:7];
				funct3 = instruction[14:12];
				rs1 = instruction[19:15];
				// 规定最高 12 位是立即数，但是规定了raw_imm是20位的，所以要8'b0，补充 8 位 0 占位
				raw_imm = {8'b0, instruction[31:20]};
				
				// I型指令用不到 rs2 和 funct7，强制清零防止 Latch
				rs2 = 5'b00000;
				funct7 = 7'b0000000;
			end
			
			`OPCODE_STORE: begin // S-type (存入内存指令，如 SW, SB)
				funct3 = instruction[14:12];
				rs1 = instruction[19:15];
				rs2 = instruction[24:20];
				// S型指令的立即数被 rd 字段的位置强行拆成了两半，需要拼起来
				raw_imm = {8'b0, instruction[31:25], instruction[11:7]};
				
				rd = 5'b00000;
				funct7 = 7'b0000000;
			end
			
			`OPCODE_RTYPE: begin // R-type (寄存器-寄存器指令，如 ADD, SUB)
				rd = instruction[11:7];      // 切出目标寄存器 rd
				funct3 = instruction[14:12]; // 切出功能码
				rs1 = instruction[19:15];    // 切出源寄存器 1
				rs2 = instruction[24:20];    // 切出源寄存器 2
				funct7 = instruction[31:25]; // 切出辅助功能码
				
				// R型指令全是寄存器操作，没有立即数，强制设为 0 (20位)
				raw_imm = 20'b0;
			end
			default: begin
			// 未知操作码的默认处理，全部清零以保安全
			funct3 = 3'b0;
            funct7 = 7'b0;
            rs1 = 5'b0;
            rs2 = 5'b0;
            rd = 5'b0;
            raw_imm = 20'b0;
            end
		endcase
    end

endmodule
