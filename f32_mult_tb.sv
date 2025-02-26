module f32_mult_tb ();

logic clk, rst_n;
logic [31:0] a, b;
logic start, done;
logic [31:0] p;
logic underflow_o, overflow_o;

f32_mult dut (
  .clk(clk),
  .rst_n(rst_n),
  .a(a),
  .b(b),
  .start(start),
  .done(done),
  .p(p),
  .underflow_o(underflow_o),
  .overflow_o(overflow_o)
);

// Clock generation
initial begin
  clk = 0;
  forever #5 clk = ~clk;
end

// Reset generation
initial begin
  rst_n = 0;
  #10 rst_n = 1;
end

// File handling
integer file;
integer status;
logic [31:0] a_file, b_file, expected_p;

// Error counter
integer error_count = 0;

initial begin
  $dumpfile("wave.vcd"); // Specify the VCD file name
  $dumpvars(0, f32_mult_tb);

  // Open the test vectors file
  file = $fopen("test_vectors.txt", "r");
  if (file == 0) begin
    $display("Error: Could not open test_vectors.txt");
    $finish;
  end

  // Monitor signals
  // $monitor("Time=%0t: rst_n=%b, a=%h, b=%h, start=%b, done=%b, p=%h",
  //           $time, rst_n, a, b, start, done, p);

  a = 0;
  b = 0;
  start = 0;
  
  // Wait for 10 cycles before the first start
  #100;

  // Read inputs from file and apply them
  while (!$feof(file)) begin
    // Read a, b, and expected_p from the line
    status = $fscanf(file, "%h %h %h", a_file, b_file, expected_p);
    if (status != 3) begin
      $display("Error: Invalid input format in test_vectors.txt");
      $finish;
    end

    // Apply inputs
    a = a_file;
    b = b_file;

    // Start multiplication
    start = 1;
    #10 start = 0;

    // Wait for done signal
    wait (done == 1'b1);

    // Compare actual result with expected result
    if (p === expected_p) begin
      // $display("Test PASSED: a=%h, b=%h, p=%h (expected=%h)", a, b, p, expected_p);
    end else begin
      $display("Test FAILED: a=%h, b=%h, p=%h (expected=%h)", a, b, p, expected_p);
      error_count = error_count + 1; // Increment error counter
    end

    // Wait a few cycles before next test
    #20;
  end

  // Close the file
  $fclose(file);

  // Display total errors
  if (error_count == 0) begin
    $display("All tests PASSED!");
  end else begin
    $display("Tests completed with %0d errors.", error_count);
  end

  // Finish simulation
  $finish;
end

endmodule