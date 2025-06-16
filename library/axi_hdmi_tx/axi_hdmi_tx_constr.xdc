###############################################################################
## Copyright (C) 2014-2023 Analog Devices, Inc. All rights reserved.
### SPDX short identifier: ADIBSD
###############################################################################

set_property ASYNC_REG TRUE [get_cells -hier -filter {name =~ *vdma_fs_toggle*}]
set_property ASYNC_REG TRUE [get_cells -hier -filter {name =~ *vdma_raddr_g*}]
set_property ASYNC_REG TRUE [get_cells -hier -filter {name =~ *hdmi_fs_ret_toggle*}]

set_false_path -from [get_cells -hier -filter {name =~ *hdmi_fs_toggle_reg      && IS_SEQUENTIAL}] -to [get_cells -hier -filter {name =~ *vdma_fs_toggle_m1_reg     && IS_SEQUENTIAL}]
set_false_path -from [get_cells -hier -filter {name =~ *hdmi_raddr_g*           && IS_SEQUENTIAL}] -to [get_cells -hier -filter {name =~ *vdma_raddr_g_m1*          && IS_SEQUENTIAL}]
set_false_path -from [get_cells -hier -filter {name =~ *vdma_fs_ret_toggle_reg  && IS_SEQUENTIAL}] -to [get_cells -hier -filter {name =~ *hdmi_fs_ret_toggle_m1_reg && IS_SEQUENTIAL}]
set_false_path -from [get_cells -hier -filter {name =~ *vdma_fs_waddr*          && IS_SEQUENTIAL}] -to [get_cells -hier -filter {name =~ *hdmi_fs_waddr*            && IS_SEQUENTIAL}]

create_clock -name ref_clk -period 7.500 [get_ports reference_clk]
create_clock -name axi_clk -period 10.000 [get_ports vdma_clk]
create_clock -name dma_clk -period 10.000 [get_ports s_axi_aclk]