module Hardware_Multiplier (
    input  wire [31:0] src_A,
    input  wire [31:0] src_B,
    input  wire [2:0]  mul_op,
    output reg  [31:0] mul_result
);

    wire signed [31:0] signed_A = src_A;
    wire signed [31:0] signed_B = src_B;
    wire signed [63:0] mul_ss = signed_A * signed_B;
    wire signed [64:0] mul_su = signed_A * $signed({1'b0, src_B});
    wire        [63:0] mul_uu = src_A * src_B;

    always @(*) begin
        case (mul_op)
            3'b000: mul_result = mul_ss[31:0];
            3'b001: mul_result = mul_ss[63:32];
            3'b010: mul_result = mul_su[63:32];
            3'b011: mul_result = mul_uu[63:32];
            3'b100: begin
                if (src_B == 0)
                    mul_result = 32'hffffffff;
                else if (src_A == 32'h80000000 && src_B == 32'hffffffff)
                    mul_result = 32'h80000000;
                else
                    mul_result = $signed(src_A) / $signed(src_B);
            end
            3'b101: mul_result = (src_B == 0) ? 32'hffffffff : src_A / src_B;
            3'b110: begin
                if (src_B == 0)
                    mul_result = src_A;
                else if (src_A == 32'h80000000 && src_B == 32'hffffffff)
                    mul_result = 32'h00000000;
                else
                    mul_result = $signed(src_A) % $signed(src_B);
            end
            3'b111: mul_result = (src_B == 0) ? src_A : src_A % src_B;
            default: mul_result = 32'd0;
        endcase
    end
endmodule
