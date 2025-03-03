module f32_mult (
  input logic clk, rst_n,
  input logic [31:0] a, b,
  input logic start,
  output logic done,
  output logic [31:0] p
);

// Extract step
logic s_a, s_b;
logic [7:0] e_a, e_b;
logic [23:0] m_a, m_b; // 24-bit mantissa (1 implicit + 23 explicit)

// Multiplication step
logic [47:0] mantissa_product;
logic signed [9:0] exp_sum;

// Normalize step
logic overflow;
logic signed [9:0] normalized_exp; // exp, possible some overflow
logic [22:0] normalized_mantissa; // 23-bit stored mantissa
logic result_sign;

// Special case flags
logic a_is_zero, b_is_zero;
logic a_is_inf, b_is_inf;
logic a_is_nan, b_is_nan;
logic a_is_denormal, b_is_denormal;

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
      result_reg <= {result_sign, normalized_exp[7:0], normalized_mantissa}; // Store the result
    end
  end
end

// FSM logic
always @(*) begin
  next_state = state;
  done = 0;

  // Default values -- Uninitialized SNaN
  result_sign = 0;
  normalized_exp = 8'hFF;
  normalized_mantissa = {1'b0, {22{1'b1}}};

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
      m_a = a[22:0];
      m_b = b[22:0];

      // Check for special cases
      a_is_zero = (e_a == 0) && (a[22:0] == 0);
      b_is_zero = (e_b == 0) && (b[22:0] == 0);
      a_is_inf = (e_a == 8'hFF) && (a[22:0] == 0);
      b_is_inf = (e_b == 8'hFF) && (b[22:0] == 0);
      a_is_nan = (e_a == 8'hFF) && (a[22:0] != 0);
      b_is_nan = (e_b == 8'hFF) && (b[22:0] != 0);
      a_is_denormal = (e_a == 0) && (a[22:0] != 0);
      b_is_denormal = (e_b == 0) && (b[22:0] != 0);

      // Adjust mantissa for denormals
      m_a[23] = (a_is_denormal) ? 1'b0 : 1'b1;
      m_b[23] = (b_is_denormal) ? 1'b0 : 1'b1;

      next_state = MULTIPLY;
    end

    MULTIPLY: begin
      result_sign = s_a ^ s_b;

      // Handle special cases
      if (a_is_nan || b_is_nan) begin
        normalized_exp = 8'hFF;
        normalized_mantissa = (a_is_nan) ? m_a : m_b;
        next_state = DONE;
      end else if (a_is_inf || b_is_inf) begin
        if (a_is_zero || b_is_zero) begin
          normalized_exp = 8'hFF;
          normalized_mantissa = (a_is_nan) ? m_a : m_b;
        end else begin
          normalized_exp = 8'hFF;
          normalized_mantissa = 0; // Infinity
        end
        next_state = DONE;
      end else if ((a_is_zero || b_is_zero) ||
                    (a_is_denormal && b_is_denormal)) begin
        normalized_exp = 0;
        normalized_mantissa = 0; // Zero
        next_state = DONE;
      end else begin
        // Normal multiplication
        mantissa_product = m_a * m_b;
        exp_sum = e_a + e_b - 127;
        next_state = NORMALIZE;
      end
    end

    NORMALIZE: begin
      // Normalize the mantissa product
      overflow = mantissa_product[47]; // Check if product >= 2.0
      normalized_mantissa = overflow ? mantissa_product[46:24] : mantissa_product[45:23];
      normalized_exp = exp_sum + overflow; // Adjust exponent
      result_sign = s_a ^ s_b;

      // Exponent check
      if (normalized_exp >= 9'sd255) begin
        normalized_exp = 8'hFF;
        normalized_mantissa = 0; // Infinity
      end else if (normalized_exp < 9'sd1) begin
        
        if (normalized_exp >= -9'sd126) begin
          // Gradual underflow (denormal number)
          if (a_is_denormal || b_is_denormal) 
            normalized_mantissa = mantissa_product[45:23] >> (-normalized_exp);
          else
            normalized_mantissa = mantissa_product[46:24] >> (-normalized_exp);

          normalized_exp = 0;
        end else begin
          // Too small, set to zero
          normalized_exp = 0;
          normalized_mantissa = 0;
        end
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