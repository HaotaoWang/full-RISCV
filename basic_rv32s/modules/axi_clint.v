/*
 * AXI4 Compatible Core Local Interruptor (CLINT)
 * Memory map conforms to standard RISC-V CLINT specification:
 *   0x4000: mtimecmp (lower 32 bits)
 *   0x4004: mtimecmp (upper 32 bits)
 *   0xBFF8: mtime (lower 32 bits)
 *   0xBFFC: mtime (upper 32 bits)
 */

module axi_clint #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32,
    parameter ID_WIDTH = 4
) (
    input  wire clk,
    input  wire rst,

    // AXI4 Slave Interface
    input  wire [ID_WIDTH-1:0]    s_axi_awid,
    input  wire [ADDR_WIDTH-1:0]  s_axi_awaddr,
    input  wire [7:0]             s_axi_awlen,
    input  wire [2:0]             s_axi_awsize,
    input  wire [1:0]             s_axi_awburst,
    input  wire                   s_axi_awvalid,
    output reg                    s_axi_awready,
    input  wire [DATA_WIDTH-1:0]  s_axi_wdata,
    input  wire [3:0]             s_axi_wstrb,
    input  wire                   s_axi_wlast,
    input  wire                   s_axi_wvalid,
    output reg                    s_axi_wready,
    output reg  [ID_WIDTH-1:0]    s_axi_bid,
    output wire [1:0]             s_axi_bresp,
    output reg                    s_axi_bvalid,
    input  wire                   s_axi_bready,
    input  wire [ID_WIDTH-1:0]    s_axi_arid,
    input  wire [ADDR_WIDTH-1:0]  s_axi_araddr,
    input  wire [7:0]             s_axi_arlen,
    input  wire [2:0]             s_axi_arsize,
    input  wire [1:0]             s_axi_arburst,
    input  wire                   s_axi_arvalid,
    output reg                    s_axi_arready,
    output reg  [ID_WIDTH-1:0]    s_axi_rid,
    output reg  [DATA_WIDTH-1:0]  s_axi_rdata,
    output wire [1:0]             s_axi_rresp,
    output reg                    s_axi_rlast,
    output reg                    s_axi_rvalid,
    input  wire                   s_axi_rready,

    // Timer Interrupt Output
    output wire timer_irq
);

    assign s_axi_bresp = 2'b00; // OKAY
    assign s_axi_rresp = 2'b00; // OKAY

    // CLINT Registers
    reg [63:0] mtime;
    reg [63:0] mtimecmp;

    // Interrupt Generation (mtime >= mtimecmp)
    assign timer_irq = (mtime >= mtimecmp);

    always @(posedge clk) begin
        if (s_axi_wvalid && s_axi_wready && s_axi_awvalid && s_axi_awready) begin
            $display("[%0d] CLINT WRITE: addr=%x, data=%x, mtime=%d", $time, s_axi_awaddr, s_axi_wdata, mtime);
        end
        if (mtime == mtimecmp && !rst) begin
             $display("[%0d] CLINT TIMER_IRQ ACTIVE! mtime=%d, mtimecmp=%d", $time, mtime, mtimecmp);
        end
    end

    // Timer Increment Logic
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            mtime <= 64'b0;
        end else begin
            mtime <= mtime + 1'b1;
            
            // Handle Memory Mapped Writes to mtime
            if (s_axi_wvalid && s_axi_wready && s_axi_awvalid && s_axi_awready) begin
                if (s_axi_awaddr[15:0] == 16'hBFF8) mtime[31:0]  <= s_axi_wdata;
                if (s_axi_awaddr[15:0] == 16'hBFFC) mtime[63:32] <= s_axi_wdata;
            end
        end
    end

    // mtimecmp Update Logic
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            mtimecmp <= 64'hFFFFFFFF_FFFFFFFF; // Reset to max value so it doesn't fire immediately
        end else begin
            if (s_axi_wvalid && s_axi_wready && s_axi_awvalid && s_axi_awready) begin
                if (s_axi_awaddr[15:0] == 16'h4000) mtimecmp[31:0]  <= s_axi_wdata;
                if (s_axi_awaddr[15:0] == 16'h4004) mtimecmp[63:32] <= s_axi_wdata;
            end
        end
    end

    // --- AXI4 Simplified Write State Machine (Single Beat Only) ---
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            s_axi_awready <= 1'b0;
            s_axi_wready <= 1'b0;
            s_axi_bvalid <= 1'b0;
            s_axi_bid <= {ID_WIDTH{1'b0}};
        end else begin
            if (s_axi_awvalid && !s_axi_awready && s_axi_wvalid && !s_axi_wready) begin
                s_axi_awready <= 1'b1;
                s_axi_wready <= 1'b1;
                s_axi_bid <= s_axi_awid;
            end else begin
                s_axi_awready <= 1'b0;
                s_axi_wready <= 1'b0;
            end
            
            if (s_axi_awready && s_axi_wready) begin
                s_axi_bvalid <= 1'b1;
            end else if (s_axi_bready && s_axi_bvalid) begin
                s_axi_bvalid <= 1'b0;
            end
        end
    end

    // --- AXI4 Simplified Read State Machine (Single Beat Only) ---
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            s_axi_arready <= 1'b0;
            s_axi_rvalid <= 1'b0;
            s_axi_rlast <= 1'b0;
            s_axi_rdata <= 32'b0;
            s_axi_rid <= {ID_WIDTH{1'b0}};
        end else begin
            if (s_axi_arvalid && !s_axi_arready && !s_axi_rvalid) begin
                s_axi_arready <= 1'b1;
                s_axi_rvalid <= 1'b1;
                s_axi_rlast <= 1'b1;
                s_axi_rid <= s_axi_arid;
                
                // Read Multiplexer
                if (s_axi_araddr[15:0] == 16'h4000) s_axi_rdata <= mtimecmp[31:0];
                else if (s_axi_araddr[15:0] == 16'h4004) s_axi_rdata <= mtimecmp[63:32];
                else if (s_axi_araddr[15:0] == 16'hBFF8) s_axi_rdata <= mtime[31:0];
                else if (s_axi_araddr[15:0] == 16'hBFFC) s_axi_rdata <= mtime[63:32];
                else s_axi_rdata <= 32'b0;
                
            end else if (s_axi_rvalid && s_axi_rready) begin
                s_axi_rvalid <= 1'b0;
                s_axi_arready <= 1'b0;
                s_axi_rlast <= 1'b0;
            end else begin
                s_axi_arready <= 1'b0;
            end
        end
    end

endmodule
