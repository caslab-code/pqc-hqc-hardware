`timescale 1ns / 1ps
/*
 * 
 *
 * Copyright (C) 2023
 * Author: Sanjay Deshpande <sanjay.deshpande@yale.edu>
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


module cdw_xor_tmp
#( 

    parameter parameter_set = "hqc128",
                                                   
    parameter N1_BYTES =    (parameter_set == "hqc128")? 46:
				            (parameter_set == "hqc192")? 56:
				            (parameter_set == "hqc256")? 90:
				                                         46,
	
	parameter K_BYTES = (parameter_set == "hqc128")? 16:
				        (parameter_set == "hqc192")? 24:
			            (parameter_set == "hqc256")? 32: 
                                                     16,
	
	parameter N1 = 8*N1_BYTES,
	parameter K = 8*K_BYTES
													
)
(
    
//    input seed_valid,
    input [N1-K-1:0] cdw_in,
    input [N1-K-1:0] tmp_arr,
    output [N1-K-1:0] cdw_out
    );
    
    
  genvar i;
  generate
    for (i = N1_BYTES-K_BYTES; i>1; i=i-1) begin:cdw_xor_tmparr
        assign cdw_out[8*i-1:8*i-8] =  cdw_in[8*(i-1)-1:8*(i-1)-8] ^ tmp_arr[8*i-1:8*i-8];
    end
  endgenerate
    
  assign cdw_out[7:0] = tmp_arr[7:0];
    
endmodule
