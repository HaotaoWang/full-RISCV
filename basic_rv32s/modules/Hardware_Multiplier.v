module Hardware_Multiplier (
    input [31:0] src_A,
    input [31:0] src_B,
    input [2:0] mul_op, // funct3 字段: 000=MUL, 001=MULH, 010=MULHSU, 011=MULHU
    output reg [31:0] mul_result
);

    // 有符号和无符号的类型转换
    wire signed [31:0] signed_A = src_A;
    wire signed [31:0] signed_B = src_B;
    
    // Xilinx Vivado 会自动将以下 '*' 运算符综合为 DSP48E1 硬件乘法器硬核
    wire signed [63:0] mul_ss = signed_A * signed_B;                             // 有符号 * 有符号
    wire signed [63:0] mul_su = signed_A * $signed({1'b0, src_B});               // 有符号 * 无符号
    wire [63:0] mul_uu = {32'd0, src_A} * {32'd0, src_B};                        // 无符号 * 无符号
    
    always @(*) begin
        case (mul_op)
            3'b000: mul_result = mul_ss[31:0];   // MUL    (取低32位，有符号无符号都一样)
            3'b001: mul_result = mul_ss[63:32];  // MULH   (有符号高32位)
            3'b010: mul_result = mul_su[63:32];  // MULHSU (有符号-无符号高32位)
            3'b011: mul_result = mul_uu[63:32];  // MULHU  (无符号高32位)
            default: mul_result = 32'd0;
        endcase
    end
endmodule
