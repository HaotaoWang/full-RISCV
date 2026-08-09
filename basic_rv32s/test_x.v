
module test;
    reg out;
    reg cond;
    initial begin
        cond = 1'bx;
        out = 0;
        if (cond) out = 1;
        $display("out=%b", out);
        out = 0;
        if (1'b1 && !cond) out = 1;
        $display("out=%b", out);
    end
endmodule
