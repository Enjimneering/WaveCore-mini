// A simple parameterized counter module that counts down by a configurable step size
module Counter #( parameter PERIOD_BITS = 8, LOG2_STEP = 0 ) (
		input wire [PERIOD_BITS-1:0] period0,
		input wire [PERIOD_BITS-1:0] period1,
		input wire enable,
		output wire trigger,

		// External state: Provide current state in counter, update it to next_counter if counter_we is true.
		input wire [PERIOD_BITS-1:0] counter,
		output wire counter_we,
		output wire [PERIOD_BITS-1:0] next_counter
	);

	assign trigger = enable & !(|counter[PERIOD_BITS-1:LOG2_STEP]); // Trigger if decreasing by 1 << LOG2_STEP would wrap around.

	wire [PERIOD_BITS-1:0] delta_counter = (trigger ? period1 : period0) - (1 << LOG2_STEP);

	assign counter_we = enable;
	assign next_counter = counter + delta_counter;
endmodule

module AudioProcessingUnit (
    input wire clk,
    input wire reset,
    input wire SheepDragonCollision,
    input wire SwordDragonCollision,
    input wire PlayerDragonCollision,
    // input wire frame_end,
    input wire [9:0] x,
    input wire [9:0] y,
    output wire sound
);

  // Simple PWM sound generator based on sawtooth wave
  // Oscillator: Sawtooth wave

  reg [15:0] counter_reg;
  wire [15:0] next_counter;
  
  reg square_reg;
  wire trigger;
  wire counter_we;

  // Counter for sawtooth wave
  Counter #(.PERIOD_BITS(16), .LOG2_STEP(2)) saw_config (
    .period0(16'hAAAA), .period1(16'hAAAA),
    .enable(1'b1),
    .trigger(trigger),
   	.counter(counter_reg),
    .next_counter(next_counter),
    .counter_we(counter_we)
  );

  reg[2:0] trig_count;

  always @(posedge clk) begin
    if (reset) begin
      trig_count <= 0;
      square_reg <= 0;
    end else begin
      if (trigger) begin
        trig_count <= trig_count + 1;
      if (trig_count == 3'b111) 
        square_reg <= ~square_reg;
      end 
    end
  end

  always @(posedge clk) begin
    if (reset) begin
      counter_reg <= 0;
    end else begin
      if (counter_we) begin
        counter_reg <= next_counter; 
      end
    end
  end

  reg [15:0] pwm_counter = 0; // PWM timebase counter
  reg saw_pwm_out;
  reg lfsr_pwm_out;

  always @(posedge clk) begin
    if (reset) begin
        pwm_counter <= 0;
        saw_pwm_out <= 0;
        lfsr_pwm_out <= 0;
    end else begin
        // Increment the pwm counter
        pwm_counter  <= pwm_counter + 1;
        // PWM output: high while pwm_counter < saw_counter
        saw_pwm_out  <= (pwm_counter < counter_reg);
        lfsr_pwm_out <= (pwm_counter[12:0] < lfsr);
    end
  end


  // lsfr  
  reg [12:0] lfsr = 13'h0e1f;
  wire feedback = lfsr[12] ^ lfsr[8] ^ lfsr[2] ^ lfsr[0] + 1;
  always @(posedge clk) begin
    lfsr <= {lfsr[11:0], feedback};
  end

  // envelopes and timer
  wire [11:0] timer = frame_counter;
  reg noise_reg, noise_src = ^lfsr;
  reg  [2:0] noise_counter;
  
  wire [4:0] envelopeA = 5'd31 - timer[4:0];   // exp(t*-10) decays to 0 approximately in 32 frames  [255 215 181 153 129 109  92  77  65  55  46  39  33  28  23  20  16  14 12  10   8   7   6   5   4   3   3   2   2]
  wire [4:0] envelopeB = 5'd31 - timer[3:0]*2; // exp(t*-20) decays to 0 approximately in 16 frames  [255 181 129  92  65  46  33  23  16  12   8   6   4   3]

  reg [11:0] frame_counter;
  always @(posedge clk) begin
    if (reset) begin
      frame_counter <= 0;
      noise_counter <= 0;
      noise_reg <= 0;
    end else begin

      // frame counter
      if (x == 0 && y == 0) begin
        frame_counter <= frame_counter + 1;
      end

      // noise
      if (x == 0) begin
        if (noise_counter > 1) begin 
          noise_counter <= 0;
          noise_reg <= noise_reg ^ noise_src;
        end else begin
          noise_counter <= noise_counter + 1'b1;
        end
      end

    end
  end

  wire saw    = SheepDragonCollision  & saw_pwm_out & (x < envelopeA*8);
  wire noise  = PlayerDragonCollision & noise_reg   & (x >= 128 && x < 128+envelopeB*4);
  wire square = SwordDragonCollision  & square_reg  & (x < envelopeA*4); ;

  assign sound = saw + noise + square;

endmodule
