`include "modules/headers/opcode.vh"

// 立即数生成器（Immediate Generator）模块
// 该模块负责根据指令的操作码（opcode）提取并符号扩展生成32位立即数。
module ImmediateGenerator (
    input [19:0] raw_imm, 	// 从指令译码器（Instruction Decoder）传入的20位未经符号扩展的原始立即数字段
	input [6:0] opcode,		// 从指令译码器传入的操作码，用于判断指令类型
    output reg [31:0] imm	// 输出生成的32位符号扩展后的立即数
);
	
	always @(*) begin
		case (opcode)
			/* 按照硬件设计的习惯，通常会按照 RISC-V 的 6 种基本指令格式（R、I、S、B、U、J）来划分代码块。 */

			
			// 广义I型指令 包含：JALR（跳转并链接寄存器）、Load（加载）、I型算术指令、FENCE（内存屏障）、系统环境指令
			// 在高位按照符号位拓展
			`OPCODE_JALR, `OPCODE_LOAD, `OPCODE_ITYPE, `OPCODE_FENCE, `OPCODE_ENVIRONMENT: begin 
				// 使用 raw_imm 的最高位（第11位）进行20位的符号扩展，拼接上低12位
				// 在 Verilog 中，{n{x}} 的语法意思是把 x 这个信号连续复制 n 次。 因此，{20{raw_imm[11]}} 的意思就是：把刚才取出来的那个符号位，连续复制 20 遍。
				// 如果符号位是 0，这就变成了 20 个 0；如果符号位是 1，这就变成了 20 个 1。
				imm = {{20{raw_imm[11]}}, raw_imm[11:0]}; //20+12=32位
			end
			// S型指令
			`OPCODE_STORE: begin 
				// S型立即数的扩展方式与I型相同
				imm = {{20{raw_imm[11]}}, raw_imm[11:0]};
			end


			// U型指令 (U-Type):
			// 在低位补零拓展
			//LUI Load Upper Immediate）加载高位立即数 的作用是直接给寄存器的高 20 位赋一个常数。
			//AUIPC (Add Upper Immediate to PC）加上PC的高位立即数 的作用是把立即数的高20位加到当前的PC上，得到一个新的地址。
			`OPCODE_LUI, `OPCODE_AUIPC: begin 
				// 立即数本身就是高20位，直接在低位拼接12个0补齐到32位
				imm = {raw_imm, 12'b0};
			end


			// B型指令 (B-Type): 用于在附近小范围内跳转
			// 在第0位补一个0
			`OPCODE_BRANCH: begin 
				//为什么要在最后补 1'b0？（重点） 
				// 在 RISC-V 架构中，指令的长度要么是 32 位（4 字节），要么是 16 位（2 字节压缩指令）。
				// 也就是说，任何合法指令的内存地址，一定是偶数（最低位永远是 0）。 
				// 为了极致压缩空间，RISC-V 的设计者耍了个聪明：既然跳转地址的最后一位永远是 0，
				// 那我就不在指令里存这个 0 了！ 
				// 所以，传进来的 12 位 raw_imm[11:0]，其实相当于去掉了末尾 0 的缩水版。
				// 在这里我们必须要在它末尾手动补上一个 0 还原它。
				imm = {{19{raw_imm[11]}}, raw_imm[11:0], 1'b0};
				//19（符号扩展）+ 12（数值部分）+ 1（末尾补的0） = 32 位
			end


			// J型指令 (J-Type): JAL（无条件跳转并链接）指令
			// 在第0位补一个0
			`OPCODE_JAL: begin 
				// 取 raw_imm 的最高有效位（第19位）进行11次符号扩展，拼接中间的20位值，并在最后补1个0（偶数地址要求）
				imm = {{11{raw_imm[19]}}, raw_imm[19:0], 1'b0};
				//11（符号扩展）+ 20（数值部分）+ 1（末尾补的0） = 32 位。
			end


			// 其他情况：默认输出全0，防止锁存器（latch）产生
			default: begin
				imm = 32'b0;
			end
        endcase
	end
	
endmodule
