`include "modules/headers/branch.vh"
`include "modules/headers/itype.vh"
`include "modules/headers/load.vh"
`include "modules/headers/rtype.vh"
`include "modules/headers/store.vh"
`include "modules/headers/opcode.vh"
`include "modules/headers/csr.vh"

module InstructionMemory (
    input [31:0] pc,  						// 输入PC
    output reg [31:0] instruction,  		// 输出指令

	input [31:0] rom_address,  				// ROM地址,是作者后来加的高级功能。因为有时候不仅 CPU 要取指令，有些特殊的数据（比如只读常量）也存在这里，供别的模块读取。你可以先不用管它。
	output reg [31:0] rom_read_data  		// ROM读取到的数据
);

	//[31:0] 表示仓库里的每一个小格子都能装 32 位（4个字节）的数据。
	//[0:2047] 表示这个仓库一共有 2048 个这样的小格子。
	//算笔账：2048 个格子 × 4字节 = 8192 字节 = 8KB。 也就是说，我们的这台小 CPU，目前拥有 8KB 的指令内存空间！
	reg [31:0] data [0:2047];	// 划分内存空间

	//在 Verilog 里，initial 块代表“开机通电那一瞬间只做一次的事情”。 
	//作者在这里扮演了“固件烧录器”的角色。
	//他手动把一个用来测试 CPU 所有功能的汇编程序（包含了加减乘除、内存读写、分支跳转、甚至异常报错），
	//一条一条地塞进了 data 这个数组里。
	integer i;
	initial begin
		// $readmemh("./dhrystone.mem", data);
		//初始化data数组，使其填满空指令。addi x0, x0, 0x2bc
		for (i=0; i<2048; i=i+1) begin
			data[i] = {12'h2BC, 5'd0, `ITYPE_ADDI, 5'd0, `OPCODE_ITYPE};
		end

		// <位宽>'<进制><数值>
		// ──────────────────────────────────────────────
		// I-Type ALU指令 (9条) - 立即数算术逻辑 (如 ADDI, SLLI 等)
		// {imm[11:0], rs1, funct3, rd, OPCODE_ITYPE}
		data[0] = {12'h2BC, 5'd0, `ITYPE_ADDI, 5'd1, `OPCODE_ITYPE};				// ADDI:  x1 = x0 + 2BC = 000002BC
		data[1] = {12'd24,  5'd1, `ITYPE_SLLI, 5'd2, `OPCODE_ITYPE};				// SLLI:  x2 = x1 << 24 = BC000000
		data[2] = {12'd0,  5'd2, `ITYPE_SLTI, 5'd3, `OPCODE_ITYPE};				// SLTI:  x3 = (x2(-1140850688d) < 0) ? 1 : 0 = 00000001
		data[3] = {12'd0,  5'd2, `ITYPE_SLTIU, 5'd4, `OPCODE_ITYPE};				// SLTIU: x4 = (x2(3154116608d) < 0) ? 1 : 0 = 00000000
		data[4] = {12'h653,  5'd1, `ITYPE_XORI, 5'd5, `OPCODE_ITYPE};			// XORI:  x5 = x1 XOR 653 = 000004EF
		data[5] = {7'b0000000, 5'd4, 5'd2, `ITYPE_SRXI, 5'd6, `OPCODE_ITYPE};	// SRLI:  x6 = x2 >> 4 = 0BC00000
		data[6] = {7'b0100000, 5'd4, 5'd2, `ITYPE_SRXI, 5'd7, `OPCODE_ITYPE};	// SRAI:  x7 = x2 >>> 4 = FBC00000
		data[7] = {12'h0BC, 5'd2, `ITYPE_ORI, 5'd8, `OPCODE_ITYPE};				// ORI:   x8 = x2 OR BC = BC0000BC
		data[8] = {12'h0EC, 5'd5, `ITYPE_ANDI, 5'd9, `OPCODE_ITYPE};				// ANDI:  x9 = x5 AND 0EC = 000000EC

		// ──────────────────────────────────────────────
		// R-Type 指令 (10条) - 寄存器与寄存器算术逻辑 (如 ADD, SUB, XOR 等)
		// {funct7, rs2, rs1, funct3, rd, OPCODE_RTYPE}
		data[9]  = {7'b0000000, 5'd9, 5'd1, `RTYPE_ADDSUB, 5'd10, `OPCODE_RTYPE};	// ADD: x10 = x1 + x9 = 000003A8
		data[10] = {7'b0100000, 5'd5, 5'd6, `RTYPE_ADDSUB, 5'd11, `OPCODE_RTYPE};	// SUB: x11 = x6 - x5 = 0BBFFB11
		data[11] = {7'b0000000, 5'd3, 5'd7, `RTYPE_SLL, 5'd12, `OPCODE_RTYPE};		// SLL: x12 = x7 << x3 = F7800000
		data[12] = {7'b0000000, 5'd2, 5'd1, `RTYPE_SLT, 5'd13, `OPCODE_RTYPE};		// SLT: x13 = (x1 < x2) ? 1 : 0 = 00000000
		data[13] = {7'b0000000, 5'd2, 5'd1, `RTYPE_SLTU, 5'd14, `OPCODE_RTYPE};		// SLTU: x14 = (x1 < x2 unsigned) ? 1 : 0 = 00000001
		data[14] = {7'b0000000, 5'd8, 5'd12, `RTYPE_XOR, 5'd15, `OPCODE_RTYPE};		// XOR: x15 = x12 XOR x8 = 4B8000BC
		data[15] = {7'b0000000, 5'd3, 5'd12, `RTYPE_SR, 5'd16, `OPCODE_RTYPE};		// SRL: x16 = x12 >> x3 = 7BC00000
		data[16] = {7'b0100000, 5'd3, 5'd12, `RTYPE_SR, 5'd17, `OPCODE_RTYPE};		// SRA: x17 = x12 >>> x3 = FBC00000
		data[17] = {7'b0000000, 5'd7, 5'd11, `RTYPE_OR, 5'd18, `OPCODE_RTYPE};		// OR:  x18 = x11 OR x7 = FBFFFB11
		data[18] = {7'b0000000, 5'd11, 5'd7, `RTYPE_AND, 5'd19, `OPCODE_RTYPE};		// AND: x19 = x7 AND x11 = 0B800000

		// ──────────────────────────────────────────────
		// S-Type 指令 (3条) - Store 存储指令 (写入内存, 如 SW, SH, SB)
		// {imm[11:5], rs2, rs1, funct3, imm[4:0], OPCODE_STORE}
		data[19] = {7'd0, 5'd11, 5'd1, `STORE_SW, 5'd4, `OPCODE_STORE};				// SW: mem[x1+4 = 2C0] = (x11 = 0BBFFB11) -> 0BBFFB11	
		data[20] = {7'd0, 5'd10, 5'd1, `STORE_SH, 5'd7, `OPCODE_STORE};				// SH: mem[x1+7 = 2C3 (write nothing)] = (x10[15:0] = 03A8) -> 0BBFFB11 // Misaligned Memory exception. NOPs and goes to Trap Handler.
		data[21] = {7'd0, 5'd15, 5'd1, `STORE_SB, 5'd4, `OPCODE_STORE};				// SB: mem[x1+4 = 2C0] = (x15[7:0] = BC) -> 0BBFFBBC	

		// ──────────────────────────────────────────────
		// I-Type Load 指令 (5条) - 从内存读取数据 (此处将 x1 寄存器地址修改为 RAM 地址以便测试)
		// {imm[11:0], rs1, funct3, rd, OPCODE_LOAD}
		
		// 将 x1 的值修改为 0x100002BC (用于访问 RAM 区域)
		data[22] = {20'h10000, 5'd31, `OPCODE_LUI};									// LUI: x31 = 0x10000000
		data[23] = {7'b0000000, 5'd31, 5'd1, `RTYPE_OR, 5'd1, `OPCODE_RTYPE};		// OR:  x1 = x1 | x31 = 0x100002BC

		data[24] = {12'd5, 5'd1, `LOAD_LW, 5'd20, `OPCODE_LOAD};						// LW:  x20 = mem[x1+5 = 100002C1] = misaligned exception
		data[25] = {12'd4, 5'd1, `LOAD_LH, 5'd21, `OPCODE_LOAD};						// LH:  x21 = mem[x1+4 = 100002C0][15:0]
		data[26] = {12'd4, 5'd1, `LOAD_LB, 5'd22, `OPCODE_LOAD};						// LB:  x22 = mem[x1+4 = 100002C0][7:0]
		data[27] = {12'd4, 5'd1, `LOAD_LHU, 5'd23, `OPCODE_LOAD};					// LHU: x23 = mem[x1+4 = 100002C0][15:0]
		data[28] = {12'd4, 5'd1, `LOAD_LBU, 5'd24, `OPCODE_LOAD};					// LBU: x24 = mem[x1+4 = 100002C0][7:0]

		// 测试完毕，将 x1 的值恢复为 0x000002BC
		data[29] = {12'h2BC, 5'd0, `ITYPE_ADDI, 5'd1, `OPCODE_ITYPE};				// ADDI: x1 = 0x000002BC

		// ──────────────────────────────────────────────
		// U-Type 指令 (2条) - 处理长立即数的高位 (LUI, AUIPC)
		// {imm[31:12], rd, OPCODE_LUI/OPCODE_AUIPC}
		data[30] = {20'd1, 5'd25, `OPCODE_LUI};										// LUI: x25 = 00001000		
		data[31] = {20'd1, 5'd26, `OPCODE_AUIPC};									// AUIPC: x26 = 0000007C + 00001000 = 0000107C

		// ──────────────────────────────────────────────
		// J-Type 指令 (1条) - 无条件绝对跳转 (JAL)
		// {imm[20|10:1|11|19:12], rd, OPCODE_JAL}
		data[32] = {20'b0_0000001111_0_00000000, 5'd27, `OPCODE_JAL};				// JAL: PC(0x80) + 0x1E = 0x9E (misaligned), x27 = PC + 4 = 0x84
		// But since this instruction occurs exception, It's handled as NOP.

		// ──────────────────────────────────────────────
		// B-Type 指令 (6条) - 条件分支指令 (Branch, 如 BEQ, BNE)
		// {imm[12], imm[10:5], rs2, rs1, funct3, imm[4:1], imm[11], OPCODE_BRANCH}
		data[33] = {1'b0, 6'd0, 5'd2, 5'd1, `BRANCH_BEQ, 4'b0100, 1'b0, `OPCODE_BRANCH}; 	// BEQ: if(x1 == x2) branch offset = 8		Not Taken	
		data[34] = {1'b0, 6'd0, 5'd13, 5'd0, `BRANCH_BNE, 4'b0100, 1'b0, `OPCODE_BRANCH}; 	// BNE: if(x0 != x13) branch offset = 8		Not Taken
		data[35] = {1'b0, 6'd0, 5'd2, 5'd1, `BRANCH_BLT, 4'b0100, 1'b0, `OPCODE_BRANCH}; 	// BLT: if(x1 < x2) branch offset = 8		Not Taken (x2 = signed negative)
		data[36] = {1'b0, 6'd0, 5'd1, 5'd2, `BRANCH_BGE, 4'b0100, 1'b0, `OPCODE_BRANCH}; 	// BGE: if(x2 >= x1) branch offset = 8		Not Taken (x2 = signed negative)
		data[37] = {1'b0, 6'd0, 5'd1, 5'd2, `BRANCH_BLTU, 4'b0100, 1'b0, `OPCODE_BRANCH}; 	// BLTU: if(x2 < x1 unsigned) branch offset = 8		Not Taken 
		data[38] = {1'b0, 6'd0, 5'd1, 5'd2, `BRANCH_BGEU, 4'b0100, 1'b0, `OPCODE_BRANCH}; 	// BGEU: if(x2 >= x1 unsigned) branch offset = 8	Taken -> data[40]

		// ──────────────────────────────────────────────
		// I-Type 跳转指令 (1条) - 寄存器相对跳转 (JALR)
		// {imm[11:0], rs1, funct3, rd, OPCODE_JALR}
		data[39] = {12'd0, 5'd27, 3'b000, 5'd28, `OPCODE_JALR}; 						// JALR: x28 = PC + 4 = 0xA0; PC = x27 + 0 = 0x84

		// ──────────────────────────────────────────────
		// I-Type Zicsr 扩展指令 (6条) - 控制和状态寄存器 (CSR) 操作	[F11]对应供应商ID, [341]对应mepc(异常返回地址), [342]对应mcause(异常原因), [305]对应mtvec(异常向量基址)
		// {imm[11:0], rs1(uimm), funct3, rd, OPCODE_ENVIRONMENT}
		data[40] = {12'hF11, 5'd28, `CSR_CSRRW, 5'd20, `OPCODE_ENVIRONMENT}; 		// CSRRW : x28 = 0000_0000; x20 = 5256_4B43 <= CSR[F11] = 5256_4B43 // R[x20] = 5256_4B43.
		data[41] = {12'h341, 5'd1, `CSR_CSRRS, 5'd21, `OPCODE_ENVIRONMENT}; 			// CSRRS: x1 = 0000_02BC; CSR[341] = 0000_0074. 					// R[x21] = 0000_0074, CSR[341] = 0000_02fc
		data[42] = {12'h341, 5'd20, `CSR_CSRRC, 5'd21, `OPCODE_ENVIRONMENT}; 		// CSRRC: x21 = 0000_0074, x20 = 5256_4B43, CSR[341] = 0000_02fc. 	// R[x21] = 0000_02fc, CSR[341] = 0000_00BC 
		data[43] = {12'h342, 5'd3, `CSR_CSRRWI, 5'd22, `OPCODE_ENVIRONMENT}; 		// CSRRWI: x22 = FFFF_FFBC, CSR[342] = 0000_0000; 					// R[x22] = 0000_0000, CSR[342] = 0000_0003
		data[44] = {12'h305, 5'd7, `CSR_CSRRSI, 5'd22, `OPCODE_ENVIRONMENT}; 		// CSRRSI: x22 = 0000_0000, CSR[305] = 0000_1000; 					// R[x22] = 0000_1000, CSR[305] = 0000_1007
		data[45] = {12'h305, 5'b11111, `CSR_CSRRCI, 5'd23, `OPCODE_ENVIRONMENT}; 	// CSRRCI: uimm = 11111, CSR[305] = 0000_1007; 						// R[x23] = 0000_1007, CSR[305] = 0000_1000

		// ──────────────────────────────────────────────
		// I-Type HINT 指令 - (空指令，用于确认 CSR 运行状态)
		// {imm[11:0], rs1, funct3, rd, OPCODE_ITYPE}
		data[46] = {12'h2BC, 5'd0, `ITYPE_ADDI, 5'd0, `OPCODE_ITYPE};				// ADDI:  x0 = x0 + 2BC = 0000_0000

		// ──────────────────────────────────────────────
		// 用于测试异常处理的指令：包含 ECALL、故意触发指令地址未对齐异常的 JALR、以及故意触发内存地址未对齐异常的 SH
		data[47] = {12'd0, 5'd0, 3'd0, 5'd0, `OPCODE_ENVIRONMENT}; 					// ECALL: PC = CSR[mtvec] = 0000_1000 = data[1024]
		data[48] = {12'd1, 5'd27, 3'b000, 5'd28, `OPCODE_JALR}; 						// JALR: x28 = PC + 4 = 0xC4; PC = x27 + 1 = 0x85 -> misaligned
		data[49] = {7'b0, 5'd5, 5'd1, `STORE_SH, 5'd1, `OPCODE_STORE};				// SH: mem[x1+1 = 2BD, misaligned] = (x5[15:0] = 04EF) misaligned exception..

		// ──────────────────────────────────────────────
		// Debug 接口测试的前置工作：将配合 Debug 模块完成特定加法运算
		data[50] = {20'd0, 5'd22, `OPCODE_LUI};										// LUI: x22 = 0000_0000
		data[51] = {12'hFBC, 5'd22, `ITYPE_ADDI, 5'd22, `OPCODE_ITYPE};				// ADDI x22 = x22 - 0x44 = FFFF_FFBC
		data[52] = {20'hABADC, 5'd23, `OPCODE_LUI};									// LUI: x23 = ABAD_C000
		data[53] = {12'hB02, 5'd23, `ITYPE_ADDI, 5'd23, `OPCODE_ITYPE};				// ADDI:  x23 = x23 + -4FE = ABAD_BB02

		// ──────────────────────────────────────────────
		// MMIO (内存映射IO) 测试指令：向 0x10010000 地址写入数据 "ABADBEBE"，用于模拟 UART 串口打印输出
		data[54] = {1'b0, 10'b0000000110, 1'b0, 8'b0, 5'd0, `OPCODE_JAL};			// JAL x0, +12: 跳转到 data[57]

		data[55] = {12'd1, 5'd0, 3'd0, 5'd0, `OPCODE_ENVIRONMENT};					// EBREAK: 
																					// └ADD: x22 = x22 + x23. FFFF_FFBC(x22) + ABAD_BB02(x23) = ABAD_BABE(x22)

		// HINT; NOP for 'x' signal after EBREAK in pipeline
		data[56] = {12'h2BC, 5'd0, `ITYPE_ADDI, 5'd0, `OPCODE_ITYPE};				// ADDI:  x0 = x0 + 2BC = 0000_0000
		
		// ──────────────────────────────────────────────
		// UART MMIO 测试：向 0x10010000 地址逐字节发送 "ABADBEBE" (带有轮询 Busy 位的逻辑)
		data[57] = {20'h10010, 5'd29, `OPCODE_LUI};									// LUI: x29 = 0x10010000 (UART TX Data 주소)
		data[58] = {12'h004, 5'd29, `ITYPE_ADDI, 5'd28, `OPCODE_ITYPE};				// ADDI: x28 = x29 + 4 = 0x10010004 (UART Status 주소)

		// 发送字符 'A'
		data[59] = {12'h041, 5'd0, `ITYPE_ADDI, 5'd31, `OPCODE_ITYPE};				// ADDI: x31 = 'A' (0x41)
		data[60] = {12'd0, 5'd28, `LOAD_LW, 5'd30, `OPCODE_LOAD};					// LW x30, 0(x28): 读取 UART 状态寄存器
		data[61] = {12'd1, 5'd30, `ITYPE_ANDI, 5'd30, `OPCODE_ITYPE};				// ANDI x30, x30, 1: 使用 ANDI 提取 Busy 位
		data[62] = {1'b1, 6'b111111, 5'd0, 5'd30, `BRANCH_BNE, 4'b1100, 1'b1, `OPCODE_BRANCH}; // BNE x30, x0, -8: 如果 Busy 位为 1，则跳回前面的指令重新尝试 (Polling轮询等待)
		data[63] = {7'd0, 5'd31, 5'd29, `STORE_SB, 5'd0, `OPCODE_STORE};				// SB: mem[x29+0] = 'A'

		// 发送字符 'B'
		data[64] = {12'h042, 5'd0, `ITYPE_ADDI, 5'd31, `OPCODE_ITYPE};				// ADDI: x31 = 'B' (0x42)
		data[65] = {12'd0, 5'd28, `LOAD_LW, 5'd30, `OPCODE_LOAD};					// LW x30, 0(x28): 读取 UART 状态寄存器
		data[66] = {12'd1, 5'd30, `ITYPE_ANDI, 5'd30, `OPCODE_ITYPE};				// ANDI x30, x30, 1: 使用 ANDI 提取 Busy 位
		data[67] = {1'b1, 6'b111111, 5'd0, 5'd30, `BRANCH_BNE, 4'b1100, 1'b1, `OPCODE_BRANCH}; // BNE x30, x0, -8: 如果 Busy 位为 1，则跳回前面的指令重新尝试
		data[68] = {7'd0, 5'd31, 5'd29, `STORE_SB, 5'd0, `OPCODE_STORE};				// SB: mem[x29+0] = 'B'

		// 发送字符 'A'
		data[69] = {12'h041, 5'd0, `ITYPE_ADDI, 5'd31, `OPCODE_ITYPE};				// ADDI: x31 = 'A' (0x41)
		data[70] = {12'd0, 5'd28, `LOAD_LW, 5'd30, `OPCODE_LOAD};					// LW x30, 0(x28): 读取 UART 状态寄存器
		data[71] = {12'd1, 5'd30, `ITYPE_ANDI, 5'd30, `OPCODE_ITYPE};				// ANDI x30, x30, 1: 使用 ANDI 提取 Busy 位
		data[72] = {1'b1, 6'b111111, 5'd0, 5'd30, `BRANCH_BNE, 4'b1100, 1'b1, `OPCODE_BRANCH}; // BNE x30, x0, -8: 如果 Busy 位为 1，则跳回前面的指令重新尝试
		data[73] = {7'd0, 5'd31, 5'd29, `STORE_SB, 5'd0, `OPCODE_STORE};				// SB: mem[x29+0] = 'A'

		// 发送字符 'D'
		data[74] = {12'h044, 5'd0, `ITYPE_ADDI, 5'd31, `OPCODE_ITYPE};				// ADDI: x31 = 'D' (0x44)
		data[75] = {12'd0, 5'd28, `LOAD_LW, 5'd30, `OPCODE_LOAD};					// LW x30, 0(x28): 读取 UART 状态寄存器
		data[76] = {12'd1, 5'd30, `ITYPE_ANDI, 5'd30, `OPCODE_ITYPE};				// ANDI x30, x30, 1: 使用 ANDI 提取 Busy 位
		data[77] = {1'b1, 6'b111111, 5'd0, 5'd30, `BRANCH_BNE, 4'b1100, 1'b1, `OPCODE_BRANCH}; // BNE x30, x0, -8: 如果 Busy 位为 1，则跳回前面的指令重新尝试
		data[78] = {7'd0, 5'd31, 5'd29, `STORE_SB, 5'd0, `OPCODE_STORE};				// SB: mem[x29+0] = 'D'

		// 发送字符 'B'
		data[79] = {12'h042, 5'd0, `ITYPE_ADDI, 5'd31, `OPCODE_ITYPE};				// ADDI: x31 = 'B' (0x42)
		data[80] = {12'd0, 5'd28, `LOAD_LW, 5'd30, `OPCODE_LOAD};					// LW x30, 0(x28): 读取 UART 状态寄存器
		data[81] = {12'd1, 5'd30, `ITYPE_ANDI, 5'd30, `OPCODE_ITYPE};				// ANDI x30, x30, 1: 使用 ANDI 提取 Busy 位
		data[82] = {1'b1, 6'b111111, 5'd0, 5'd30, `BRANCH_BNE, 4'b1100, 1'b1, `OPCODE_BRANCH}; // BNE x30, x0, -8: 如果 Busy 位为 1，则跳回前面的指令重新尝试
		data[83] = {7'd0, 5'd31, 5'd29, `STORE_SB, 5'd0, `OPCODE_STORE};				// SB: mem[x29+0] = 'B'

		// 发送字符 'E'
		data[84] = {12'h045, 5'd0, `ITYPE_ADDI, 5'd31, `OPCODE_ITYPE};				// ADDI: x31 = 'E' (0x45)
		data[85] = {12'd0, 5'd28, `LOAD_LW, 5'd30, `OPCODE_LOAD};					// LW x30, 0(x28): 读取 UART 状态寄存器
		data[86] = {12'd1, 5'd30, `ITYPE_ANDI, 5'd30, `OPCODE_ITYPE};				// ANDI x30, x30, 1: 使用 ANDI 提取 Busy 位
		data[87] = {1'b1, 6'b111111, 5'd0, 5'd30, `BRANCH_BNE, 4'b1100, 1'b1, `OPCODE_BRANCH}; // BNE x30, x0, -8: 如果 Busy 位为 1，则跳回前面的指令重新尝试
		data[88] = {7'd0, 5'd31, 5'd29, `STORE_SB, 5'd0, `OPCODE_STORE};				// SB: mem[x29+0] = 'E'

		// 发送字符 'B'
		data[89] = {12'h042, 5'd0, `ITYPE_ADDI, 5'd31, `OPCODE_ITYPE};				// ADDI: x31 = 'B' (0x42)
		data[90] = {12'd0, 5'd28, `LOAD_LW, 5'd30, `OPCODE_LOAD};					// LW x30, 0(x28): 读取 UART 状态寄存器
		data[91] = {12'd1, 5'd30, `ITYPE_ANDI, 5'd30, `OPCODE_ITYPE};				// ANDI x30, x30, 1: 使用 ANDI 提取 Busy 位
		data[92] = {1'b1, 6'b111111, 5'd0, 5'd30, `BRANCH_BNE, 4'b1100, 1'b1, `OPCODE_BRANCH}; // BNE x30, x0, -8: 如果 Busy 位为 1，则跳回前面的指令重新尝试
		data[93] = {7'd0, 5'd31, 5'd29, `STORE_SB, 5'd0, `OPCODE_STORE};				// SB: mem[x29+0] = 'B'

		// 发送字符 'E'
		data[94] = {12'h045, 5'd0, `ITYPE_ADDI, 5'd31, `OPCODE_ITYPE};				// ADDI: x31 = 'E' (0x45)
		data[95] = {12'd0, 5'd28, `LOAD_LW, 5'd30, `OPCODE_LOAD};					// LW x30, 0(x28): 读取 UART 状态寄存器
		data[96] = {12'd1, 5'd30, `ITYPE_ANDI, 5'd30, `OPCODE_ITYPE};				// ANDI x30, x30, 1: 使用 ANDI 提取 Busy 位
		data[97] = {1'b1, 6'b111111, 5'd0, 5'd30, `BRANCH_BNE, 4'b1100, 1'b1, `OPCODE_BRANCH}; // BNE x30, x0, -8: 如果 Busy 位为 1，则跳回前面的指令重新尝试
		data[98] = {7'd0, 5'd31, 5'd29, `STORE_SB, 5'd0, `OPCODE_STORE};				// SB: mem[x29+0] = 'E'

		// ──────────────────────────────────────────────
		// [新增] 测试 RV32M 硬件乘法器扩展
		// addi x1, x0, 12
		// addi x2, x0, 10
		// mul x3, x1, x2  (期望 x3 最终等于 120, 即 0x78)
		data[100] = {12'd12, 5'd0, `ITYPE_ADDI, 5'd1, `OPCODE_ITYPE}; 
		data[101] = {12'd10, 5'd0, `ITYPE_ADDI, 5'd2, `OPCODE_ITYPE}; 
		data[102] = {7'b0000001, 5'd2, 5'd1, 3'b000, 5'd3, `OPCODE_RTYPE}; // MUL x3, x1, x2
		
		data[103] = {1'b1, 10'b1110101000, 1'b1, 8'b11111111, 5'd0, `OPCODE_JAL};		// JAL x0, -176: 跳转到 data[55] (返回 EBREAK)

		// ──────────────────────────────────────────────
		// 异常处理程序 (Trap Handler) 的入口地址。mtvec 寄存器指向 0x1000 (即十进制 4096)，对应数组索引 1024
		// 正常情况下，进入 Trap Handler 时需要将通用寄存器(GPR)压入堆栈保存，但当前单周期阶段为了简化予以省略。
		// 检查 CSR 中的 mcause (异常原因) 寄存器：如果是 ecall 则清空 x1，如果是地址未对齐异常则将 x2 加 0xFF
		// 准备条件分支：加载用于比较的常量值 (如 ECALL 代码 11 等)
		data[1024] = {12'h342, 5'd0, 3'b010, 5'd6, `OPCODE_ENVIRONMENT}; 					// csrrs x6, mcause, x0:	将 mcause 寄存器的值加载到 x6 寄存器
		data[1025] = {12'd11, 5'd0, `ITYPE_ADDI, 5'd7, `OPCODE_ITYPE};						// addi x7, x0, 11: 		将 ECALL 的异常代码 (11) 加载到 x7
		data[1026] = {12'd2, 5'd0, `ITYPE_ADDI, 5'd8, `OPCODE_ITYPE};						// addi x8, x0, 2: 			将 ILLEGAL INSTRUCTION 的异常代码 (2) 加载到 x8
		data[1027] = {12'd4, 5'd0, `ITYPE_ADDI, 5'd9, `OPCODE_ITYPE};						// addi x9, x0, 4: 			将 MISALIGNED LOAD 的异常代码 (4) 加载到 x9
		data[1028] = {12'd6, 5'd0, `ITYPE_ADDI, 5'd10, `OPCODE_ITYPE};						// addi x10, x0, 6: 		将 MISALIGNED STORE 的异常代码 (6) 加载到 x10

		// 分析 mcause 寄存器的值，并跳转到对应的异常处理子程序
		data[1029] = {1'b0, 6'b0, 5'd7, 5'd6, `BRANCH_BEQ, 4'b1100, 1'b0, `OPCODE_BRANCH};	// beq x6, x7, +24: 		ECALL; 如果 x6 == x7 (发生了ECALL)，则跳转到 24 字节后的地址，即 data[1035]
		data[1030] = {1'b0, 6'd0, 5'd0, 5'd6, `BRANCH_BEQ, 4'b1110, 1'b0, `OPCODE_BRANCH};	// beq x6, x0, +28: 		MISALIGNED INSTRUCTION; 如果 x6 == 0 (非法指令)，则跳转到 28 字节后的地址，即 data[1037]
		data[1031] = {1'b0, 6'd0, 5'd10, 5'd6, `BRANCH_BEQ, 4'b1100, 1'b0, `OPCODE_BRANCH};	// beq x6, x10, +24: 		MISALIGNED STORE; 如果 x6 == x10 (Store未对齐)，则跳转到 24 字节后的地址，即 data[1037]
		data[1032] = {1'b0, 6'd0, 5'd9, 5'd6, `BRANCH_BEQ, 4'b1010, 1'b0, `OPCODE_BRANCH};	// beq x6, x9, +20: 		MISALIGNED LOAD; 如果 x6 == x9 (Load未对齐)，则跳转到 20 字节后的地址，即 data[1037]
		data[1033] = {1'b0, 6'd0, 5'd8, 5'd6, `BRANCH_BEQ, 4'b1000, 1'b0, `OPCODE_BRANCH};	// beq x6, x8, +16: 		ILLEGAL; 如果 x6 == x8 (非法指令)，则跳转到 16 字节后的地址，即 data[1037]
		data[1034] = {1'b0, 10'b000_0001_000, 1'b0, 8'b0, 5'd0, `OPCODE_JAL};				// jal x0, +16: 			结束异常处理 (跳转到 mret 指令准备返回主程序)
		
		// ECALL 异常处理子程序 @ data[1035]
		data[1035] = {12'd0, 5'd0, `ITYPE_ADDI, 5'd1, `OPCODE_ITYPE};						// addi x1, x0, 0: 			将寄存器 x1 清零
		data[1036] = {1'b0, 10'b000_0000_100, 1'b0, 8'b0, 5'd0, `OPCODE_JAL};				// jal x0, +8:				结束异常处理 (跳转到 mret 指令准备返回主程序)

		// 非法指令 / 地址未对齐 异常处理子程序 @ data[1037]
		data[1037] = {12'hFF, 5'd2, `ITYPE_ADDI, 5'd30, `OPCODE_ITYPE};						// addi x30, x2, 255: 		将 x2 的值加上 0xFF 存入 x30，作为异常处理的标记

		// 退出异常处理程序 @ data[1038]
		data[1038] = {12'b001100000010, 5'b0, 3'b0, 5'b0, `OPCODE_ENVIRONMENT};				// MRET: PC = CSR[mepc]

		// HINT; NOP for 'x' signal after MRET in pipeline
		data[1039] = {12'h2BC, 5'd0, `ITYPE_ADDI, 5'd0, `OPCODE_ITYPE};						// ADDI:  x0 = x0 + 2BC = 0000_0000
		data[1040] = {12'h2BC, 5'd0, `ITYPE_ADDI, 5'd0, `OPCODE_ITYPE};						// ADDI:  x0 = x0 + 2BC = 0000_0000
		data[1041] = {12'h2BC, 5'd0, `ITYPE_ADDI, 5'd0, `OPCODE_ITYPE};						// ADDI:  x0 = x0 + 2BC = 0000_0000
		data[1042] = {12'h2BC, 5'd0, `ITYPE_ADDI, 5'd0, `OPCODE_ITYPE};						// ADDI:  x0 = x0 + 2BC = 0000_0000
	end
	

	//当 CPU 运行起来后，pc 的值会不断变化（0, 4, 8, 12...）。
	//always @(*) 的意思是“只要输入发生了变化，立刻执行”。
	always @(*) begin  
		instruction = data[pc[31:2]];
	end

	//最核心的难点：为什么要写 pc[31:2]，而不是直接写 pc？
	// CPU 的 PC 是按字节编号的，第一条指令地址是 0，第二条指令地址是 4，第三条是 8。
	// 但是我们的 data 数组是按**格子（字）**编号的，0号格子，1号格子，2号格子。
	// 如果你直接查 data[4]，就越界拿错了！
	// 怎么把 4 变成 1，把 8 变成 2？很简单，除以 4。
	// 在二进制里，截断最后两位（[31:2] 就是抛弃第 0 位和第 1 位），就等于在数学上除以 4 并向下取整！ 
//这样，CPU 传过来地址 4，内存立刻返回 data[1] 里的内容；传过来地址 8，立刻返回 data[2] 里的内容。这就是这行代码的精妙之处。

	wire rom_access = (rom_address[31:16] == 16'h0000);
	always @(*) begin
		if (rom_access) begin
			rom_read_data = data[rom_address[15:2]];
		end else begin
			rom_read_data = 32'b0;
		end
	end
endmodule