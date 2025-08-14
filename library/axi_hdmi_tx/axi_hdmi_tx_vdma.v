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
  output  reg [511:0]      vdma_waddr,
  output  reg [ 47:0]      vdma_wdata,
  output  reg              vdma_fs_ret_toggle,
  output  reg [511:0]      vdma_fs_waddr,
  output  reg              vdma_tpm_oos,
  output  reg              vdma_ovf,
  output                   vdma_unf
);

  // internal registers

  reg              vdma_fs_toggle_m1 = 1'd0;
  reg              vdma_fs_toggle_m2 = 1'd0;
  reg              vdma_fs_toggle_m3 = 1'd0;
  reg     [ 22:0]  vdma_tpm_data = 23'd0;
  reg              hdmi_fs = 1'd0;
  reg              vdma_fs = 1'd0;
  reg              vdma_end_of_frame_d = 1'd0;
  reg              vdma_active_frame = 1'd0;
  reg     [255:0]  search_half_full = 256'd0;
  reg     [511:0]  vdma_status_reg = 512'd0;

  // internal wires

  wire    [47:0]  vdma_tpm_data_s;
  wire            vdma_tpm_oos_s;
  wire            vdma_ovf_s;
  wire            unf_s;
  wire            vdma_half_full;
  wire            vdma_delayed_half_full;
  wire            vdma_full;
  wire            vdma_empty_n_s;

  // variables
  integer         i;
  genvar         gi;

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
      vdma_fs_waddr <= {511'd0, 1'b1}; 
    end else begin
      if (vdma_fs) begin
        vdma_fs_ret_toggle <= ~vdma_fs_ret_toggle;
        vdma_fs_waddr <= vdma_waddr ;
      end
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
      vdma_waddr <= {511'd0, 1'b1};
    end else if (vdma_wr == 1'b1) begin
      vdma_waddr <= vdma_waddr + 1'b1;
    end
    vdma_wdata <= {vdma_data[55:32], vdma_data[23:0]};
  end

  // status register

  generate
    for (gi = 1; gi < 512; gi = gi + 1) begin
      always @(posedge vdma_clk or posedge hdmi_raddr[gi]) begin
        if (hdmi_raddr[gi] || vdma_rst) begin
          vdma_status_reg[gi] <= 1'b0;
        end else if (vdma_wr == 1'b1) begin
          vdma_status_reg[gi] <= vdma_status_reg[gi] | vdma_waddr[gi-1];
        end  
      end
    end  
  endgenerate  

  always @(posedge vdma_clk or posedge hdmi_raddr[0]) begin
    if (hdmi_raddr[0] || vdma_rst) begin
      vdma_status_reg[0] <= 1'b0;
    end else if (vdma_wr == 1'b1) begin
      vdma_status_reg[0] <= vdma_status_reg[0] | vdma_waddr[511];
    end  
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

  // overflow or underflow status
  // overflow cannot be detected
  assign vdma_ovf_s = 1'b0;
  assign unf_s = ~vdma_empty_n_s & vdma_wr;
  assign vdma_empty_n_s = |(vdma_status_reg);

  always @(*) begin
    for (i = 0; i < 256; i = i + 1) begin
      search_half_full[i] = vdma_status_reg[i] & vdma_status_reg[i + 256];
    end
  end
  assign vdma_half_full = |search_half_full;

  prog_delay_sync #(
    .DATA_WIDTH(1),
    .ADDRESS_WIDTH(8) // maximum delay is 255 cycles
  ) delay_full (
    .clk(vdma_clk),
    .rst(vdma_rst),
    .ce(vdma_wr),
    .l(8'd253), // delay 253 cycles
    .din(vdma_half_full),
    .dout(vdma_delayed_half_full)
  );
  assign vdma_full = (vdma_delayed_half_full & vdma_half_full);

  prog_delay_sync #(
    .DATA_WIDTH(1),
    .ADDRESS_WIDTH(2) // maximum delay is 3 cycles
  ) sync_unf (
    .clk(vdma_clk),
    .rst(vdma_rst),
    .ce(1'b1),
    .l(4'd2), // delay 2 cycles
    .din(unf_s),
    .dout(vdma_unf)
  );

  always @(posedge vdma_clk) begin
    vdma_ready <= ~(vdma_full) & vdma_active_frame;
    vdma_ovf <= vdma_ovf_s;
  end

endmodule
