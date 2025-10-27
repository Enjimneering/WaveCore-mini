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

/*
 * Music from "Drop" demo.
 * Full version: https://github.com/rejunity/tt08-vga-drop
 *
 * Copyright (c) 2024 Renaldas Zioma, Erik Hemming
 * SPDX-License-Identifier: Apache-2.0
 */

module tt_um_vga_example (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

  // VGA signals
  wire hsync;
  wire vsync;
  wire [1:0] R;
  wire [1:0] G;
  wire [1:0] B;
  wire video_active;
  wire [9:0] x;
  wire [9:0] y;
  
  assign {R,G,B} = 6'b000_000;
  wire sound;

  wire reset = !rst_n;

  // TinyVGA PMOD
  assign uo_out = {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]};
  assign uio_out = {sound, 7'b0};

  // Unused outputs assigned to 0.
  assign uio_oe  = 8'hff;

  // Suppress unused signals warning
  wire _unused_ok = &{ena, ui_in, uio_in};

  hvsync_generator hvsync_gen(
    .clk(clk),
    .reset(~rst_n),
    .hsync(hsync),
    .vsync(vsync),
    .display_on(video_active),
    .hpos(x),
    .vpos(y)
  );

   AudioProcessingUnit apu (
    .clk(clk),
    .reset(~rst_n),
    .SheepDragonCollision(ui_in[0]),
    .SwordDragonCollision(ui_in[1]),
    .PlayerDragonCollision(ui_in[2]),
    .x(x),
    .y(y),
    .sound(sound)
  );
  
endmodule
