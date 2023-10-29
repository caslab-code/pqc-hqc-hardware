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


module reed_muller_encode
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
	
	parameter LOG_N1_BYTES = `CLOG2(N1_BYTES),
	
	parameter N1 = 8*N1_BYTES,
	parameter K = 8*K_BYTES
													
)
(
    input clk,
    input rst,
    input start,
    input [N1-1:0] rs_cdw_in,
    
    input  cdw_out_en,
    input [LOG_N1_BYTES-1:0] cdw_out_addr,
    output [127:0] cdw_out,
    output reg done
    );
    

reg [N1-1:0] cdw_in;
wire[7:0] gate_value;
reg [N1-1:0] cdw_bytes;
wire [N1-K-1:0] cdw_out_int;


always@(posedge clk)
begin
    if (init) begin
        cdw_in <= rs_cdw_in;
    end
    else if (shift_cdw) begin
        cdw_in <= {cdw_in[7:0],cdw_in[N1-1:8]};
    end
end

wire [127:0] encoder_out;
wire [LOG_N1_BYTES-1:0] addr;
rm_encoder ENCODER
(
    .clk(clk),
    .start(0),
    .byte_in(cdw_in[7:0]),
//    .done(),
    .cdw_out(encoder_out)
    );

assign addr = (cdw_out_en)? cdw_out_addr : count_cdw_bytes;

 mem_single #(.WIDTH(128), .DEPTH(N1_BYTES)) CODEWORD
 (
        .clock(clk),
        .data(encoder_out),
        .address(addr),
        .wr_en(wr_en),
        .q(cdw_out)
 );


     
reg init;
reg shift_cdw;
reg wr_en;

reg [LOG_N1_BYTES-1:0] count_cdw_bytes = 0;
reg [3:0] state = 0;
parameter s_wait_start      =   0;
parameter s_encode         =   1;
parameter s_done            =  3;


always@(posedge clk)
begin
    if (rst) begin
        state <= s_wait_start;
        count_cdw_bytes <= 0;
        done <= 0;
    end
    else begin
        if (state == s_wait_start) begin
           done <= 0;
           if (start) begin
               state <= s_encode;
               count_cdw_bytes <= 0;
           end   
        end
        
        else if (state == s_encode) begin
            done <= 0;
            if (count_cdw_bytes == N1_BYTES) begin
                state <= s_done;
            end
            else begin 
                state <= s_encode;
                count_cdw_bytes <= count_cdw_bytes+1;
            end
            
        end
        
        else if (state == s_done) begin
            state <= s_wait_start;
            done <= 1;
            count_cdw_bytes <= 0;
        end
    
    end  
end


always@(state, start) 
begin
    case (state)
        s_wait_start:begin
            if (start) begin
                init <= 1;
                shift_cdw <= 0;
                wr_en <= 0;
            end
            else begin
                init <= 0;
                shift_cdw <= 0;
                wr_en <= 0;
            end
        end
        
        s_encode:begin
           wr_en <= 1;
           shift_cdw <= 1;
           init <= 0;
        end
        
        s_done:begin
           shift_cdw <= 0;
           init <= 0;
           wr_en <= 0;
        end
        
        default: begin
           shift_cdw <= 0;
           init <= 0;
           wr_en <= 0;  
        end
        
    endcase

end 
    
    
endmodule
