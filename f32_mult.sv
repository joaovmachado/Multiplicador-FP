module f32_mult (
  input logic clk, rst_n,
  input logic [31:0] a, b,
  input logic start,
  output logic done,
  output logic [31:0] p
);

// Internal signals
logic s_a, s_b;
logic [7:0] e_a, e_b;
logic [23:0] m_a, m_b;       // 24-bit mantissa (1 implicit + 23 explicit)
logic [47:0] mantissa_product;
logic overflow;
logic [7:0] normalized_exp;
logic [22:0] normalized_mantissa; // 23-bit stored mantissa
logic result_sign;

// FSM
typedef enum logic [2:0] { IDLE, EXTRACT, MULTIPLY, NORMALIZE, DONE } state_t;
state_t state, next_state;

// State transition
always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n) state <= IDLE;
  else state <= next_state;
end

// FSM logic
always @(*) begin
  next_state = state;
  done = 0;
  p = 0;

  case (state)
    IDLE: begin
      if (start) next_state = EXTRACT;
    end

    EXTRACT: begin
      s_a = a[31];
      s_b = b[31];
      e_a = a[30:23];
      e_b = b[30:23];
      m_a = {1'b1, a[22:0]};
      m_b = {1'b1, b[22:0]};
      next_state = MULTIPLY;
    end

    MULTIPLY: begin
      mantissa_product = m_a * m_b;
      next_state = NORMALIZE;
    end

    NORMALIZE: begin
      overflow = mantissa_product[47]; // Check if product >= 2.0
      normalized_mantissa = overflow ? mantissa_product[46:24] : mantissa_product[45:23];
      normalized_exp = e_a + e_b - 127 + overflow;
      result_sign = s_a ^ s_b;
      next_state = DONE;
    end

    DONE: begin
      p = {result_sign, normalized_exp, normalized_mantissa};
      done = 1;
      next_state = IDLE;
    end

    default: next_state = IDLE;
  endcase
end

endmodule