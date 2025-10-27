`timescale 1ns/1ps
`define MAX 100000 // Max cycle number
`include "FPU.v"
module tb_fp32;
  logic         clk;
  logic         rst;
  logic         start;
  logic [31:0]  a, b;
  logic [31:0]  result;
  logic         ready;
  logic [1:0]   ins;
  initial begin
	clk = 0;
	forever #5 clk = ~clk;
  end

  FPU dut(
	.clk(clk),
	.rst(rst),
	.enable(start),
	.instruction(ins),
	.ai(a),
	.bi(b),
	.co(result),
	.valid(ready)
  );
 

  int fd, line_no, nread;
  string line;
  int unsigned n_total, n_pass, n_fail;

  logic [31:0] a_hex, b_hex, exp_hex;
  logic [1:0] in;
  function automatic bit equal_bits(logic [31:0] x, logic [31:0] y);
	return x === y;
  endfunction

task send_and_check;
	  input [31:0] ai, bi, expected;
	  input [1:0] ii;
	  reg   [31:0] got;
	  begin
		// ? A
	  ins   <= ii;
	  a     <= ai;
	  start <= 1'd1;	  
		// ? B
	  b     <= bi;
	  @(posedge clk);
	  start <= 1'd0;
		// ? Z
		@(posedge clk);
		while (!ready) @(posedge clk);
		got = result;


		n_total = n_total + 1;
		if (equal_bits(got, expected)) begin
		  n_pass = n_pass + 1;
		  //$display("[PASS] A=%h  B=%h  Z=%h", ai, bi, got);
		end else begin
		  n_fail = n_fail + 1;
		  $display("[FAIL] line = %d A=%h  B=%h  GOT=%h  EXP=%h", line_no,ai, bi, got, expected);
		end
	  end
	endtask

  initial begin
	rst   = 1;
	start = 0;
	a     = '0;
	b     = '0;
	#20;
	rst   = 0;
	n_total = 0; n_pass = 0; n_fail = 0; line_no = 0;
	
	///////////////////////////////////
	//    complete it by yourself!!  //
	///////////////////////////////////
	//4FDBC8C7,CFB55925,4E99BE88,2
	a_hex = 32'h4FDBC8C7;
	b_hex = 32'hCFB55925;
	exp_hex = 32'h4E99BE88;
	in = 2'h2;
	send_and_check(a_hex,b_hex,exp_hex,in);
	//CEA6EBF4,CFECCD81,D00B443F,2
	a_hex = 32'hCEA6EBF4;
	b_hex = 32'hCFECCD81;
	exp_hex = 32'hD00B443F;
	in = 2'h2;
	send_and_check(a_hex,b_hex,exp_hex,in);
	//4EC6F5EF,4F92AF81,4FC46CFD,2
	a_hex = 32'h4EC6F5EF;
	b_hex = 32'h4F92AF81;
	exp_hex = 32'h4FC46CFD;
	in = 2'h2;
	send_and_check(a_hex,b_hex,exp_hex,in);
	//CE9CF28A,800EAEBA,CE9CF28A,2
	a_hex = 32'hCE9CF28A;
	b_hex = 32'h800EAEBA;
	exp_hex = 32'hCE9CF28A;
	in = 2'h2;
	send_and_check(a_hex,b_hex,exp_hex,in);
	//4FC7121D,4EF9FBEA,5002C88C,2
	a_hex = 32'h4FC7121D;
	b_hex = 32'h4EF9FBEA;
	exp_hex = 32'h5002C88C;
	in = 2'h2;
	send_and_check(a_hex,b_hex,exp_hex,in);


	#(10*`MAX)
	$fclose(fd);
	$display("TOTAL=%0d PASS=%0d FAIL=%0d", n_total, n_pass, n_fail);
	if (n_fail != 0)begin 
	  $display("   THERE ARE FAILURES                      ");
	  $display("       _______                             ");
	  $display("      |.--+--.|                            ");
	  $display("      ||  |  ||                            ");
	  $display("      ||--`--||                            ");
	  $display("      ||    ,||                            ");
	  $display("      ||  ,' ||                            ");
	  $display("      ||,'   ||                            ");
	  $display("      ||     ||                            ");
	  $display("      ||_____||__                          ");
	  $display("      | ___.  |  `.                        ");
	  $display("      |(x x)) |  ,(                        ");
	  $display("      |`.-,'  |-'_ )                       ");
	  $display("      |______ |\' -'     See u again        ");
	  $display("    _\     /_) )                            ");
	  $display("    '\"`\___//_)'                           ");
	  $display("          ''^                               ");
	end
	else begin            
	  $display("   ALL TEST PASS                           ");
	  $display("       _______                             ");
	  $display("      |.--+--.|                            ");
	  $display("      ||  |  ||                            ");
	  $display("      ||--`--||                            ");
	  $display("      ||    ,||                            ");
	  $display("      ||  ,' ||                            ");
	  $display("      ||,'   ||                            ");
	  $display("      ||     ||                            ");
	  $display("      ||_____||__                          ");
	  $display("      | ___.  |  `.                        ");
	  $display("      |(o o)) |  ,(                        ");
	  $display("      | `--'  |-'_ )                       ");
	  $display("      |______ |\' -'     Good job           ");
	  $display("    _\     /_) )                            ");
	  $display("    '\"`\___//_)'                           ");
	  $display("          ''^                               ");
	end
	$finish;
  end

  initial begin
	`ifdef FSDB
		$dumpfile("FPU.fsdb");
		$dumpvars(0, tb_fp32);
	`endif
  end
endmodule
