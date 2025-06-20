`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06/17/2025 03:20:32 PM
// Design Name: 
// Module Name: fifo_mem1
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: Bi-synchronous FIFO with Bubble encoded counters
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module fifo_mem1 #(

  parameter  DATA_WIDTH = 16,
  parameter  ADDRESS_WIDTH = 5
) (
  input                               clka,
  input                               wea,
  input       [(ADDRESS_WIDTH-1):0]   addra,
  input       [(DATA_WIDTH-1):0]      dina,

  input                               clkb,
  input                               reb,
  input       [(ADDRESS_WIDTH-1):0]   addrb,
  output reg  [(DATA_WIDTH-1):0]      doutb
);

  integer i, j;

  reg         [(DATA_WIDTH-1):0]      doutb_temp = {DATA_WIDTH{1'b0}};
  reg         [(DATA_WIDTH-1):0]      m_ram[0:(ADDRESS_WIDTH-1)];

  always @(posedge clka) begin
    if (wea == 1'b1) begin
      for (i = 0; i < ADDRESS_WIDTH; i = i + 1) begin
        if (addra[i]) begin
          m_ram[i] <= dina;
        end  
      end
    end  
  end

  always @(posedge clkb) begin
    if (reb == 1'b1) begin
      doutb <= doutb_temp;
    end
  end

  always @(*) begin
    for (j = 0; j < ADDRESS_WIDTH; j = j + 1) begin
      if (addrb[j]) begin
        doutb_temp = m_ram[j];
      end
    end
  end

endmodule