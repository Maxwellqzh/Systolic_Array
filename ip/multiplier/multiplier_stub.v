// Copyright 1986-2020 Xilinx, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2020.2 (win64) Build 3064766 Wed Nov 18 09:12:45 MST 2020
// Date        : Mon Dec  1 20:19:37 2025
// Host        : DESKTOP-4ON021E running 64-bit major release  (build 9200)
// Command     : write_verilog -force -mode synth_stub
//               c:/Users/123/Desktop/DIC/PJ/Systolic_Array.gen/sources_1/ip/multiplier/multiplier_stub.v
// Design      : multiplier
// Purpose     : Stub declaration of top-level module interface
// Device      : xc7a200tlsbv484-2L
// --------------------------------------------------------------------------------

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// The synthesis directives are for Synopsys Synplify support to prevent IO buffer insertion.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
(* x_core_info = "mult_gen_v12_0_16,Vivado 2020.2" *)
module multiplier(CLK, A, B, CE, SCLR, P)
/* synthesis syn_black_box black_box_pad_pin="CLK,A[7:0],B[7:0],CE,SCLR,P[15:0]" */;
  input CLK;
  input [7:0]A;
  input [7:0]B;
  input CE;
  input SCLR;
  output [15:0]P;
endmodule
