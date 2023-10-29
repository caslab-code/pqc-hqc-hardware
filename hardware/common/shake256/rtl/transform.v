/*
 * This is a module for cSHAKE, it is translated manually from transform.vhd, 
 * which was developed by Bernhard Jungk <bernhard@projectstarfire.de>
 * 
 * Copyright (C): 2019
 * Author:        Shanquan Tian <shanquan.tian@yale.edu>
 * Updated:       2019-06-16
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


module transform(
    input wire                          clk,
    input wire                          rst,
    input wire                          computation_en,
    input wire [`ROUND_COUNT_WIDTH-1:0] round,
    input wire [`DATAPATH_WIDTH-1:0]    din,
    input wire [`DATAPATH_WIDTH-1:0]    rcin,
    output reg [`DATAPATH_WIDTH -1:0]   dout,
    output reg [4:0]                   dout_z0
);

reg [`DATAPATH_WIDTH - 1:0] chi_iota_out;  //  
reg [4:0] carry;
reg [4:0] carry_reg;  
reg [2:0] x_plus_1;
reg [2:0] x_plus_2;
integer x;
integer y;

always @(round or din or rcin) begin : step_0

    if((round >> `CLOG2(`NUM_SUB_ROUNDS)) != 0 ) begin
      // for all rounds, but the first we compute:
      // for all sub-lanes the chi and the iota permutations
      // a[x]+(a[x+1]+1)*a[x+2] where + and * are operations in GF(2)
      for (x=0; x <= 4; x = x + 1) begin
        for (y=0; y <= 4; y = y + 1) begin
          // fix for the inability to use mod 5 by XST 
          // (and probably most or all other synthesis tools)
          if((x == 4)) begin
            x_plus_1 = 0;
          end
          else begin
            x_plus_1 = x + 1;
          end
          if((x_plus_1 == 4)) begin
            x_plus_2 = 0;
          end
          else begin
            x_plus_2 = x_plus_1 + 1;
          end
          // The 200 bits of d_in are organized as follows (at least I think so ;-)
          // (x,y) -> z
          // 0,0         | 1,0         | ...
          //  7, ...,  0 | 15, ...,  8 | ...
          //--------------------------------
          // 0,1         | 1,1         | ...
          // 47, ..., 40 | 55, ..., 48 | ...
          //--------------------------------
          // ...         | ...         | ...
          chi_iota_out[(x + 1 + y * 5) * `PARALLEL_SLICES - 1 -: `PARALLEL_SLICES] 
          = din[(x + 1 + y * 5) * `PARALLEL_SLICES - 1 -:`PARALLEL_SLICES] 
          ^ (
          	((( ~din[((x_plus_1 + 1 + y * 5)) * `PARALLEL_SLICES - 1 -:`PARALLEL_SLICES])) 
          		& din[((x_plus_2 + 1 + y * 5)) * `PARALLEL_SLICES - 1 -:`PARALLEL_SLICES])
          	) 
          ^ rcin[((x + 1 + y * 5)) * `PARALLEL_SLICES - 1 -:`PARALLEL_SLICES];
          

        end
      end
    end
    else begin
      chi_iota_out = din;
    end
end

always @(posedge clk) begin
    if((rst == 1'b1)) begin
      carry_reg <= {5{1'b0}};
    end
    else if((computation_en == 1'b 1)) begin
      carry_reg <= carry;
    end
end

reg [5 * `PARALLEL_SLICES - 1:0] sum_x_z;
reg [2:0] x0_plus_1;
reg [2:0] x0_plus_2;
integer x0;
integer y0;
// compute theta

generate
  if((`PARALLEL_SLICES > 1)) begin
    
    always @(chi_iota_out or carry_reg or round) begin : step_1
        
        if( (round >> `CLOG2(`NUM_SUB_ROUNDS)) == `KECCAK_ROUNDS) begin
          dout = chi_iota_out;
          dout_z0 = {5{1'b0}};
          carry = {5{1'b0}};
        end
        else begin
          // first we sum up the sub-lanes
          sum_x_z = {5 * `PARALLEL_SLICES{1'b0}};
          // this computation could be extracted in a separate pipeline step
          for (x0=0; x0 <= 4; x0 = x0 + 1) begin
            for (y0=0; y0 <= 4; y0 = y0 + 1) begin
              sum_x_z[(x0 + 1) * `PARALLEL_SLICES - 1 -:`PARALLEL_SLICES] 
              = sum_x_z[(x0 + 1) * `PARALLEL_SLICES - 1 -:`PARALLEL_SLICES] 
                ^ chi_iota_out[(x0 + 1 + 5 * y0) * `PARALLEL_SLICES - 1 -:`PARALLEL_SLICES];
            end
          end
          // the exceptional handling of z=0 should be unnecessary or much simpler for an implementation with pipelining
          if((round & (`NUM_SUB_ROUNDS-1)) == `MAX_SUB_ROUNDS) begin
            carry = {5{1'b0}};
            dout_z0 = {sum_x_z[5 * `PARALLEL_SLICES - 1],
                        sum_x_z[4 * `PARALLEL_SLICES - 1],
                        sum_x_z[3 * `PARALLEL_SLICES - 1],
                        sum_x_z[2 * `PARALLEL_SLICES - 1],
                        sum_x_z[1 * `PARALLEL_SLICES - 1]};
          end
          else begin
            // store the carry
            carry = {sum_x_z[5 * `PARALLEL_SLICES - 1],
                      sum_x_z[4 * `PARALLEL_SLICES - 1],
                      sum_x_z[3 * `PARALLEL_SLICES - 1],
                      sum_x_z[2 * `PARALLEL_SLICES - 1],
                      sum_x_z[1 * `PARALLEL_SLICES - 1]};
            dout_z0 = {5{1'b0}};
          end
          for (x0=0; x0 <= 4; x0 = x0 + 1) begin
            for (y0=0; y0 <= 4; y0 = y0 + 1) begin
              if((x0 == 4)) begin
                x0_plus_1 = 0;
              end
              else begin
                x0_plus_1 = x0 + 1;
              end

              if((x0_plus_1 == 4)) begin
                x0_plus_2 = 0;
              end
              else begin
                x0_plus_2 = x0_plus_1 + 1;
              end
              // computation for 1<=z<=7 ("local" z)
              //if((`PARALLEL_SLICES > 1)) begin
              dout[(x0_plus_1 + 1 + 5 * y0) * `PARALLEL_SLICES - 1 -:`PARALLEL_SLICES-1] 
              = sum_x_z[(x0 + 1) * `PARALLEL_SLICES - 1 -:`PARALLEL_SLICES -1] 
              ^ sum_x_z[((x0_plus_2 + 1)) * `PARALLEL_SLICES - 2 -:`PARALLEL_SLICES-1] 
              ^ chi_iota_out[((x0_plus_1 + 1 + 5 * y0)) * `PARALLEL_SLICES - 1 -:`PARALLEL_SLICES-1];
                // x,y,z     
              //end
              if((`NUM_SUB_ROUNDS > 1)) begin
                // finish computation for z=0 ("local" z)
                dout[((x0_plus_1 + 5 * y0)) * `PARALLEL_SLICES] 
                = sum_x_z[x0 * `PARALLEL_SLICES] 
                 ^ carry_reg[x0_plus_2] 
                 ^ chi_iota_out[((x0_plus_1 + 5 * y0)) * `PARALLEL_SLICES];
              end
              else begin
                dout[((x0_plus_1 + 5 * y0)) * `PARALLEL_SLICES] 
                = sum_x_z[((x0)) * `PARALLEL_SLICES] 
                 ^ sum_x_z[((x0_plus_2 + 1)) * `PARALLEL_SLICES - 1] 
                 ^ chi_iota_out[((x0_plus_1 + 5 * y0)) * `PARALLEL_SLICES];
              end
            end
          end
        end
    end




  end else begin


    always @(chi_iota_out or carry_reg or round) begin : step_1
        
        if( (round >> `CLOG2(`NUM_SUB_ROUNDS)) == `KECCAK_ROUNDS) begin
          dout = chi_iota_out;
          dout_z0 = {5{1'b0}};
          carry = {5{1'b0}};
        end
        else begin
          // first we sum up the sub-lanes
          sum_x_z = {5 * `PARALLEL_SLICES{1'b0}};
          // this computation could be extracted in a separate pipeline step
          for (x0=0; x0 <= 4; x0 = x0 + 1) begin
            for (y0=0; y0 <= 4; y0 = y0 + 1) begin
              sum_x_z[(x0 + 1) * `PARALLEL_SLICES - 1 -:`PARALLEL_SLICES] 
              = sum_x_z[(x0 + 1) * `PARALLEL_SLICES - 1 -:`PARALLEL_SLICES] 
                ^ chi_iota_out[(x0 + 1 + 5 * y0) * `PARALLEL_SLICES - 1 -:`PARALLEL_SLICES];
            end
          end
          // the exceptional handling of z=0 should be unnecessary or much simpler for an implementation with pipelining
          if((round & (`NUM_SUB_ROUNDS-1)) == `MAX_SUB_ROUNDS) begin
            carry = {5{1'b0}};
            dout_z0 = {sum_x_z[5 * `PARALLEL_SLICES - 1],
                        sum_x_z[4 * `PARALLEL_SLICES - 1],
                        sum_x_z[3 * `PARALLEL_SLICES - 1],
                        sum_x_z[2 * `PARALLEL_SLICES - 1],
                        sum_x_z[1 * `PARALLEL_SLICES - 1]};
          end
          else begin
            // store the carry
            carry = {sum_x_z[5 * `PARALLEL_SLICES - 1],
                      sum_x_z[4 * `PARALLEL_SLICES - 1],
                      sum_x_z[3 * `PARALLEL_SLICES - 1],
                      sum_x_z[2 * `PARALLEL_SLICES - 1],
                      sum_x_z[1 * `PARALLEL_SLICES - 1]};
            dout_z0 = {5{1'b0}};
          end
          for (x0=0; x0 <= 4; x0 = x0 + 1) begin
            for (y0=0; y0 <= 4; y0 = y0 + 1) begin
              if((x0 == 4)) begin
                x0_plus_1 = 0;
              end
              else begin
                x0_plus_1 = x0 + 1;
              end

              if((x0_plus_1 == 4)) begin
                x0_plus_2 = 0;
              end
              else begin
                x0_plus_2 = x0_plus_1 + 1;
              end
              // computation for 1<=z<=7 ("local" z)
              // //if((`PARALLEL_SLICES > 1)) begin
              // dout[(x0_plus_1 + 1 + 5 * y0) * `PARALLEL_SLICES - 1 -:`PARALLEL_SLICES-1] 
              // = sum_x_z[(x0 + 1) * `PARALLEL_SLICES - 1 -:`PARALLEL_SLICES -1] 
              // ^ sum_x_z[((x0_plus_2 + 1)) * `PARALLEL_SLICES - 2 -:`PARALLEL_SLICES-1] 
              // ^ chi_iota_out[((x0_plus_1 + 1 + 5 * y0)) * `PARALLEL_SLICES - 1 -:`PARALLEL_SLICES-1];
              //   // x,y,z     
              // //end
              if((`NUM_SUB_ROUNDS > 1)) begin
                // finish computation for z=0 ("local" z)
                dout[((x0_plus_1 + 5 * y0)) * `PARALLEL_SLICES] 
                = sum_x_z[x0 * `PARALLEL_SLICES] 
                 ^ carry_reg[x0_plus_2] 
                 ^ chi_iota_out[((x0_plus_1 + 5 * y0)) * `PARALLEL_SLICES];
              end
              else begin
                dout[((x0_plus_1 + 5 * y0)) * `PARALLEL_SLICES] 
                = sum_x_z[((x0)) * `PARALLEL_SLICES] 
                 ^ sum_x_z[((x0_plus_2 + 1)) * `PARALLEL_SLICES - 1] 
                 ^ chi_iota_out[((x0_plus_1 + 5 * y0)) * `PARALLEL_SLICES];
              end
            end
          end
        end
    end
  end  
endgenerate


// always @(chi_iota_out or carry_reg or round) begin : step_1
    
//     if( (round >> `CLOG2(`NUM_SUB_ROUNDS)) == `KECCAK_ROUNDS) begin
//       dout = chi_iota_out;
//       dout_z0 = {5{1'b0}};
//       carry = {5{1'b0}};
//     end
//     else begin
//       // first we sum up the sub-lanes
//       sum_x_z = {5 * `PARALLEL_SLICES{1'b0}};
//       // this computation could be extracted in a separate pipeline step
//       for (x0=0; x0 <= 4; x0 = x0 + 1) begin
//         for (y0=0; y0 <= 4; y0 = y0 + 1) begin
//           sum_x_z[(x0 + 1) * `PARALLEL_SLICES - 1 -:`PARALLEL_SLICES] 
//           = sum_x_z[(x0 + 1) * `PARALLEL_SLICES - 1 -:`PARALLEL_SLICES] 
//             ^ chi_iota_out[(x0 + 1 + 5 * y0) * `PARALLEL_SLICES - 1 -:`PARALLEL_SLICES];
//         end
//       end
//       // the exceptional handling of z=0 should be unnecessary or much simpler for an implementation with pipelining
//       if((round & (`NUM_SUB_ROUNDS-1)) == `MAX_SUB_ROUNDS) begin
//         carry = {5{1'b0}};
//         dout_z0 = {sum_x_z[5 * `PARALLEL_SLICES - 1],
//                     sum_x_z[4 * `PARALLEL_SLICES - 1],
//                     sum_x_z[3 * `PARALLEL_SLICES - 1],
//                     sum_x_z[2 * `PARALLEL_SLICES - 1],
//                     sum_x_z[1 * `PARALLEL_SLICES - 1]};
//       end
//       else begin
//         // store the carry
//         carry = {sum_x_z[5 * `PARALLEL_SLICES - 1],
//                   sum_x_z[4 * `PARALLEL_SLICES - 1],
//                   sum_x_z[3 * `PARALLEL_SLICES - 1],
//                   sum_x_z[2 * `PARALLEL_SLICES - 1],
//                   sum_x_z[1 * `PARALLEL_SLICES - 1]};
//         dout_z0 = {5{1'b0}};
//       end
//       for (x0=0; x0 <= 4; x0 = x0 + 1) begin
//         for (y0=0; y0 <= 4; y0 = y0 + 1) begin
//           if((x0 == 4)) begin
//             x0_plus_1 = 0;
//           end
//           else begin
//             x0_plus_1 = x0 + 1;
//           end

//           if((x0_plus_1 == 4)) begin
//             x0_plus_2 = 0;
//           end
//           else begin
//             x0_plus_2 = x0_plus_1 + 1;
//           end
//           // computation for 1<=z<=7 ("local" z)
// `ifdef PARALLEL_SLICES_LARGER_THAN_1
//           //if((`PARALLEL_SLICES > 1)) begin
//             dout[(x0_plus_1 + 1 + 5 * y0) * `PARALLEL_SLICES - 1 -:`PARALLEL_SLICES-1] 
//             = sum_x_z[(x0 + 1) * `PARALLEL_SLICES - 1 -:`PARALLEL_SLICES -1] 
//             ^ sum_x_z[((x0_plus_2 + 1)) * `PARALLEL_SLICES - 2 -:`PARALLEL_SLICES-1] 
//             ^ chi_iota_out[((x0_plus_1 + 1 + 5 * y0)) * `PARALLEL_SLICES - 1 -:`PARALLEL_SLICES-1];
//             // x,y,z     
//           //end
// `endif
//           if((`NUM_SUB_ROUNDS > 1)) begin
//             // finish computation for z=0 ("local" z)
//             dout[((x0_plus_1 + 5 * y0)) * `PARALLEL_SLICES] 
//             = sum_x_z[x0 * `PARALLEL_SLICES] 
//              ^ carry_reg[x0_plus_2] 
//              ^ chi_iota_out[((x0_plus_1 + 5 * y0)) * `PARALLEL_SLICES];
//           end
//           else begin
//             dout[((x0_plus_1 + 5 * y0)) * `PARALLEL_SLICES] 
//             = sum_x_z[((x0)) * `PARALLEL_SLICES] 
//              ^ sum_x_z[((x0_plus_2 + 1)) * `PARALLEL_SLICES - 1] 
//              ^ chi_iota_out[((x0_plus_1 + 5 * y0)) * `PARALLEL_SLICES];
//           end
//         end
//       end
//     end
// end




endmodule
