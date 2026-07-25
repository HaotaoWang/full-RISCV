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
		// 初始化data数组，使其填满空指令。addi x0, x0, 0x2bc
		for (i=0; i<2048; i=i+1) begin
			data[i] = {12'h2BC, 5'd0, `ITYPE_ADDI, 5'd0, `OPCODE_ITYPE};
		end

		// 读取自动生成的测试程序
		$readmemh("smode_test.hex", data);
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