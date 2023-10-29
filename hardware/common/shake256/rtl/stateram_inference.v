
/*
 * This is the stateram_inference for the Keccak design, it was translated manually from stateram_inference.vhd,
 * which was developed by Bernhard Jungk <bernhard@projectstarfire.de>
 * 
 * Copyright (C): 2019
 * Author:        Xiayuan Wen <xiayuan.wen@yale.edu> 
 *                Shanquan Tian <shanquan.tian@yale.edu>
 * Updated:       2019-06-18
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
`include "keccak_math.v"
//`include "../../cshake/keccak_math.v"



module stateram_inference #(
  parameter                                 i = 0
)(
  input   wire                              clk,
  input   wire                              rst,
  input   wire                              re,
  input   wire [31:0]                       raddr,
  input   wire [`PARALLEL_SLICES-1:0]       d_in,
  input   wire                              we,
  input   wire [31:0]                       raddr_high_offset,//FIXED
  input   wire [31:0]                       waddr,//FIXED
  output  wire [`PARALLEL_SLICES-1:0]       d_out    
);

/* verilator lint_off LITENDIAN */
reg   [`RHO_OFFSET(i)-1:0]                     ram_high [`MAX_SUB_ROUNDS:0];
wire  [`RHO_OFFSET(i)-1:0]                     din_high;
wire  [`CLOG2(`MAX_SUB_ROUNDS+1)-1:0]             waddr_high;

reg   [`PARALLEL_SLICES-1-`RHO_OFFSET(i):0]    ram_low  [`MAX_SUB_ROUNDS:0];
wire  [`PARALLEL_SLICES-1-`RHO_OFFSET(i):0]    din_low;
wire  [`CLOG2(`MAX_SUB_ROUNDS+1)-1:0]             waddr_low;

reg   [`CLOG2(`MAX_SUB_ROUNDS+1)-1:0]             raddr_high_reg;
reg   [`CLOG2(`MAX_SUB_ROUNDS+1)-1:0]             raddr_low_reg;

wire  [31:0]                                  raddr_high_reg_temp;

generate
  if (`RHO_OFFSET(i) > 0)
    begin
      assign waddr_high = raddr_high_reg; //FIXED
      assign din_high = d_in[(`PARALLEL_SLICES-1)-:`RHO_OFFSET(i)];//FIXED
      assign d_out[`RHO_OFFSET(i)-1:0] = ram_high[raddr_high_reg];//FIXED
      assign raddr_high_reg_temp = raddr - raddr_high_offset;
    end
endgenerate

generate
  if (`RHO_OFFSET(i) > 0)
    begin
      always @ (posedge clk)
      begin: ram_high_proc
        if (rst == 1'b1) 
          raddr_high_reg <= 0;
        else
          begin
          if (re == 1'b1)
            raddr_high_reg <= raddr_high_reg_temp[`CLOG2(`MAX_SUB_ROUNDS+1)-1:0];
          if (we == 1'b1)
            ram_high[waddr_high] <= din_high;
          end
      end
    end
endgenerate
    
        
 
assign waddr_low = raddr_low_reg;
assign din_low = d_in[`PARALLEL_SLICES-`RHO_OFFSET(i)-1:0];
assign d_out[`PARALLEL_SLICES-1:`RHO_OFFSET(i)] = ram_low[raddr_low_reg];
       
       
always @(posedge clk)
begin: ram_low_proc
  if(rst == 1'b1)
    raddr_low_reg <= 0;
  else
    begin
    if(re == 1'b1)
      raddr_low_reg <= raddr[`CLOG2(`MAX_SUB_ROUNDS+1)-1:0];
    
    if(we == 1'b1)
      ram_low[waddr_low] <= din_low;
    end
end       

endmodule

/*`include "keccak_pkg.vh"
`include "keccak_math.vh"




module stateram_inference #(
  parameter                                 i = 0
)(
  input   wire                              clk,
  input   wire                              rst,
  input   wire                              re,
  input   wire [31:0]                       raddr,
  input   wire [`PARALLEL_SLICES-1:0]       d_in,
  input   wire                              we,
  input   wire [`CLOG2(`MAX_SUB_ROUNDS+1)-1:0]  raddr_high_offset,//FIXED
  input   wire [`CLOG2(`MAX_SUB_ROUNDS+1)-1:0]  waddr,//FIXED
  output  wire [`PARALLEL_SLICES-1:0]       d_out    
);

reg   [rho_offset[i]-1:0]                     ram_high [`MAX_SUB_ROUNDS:0];
wire  [rho_offset[i]-1:0]                     din_high;
wire  [`CLOG2(`MAX_SUB_ROUNDS+1)-1:0]             waddr_high;

reg   [`PARALLEL_SLICES-1-rho_offset[i]:0]    ram_low  [`MAX_SUB_ROUNDS:0];
wire  [`PARALLEL_SLICES-1-rho_offset[i]:0]    din_low;
wire  [`CLOG2(`MAX_SUB_ROUNDS+1)-1:0]         waddr_low;

reg   [`CLOG2(`MAX_SUB_ROUNDS+1)-1:0]         raddr_high_reg;
reg   [`CLOG2(`MAX_SUB_ROUNDS+1)-1:0]         raddr_low_reg;

wire  [31:0]                                  raddr_high_reg_temp;

generate
  if (rho_offset[i] > 0)
    begin
      assign waddr_high = raddr_high_reg; //FIXED
      assign din_high = d_in[(`PARALLEL_SLICES-1)-:rho_offset[i]];//FIXED
      assign d_out[rho_offset[i]-1:0] = ram_high[raddr_high_reg];//FIXED
      assign raddr_high_reg_temp = raddr - raddr_high_offset;
    end
endgenerate

generate
  if (rho_offset[i] > 0)
    begin
      always @ (posedge clk)
      begin: ram_high_proc
        if (rst == 1'b1) 
          raddr_high_reg <= 0;
        else
          begin
          if (re == 1'b1)
            raddr_high_reg <= raddr_high_reg_temp[`NUM_SUB_ROUNDS_WIDTH-1:0];
          if (we == 1'b1)
            ram_high[waddr_high] <= din_high;
          end
      end
    end
endgenerate
    
        
 
assign waddr_low = raddr_low_reg;
assign din_low = d_in[`PARALLEL_SLICES-rho_offset[i]-1:0];
assign d_out[`PARALLEL_SLICES-1:rho_offset[i]] = ram_low[raddr_low_reg];
       
       
always @(posedge clk)
begin: ram_low_proc
  if(rst == 1'b1)
    raddr_low_reg <= 0;
  else
    begin
    if(re == 1'b1)
      raddr_low_reg <= raddr[`MAX_SUB_ROUNDS_WIDTH-1:0];
    end
    
    if(we == 1'b1)
      ram_low[waddr_low] <= din_low;
    end
end       

endmodule*/
