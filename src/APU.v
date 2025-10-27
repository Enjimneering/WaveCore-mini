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

  reg [7:0] saw_counter;
  reg [7:0] saw_counter_next;
  reg saw_we;
  wire trig;

  Counter #(.PERIOD_BITS(8), .LOG2_STEP(2)) saw_config (
    .period0(0), .period1(8'hff), // Max period
    .enable(1'b1),
    .trigger(trig),
    .counter(saw_counter),
    
    .counter_we(saw_we), .next_counter(saw_counter_next)
  );

  always @(posedge clk) begin
    if (reset) begin
      saw_counter <= 0;
    end else begin
      if (saw_we) saw_counter <= saw_counter_next;
    end
  end

reg [7:0] pwm_counter = 0; // PWM timebase counter
reg pwm_out;

always @(posedge clk) begin
    if (reset) begin
        pwm_counter <= 0;
        pwm_out <= 0;
    end else begin
        // Increment the pwm counter
        pwm_counter <= pwm_counter + 1;
        // PWM output: high while pwm_counter < saw_counter
        pwm_out <= (pwm_counter < saw_counter);
    end
end

assign sound = pwm_out;

endmodule
