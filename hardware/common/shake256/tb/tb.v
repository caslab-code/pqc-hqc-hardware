
/*
 * This is a module for cSHAKE, it is translated manually from tb.vhd, 
 * which was developed by Bernhard Jungk <bernhard@projectstarfire.de>
 * 
 * Copyright (C): 2019
 * Author:        Shanquan Tian <shanquan.tian@yale.edu>
 * Updated:       2019-06-17
 *          
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software Foundation,
 * Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301  USA
 *
*/


`include "clog2.v"// Used in cshake project only
//`include "../../cshake/clog2.v"// used with Gaussian Sampler
`include "keccak_pkg.v"
//`include "../../cshake/keccak_pkg.v"



module cshake_tb;

reg clk = 1'b0;
always 
  #5 clk = !clk;

reg rst;
integer start_time;

reg din_valid;
reg [31:0] din;
wire din_ready;
wire [31:0] dout;
reg dout_ready;
reg force_done;
wire dout_valid;

keccak_top cshake_simple
(
    .rst(rst),
    .clk(clk),
    .din_valid(din_valid),
    .din_ready(din_ready),
    .din(din),
    .dout_valid(dout_valid),
    .dout_ready(dout_ready),
    .dout(dout),
    .force_done(force_done)
);


  integer start_time;
  
  initial
    begin
    rst <= 1'b1;
    din_valid = 1'b0;
    dout_ready = 1'b0;
    force_done = 1'b0;
    
    # 20;
    rst <= 1'b0;
    #100
    start_time = $time;
    
      din <= 32'h40000df8; din_valid = 1'b1; #10   
      din <= 32'h80000140; din_valid = 1'b1; #10 
      
//      @(posedge din_ready);
//      #20
      din <= 32'h00000000; din_valid = 1'b1; #680  

      din_valid <= 1'b0;
      dout_ready <= 1'b0;
    
      #100
      @(posedge dout_valid);
      dout_ready <= 1'b1;
//      @(posedge done);
//      PK_col_valid = 1'b0;
       $display("\n Parallel Slice: %0d \n", `PARALLEL_SLICES);
      $display("\n total runtime for SHAKE256: %0d cycles\n", (($time-start_time)/10));
      #6600
      
//      din <= 32'h00000100; din_valid = 1'b1; #10
//      din_valid = 1'b0; #10
      
//      #4000
//      din <= 32'h00000200; din_valid = 1'b1; #10
//      din_valid = 1'b0; #10
      
//      #4000
//      din <= 32'h00000100; din_valid = 1'b1; #10
//      din_valid = 1'b0; #10
      
//      #4000
//      din <= 32'h00000200; din_valid = 1'b1; #10
//      din_valid = 1'b0; #10
      
//      #4000
//      din <= 32'h00000460; din_valid = 1'b1; #10
//      din_valid = 1'b0; #10
      
//      #4000
//      din <= 32'h00000100; din_valid = 1'b1; #10
//      din_valid = 1'b0; #10
      
      $fflush();
      # 10000;
      $finish;
    end


wire [31:0] dout_software_comp;
wire [7:0] dout_software_in_0;
wire [7:0] dout_software_in_1;
wire [7:0] dout_software_in_2;
wire [7:0] dout_software_in_3;
wire [7:0] dout_software_comp_0;
wire [7:0] dout_software_comp_1;
wire [7:0] dout_software_comp_2;
wire [7:0] dout_software_comp_3;

assign dout_software_in_0 = dout[7:0]; 
assign dout_software_in_1 = dout[15:8]; 
assign dout_software_in_2 = dout[23:16]; 
assign dout_software_in_3 = dout[31:24]; 

  genvar i;
  generate
        for (i = 0; i < 8; i=i+1) begin:rev_bits
            assign dout_software_comp_0[i] = dout_software_in_0[7-i]; 
            assign dout_software_comp_1[i] = dout_software_in_1[7-i]; 
            assign dout_software_comp_2[i] = dout_software_in_2[7-i]; 
            assign dout_software_comp_3[i] = dout_software_in_3[7-i]; 
        end
  endgenerate

assign dout_software_comp = {dout_software_in_0,dout_software_in_1,dout_software_in_2,dout_software_in_3};
endmodule // cshake_tb

