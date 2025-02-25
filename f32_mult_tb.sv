module f32_mult_tb ();

logic clk, rst_n;
logic [31:0] a, b;
logic start, done;
logic [31:0] p;

f32_mult dut (
  .clk(clk),
  .rst_n(rst_n),
  .a(a),
  .b(b),
  .start(start),
  .done(done),
  .p(p)
);

initial begin
  $dumpfile("wave.vcd"); // Specify the VCD file name
  $dumpvars(0, f32_mult_tb);

  clk = 0;
  forever #5 clk = ~clk;
end

initial begin
  $monitor("rst_n=%b, a=%h, b=%h, start=%b, done=%b, p=%h", rst_n, a, b, start, done, p);
  
  rst_n = 0;
  #10 rst_n = 1;
  a = 32'h40200000; // 2.5
  b = 32'h40e00000; // 7.0

  start = 1;
  #10 start = 0;

  #100;
  $finish;
end

endmodule