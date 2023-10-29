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


module rm_encoder
#( 	
	parameter ENCODING_MATRIX_0	= 	128'haaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa,
	parameter ENCODING_MATRIX_1	= 	128'hcccccccccccccccccccccccccccccccc,
	parameter ENCODING_MATRIX_2	= 	128'hf0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0,
	parameter ENCODING_MATRIX_3	= 	128'hff00ff00ff00ff00ff00ff00ff00ff00,
	parameter ENCODING_MATRIX_4	= 	128'hffff0000ffff0000ffff0000ffff0000,
	parameter ENCODING_MATRIX_5	= 	128'h00000000ffffffff00000000ffffffff,
	parameter ENCODING_MATRIX_6	= 	128'h0000000000000000ffffffffffffffff,
	parameter ENCODING_MATRIX_7	= 	128'hffffffffffffffffffffffffffffffff 
    
//	parameter ENCODING_MATRIX_7	= 	128'h55555555555555555555555555555555,
//	parameter ENCODING_MATRIX_6	= 	128'h33333333333333333333333333333333,
//	parameter ENCODING_MATRIX_5	= 	128'h0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f,
//	parameter ENCODING_MATRIX_4	= 	128'h00ff00ff00ff00ff00ff00ff00ff00ff,
//	parameter ENCODING_MATRIX_3	= 	128'h0000ffff0000ffff0000ffff0000ffff,
//	parameter ENCODING_MATRIX_2	= 	128'hffffffff00000000ffffffff00000000,
//	parameter ENCODING_MATRIX_1	= 	128'hffffffffffffffff0000000000000000,
//	parameter ENCODING_MATRIX_0	= 	128'hffffffffffffffffffffffffffffffff 
	)
(
    input clk,
    input rst,
    input start,
    input [7:0] byte_in,
    output [128-1:0] cdw_out,
    output reg done
    );
    

reg [127:0] en_matrix [0:7];
//wire [127:0] en_matrix [0:7];
wire [7:0]in_byte;
wire [127:0] cdw_out_temp;
wire [127:0] cdw_out_rearrange;

assign in_byte = byte_in;

always@(in_byte)
begin
    
    if (in_byte[0]) begin
        en_matrix[0] <= ENCODING_MATRIX_0;
    end
    else begin
        en_matrix[0] <= 0;
    end
    
    if (in_byte[1]) begin
        en_matrix[1] <= ENCODING_MATRIX_1;
    end
    else begin
        en_matrix[1] <= 0;
    end
    
    if (in_byte[2]) begin
        en_matrix[2] <= ENCODING_MATRIX_2;
    end
    else begin
        en_matrix[2] <= 0;
    end
    
    if (in_byte[3]) begin
        en_matrix[3] <= ENCODING_MATRIX_3;
    end
    else begin
        en_matrix[3] <= 0;
    end
    
    if (in_byte[4]) begin
        en_matrix[4] <= ENCODING_MATRIX_4;
    end
    else begin
        en_matrix[4] <= 0;
    end
    
    if (in_byte[5]) begin
        en_matrix[5] <= ENCODING_MATRIX_5;
    end
    else begin
        en_matrix[5] <= 0;
    end
    
    if (in_byte[6]) begin
        en_matrix[6] <= ENCODING_MATRIX_6;
    end
    else begin
        en_matrix[6] <= 0;
    end
    
    if (in_byte[7]) begin
        en_matrix[7] <= ENCODING_MATRIX_7;
    end
    else begin
        en_matrix[7] <= 0;
    end
    
end

//assign en_matrix[0] = (in_byte[0])? ENCODING_MATRIX_0 : 0;
//assign en_matrix[1] = (in_byte[1])? ENCODING_MATRIX_1 : 0;
//assign en_matrix[2] = (in_byte[2])? ENCODING_MATRIX_2 : 0;
//assign en_matrix[3] = (in_byte[3])? ENCODING_MATRIX_3 : 0;
//assign en_matrix[4] = (in_byte[4])? ENCODING_MATRIX_4 : 0;
//assign en_matrix[5] = (in_byte[5])? ENCODING_MATRIX_5 : 0;
//assign en_matrix[6] = (in_byte[6])? ENCODING_MATRIX_6 : 0;
//assign en_matrix[7] = (in_byte[7])? ENCODING_MATRIX_7 : 0;

assign cdw_out_temp = en_matrix[0]^en_matrix[1]^en_matrix[2]^en_matrix[3]^en_matrix[4]^en_matrix[5]^en_matrix[6]^en_matrix[7];

assign cdw_out_rearrange = {cdw_out_temp[13*8-1:13*8-8],
                            cdw_out_temp[14*8-1:14*8-8],
                            cdw_out_temp[15*8-1:15*8-8],
                            cdw_out_temp[16*8-1:16*8-8],
                            cdw_out_temp[9*8-1:9*8-8],
                            cdw_out_temp[10*8-1:10*8-8],
                            cdw_out_temp[11*8-1:11*8-8],
                            cdw_out_temp[12*8-1:12*8-8],
                            cdw_out_temp[5*8-1:5*8-8],
                            cdw_out_temp[6*8-1:6*8-8],
                            cdw_out_temp[7*8-1:7*8-8],
                            cdw_out_temp[8*8-1:8*8-8],
                            cdw_out_temp[1*8-1:1*8-8],
                            cdw_out_temp[2*8-1:2*8-8],
                            cdw_out_temp[3*8-1:3*8-8],
                            cdw_out_temp[4*8-1:4*8-8]};




genvar k;
generate
    for(k =1; k <= 16; k= k+1) begin
        assign cdw_out[8*k-1:8*k-8] = cdw_out_rearrange[(128-1)-(8*k-8):(128-8)-(8*k-8)];
    end
endgenerate
   
endmodule
