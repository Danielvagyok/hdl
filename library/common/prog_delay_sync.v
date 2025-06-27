`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06/26/2025 03:33:49 PM
// Design Name: 
// Module Name: prog_delay_sync
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


module prog_delay_sync #(
  parameter DATA_WIDTH    = 4,
  parameter ADDRESS_WIDTH = 2 
) (
  input                            clk ,
  input                            rst ,
  input                            ce,
  input      [(ADDRESS_WIDTH-1):0] l   ,
  input      [   (DATA_WIDTH-1):0] din ,
  output reg [   (DATA_WIDTH-1):0] dout
);

  reg  [        (DATA_WIDTH-1):0]  delayed_data[0:((2**ADDRESS_WIDTH)-1)];
  reg  [((2**ADDRESS_WIDTH)-1):0]  sel;
  reg  [((2**ADDRESS_WIDTH)-1):0]  en;

  integer i;
  
  always @(posedge clk) begin
    if (rst) begin
      sel <= 'd1;
    end else if (ce) begin
      sel <= {sel[((2**ADDRESS_WIDTH)-2):0], sel[l]};
      if (sel[l]) begin
        sel[l+1] <= 1'b0;
      end
    end
  end

  always @(posedge clk) begin
    if (rst) begin
      en <= 'd0;
    end else begin
      en <= sel;
    end
  end
  
  always @(posedge clk) begin
    for (i = 0; i < (2**ADDRESS_WIDTH); i = i + 1) begin
      if (en[i]) begin
        delayed_data[i] <= din;
      end
    end
  end
  
  always @(posedge clk) begin
    for (i = 0; i < (2**ADDRESS_WIDTH); i = i + 1) begin
      if (sel[i]) begin
        dout <= delayed_data[i];
      end
    end
  end

endmodule
