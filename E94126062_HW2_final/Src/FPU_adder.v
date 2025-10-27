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

	reg [2:0] current_state, next_state;

	//unpack para declare
	reg a_sign;
	reg [7:0] a_exp;
	reg [26:0] a_mantissa;
  reg [26:0] a_alige;
	reg [26:0] a_shifted;

	reg b_sign;
	reg [7:0] b_exp;
	reg [26:0] b_mantissa;
  reg [26:0] b_alige;
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

	reg a_is_NaN,b_is_NaN,a_is_inf,b_is_inf,a_is_zero,b_is_zero,a_b_sign_diff ;

	always @(posedge clk or posedge rst) begin
		if (rst)
			current_state <= IDLE;
		else 
			current_state <= next_state;
	end

	always @(*) begin
    
    		output_c_ready = 1'b0;
    		next_state = current_state;

		case (current_state) 
			
			IDLE: begin 
				output_c_ready = 1'b0;
				if (enable) 
					next_state = unpack;
				else 
					next_state = current_state;
			end

			unpack: begin
				a_sign = input_a[31];
				// a_exp = $signed(input_a[30:23]-8'd127);
				a_exp = input_a[30:23];
				a_mantissa = (a_exp == 8'h00) ? {1'b0,input_a[22:0],3'b0} : {1'b1,input_a[22:0],3'b0};
        			a_shifted = a_mantissa;
        			a_alige = a_mantissa;


				b_sign = input_b[31];
				// b_exp = $signed(input_b[30:23]-8'd127);
				b_exp = input_b[30:23];
				b_mantissa = (b_exp == 8'h00) ? {1'b0,input_b[22:0],3'b0} : {1'b1,input_b[22:0],3'b0};
        			b_shifted = b_mantissa;
        			b_alige = b_mantissa;
				next_state = specialcase;
			end

			specialcase: begin
			
				a_is_NaN = (input_a[30:23] == 8'hFF) && (input_a[22:0] != 23'b0);
				a_is_inf = (input_a[30:23] == 8'hFF) && (input_a[22:0] == 23'b0);
				b_is_NaN = (input_b[30:23] == 8'hFF) && (input_b[22:0] != 23'b0);
				b_is_inf = (input_b[30:23] == 8'hFF) && (input_b[22:0] == 23'b0);
				a_is_zero = (input_a[30:23] == 8'h00) && (input_a[22:0] == 23'b0);
				b_is_zero = (input_b[30:23] == 8'h00) && (input_b[22:0] == 23'b0);
				a_b_sign_diff = (input_a[31] != input_b[31]);
				
				// any NaN in operanc
				if (a_is_NaN || b_is_NaN) begin						
					output_c = 32'hFFC00000;
					next_state = DONE;
				end
				// Sign mismatch Inf(+∞ + -∞)
				else if (a_is_inf && b_is_inf && a_b_sign_diff) begin       
					output_c = 32'hFFC00000;
					next_state = DONE;		
				end							
				// Any Inf in operand (except sign mismatch)
				else if (a_is_inf || b_is_inf) begin					
					output_c = (a_is_inf == 1'b1) ? input_a : input_b;
					next_state = DONE;
				end
				// 0+0
				else if (a_is_zero && b_is_zero) begin					
					output_c = (a_b_sign_diff == 1'b1) ? 32'h00000000 : input_a;
					next_state = DONE;
				end
				// 0+another
				else if (a_is_zero || b_is_zero) begin						
					output_c = (a_is_zero == 1'b1) ? input_b : input_a;
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
					exp_shift_count = (b_exp - a_exp > 8'd27) ? 5'd27 : (b_exp - a_exp);
					shifted_exp = b_exp;

					sticky = (exp_shift_count == 5'd27) ? |(a_shifted) : |(a_shifted << (5'd26 - exp_shift_count));

					a_mantissa = a_alige >> exp_shift_count;
				  a_mantissa[0] = sticky;
					next_state = addsub;
				end
				else if (a_exp > b_exp) begin
					exp_shift_count = (a_exp - b_exp > 8'd27) ? 5'd27 : (a_exp - b_exp);
					shifted_exp = a_exp;

					sticky = (exp_shift_count == 5'd27) ? |(b_shifted) : |(b_shifted << (5'd26 - exp_shift_count));

					b_mantissa = b_alige >> exp_shift_count;
					// b_mantissa = b_shifted;
					// b_mantissa[26:1] = b_shifted[26:1];
					b_mantissa[0] = sticky;
					next_state = addsub;
				end
				else begin
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
						add_result_mantissa = (add_result_sign) ? {1'b0, a_mantissa} - {1'b0, b_mantissa} : {1'b0, b_mantissa} - {1'b0, a_mantissa};
						next_state = normalize;
					end
					// a + (-b) or a - b
					{1'b0, 1'b0, 1'b1}, {1'b1, 1'b0, 1'b0}: begin
						add_result_sign = (a_mantissa > b_mantissa) ? 1'b0 : 1'b1;
						add_result_mantissa = (add_result_sign) ? {1'b0, b_mantissa} - {1'b0, a_mantissa} : {1'b0, a_mantissa} - {1'b0, b_mantissa};
						next_state = normalize;
					end
					// (-a) + (-b) or (-a) - b
					{1'b0, 1'b1, 1'b1}, {1'b1, 1'b1, 1'b0}: begin
						add_result_sign = 1'b1;
						add_result_mantissa = a_mantissa + b_mantissa;
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
							normalize_exp = shifted_exp + 8'd1;
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
							normalize_exp = (shifted_exp > man_shift_count) ? shifted_exp - (man_shift_count - 5'd1) : 8'h00;
							normalize_mantissa = add_result_mantissa[26:0] << (man_shift_count - 5'd1) ;
							next_state = pack;
						end	
					end
				endcase
			end

			pack: begin
				//round and pack
				output_c[31] = add_result_sign;
				output_c[30:23] = normalize_exp;
				casez (normalize_mantissa[2:0])
					3'b0??: begin
						output_c[22:0] = normalize_mantissa[25:3];
						next_state = DONE;
					end
					3'b110,3'b101,3'b111: begin
						output_c[22:0] = normalize_mantissa[25:3] + 23'd1;
						next_state = DONE;
					end
					3'b100: begin
						output_c[22:0] = (normalize_mantissa[3]) ? normalize_mantissa[25:3] + 23'd1 : normalize_mantissa[25:3];
						next_state = DONE;
					end
					default: begin
						output_c[22:0] = normalize_mantissa[25:3];
						next_state = DONE;
					end
				endcase
			end
				
			DONE: begin
				output_c_ready = 1'b1;
				next_state = IDLE;
			end

		endcase
	end

  function [4:0] lead_zeros;
      input [27:0] mantissa;
      begin
          casez (mantissa)
              28'b1???????????????????????????: lead_zeros = 5'd0;
              28'b01??????????????????????????: lead_zeros = 5'd1;
              28'b001?????????????????????????: lead_zeros = 5'd2;
              28'b0001????????????????????????: lead_zeros = 5'd3;
              28'b00001???????????????????????: lead_zeros = 5'd4;
              28'b000001??????????????????????: lead_zeros = 5'd5;
              28'b0000001?????????????????????: lead_zeros = 5'd6;
              28'b00000001????????????????????: lead_zeros = 5'd7;
              28'b000000001???????????????????: lead_zeros = 5'd8;
              28'b0000000001??????????????????: lead_zeros = 5'd9;
              28'b00000000001?????????????????: lead_zeros = 5'd10;
              28'b000000000001????????????????: lead_zeros = 5'd11;
              28'b0000000000001???????????????: lead_zeros = 5'd12;
              28'b00000000000001??????????????: lead_zeros = 5'd13;
              28'b000000000000001?????????????: lead_zeros = 5'd14;
              28'b0000000000000001????????????: lead_zeros = 5'd15;
              28'b00000000000000001???????????: lead_zeros = 5'd16;
              28'b000000000000000001??????????: lead_zeros = 5'd17;
              28'b0000000000000000001?????????: lead_zeros = 5'd18;
              28'b00000000000000000001????????: lead_zeros = 5'd19;
              28'b000000000000000000001???????: lead_zeros = 5'd20;
              28'b0000000000000000000001??????: lead_zeros = 5'd21;
              28'b00000000000000000000001?????: lead_zeros = 5'd22;
              28'b000000000000000000000001????: lead_zeros = 5'd23;
              28'b0000000000000000000000001???: lead_zeros = 5'd24;
              28'b00000000000000000000000001??: lead_zeros = 5'd25;
              28'b000000000000000000000000001?: lead_zeros = 5'd26;
              28'b0000000000000000000000000001: lead_zeros = 5'd27;
              default: lead_zeros = 5'd28; // 全 0
          endcase
      end
  endfunction

endmodule        
