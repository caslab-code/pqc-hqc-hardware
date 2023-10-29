/*
 * This is a module for cSHAKE, it is translated manually from rc.vhd, 
 * which was developed by Bernhard Jungk <bernhard@projectstarfire.de>
 * 
 * Copyright (C): 2019
 * Author:        Shanquan Tian <shanquan.tian@yale.edu>
 * Updated:       2019-06-14
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

module rc(
    input wire                          clk,
    input wire                          rst,
    input wire [`ROUND_COUNT_WIDTH-1:0] round,
    output reg [`PARALLEL_SLICES-1:0]  rcout
);

(* ram_style = "block" *) reg [1599:0] rc_const_all = {
    64'h8000000080008008 ,
    64'h0000000080000001 ,
    64'h8000000000008080 ,
    64'h8000000080008081 ,
    64'h800000008000000A ,
    64'h000000000000800A ,
    64'h8000000000000080 ,
    64'h8000000000008002 ,
    64'h8000000000008003 ,
    64'h8000000000008089 ,
    64'h800000000000008B ,
    64'h000000008000808B ,
    64'h000000008000000A ,
    64'h0000000080008009 ,
    64'h0000000000000088 ,
    64'h000000000000008A ,
    64'h8000000000008009 ,
    64'h8000000080008081 ,
    64'h0000000080000001 ,
    64'h000000000000808B ,
    64'h8000000080008000 ,
    64'h800000000000808A ,
    64'h0000000000008082 ,
    64'h0000000000000001 ,
    64'h0000000000000000 
};

wire [`PARALLEL_SLICES-1:0] rc_const [0:(25*`NUM_SUB_ROUNDS -1)];

reg [`CLOG2(`MAX_ROUND_COUNT+1):0] round_natural;

generate
    genvar i;
    for (i = 0; i < (25*`NUM_SUB_ROUNDS); i = i + 1) begin: generate_rc_const
//        assign rc_const[i] = rc_const_all[(i >> `CLOG2(`NUM_SUB_ROUNDS))*64 + SHANQUAN's edit 32
        assign rc_const[i] = rc_const_all[(i >> `DIVCLOG2(`NUM_SUB_ROUNDS))*64 +
                                (i & (`NUM_SUB_ROUNDS-1))*`PARALLEL_SLICES +
                                `PARALLEL_SLICES-1 -: `PARALLEL_SLICES] ;
    end
endgenerate


always @(round) begin
    if(round < `MAX_ROUND_COUNT) begin
      round_natural = round + 1'b1;
    end
    else begin
      round_natural = 0;
    end
end

always @(posedge clk) begin
    rcout <= rc_const[round_natural];
end




endmodule

