// 寄存器堆（Register File）模块
// 该模块模拟了 RISC-V 处理器中的 32 个 32 位通用寄存器。
// 它包含两个异步的读端口和一个同步的写端口，并实现了内部数据转发（Bypass）以解决 RAW（写后读）数据冒险。
// 异步瞬间读取，同步等待时钟写入

module RegisterFile (
    input clk,                      // 时钟信号：用于控制写入操作的同步
    input [4:0] read_reg1,          // 读端口 1：需要读取的源寄存器 1 的编号 (0~31)
    input [4:0] read_reg2,          // 读端口 2：需要读取的源寄存器 2 的编号 (0~31)
    input [4:0] write_reg,          // 写端口：需要写入的目标寄存器的编号 (0~31)
    input [31:0] write_data,        // 写数据：即将写入到目标寄存器中的 32 位数据
    input write_enable,             // 写使能信号：为 1 时才允许将数据写入到寄存器中
	
    output reg [31:0] read_data1,   // 读出数据 1：从读端口 1 取出的 32 位数据
    output reg [31:0] read_data2    // 读出数据 2：从读端口 2 取出的 32 位数据
);

    // 定义 32 个 32 位宽的寄存器数组，用于存储真实数据
    reg [31:0] registers [0:31]; 
    
    // 初始化模块：在仿真开始时将所有寄存器清零，防止出现未知状态 (X态)
    integer i;
    initial begin
        for (i = 1; i < 32; i = i + 1) registers[i] = 32'b0;
    end

    // -------------------------------------------------------------------------
    // 读操作 (异步读取 + bypass)
    // 异步就是瞬间读取，不需要等时钟来：只要 read_reg1 或 read_reg2 发生变化，读出的数据就会立刻变化，无需等待时钟边沿。
    // -------------------------------------------------------------------------
    always @(*) begin
        // 读取寄存器 1 的逻辑
        if (read_reg1 == 5'd0) begin
            // 规则：RISC-V 规定 0 号寄存器 (x0) 必须恒等于 0。
            // 不管发生什么，只要是读 0 号寄存器，直接输出 0。
            read_data1 = 32'd0;
        end
        else if (write_enable && (write_reg == read_reg1)) begin
            // 内部数据转发（Internal Forwarding / Bypass）逻辑：
            // 解决写后读（RAW）冲突：如果我们现在正打算向某个寄存器写入数据，而恰好此时也要读取这个寄存器。
            // 因为写入是等到“下一个时钟上升沿”才落盘到物理寄存器中，此时从 registers 数组里读出来的还是旧数据。
            // 为了保证读到的是“最新”的值，我们直接把即将写入的数据 (write_data) 拦截并转发给读出端口。

            //这段代码的意思是，每次执行读操作前，门卫先核对一下身份：
            // 1.现在有写入任务正在进行吗？（write_enable 是真吗？）
            // 2.你要读的寄存器，恰好就是现在正准备写入的那个寄存器吗？（write_reg == read_reg1 吗？）
            read_data1 = write_data;
        end
        else begin
            // 正常情况：直接从寄存器数组中读出数据
            read_data1 = registers[read_reg1];
        end

        // 读取寄存器 2 的逻辑（原理与上面完全相同）
        if (read_reg2 == 5'd0) begin
            read_data2 = 32'd0;
        end
        else if (write_enable && (write_reg == read_reg2)) begin
            read_data2 = write_data;
        end
        else begin
            read_data2 = registers[read_reg2];
        end
    end

    // -------------------------------------------------------------------------
    // 写操作 (同步写入)
    // -------------------------------------------------------------------------
    always @(posedge clk) begin
        // 只有在写使能 (write_enable) 为 1，且写入目标不是 0 号寄存器 (x0) 的情况下，才允许修改物理寄存器。
        // 因为 x0 是硬连线的常数 0，且必须是 0，绝对不能当作临时变量来用，给他赋别的值。
        if (write_enable && write_reg != 5'd0) begin
            registers[write_reg] <= write_data; 
        end
    end


endmodule


/*always 里面什么时候用<= 什么时候用= 

它是用来区分**“连线（组合逻辑）”和“触发器（时序逻辑）”**的。
在 Verilog 中有一条必须死记硬背的黄金法则：

1. always @(*)（组合逻辑）里面，永远用 =（阻塞赋值）。
2. always @(posedge clk)（时序逻辑）里面，永远用 <=（非阻塞赋值）。
*/