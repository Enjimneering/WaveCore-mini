/*
 * Music from "Drop" demo.
 * Full version: https://github.com/rejunity/tt08-vga-drop
 *
 * Copyright (c) 2024 Renaldas Zioma, Erik Hemming
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

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


module tt_um_enjimneering_apu #(
		parameter OCT_BITS = 4,             // 8 octaves is enough for pitch, but the filters need to be able to sweep lower
		parameter DIVIDER_BITS = 16+1,      // 14 for the pitch, 2 extra for the sweeps
		parameter OSC_PERIOD_BITS = 10,
		parameter MOD_PERIOD_BITS = 6,
		parameter SWEEP_PERIOD_BITS = 4,
		parameter LOG2_SWEEP_UPDATE_PERIOD = 2,
		parameter WAVE_BITS = 2,
		parameter LEAST_SHR = 3
	)(
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

  localparam STATE_BITS = 5;
	localparam OUT_BITS = 8;

	localparam CEIL_LOG2_NUM_OSCS = 1;
	localparam NUM_OSCS = 2;

	localparam CEIL_LOG2_NUM_MODS = 2;
	localparam NUM_MODS = 3;
	localparam CUTOFF_INDEX = 0;
	localparam DAMP_INDEX = 1;
	localparam VOL_INDEX = 2;
	localparam NFZERO_INDEX = 3; // Not a modulator; use to set nf to zero

	localparam CEIL_LOG2_NUM_SWEEPS = 3;
	localparam NUM_SWEEPS = NUM_OSCS + NUM_MODS;

	localparam CEIL_LOG2_CFG_WORDS = 3;
	localparam CFG_WORDS = 8;
	localparam OSC_PERIOD_BASE = 0;
	localparam MOD_PERIOD_BASE = NUM_OSCS;
	localparam SWEEP_PERIOD_BASE = MOD_PERIOD_BASE + NUM_MODS;
	localparam MISC_BASE8 = 2*SWEEP_PERIOD_BASE + NUM_SWEEPS;

	localparam EXTRA_BITS = LEAST_SHR + (1 << OCT_BITS) - 1;
	localparam FEED_SHL = (1 << OCT_BITS) - 1;
	localparam FSTATE_BITS = WAVE_BITS + EXTRA_BITS;
	localparam SHIFTER_BITS = WAVE_BITS + (1 << OCT_BITS) - 1;
	localparam DITHER_BITS = SHIFTER_BITS - (STATE_BITS - LEAST_SHR);

	localparam WF_PULSE = 0;
	localparam WF_SQUARE = 1;
	localparam WF_NOISE = 2;
	localparam WF_SAW = 3;

  genvar i;

  // VGA signals
  wire hsync;
  wire vsync;
  wire [1:0] R;
  wire [1:0] G;
  wire [1:0] B;
  wire video_active;
  wire [9:0] x;
  wire [9:0] y;
  assign {R,G,B} = {6{video_active * sound}};
  
  wire pwm_output;
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

  // Audio 

  // cfg 
  wire [1:0] cfg_we; // byte enables
	wire [15:0] cfg_w_data;
	wire [CEIL_LOG2_CFG_WORDS-1:0] cfg_w_addr;
	reg [15:0] cfg[CFG_WORDS];
	wire [15:0] period_cfg[NUM_SWEEPS]; // Restricted to maybe avoid some multiplexers when reading from it
	wire [7:0] cfg8[CFG_WORDS*2];


  // osciliator
  
  // Octave divider
	// ==============
	reg [DIVIDER_BITS-1:0] oct_counter;
	wire [DIVIDER_BITS-1:0] next_oct_counter = oct_counter + 1;
	wire [DIVIDER_BITS:0] oct_enables;
	assign oct_enables[0] = 1;
	assign oct_enables[DIVIDER_BITS:1] = next_oct_counter & ~oct_counter; // Could optimize oct_enables[1] to just next_oct_counter[0]

	always @(posedge clk) begin
		if (reset) begin
			state <= 0;
			oct_counter <= 0;
		end else begin
			state <= next_state[STATE_BITS-1:0];
			if (last_cycle_of_sample) oct_counter <= next_oct_counter;
		end
	end

	// LFSR
	// ====
	reg [14:0] lfsr;

	always @(posedge clk) begin
		if (reset) lfsr <= '1;
		else if (last_cycle_of_sample) lfsr <= {lfsr[13:0], lfsr[0] ^ lfsr[14]};
	end

  // Sawtooth oscillators
	// ====================
	wire update_saw = state < NUM_OSCS;
	wire [CEIL_LOG2_NUM_OSCS-1:0] saw_index = state[CEIL_LOG2_NUM_OSCS-1:0];

	wire [OCT_BITS-1:0] curr_saw_oct = saw_oct[saw_index];
	wire [2**OCT_BITS-1:0] saw_oct_enables = {1'b0, oct_enables[2**OCT_BITS-2:0]};
	wire saw_en = saw_oct_enables[curr_saw_oct];
	wire saw_trigger;

	wire [OSC_PERIOD_BITS-1:0] saw_period[NUM_OSCS];
	wire [OCT_BITS-1:0] saw_oct[NUM_OSCS];
	reg [WAVE_BITS-1:0] saw[NUM_OSCS];
	wire [WAVE_BITS-1:0] curr_saw = saw[saw_index];
	wire [WAVE_BITS-1:0] next_saw = (wf == WF_NOISE) ? {~lfsr[WAVE_BITS-1], lfsr[WAVE_BITS-2:0]} : (curr_saw + 1);

	reg [OSC_PERIOD_BITS-1:0] saw_counter_state[NUM_OSCS];
	wire [OSC_PERIOD_BITS-1:0] saw_counter_next_state;
	wire saw_counter_state_we;
	
  Counter #(.PERIOD_BITS(OSC_PERIOD_BITS), .LOG2_STEP(WAVE_BITS)) saw_counter(
		.period0('0), .period1(saw_period[saw_index]), .enable(saw_en),
		.trigger(saw_trigger),

		.counter(saw_counter_state[saw_index]), .counter_we(saw_counter_state_we), .next_counter(saw_counter_next_state)
	);

	generate
		for (i = 0; i <  1; i++) begin : osc
			assign saw_period[i] = {1'b1, cfg[OSC_PERIOD_BASE+i][OSC_PERIOD_BITS-2:0]};
			assign saw_oct[i] = cfg[OSC_PERIOD_BASE+i][OSC_PERIOD_BITS-2+OCT_BITS -: OCT_BITS];

			always @(posedge clk) begin
				if (reset) begin
					saw_counter_state[i] <= '0;
					saw[i] <= '0;
				end else if (update_saw && saw_index == i) begin
					if (saw_counter_state_we) saw_counter_state[i] <= saw_counter_next_state;
					if (saw_trigger) saw[i] <= next_saw;
				end
			end
		end
	endgenerate

  // control fsm
  reg [STATE_BITS-1:0] state;
	wire [STATE_BITS:0] next_state = state + 1;
	wire last_cycle_of_sample = next_state[STATE_BITS];

  always @(posedge clk) begin
		if (reset) begin
			state <= 0;
		end else begin
			state <= next_state[STATE_BITS-1:0];
		end
	end


  // filter
  wire [7:0] misc_cfg = cfg8[MISC_BASE8];
  wire [1:0] wf = saw_index ? misc_cfg[3:2] : misc_cfg[1:0];
	wire [WAVE_BITS:0] curr_wave = (wf == WF_SQUARE) ? {~curr_saw[WAVE_BITS-1], 2'b10} :
		((wf == WF_PULSE) ? {~(|curr_saw), 2'b01} : {~curr_saw[WAVE_BITS-1], curr_saw[WAVE_BITS-2:0], 1'b1});

  // pwm
	reg [STATE_BITS-1:0] pwm_counter;

	wire pwm_positive = pwm_counter != 0;
	always @(posedge clk) begin
		if (reset) pwm_counter <= 0;
		else begin
			if (last_cycle_of_sample) pwm_counter <= 0;
			else pwm_counter <= pwm_counter - {4'b000,pwm_positive};
		end
	end

	assign sound = pwm_positive;
 

endmodule
