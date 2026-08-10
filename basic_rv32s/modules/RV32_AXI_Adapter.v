// RV32 AXI4-Lite Adapter
// Adapted from the brilliant picorv32_axi_adapter
// Translates simple valid/ready memory requests into AXI4-Lite protocol.

module RV32_AXI_Adapter (
    input clk, 
    input reset,

    // ----------------------------------------------------
    // AXI4-Lite Master Interface
    // ----------------------------------------------------
    // Write Address Channel
    output        axi_awvalid,
    input         axi_awready,
    output [31:0] axi_awaddr,
    output [ 2:0] axi_awprot,

    // Write Data Channel
    output        axi_wvalid,
    input         axi_wready,
    output [31:0] axi_wdata,
    output [ 3:0] axi_wstrb,

    // Write Response Channel
    input         axi_bvalid,
    output        axi_bready,

    // Read Address Channel
    output        axi_arvalid,
    input         axi_arready,
    output [31:0] axi_araddr,
    output [ 2:0] axi_arprot,

    // Read Data Channel
    input         axi_rvalid,
    output        axi_rready,
    input  [31:0] axi_rdata,

    // ----------------------------------------------------
    // Native CPU Memory Interface (Simple Handshake)
    // ----------------------------------------------------
    input         mem_valid,
    input         mem_instr, // 1 for Instruction Fetch, 0 for Data Access
    input  [31:0] mem_addr,
    input  [31:0] mem_wdata,
    input  [ 3:0] mem_wstrb, // 0000 indicates a READ operation
    
    output        mem_ready,
    output [31:0] mem_rdata
);

    localparam [2:0] STATE_IDLE       = 3'd0;
    localparam [2:0] STATE_READ_ADDR  = 3'd1;
    localparam [2:0] STATE_READ_DATA  = 3'd2;
    localparam [2:0] STATE_WRITE_SEND = 3'd3;
    localparam [2:0] STATE_WRITE_RESP = 3'd4;
    localparam [2:0] STATE_WAIT_DROP  = 3'd5;

    reg [2:0] state;
    reg [31:0] request_addr;
    reg [31:0] request_wdata;
    reg [3:0] request_wstrb;
    reg request_instr;
    reg aw_sent;
    reg w_sent;

    wire aw_handshake = axi_awvalid && axi_awready;
    wire w_handshake  = axi_wvalid && axi_wready;
    wire ar_handshake = axi_arvalid && axi_arready;
    wire b_handshake  = axi_bvalid && axi_bready;
    wire r_handshake  = axi_rvalid && axi_rready;

    // A native request is captured once in IDLE.  All AXI payloads then come
    // from these registers, so a stalled CPU pipeline cannot change an
    // in-flight transaction.
    assign axi_awvalid = (state == STATE_WRITE_SEND) && !aw_sent;
    assign axi_awaddr  = request_addr;
    assign axi_awprot  = 3'b000;

    assign axi_wvalid  = (state == STATE_WRITE_SEND) && !w_sent;
    assign axi_wdata   = request_wdata;
    assign axi_wstrb   = request_wstrb;

    assign axi_bready  = (state == STATE_WRITE_RESP);

    assign axi_arvalid = (state == STATE_READ_ADDR);
    assign axi_araddr  = request_addr;
    assign axi_arprot  = request_instr ? 3'b100 : 3'b000;

    assign axi_rready  = (state == STATE_READ_DATA);

    // Completion is a single response handshake, not the raw AXI VALID
    // level.  WAIT_DROP prevents a response that remains VALID for another
    // cycle from being replayed into the following native request.
    assign mem_ready = r_handshake || b_handshake;
    assign mem_rdata = axi_rdata;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= STATE_IDLE;
            request_addr <= 32'b0;
            request_wdata <= 32'b0;
            request_wstrb <= 4'b0;
            request_instr <= 1'b0;
            aw_sent <= 1'b0;
            w_sent <= 1'b0;
        end else begin
            case (state)
                STATE_IDLE: begin
                    aw_sent <= 1'b0;
                    w_sent <= 1'b0;
                    if (mem_valid) begin
                        request_addr <= mem_addr;
                        request_wdata <= mem_wdata;
                        request_wstrb <= mem_wstrb;
                        request_instr <= mem_instr;
                        state <= (|mem_wstrb) ? STATE_WRITE_SEND : STATE_READ_ADDR;
                    end
                end

                STATE_READ_ADDR: begin
                    if (ar_handshake)
                        state <= STATE_READ_DATA;
                end

                STATE_READ_DATA: begin
                    if (r_handshake)
                        state <= STATE_WAIT_DROP;
                end

                STATE_WRITE_SEND: begin
                    if (aw_handshake)
                        aw_sent <= 1'b1;
                    if (w_handshake)
                        w_sent <= 1'b1;
                    if ((aw_sent || aw_handshake) &&
                        (w_sent || w_handshake))
                        state <= STATE_WRITE_RESP;
                end

                STATE_WRITE_RESP: begin
                    if (b_handshake)
                        state <= STATE_WAIT_DROP;
                end

                STATE_WAIT_DROP: begin
                    if (!mem_valid)
                        state <= STATE_IDLE;
                end

                default: state <= STATE_IDLE;
            endcase
        end
    end

endmodule
