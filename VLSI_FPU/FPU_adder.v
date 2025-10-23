module FPU_adder(
	input [31:0] input_a,
	input [31:0] input_b,
	input enable,
	input sub,
	input clk,
	input rst,
	output reg [31:0] output_c,
	output reg output_c_ready);

	//FSM
	parameter IDLE = 3'b000;
	parameter unpack = 3'b001;
	parameter specialcase = 3'b010;
	parameter alignmantissa = 3'b011;
	parameter addsub = 3'b100;
	parameter normalize = 3'b101;
	parameter pack = 3'b110;
	parameter DONE = 3'b111;

	reg [3:0] current_state, next_state;

	//unpack para declare
	reg a_sign;
	reg [7:0] a_exp;
	reg [26:0] a_mantissa;
	reg [26:0] a_shifted;

	reg b_sign;
	reg [7:0] b_exp;
	reg [26:0] b_mantissa;
	reg [26:0] b_shifted;
	reg [4:0] exp_shift_count;
	reg [4:0] man_shift_count;

	reg sticky;
	reg add_result_sign;
	reg [7:0] add_result_exp;
	reg [7:0] shifted_exp;
	reg [27:0] add_result_mantissa;

	reg [7:0] normalize_exp;
	reg [26:0] normalize_mantissa;

	reg a_is_NaN,b_is_NaN,a_is_inf,b_is_inf,a_is_zero,b_is_zero,a_b_signdiff ;

	always @(posedge clk or posedge rst) begin
		if (rst)
			current_state <= IDLE;
		else 
			current_state <= next_state;
	end

	always @(*) begin

		case (current_state) 
			
			IDLE: begin 
				output_c_ready = 0;
				if (enable) 
					next_state = unpack;
				else 
					next_state = current_state;
			end

			unpack: begin
				a_sign = input_a[31];
				// a_exp = $signed(input_a[30:23]-8'd127);
				a_exp = input_a[30:23];
				a_mantissa = (a_exp == 32'h00) ? {1'b0,input_a[22:0],3'b0} : {1'b1,input_a[22:0],3'b0};
				b_sign = input_b[31];
				// b_exp = $signed(input_b[30:23]-8'd127);
				b_exp = input_b[30:23];
				b_mantissa = (b_exp == 32'h00) ? {1'b0,input_b[22:0],3'b0} : {1'b1,input_b[22:0],3'b0};
				next_state = specialcase;
			end

			specialcase: begin
			
				a_is_NaN = (input_a[30:23] == 8'hFF) && (input_a[22:0] != 0);
				a_is_inf = (input_a[30:23] == 8'hFF) && (input_a[22:0] == 0);
				b_is_NaN = (input_b[30:23] == 8'hFF) && (input_b[22:0] != 0);
				b_is_inf = (input_b[30:23] == 8'hFF) && (input_b[22:0] == 0);
				a_is_zero = (input_a[30:23] == 0) && (input_a[22:0] == 0);
				b_is_zero = (input_b[30:23] == 0) && (input_b[22:0] == 0);
				a_b_signdiff = (input_a[31] != input_b[31]);
				
				// any NaN in operanc
				if (a_is_NaN || b_is_NaN) begin						
					output_c = 32'hFFC00000;
					next_state = DONE;
				end
				// Sign mismatch Inf(+∞ + -∞)
				else if (a_is_inf && b_is_inf && a_b_signdiff) begin       
					output_c = 32'hFFC00000;
					next_state = DONE;		
				end							
				// Any Inf in operand (except sign mismatch)
				else if (a_is_inf || b_is_inf) begin					
					output_c = (a_is_inf == 1) ? input_a : input_b;
					next_state = DONE;
				end
				// 0+0
				else if (a_is_zero && b_is_zero) begin					
					output_c = (a_b_signdiff == 1) ? 32'h00000000 : input_a;
					next_state = DONE;
				end
				// 0+another
				else if (a_is_zero || b_is_zero) begin						
					output_c = (a_is_zero == 1) ? input_b : input_a;
					next_state = DONE;
				end
				// A - A = +0, A + (-A) = +0, -A - (-A) = +0, -A + A = +0
				else if ((a_exp == b_exp) && (a_mantissa == b_mantissa)) begin
					case ({a_sign, sub, b_sign})
						{1'b0, 1'b1, 1'b0}, {1'b0, 1'b0, 1'b1}, {1'b1, 1'b1, 1'b1}, {1'b1, 1'b0, 1'b0}: begin
							output_c = 32'h00000000;
							next_state = DONE;
						end
						default: begin
							next_state = alignmantissa;
						end
					endcase
				end
				// no special case
				else begin
					next_state = alignmantissa;
				end
			end

			alignmantissa: begin
				// comparasion and shift
				if (a_exp < b_exp) begin
					exp_shift_count = (b_exp - a_exp > 27) ? 5'd27 : (b_exp - a_exp);
					shifted_exp = b_exp;
					/* 留下來的部分就是前面 27 - exp_shift_count 個 bit，
					然後還要加上原本的S位所以會是 26 - exp_shift_count ，
					用 |() 把所有位元 OR 起來，只要有 1 → sticky = 1。
					*/
					sticky = |(a_mantissa << (26 - exp_shift_count));
					a_shifted = a_mantissa >> exp_shift_count;
					a_mantissa[26:1] = a_shifted[26:1];
					a_mantissa[0] = sticky;
					next_state = addsub;
				end
				else if (a_exp > b_exp) begin
					// (a_exp - b_exp >27) ? exp_shift_count = 27 : (exp_shift_count = a_exp - b_exp);
					exp_shift_count = (a_exp - b_exp > 27) ? 5'd27 : (a_exp - b_exp);
					shifted_exp = a_exp;

					sticky = |(b_mantissa << (26 - exp_shift_count));
					b_shifted = b_mantissa >> exp_shift_count;
					b_mantissa[26:1] = b_shifted[26:1];
					b_mantissa[0] = sticky;
					next_state = addsub;
				end
				else begin
					exp_shift_count = 0;
					shifted_exp = a_exp;
					next_state = addsub;
				end
			end

			addsub: begin
				case ({sub, a_sign , b_sign})
					// a + b or a - (-b)
					{1'b0, 1'b0, 1'b0}, {1'b1, 1'b0, 1'b1}: begin
						add_result_sign = 1'b0;
						add_result_mantissa = a_mantissa + b_mantissa;
						next_state = normalize;
					end
					// (-a) + b or (-a) - (-b)
					{1'b0, 1'b1, 1'b0}, {1'b1, 1'b1, 1'b1}: begin
						add_result_sign = (a_mantissa > b_mantissa) ? 1'b1 : 1'b0;
						add_result_mantissa = (add_result_sign) ? a_mantissa - b_mantissa : b_mantissa - a_mantissa;
						next_state = normalize;
					end
					// a + (-b) or a - b
					{1'b0, 1'b0, 1'b1}, {1'b1, 1'b0, 1'b0}: begin
						add_result_sign = (a_mantissa > b_mantissa) ? 1'b0 : 1'b1;
						add_result_mantissa = (add_result_sign) ? b_mantissa - a_mantissa : a_mantissa - b_mantissa;
						next_state = normalize;
					end
					// (-a) + (-b) or (-a) - b
					{1'b0, 1'b1, 1'b1}, {1'b1, 1'b1, 1'b0}: begin
						add_result_sign = 1'b1;
						add_result_mantissa = a_mantissa + b_mantissa;
						next_state = normalize;
					end

					default: begin
						next_state = normalize;
					end
				endcase
			end

			normalize: begin
				case (add_result_mantissa[27]) 
					/* reg [27:0] add_result_mantissa
					   reg [26:0] normalize_mantissa  */
					1'b1: begin
						if (shifted_exp == 8'hFF) begin
							output_c = 32'h7F800000;
							next_state = DONE;
						end
						else begin
							normalize_exp = shifted_exp + 1;
							sticky = (add_result_mantissa[0] || add_result_mantissa[1]);
							normalize_mantissa = add_result_mantissa >> 1;
							normalize_mantissa[0] = sticky;
							next_state = pack;
						end
					end
					1'b0: begin
						// denormailize number
						if (shifted_exp == 8'd00000000 ) begin
							normalize_mantissa = add_result_mantissa[26:0];
							normalize_exp = shifted_exp;
							next_state = pack;
						end
						else begin
							man_shift_count = lead_zeros(add_result_mantissa);
							normalize_exp = (shifted_exp > man_shift_count) ? shifted_exp - (man_shift_count - 1) : 0;
							normalize_mantissa = add_result_mantissa[26:0] << (man_shift_count -1) ;
							next_state = pack;
						end	
					end
					default: begin
						next_state = pack;
					end
				endcase
			end

			pack: begin
				//round and pack
				output_c[31] = add_result_sign;
				output_c[30:23] = normalize_exp;
				casex (normalize_mantissa[2:0])
					3'b0XX: begin
						output_c[22:0] = normalize_mantissa[25:3];
						next_state = DONE;
					end
					3'b110,3'b101,3'b111: begin
						output_c[22:0] = normalize_mantissa[25:3] + 1'b1;
						next_state = DONE;
					end
					3'b100: begin
						output_c[22:0] = (normalize_mantissa[3]) ? normalize_mantissa[25:3] + 1'b1 : normalize_mantissa[25:3];
						next_state = DONE;
					end
					default: begin
						output_c[22:0] = normalize_mantissa[25:3];
						next_state = DONE;
					end
				endcase
			end
				
			DONE: begin
				output_c_ready = 1;
				next_state = IDLE;
			end

			default: begin
				next_state = IDLE;
			end
		endcase
	end

	function [4:0] lead_zeros;
		input [27:0] mantissa ;
		integer i;
		begin
			for (i=5'd27 ; i >=0 ; i=i-1) begin
				if (mantissa[i]) begin
					lead_zeros = 5'd27-i;
					i = -1;
				end
			end
		end
	endfunction

endmodule        