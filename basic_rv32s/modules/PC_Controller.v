module PCController (
    input jump, 				// signal indicating if PC should jump (from EX stage, for backward compatibility)
    input ID_jump,              // signal indicating if PC should jump (from ID stage, for JAL/JALR)
	input branch_estimation,	// signal indicating if PC should take the branch
	input branch_prediction_miss,
	input trapped,				// signal indicating if trap has occurred
	input [31:0] pc,			// current pc value
	input [31:0] jump_target,	// target address for jump (from EX stage)
	input [31:0] ID_jump_target, // target address for jump (from ID stage)
	input [31:0] branch_target, // target address for branch from branch predictor
	input [31:0] branch_target_actual, // actual branch target address when mispredicted
	input [31:0] trap_target,	// target address for trap
	input pc_stall,				// signal indicating if pc update should be paused
    input trap_jump,            // signal from TrapController to jump to trap_target

	output reg [31:0] next_pc	// next pc value
);

    always @(*) begin
        // Redirects must win over a fetch stall.  EX control-flow signals are
        // held while the serialized I-cache request is outstanding; masking
        // them with pc_stall would lose the redirect permanently.
        if (trap_jump)
            next_pc = trap_target;
        else if (!trapped && ID_jump)
            next_pc = ID_jump_target;
        else if (!trapped && jump)
            next_pc = jump_target;
        else if (!trapped && branch_prediction_miss)
            next_pc = branch_target_actual;
        else if (pc_stall)
            next_pc = pc;
        else if (!trapped && branch_estimation)
            next_pc = branch_target;
        else
            next_pc = pc + 4;
    end

endmodule
