// ***************************************************************************
// ***************************************************************************
// Copyright (C) 2014-2023 Analog Devices, Inc. All rights reserved.
//
// In this HDL repository, there are many different and unique modules, consisting
// of various HDL (Verilog or VHDL) components. The individual modules are
// developed independently, and may be accompanied by separate and unique license
// terms.
//
// The user should read each of these license terms, and understand the
// freedoms and responsibilities that he or she has by using this source/core.
//
// This core is distributed in the hope that it will be useful, but WITHOUT ANY
// WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
// A PARTICULAR PURPOSE.
//
// Redistribution and use of source or resulting binaries, with or without modification
// of this file, are permitted under one of the following two license terms:
//
//   1. The GNU General Public License version 2 as published by the
//      Free Software Foundation, which can be found in the top level directory
//      of this repository (LICENSE_GPL2), and also online at:
//      <https://www.gnu.org/licenses/old-licenses/gpl-2.0.html>
//
// OR
//
//   2. An ADI specific BSD license, which can be found in the top level directory
//      of this repository (LICENSE_ADIBSD), and also on-line at:
//      https://github.com/analogdevicesinc/hdl/blob/main/LICENSE_ADIBSD
//      This will allow to generate bit files and not release the source code,
//      as long as it attaches to an ADI device.
//
// ***************************************************************************
// ***************************************************************************
// Transmit HDMI, video dma data in, hdmi separate syncs data out.

`timescale 1ns/100ps

module axi_hdmi_tx_vdma (

  // hdmi interface

  input                    hdmi_fs_toggle,
  input       [511:0]      hdmi_raddr,

  // vdma interface

  input                    vdma_clk,
  input                    vdma_rst,
  input                    vdma_end_of_frame,
  input                    vdma_valid,
  input       [ 63:0]      vdma_data,
  output  reg              vdma_ready,
  output  reg              vdma_wr,
  output  reg [  8:0]      vdma_waddr_b,
  output  reg [ 47:0]      vdma_wdata,
  output  reg              vdma_fs_ret_toggle,
  output  reg [511:0]      vdma_fs_waddr,
  output  reg              vdma_tpm_oos,
  output  reg              vdma_ovf,
  output  reg              vdma_unf
);

  localparam      BUF_THRESHOLD_LO = 9'd3;
  localparam      BUF_THRESHOLD_HI = 9'd509;
  localparam      RDY_THRESHOLD_LO = 9'd450;
  localparam      RDY_THRESHOLD_HI = 9'd500;

  // internal registers

  reg              vdma_fs_toggle_m1 = 1'd0;
  reg              vdma_fs_toggle_m2 = 1'd0;
  reg              vdma_fs_toggle_m3 = 1'd0;
  reg     [ 22:0]  vdma_tpm_data = 23'd0;
  reg              vdma_almost_full_m1 = 1'd0;
  reg              vdma_almost_full_m2 = 1'd0;
  reg              vdma_empty_m1 = 1'd0;
  reg              vdma_empty_m2 = 1'd0;
  reg              hdmi_fs = 1'd0;
  reg              vdma_fs = 1'd0;
  reg              vdma_end_of_frame_d = 1'd0;
  reg              vdma_active_frame = 1'd0;
  reg     [511:0]  vdma_waddr = {510'd0, 2'b11};
  reg     [511:0]  vdma_raddr_m1 = 512'd0;
  reg     [511:0]  vdma_raddr_m2 = 512'd0;

  // internal wires

  wire    [ 47:0]  vdma_tpm_data_s;
  wire             vdma_tpm_oos_s;
  wire             vdma_ovf_s;
  wire             vdma_unf_s;
  wire             almost_full;
  wire    [511:0]  vdma_waddr_oh_s;


// one-hot to binary conversion

function [8:0] oh2b;
    input [511:0] oh;
    reg   [  8:0] b;
    reg  [255:0] oh_256;
    reg  [127:0] oh_128;
    reg  [ 63:0] oh_64;
    reg  [ 31:0] oh_32;
    reg  [ 15:0] oh_16;
    reg  [  7:0] oh_8;
    reg  [  3:0] oh_4;
    reg  [  1:0] oh_2;
    begin
      b[8] = |oh[511:256];
      oh_256 = (b[8]) ? oh[511:256] : oh[255:0];
      b[7] = |oh_256[255:128];
      oh_128 = (b[7]) ? oh_256[255:128] : oh_256[127:0];
      b[6] = |oh_128[127:64];
      oh_64  = (b[6]) ? oh_128[127:64] : oh_128[63:0];
      b[5] = |oh_64[63:32];
      oh_32  = (b[5]) ? oh_64[63:32] : oh_64[31:0];
      b[4] = |oh_32[31:16];
      oh_16  = (b[4]) ? oh_32[31:16] : oh_32[15:0];
      b[3] = |oh_16[15:8];
      oh_8   = (b[3]) ? oh_16[15:8] : oh_16[7:0];
      b[2] = |oh_8[7:4];
      oh_4 = (b[2]) ? oh_8[7:4] : oh_8[3:0];
      b[1] = |oh_4[3:2];
      oh_2 = (b[1]) ? oh_4[3:2] : oh_4[1:0];
      b[0] = oh_2[1];
      oh2b = b;
    end
  endfunction

  // hdmi frame sync

  always @(posedge vdma_clk) begin
    if (vdma_rst == 1'b1) begin
      vdma_fs_toggle_m1 <= 1'd0;
      vdma_fs_toggle_m2 <= 1'd0;
      vdma_fs_toggle_m3 <= 1'd0;
    end else begin
      vdma_fs_toggle_m1 <= hdmi_fs_toggle;
      vdma_fs_toggle_m2 <= vdma_fs_toggle_m1;
      vdma_fs_toggle_m3 <= vdma_fs_toggle_m2;
    end
    hdmi_fs <= vdma_fs_toggle_m2 ^ vdma_fs_toggle_m3;
  end

  // dma frame sync

  always @(posedge vdma_clk) begin
    if (vdma_rst == 1'b1) begin
      vdma_end_of_frame_d <= 1'b0;
      vdma_fs <=  1'b0;
    end else begin
      vdma_end_of_frame_d <= vdma_end_of_frame;
      vdma_fs <= vdma_end_of_frame_d;
    end
  end

  // sync dma and hdmi frames

  always @(posedge vdma_clk) begin
    if (vdma_rst == 1'b1) begin
      vdma_fs_ret_toggle = 1'b0;
      vdma_fs_waddr <= {510'd0, 2'b11}; 
    end else begin
      if (vdma_fs) begin
        vdma_fs_ret_toggle <= ~vdma_fs_ret_toggle;
        vdma_fs_waddr <= vdma_waddr;
      end
    end
  end

  always @(posedge vdma_clk) begin
    if (vdma_rst == 1'b1) begin
      vdma_waddr_b <= 9'd0;
    end begin
      vdma_waddr_b <= oh2b(vdma_waddr_oh_s);
    end
  end

  // accept new frame from dma

  always @(posedge vdma_clk) begin
    if (vdma_rst == 1'b1) begin
      vdma_active_frame <= 1'b0;
    end else begin
      if ((vdma_active_frame == 1'b1) && (vdma_end_of_frame == 1'b1)) begin
        vdma_active_frame <= 1'b0;
      end else if ((vdma_active_frame == 1'b0) && (hdmi_fs == 1'b1)) begin
        vdma_active_frame <= 1'b1;
      end
    end
  end

  // vdma write

  always @(posedge vdma_clk) begin
    vdma_wr <= vdma_valid & vdma_ready;
    if (vdma_rst == 1'b1) begin
      vdma_waddr <= {510'd0, 2'b11};
    end else if (vdma_wr == 1'b1) begin
      vdma_waddr <= {vdma_waddr[510:0], vdma_waddr[511]};
    end
    vdma_wdata <= {vdma_data[55:32], vdma_data[23:0]};
  end

  // test error conditions

  assign vdma_tpm_data_s = {vdma_tpm_data, 1'b1, vdma_tpm_data, 1'b0};
  assign vdma_tpm_oos_s = (vdma_wdata == vdma_tpm_data_s) ? 1'b0 : vdma_wr;

  always @(posedge vdma_clk) begin
    if ((vdma_rst == 1'b1) || (vdma_fs == 1'b1)) begin
      vdma_tpm_data <= 23'd0;
      vdma_tpm_oos <= 1'd0;
    end else if (vdma_wr == 1'b1) begin
      vdma_tpm_data <= vdma_tpm_data + 1'b1;
      vdma_tpm_oos <= vdma_tpm_oos_s;
    end
  end

  always @(posedge vdma_clk) begin
    if (vdma_rst == 1'b1) begin
      vdma_raddr_m1 <= 512'd0;
      vdma_raddr_m2 <= 512'd0;
    end else begin
      vdma_raddr_m1 <= hdmi_raddr;
      vdma_raddr_m2 <= vdma_raddr_m1;
    end
  end

  assign vdma_waddr_oh_s = {vdma_waddr[511] & vdma_waddr[0],
                            vdma_waddr[510:0] & vdma_waddr[511:1]};
  assign almost_full_s = |(vdma_waddr & vdma_raddr_m2);
  assign ready_s = ~almost_full_s & vdma_active_frame;
  assign empty_and_s = {vdma_waddr_oh_s[511:1] & ~vdma_raddr_m2[511:1] &
                        vdma_raddr_m2[510:0], vdma_waddr_oh_s[0] &
                        ~vdma_raddr_m2[0] & vdma_raddr_m2[511]};
  assign empty_s = |(empty_and_s);

  always @(posedge vdma_clk) begin
    if (vdma_rst == 1'b1) begin
      vdma_almost_full_m1 <= 1'b0;
      vdma_almost_full_m2 <= 1'b0;
      vdma_empty_m1 <= 1'b0;
      vdma_empty_m2 <= 1'b0;
    end else begin
      vdma_almost_full_m1 <= almost_full_s;
      // if (vdma_almost_full_m1)
      //   vdma_almost_full_m2 <= 1'b1;
      // else
      //   vdma_almost_full_m2 <= 1'b0;
      vdma_almost_full_m2 <= vdma_almost_full_m1;
      vdma_empty_m1 <= empty_s;
      vdma_empty_m2 <= vdma_empty_m1;
    end  
  end  

  // overflow or underflow status
  // assign vdma_ovf_s = (vdma_empty_m1) ? vdma_almost_full_m2 : 1'b0;
  // assign vdma_unf_s = (vdma_almost_full_m1) ? vdma_empty_m2 : 1'b0;
  assign vdma_ovf_s = 1'b0;
  assign vdma_unf_s = 1'b0;

  always @(posedge vdma_clk) begin
    // if (vdma_almost_full_m1) begin
    //   vdma_ready <= 1'b0;
    // end else begin
    //   vdma_ready <= vdma_active_frame;
    // end
//    vdma_ready <= ~(vdma_almost_full_m1) & vdma_active_frame;
    vdma_ready <= ready_s;
    vdma_ovf <= vdma_ovf_s;
    vdma_unf <= vdma_unf_s;
  end

endmodule
