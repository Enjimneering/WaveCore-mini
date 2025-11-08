/*
 * Music from "Drop" demo.
 * Full version: https://github.com/rejunity/tt08-vga-drop
 *
 * Copyright (c) 2024 Renaldas Zioma, Erik Hemming
 * SPDX-License-Identifier: Apache-2.0
 */

module tt_um_enjimneering_apu (
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


reg trig_eat;
reg trig_die;
reg trig_hit;

 // TODO map these inputs correctly
APU_trigger apu_trig (
    .clk(clk),
    .reset(~rst_n),
    .frame_end((x == 0) & (y == 0)),     // TODO: use frame end signal here
    .SheepDragonCollision(ui_in[0]),    
    .SwordDragonCollision(ui_in[1]),
    .PlayerDragonCollision(ui_in[2]),
    .eat_sound(trig_eat),
    .die_sound(trig_die),
    .hit_sound(trig_hit)
  );
  
AudioProcessingUnit apu (
    .clk(clk),
    .reset(~rst_n),
    .saw_trigger(trig_eat),
    .noise_trigger(trig_die),
    .square_trigger(trig_hit),
    .x(x),
    .y(y),
    .sound(sound)
  );

endmodule
