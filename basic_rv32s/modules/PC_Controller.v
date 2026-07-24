module PCController (
    input jump, 				// signal indicating if PC should jump
	input branch_estimation,	// signal indicating if PC should take the branch
	input branch_prediction_miss,	
	input trapped,				// signal indicating if trap has occurred
	input [31:0] pc,			// current pc value
	input [31:0] jump_target,	// target address for jump
	input [31:0] branch_target, // target address for branch from branch predictor
	input [31:0] branch_target_actual, // actual branch target address when mispredicted
	input [31:0] trap_target,	// target address for trap
	input pc_stall,				// signal indicating if pc update should be paused

	output reg [31:0] next_pc	// next pc value
);

    always @(*) begin
		// 第 1 优先级：停止（Stall）- 流水线暂停，PC原地踏步
		if (!pc_stall) begin
			// 第 2 优先级：异常陷阱（Trap）- 发生异常，最高优先级的强制跳转
			if (trapped) begin
				next_pc = trap_target;
			end
			// 第 3 优先级：绝对跳转（Jump）- 执行 jal/jalr 等函数跳转指令
			else if (trapped == 1'b0 && jump) begin
				next_pc = jump_target;
			end
			// 第 4 优先级：分支预测失败回滚（Mispredict）- 之前猜错了，强行修正回真实正确的路线
			else if (trapped == 1'b0 && branch_prediction_miss) begin
				next_pc = branch_target_actual;
			end
			// 第 5 优先级：分支预测跳转（Branch Estimation）- 遇到if觉得大概率要跳，先跳过去试试
			else if (trapped == 1'b0 && branch_estimation) begin
				next_pc = branch_target;
			end
			// 最底层（默认）：平平淡淡才是真（PC + 4）- 无任何特殊情况，顺序执行下一条指令
			else begin
				next_pc = pc + 4;
			end
		end
		else begin
			next_pc = pc;
		end
    end

endmodule