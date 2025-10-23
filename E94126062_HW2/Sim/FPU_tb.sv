`timescale 1ns/1ps
`define MAX 100000 // Max cycle number
`include "../Src/FPU.v"
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
    

    `ifdef probA
        fd = $fopen("./pattern/pattern1.csv","r");
    `elsif probB
        fd = $fopen("./pattern/pattern2.csv","r");
    `elsif probC
        fd = $fopen("./pattern/pattern3.csv","r");
    `else
        fd = $fopen("./pattern/pattern1.csv","r");
        $error("cannot open pattern file , auto use pattern1");
    `endif


    if (fd == 0) begin  
      $finish;
    end

    n_total = 0; n_pass = 0; n_fail = 0; line_no = 0;
    

    while (!$feof(fd)) begin
      line_no++;
      void'($fgets(line, fd));
      if (line.len() == 0) continue;

      nread = $sscanf(line, "%h,%h,%h,%h", a_hex, b_hex, exp_hex,in);
      if (nread != 4) begin
        continue;
      end

      send_and_check(a_hex,b_hex,exp_hex,in);

    end
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
