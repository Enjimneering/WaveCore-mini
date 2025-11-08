/*
 * Music from "Drop" demo.
 * Full version: https://github.com/rejunity/tt08-vga-drop
 *
 * Copyright (c) 2024 Renaldas Zioma, Erik Hemming
 * SPDX-License-Identifier: Apache-2.0
 */
 
 
 // Module : Tiny Tapestation FPGA Interface

module APU_FPGA_top (
    // System Signals
    input  wire          clk,            // PIN E3 (100 MHZ Clk)
    input  wire          RST_N,          // PIN J15
    input  wire [7:0]    PITCH,           // SWITCHES
    // Audio Signals
    output wire          PWM,            // PIN A11 (Headphone Jack)
    output wire          aud_sd_o
);
  
  assign aud_sd_o = 1'b1;
  wire pwm_ori;
  assign PWM = pwm_ori? 1'bz:1'b0;
   
    /* Make sure the name is consistent with the current iteration of the chip! */
    tt_um_enjimneering_apu apu ( // Make sure the i/o pinout is accurate according to the spec!
        .ui_in    (PITCH),    
        .uo_out   (8'b00000000), 
        .uio_in   (8'b0000_0000),   
        .uio_out  ({pwm_ori,7'b000_0000}),    
        .uio_oe   ({8'b1000_0000}),                      
        .ena      (1),                                   
        .clk      (clk),      
        .rst_n    (RST_N)    
    );
    
endmodule

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

  wire [9:0] x;
  wire [9:0] y;
  
  wire sound;
   
  assign uo_out  = {8'b0000_0000};
  assign uio_out = {sound, 7'b000_0000};
  
  // Unused outputs assigned to 0.
  assign uio_oe  = 8'hff;

  // Suppress unused signals warning
  wire _unused_ok = &{ena, uio_in};

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
