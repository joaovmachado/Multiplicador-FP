module f32_mult (
  input logic clk, rst_n,
  input logic [31:0] a, b,
  input logic start,
  output logic done,
  output logic [31:0] p,
  output logic underflow_o,
  output logic overflow_o
);

// Extract step
logic s_a, s_b;
logic [7:0] e_a, e_b;
logic [23:0] m_a, m_b;       // 24-bit mantissa (1 implicit + 23 explicit)

// Multiplication step
logic [47:0] mantissa_product;

// Normalize step
logic overflow;
logic [7:0] normalized_exp;
logic [22:0] normalized_mantissa; // 23-bit stored mantissa
logic result_sign;

// Special case flags
logic a_is_zero, b_is_zero;
logic a_is_inf, b_is_inf;
logic a_is_nan, b_is_nan;
logic a_is_denormal, b_is_denormal;

// Sinals that prepare the overflow or underflow output
logic overflow_s, underflow_s;

// Register to hold the result
logic [31:0] result_reg;

// FSM
typedef enum logic [2:0] { IDLE, EXTRACT, MULTIPLY, NORMALIZE, DONE } state_t;
state_t state, next_state;

// State transition
always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    state <= IDLE;
    result_reg <= 0; // Reset the result register
  end else begin
    state <= next_state;
    if (next_state == DONE) begin
      result_reg <= {result_sign, normalized_exp, normalized_mantissa}; // Store the result
    end
  end
end

// FSM logic
always @(*) begin
  next_state = state;
  done = 0;

  // Default values
  normalized_exp = 0;
  normalized_mantissa = 0;
  result_sign = 0;
  overflow_o = 0;
  underflow_o = 0;

  case (state)
    IDLE: begin
      if (start) next_state = EXTRACT;
    end

    EXTRACT: begin
      // Extract sign, exponent, and mantissa
      s_a = a[31];
      s_b = b[31];
      e_a = a[30:23];
      e_b = b[30:23];
      m_a = {1'b1, a[22:0]};  // Add implicit leading 1
      m_b = {1'b1, b[22:0]};  // Add implicit leading 1

      // Check for special cases
      a_is_zero = (e_a == 0) && (a[22:0] == 0);
      b_is_zero = (e_b == 0) && (b[22:0] == 0);
      a_is_inf = (e_a == 8'hFF) && (a[22:0] == 0);
      b_is_inf = (e_b == 8'hFF) && (b[22:0] == 0);
      a_is_nan = (e_a == 8'hFF) && (a[22:0] != 0);
      b_is_nan = (e_b == 8'hFF) && (b[22:0] != 0);
      a_is_denormal = (e_a == 0) && (a[22:0] != 0);
      b_is_denormal = (e_b == 0) && (b[22:0] != 0);

      next_state = MULTIPLY;
    end

    MULTIPLY: begin
      // Handle special cases
      if (a_is_nan || b_is_nan) begin
        result_sign = 0; // NaN is signless
        normalized_exp = 8'hFF;
        normalized_mantissa = 23'h400000; // Quiet NaN
        next_state = DONE;
      end else if (a_is_inf || b_is_inf) begin
        if (a_is_zero || b_is_zero) begin
          result_sign = 0; // NaN is signless
          normalized_exp = 8'hFF;
          normalized_mantissa = 23'h400000; // Quiet NaN
        end else begin
          result_sign = s_a ^ s_b;
          normalized_exp = 8'hFF;
          normalized_mantissa = 0; // Infinity
        end
        next_state = DONE;
      end else if ((a_is_zero || b_is_zero) ||
                   (a_is_denormal || b_is_denormal)) begin
        result_sign = s_a ^ s_b;
        normalized_exp = 0;
        normalized_mantissa = 0; // Zero
        next_state = DONE;
      end else begin
        // Normal multiplication
        mantissa_product = m_a * m_b;
        next_state = NORMALIZE;
      end
    end

    NORMALIZE: begin
      // Normalize the mantissa product
      overflow = mantissa_product[47]; // Check if product >= 2.0
      normalized_mantissa = overflow ? mantissa_product[46:24] : mantissa_product[45:23];
      normalized_exp = e_a + e_b - 127 + overflow; // Adjust exponent
      result_sign = s_a ^ s_b;

      // Exponent check
      if (normalized_exp >= 8'hFF) begin
          overflow_o = 1;
          normalized_exp = 8'hFF;
          normalized_mantissa = 0;
      end else if (normalized_exp < 8'd1) begin
          underflow_o = 1;
          normalized_exp = 0;
          normalized_mantissa = 0;
      end else begin
          overflow_o = 0;
          underflow_o = 0;
      end
      next_state = DONE;
    end

    DONE: begin
      done = 1;
      next_state = IDLE;
    end

    default: next_state = IDLE;
  endcase
end

// Output the result from the register
assign p = result_reg;

endmodule