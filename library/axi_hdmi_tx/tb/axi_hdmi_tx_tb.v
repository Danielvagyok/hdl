`timescale 1ns / 10ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06/13/2025 01:09:17 PM
// Design Name: 
// Module Name: axi_hdmi_tx_tb
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

module axi_hdmi_tx_tb;
  // Reset and clock 
  reg ref_clk = 1'b0;
  reg in_clk = 1'b0;
  reg trigger_reset = 1'b0;
  reg [3:0] reset_shift = 4'b1111;
  wire reset;
  wire resetn;
  
  always #5 in_clk <= ~in_clk;
  always #3.375 ref_clk <= ~ref_clk;
  
  always @(posedge in_clk) begin
    if (trigger_reset == 1'b1) begin
      reset_shift <= 3'b111;
    end else begin
      reset_shift <= {reset_shift[2:0],1'b0};
    end
  end
  
  assign reset = reset_shift[3];
  assign resetn = ~reset;
  
  task do_trigger_reset;
  begin
    @(posedge in_clk) trigger_reset <= 1'b1;
    @(posedge in_clk) trigger_reset <= 1'b0;
  end
  endtask
  
  // hdmi
  wire hdmi_16_hsync, hdmi_16_vsync, hdmi_16_data_e;
  wire [15:0] hdmi_16_data, hdmi_16_es_data;
  
  //vdma
  wire vdma_ready;
  reg vdma_end_of_frame = 1'b0;
  reg vdma_valid = 1'b0;
  reg [63:0] vdma_data = 64'h00;
  
  task dma_write;
    input [47:0] value;
    input eof;
  begin
    @(posedge in_clk) #0;
    vdma_valid <= 1'b1;
    vdma_data <= {8'h00, value[47:24], 8'h00, value[23:0]};
    vdma_end_of_frame <= eof;
      
    @(posedge vdma_valid)
    while (vdma_valid) begin
      @(posedge in_clk) #0;
      vdma_end_of_frame <= 1'b0;
      if (vdma_ready) begin
        vdma_valid <= 1'b0;
        // comment this to make write operation last 3 Tclk
        @(negedge vdma_valid) #0;
      end  
    end  
  end
  endtask
  
  task dma_write_buf;
    input [47:0] value;
  begin
    vdma_data <= {8'h00, value[47:24], 8'h00, value[23:0]};
  end
  endtask
  
  
  // axi
  reg s_axi_awvalid = 1'b0, s_axi_wvalid = 1'b0;
  reg [15:0] s_axi_awaddr = 'h00;
  reg [31:0] s_axi_wdata = 'h00;
  wire s_axi_awready, s_axi_wready;
 
  wire s_axi_bready = 1'b1;
  
  task axi_write;
    input [15:0] addr;
    input [31:0] value;
  begin
    @(posedge in_clk) #0;
    s_axi_awvalid <= 1'b1;
    s_axi_wvalid <= 1'b1;
    s_axi_awaddr <= addr;
    s_axi_wdata <= value;
    
    @(posedge in_clk)
    while (s_axi_awvalid || s_axi_wvalid) begin
      @(posedge in_clk)
      if (s_axi_awready)
        s_axi_awvalid <= 1'b0;
      if (s_axi_wready)
        s_axi_wvalid <= 1'b0;
    end
  end
  endtask
  
  reg [15:0] s_axi_araddr = 'h0;
  reg s_axi_arvalid = 'h0;
  reg s_axi_rready = 'h0;
  wire s_axi_arready;
  wire s_axi_rvalid;
  wire [31:0] s_axi_rdata;
  
  task axi_read;
    input [15:0] addr;
    output [31:0] value;
  begin
    s_axi_arvalid <= 1'b1;
    s_axi_araddr <= addr;
    s_axi_rready <= 1'b1;
    
    @(posedge in_clk) #0;
    while (s_axi_arvalid) begin
      if (s_axi_arready == 1'b1) begin
        s_axi_arvalid <= 1'b0;
      end
      @(posedge in_clk) #0;
    end

    while (s_axi_rready) begin
      if (s_axi_rvalid == 1'b1) begin
        value <= s_axi_rdata;
        s_axi_rready <= 1'b0;
      end
      @(posedge in_clk) #0;
    end
  end
  endtask
  
  wire [2:0] s_axi_awprot = 3'b000;
  wire [3:0] s_axi_wstrb = 4'b1111;
  wire s_axi_bvalid;
  wire [1:0] s_axi_bresp;
  wire [2:0] s_axi_arprot = 3'b000;
  wire [1:0] s_axi_rresp;
  
  localparam H_LINE_ACTIVE = 16'd1920;
  localparam H_LINE_WIDTH = 16'd2200;
  localparam H_SYNC_WIDTH = 16'd44;
  localparam H_ENABLE_MAX = 16'd2112; // HDE_max = HDE_min + h_active
  localparam H_ENABLE_MIN = 16'd192; // HDE_min = hsync + back porch (no of clk cycles bw falling edge of hsync and rising edge of DE)
  localparam V_FRAME_ACTIVE = 16'd1080;
  localparam V_FRAME_WIDTH = 16'd1125;
  localparam V_SYNC_WIDTH = 16'd5;
  localparam V_ENABLE_MAX = 16'd1121; // VDE_max = VDE_min + v_active
  localparam V_ENABLE_MIN = 16'd41; // VDE_min = vsync + back porch (no of clk cycles bw falling edge of vsync and rising edge of DE)

  reg [47:0] i = 1;
  // testbench sequence
  initial begin
    axi_write(16'h0040, 1'b1); // enable RESET
    // HDMI H line lengths
    axi_write(16'h0400, {H_LINE_ACTIVE, H_LINE_WIDTH});
    axi_write(16'h0404, H_SYNC_WIDTH);
    axi_write(16'h0408, {H_ENABLE_MAX, H_ENABLE_MIN});
    // HDMI V line lengths
    axi_write(16'h0440, {V_FRAME_ACTIVE, V_FRAME_WIDTH});
    axi_write(16'h0444, V_SYNC_WIDTH);
    axi_write(16'h0448, {V_ENABLE_MAX, V_ENABLE_MIN});
    // HDMI bypass chroma sub-sampler (SS) and color space conversion (CSC) for testing
    axi_write(16'h0044, 3'b101);
    
    dma_write(48'h112233445566, 1'b1);
    
    @(posedge in_clk) #0;
    vdma_valid <= 1'b1;
    dma_write_buf(23'd1);
//    @(posedge in_clk) #0;
    for (i = 2; i < 193000; i = i + 1) begin
      @(posedge in_clk) #0;
      while (~vdma_ready) begin
        @(posedge in_clk) #0;
      end
      dma_write_buf(i);
    end
    vdma_valid <= 1'b0;
  end
  
  axi_hdmi_tx #(
    .ID                 (0),             
    .CR_CB_N            (0),        
    .FPGA_TECHNOLOGY    (1),
    .INTERFACE          ("16_BIT"),
    .OUT_CLK_POLARITY   (0)
    ) i_hdmi_tx (
    .reference_clk      (ref_clk),    
    .hdmi_out_clk       (),     
    .vga_out_clk        (),      
    .hdmi_16_hsync      (hdmi_16_hsync),    
    .hdmi_16_vsync      (hdmi_16_vsync),    
    .hdmi_16_data_e     (hdmi_16_data_e),   
    .hdmi_16_data       (hdmi_16_data),     
    .hdmi_16_es_data    (hdmi_16_es_data),  
    .hdmi_24_hsync      (),    
    .hdmi_24_vsync      (),    
    .hdmi_24_data_e     (),   
    .hdmi_24_data       (),     
    .vga_hsync          (),        
    .vga_vsync          (),        
    .vga_red            (),          
    .vga_green          (),        
    .vga_blue           (),         
    .hdmi_36_hsync      (),    
    .hdmi_36_vsync      (),    
    .hdmi_36_data_e     (),   
    .hdmi_36_data       (),     
    .vdma_clk           (in_clk),         
    .vdma_end_of_frame  (vdma_end_of_frame),
    .vdma_valid         (vdma_valid),       
    .vdma_data          (vdma_data),        
    .vdma_ready         (vdma_ready),       
    .s_axi_aclk         (in_clk),       
    .s_axi_aresetn      (resetn),    
    .s_axi_awvalid      (s_axi_awvalid),    
    .s_axi_awaddr       (s_axi_awaddr),     
    .s_axi_awprot       (s_axi_awprot),     
    .s_axi_awready      (s_axi_awready),    
    .s_axi_wvalid       (s_axi_wvalid),     
    .s_axi_wdata        (s_axi_wdata),      
    .s_axi_wstrb        (s_axi_wstrb),      
    .s_axi_wready       (s_axi_wready),     
    .s_axi_bvalid       (s_axi_bvalid),     
    .s_axi_bresp        (s_axi_bresp),      
    .s_axi_bready       (s_axi_bready),     
    .s_axi_arvalid      (s_axi_arvalid),    
    .s_axi_araddr       (s_axi_araddr),     
    .s_axi_arprot       (s_axi_arprot),     
    .s_axi_arready      (s_axi_arready),    
    .s_axi_rvalid       (s_axi_rvalid),     
    .s_axi_rresp        (s_axi_rresp),      
    .s_axi_rdata        (s_axi_rdata),      
    .s_axi_rready       (s_axi_rready)
  );
    
endmodule
