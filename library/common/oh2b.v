`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08/04/2025 10:15:04 AM
// Design Name: 
// Module Name: oh2b
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module oh2b (
  input clk,
  input rst,
  input [511:0] oh,
  output reg [8:0] b
);

  reg  [255:0] oh_256;
  reg  [127:0] oh_128;
  reg  [ 63:0] oh_64;
  reg  [ 31:0] oh_32;
  reg  [ 15:0] oh_16;
  reg  [  7:0] oh_8;
  reg  [  3:0] oh_4;
  reg  [  1:0] oh_2;
  reg          b_8;
  reg  [  1:0] b_8_7;
  reg  [  2:0] b_8_6;
  reg  [  3:0] b_8_5;
  reg  [  4:0] b_8_4;
  reg  [  5:0] b_8_3;
  reg  [  6:0] b_8_2;
  reg  [  7:0] b_8_1;
  integer i;

  always @(posedge clk) begin
    if (rst) begin
      b_8 <= 1'b0;
      oh_256 <= 256'b0;
    end else begin
      b_8 <= |oh[511:256];
      oh_256 <= oh[511:256] | oh[255:0];
    end
  end

  always @(posedge clk) begin
    if (rst) begin
      b_8_7 <= 2'b0;
      oh_128 <= 128'b0;
    end else begin
      b_8_7[1] <= b_8;
      b_8_7[0] <= |oh_256[255:128];
      oh_128 <= oh_256[255:128] | oh_256[127:0];
    end
  end

  always @(posedge clk) begin
    if (rst) begin
      b_8_6 <= 3'b0;
      oh_64 <= 64'b0;
    end else begin
      b_8_6[2:1] <= b_8_7;
      b_8_6[0] <= |oh_128[127:64];
      oh_64 <= oh_128[127:64] | oh_128[63:0];
    end
  end

  always @(posedge clk) begin
    if (rst) begin
      b_8_5 <= 4'b0;
      oh_32 <= 32'b0;
    end else begin
      b_8_5[3:1] <= b_8_6;
      b_8_5[0] <= |oh_64[63:32];
      oh_32 <= oh_64[63:32] | oh_64[31:0];
    end
  end

  always @(posedge clk) begin
    if (rst) begin
      b_8_4 <= 5'b0;
      oh_16 <= 16'b0;
    end else begin
      b_8_4[4:1] <= b_8_5;
      b_8_4[0] <= |oh_32[31:16];
      oh_16 <= oh_32[31:16] | oh_32[15:0];
    end
  end

  always @(posedge clk) begin
    if (rst) begin
      b_8_3 <= 6'b0;
      oh_8 <= 8'b0;
    end else begin
      b_8_3[5:1] <= b_8_4;
      b_8_3[0] <= |oh_16[15:8];
      oh_8 <= oh_16[15:8] | oh_16[7:0];
    end
  end

  always @(posedge clk) begin
    if (rst) begin
      b_8_2 <= 7'b0;
      oh_4 <= 4'b0;
    end else begin
      b_8_2[6:1] <= b_8_3;
      b_8_2[0] <= |oh_8[7:4];
      oh_4 <= oh_8[7:4] | oh_8[3:0];
    end
  end

  always @(posedge clk) begin
    if (rst) begin
      b_8_1 <= 8'b0;
      oh_2 <= 2'b0;
    end else begin
      b_8_1[7:1] <= b_8_2;
      b_8_1[0] <= |oh_4[3:2];
      oh_2 <= oh_4[3:2] | oh_4[1:0];
    end
  end

  always @(posedge clk) begin
    if (rst) begin
      b <= 9'b0;
    end else begin
      b[8:1] <= b_8_1;
      b[0] <= oh_2[1];
    end
  end

endmodule
