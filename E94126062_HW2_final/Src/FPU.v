`include "../Src/FPU_comparator.v"
`include "../Src/FPU_adder.v"
module FPU(
    input clk,
    input rst,
    input enable,
    input [1:0] instruction,
    input [31:0] ai,
    input [31:0] bi,
    output reg [31:0] co,
    output reg valid
);

//put ur design here

wire sub;
wire mode;
wire [31:0] adder_output;
wire adder_output_ready;
wire [31:0] comparator_output;

FPU_adder adder(
	.input_a(ai),
	.input_b(bi),
	.enable(enable),
	.sub(sub),
	.clk(clk),
	.rst(rst),
	.output_c(adder_output),
	.output_c_ready(adder_output_ready)
);

FPU_comparator comparator(
    .A(ai),
    .B(bi),
    .mode(mode), 
    .answer(comparator_output)       
);

assign sub = (instruction == 2'b11);
assign mode = (instruction == 2'b01);


parameter waitanswer = 2'b00;
parameter adderoutput = 2'b01;
parameter comparatoroutput = 2'b10;

reg [1:0] current_state, next_state;

always @(posedge clk or posedge rst) begin
	if (rst) begin
		co <= 32'b0;
		valid <= 1'b0;
		current_state <= waitanswer;
	end
	else begin
		current_state <= next_state;
		case (current_state) 
			waitanswer: begin
				valid <= 1'b0;
				co <= 32'b0;
			end
			adderoutput: begin
				if (adder_output_ready) begin
					valid <= 1'b1;
					co <= adder_output;
				end
				else begin
					valid <= 1'b0;
					co <= 32'b0;
				end
			end
			comparatoroutput: begin
				valid <= 1'b1;
				co <= comparator_output;
			end
			default: begin
				valid <= 1'b0;
				co <= 32'b0;
			end
		endcase
	end
end

always @(*) begin

	case(current_state)
		waitanswer: begin
			if (enable) begin
				next_state = (instruction < 2'b10) ? comparatoroutput : adderoutput;
			end
			else begin
				next_state = current_state;
			end
		end
		adderoutput: begin
			next_state = (adder_output_ready) ? waitanswer : adderoutput;
		end
		comparatoroutput: begin
			next_state = waitanswer;
		end
		default: begin
			next_state = waitanswer;
		end
	endcase
end



endmodule
