// ============================================================================
// AXI4-Lite RAM with Hex File Initialization
// ============================================================================
// 基于 verilog-axi/rtl/axil_ram.v 的接口规范重新实现
// 新增功能: 支持通过 $readmemh 从 .hex 文件加载初始程序
// 注意: 这是独立的新文件，没有修改 verilog-axi 仓库中的任何代码
// ============================================================================

`timescale 1ns / 1ps

module axil_ram_init #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 16,
    parameter STRB_WIDTH = (DATA_WIDTH/8),
    parameter PIPELINE_OUTPUT = 0,
    parameter INIT_FILE = ""           // 新增: 初始化 hex 文件路径
)(
    input  wire                   clk,
    input  wire                   rst,

    input  wire [ADDR_WIDTH-1:0]  s_axil_awaddr,
    input  wire [2:0]             s_axil_awprot,
    input  wire                   s_axil_awvalid,
    output wire                   s_axil_awready,
    input  wire [DATA_WIDTH-1:0]  s_axil_wdata,
    input  wire [STRB_WIDTH-1:0]  s_axil_wstrb,
    input  wire                   s_axil_wvalid,
    output wire                   s_axil_wready,
    output wire [1:0]             s_axil_bresp,
    output wire                   s_axil_bvalid,
    input  wire                   s_axil_bready,
    input  wire [ADDR_WIDTH-1:0]  s_axil_araddr,
    input  wire [2:0]             s_axil_arprot,
    input  wire                   s_axil_arvalid,
    output wire                   s_axil_arready,
    output wire [DATA_WIDTH-1:0]  s_axil_rdata,
    output wire [1:0]             s_axil_rresp,
    output wire                   s_axil_rvalid,
    input  wire                   s_axil_rready
);

    parameter VALID_ADDR_WIDTH = ADDR_WIDTH - $clog2(STRB_WIDTH);
    parameter WORD_WIDTH = STRB_WIDTH;
    parameter WORD_SIZE = DATA_WIDTH / WORD_WIDTH;

    // 内部信号
    reg mem_wr_en;
    reg mem_rd_en;

    reg s_axil_awready_reg = 1'b0, s_axil_awready_next;
    reg s_axil_wready_reg  = 1'b0, s_axil_wready_next;
    reg s_axil_bvalid_reg  = 1'b0, s_axil_bvalid_next;
    reg s_axil_arready_reg = 1'b0, s_axil_arready_next;
    reg [DATA_WIDTH-1:0] s_axil_rdata_reg = {DATA_WIDTH{1'b0}}, s_axil_rdata_next;
    reg s_axil_rvalid_reg  = 1'b0, s_axil_rvalid_next;
    reg [DATA_WIDTH-1:0] s_axil_rdata_pipe_reg = {DATA_WIDTH{1'b0}};
    reg s_axil_rvalid_pipe_reg = 1'b0;

    // 存储体
    reg [DATA_WIDTH-1:0] mem [(2**VALID_ADDR_WIDTH)-1:0];

    // 地址转换
    wire [VALID_ADDR_WIDTH-1:0] s_axil_awaddr_valid = s_axil_awaddr >> (ADDR_WIDTH - VALID_ADDR_WIDTH);
    wire [VALID_ADDR_WIDTH-1:0] s_axil_araddr_valid = s_axil_araddr >> (ADDR_WIDTH - VALID_ADDR_WIDTH);

    // 输出连接
    assign s_axil_awready = s_axil_awready_reg;
    assign s_axil_wready  = s_axil_wready_reg;
    assign s_axil_bresp   = 2'b00;
    assign s_axil_bvalid  = s_axil_bvalid_reg;
    assign s_axil_arready = s_axil_arready_reg;
    assign s_axil_rdata   = PIPELINE_OUTPUT ? s_axil_rdata_pipe_reg : s_axil_rdata_reg;
    assign s_axil_rresp   = 2'b00;
    assign s_axil_rvalid  = PIPELINE_OUTPUT ? s_axil_rvalid_pipe_reg : s_axil_rvalid_reg;

    integer i, j;

    // ===== 关键区别: 支持从文件初始化 =====
    initial begin
        for (i = 0; i < 2**VALID_ADDR_WIDTH; i = i + 2**(VALID_ADDR_WIDTH/2)) begin
            for (j = i; j < i + 2**(VALID_ADDR_WIDTH/2); j = j + 1) begin
                mem[j] = 0;
            end
        end
        if (INIT_FILE != "") begin
            $readmemh(INIT_FILE, mem);
            $display("[axil_ram_init] 已从 '%s' 加载初始程序到 RAM", INIT_FILE);
        end
    end

    // 写逻辑
    always @* begin
        mem_wr_en = 1'b0;
        s_axil_awready_next = 1'b0;
        s_axil_wready_next  = 1'b0;
        s_axil_bvalid_next  = s_axil_bvalid_reg && !s_axil_bready;

        if (s_axil_awvalid && s_axil_wvalid && (!s_axil_bvalid || s_axil_bready) && (!s_axil_awready && !s_axil_wready)) begin
            s_axil_awready_next = 1'b1;
            s_axil_wready_next  = 1'b1;
            s_axil_bvalid_next  = 1'b1;
            mem_wr_en = 1'b1;
        end
    end

    always @(posedge clk) begin
        s_axil_awready_reg <= s_axil_awready_next;
        s_axil_wready_reg  <= s_axil_wready_next;
        s_axil_bvalid_reg  <= s_axil_bvalid_next;

        for (i = 0; i < WORD_WIDTH; i = i + 1) begin
            if (mem_wr_en && s_axil_wstrb[i]) begin
                mem[s_axil_awaddr_valid][WORD_SIZE*i +: WORD_SIZE] <= s_axil_wdata[WORD_SIZE*i +: WORD_SIZE];
            end
        end

        if (rst) begin
            s_axil_awready_reg <= 1'b0;
            s_axil_wready_reg  <= 1'b0;
            s_axil_bvalid_reg  <= 1'b0;
        end
    end

    // 读逻辑
    always @* begin
        mem_rd_en = 1'b0;
        s_axil_arready_next = 1'b0;
        s_axil_rvalid_next = s_axil_rvalid_reg && !(s_axil_rready || (PIPELINE_OUTPUT && !s_axil_rvalid_pipe_reg));

        if (s_axil_arvalid && (!s_axil_rvalid || s_axil_rready || (PIPELINE_OUTPUT && !s_axil_rvalid_pipe_reg)) && (!s_axil_arready)) begin
            s_axil_arready_next = 1'b1;
            s_axil_rvalid_next  = 1'b1;
            mem_rd_en = 1'b1;
        end
    end

    always @(posedge clk) begin
        s_axil_arready_reg <= s_axil_arready_next;
        s_axil_rvalid_reg  <= s_axil_rvalid_next;

        if (mem_rd_en) begin
            s_axil_rdata_reg <= mem[s_axil_araddr_valid];
        end

        if (!s_axil_rvalid_pipe_reg || s_axil_rready) begin
            s_axil_rdata_pipe_reg  <= s_axil_rdata_reg;
            s_axil_rvalid_pipe_reg <= s_axil_rvalid_reg;
        end

        if (rst) begin
            s_axil_arready_reg     <= 1'b0;
            s_axil_rvalid_reg      <= 1'b0;
            s_axil_rvalid_pipe_reg <= 1'b0;
        end
    end

endmodule
