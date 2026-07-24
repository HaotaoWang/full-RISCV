module MMIO_Interface (
    input clk,
    input reset,
    input [31:0] data_memory_write_data,
    input [31:0] data_memory_address,
    input data_memory_write_enable,
    input UART_busy,

    output reg [7:0] mmio_uart_tx_data,
    output [31:0] mmio_uart_status,
    output reg mmio_uart_tx_start,
    output mmio_uart_status_hit,
    output reg [3:0] mmio_led
);

    localparam UART_TX_ADDR = 32'h10010000;     // Write-Only
    localparam UART_STATUS_ADDR = 32'h10010004; // Read-Only
    localparam LED_ADDR = 32'h10020000;         // Write-Only for LEDs

    wire uart_tx_hit = (data_memory_address == UART_TX_ADDR);
    wire uart_stat_hit = (data_memory_address == UART_STATUS_ADDR);
    wire led_hit = (data_memory_address == LED_ADDR);
    
    assign mmio_uart_status_hit = uart_tx_hit || uart_stat_hit || led_hit;
    assign mmio_uart_status = uart_stat_hit ? {31'h0, UART_busy} : 32'h0;

    always @ (posedge clk or posedge reset) begin
        if (reset) begin
            mmio_uart_tx_data <= 8'h0;
            mmio_uart_tx_start <= 1'b0;
            mmio_led <= 4'b0000;
        end else begin
            mmio_uart_tx_start <= 1'b0;

            if (data_memory_write_enable && uart_tx_hit && !UART_busy) begin
                mmio_uart_tx_data <= data_memory_write_data[7:0];
                mmio_uart_tx_start <= 1'b1;
            end
            
            if (data_memory_write_enable && led_hit) begin
                mmio_led <= data_memory_write_data[3:0];
            end
        end
    end


endmodule