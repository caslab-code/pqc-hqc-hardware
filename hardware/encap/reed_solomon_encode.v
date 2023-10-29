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


module reed_solomon_encode
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
	parameter K = 8*K_BYTES,
	
	parameter G_x_WIDTH = (parameter_set == "hqc128")? 256:
	                      (parameter_set == "hqc192")? 264:
	                      (parameter_set == "hqc256")? 480:
	                                                   256,    
	
	//Polynomials
	parameter G_x = (parameter_set == "hqc128")? 256'h0001B5FF_52E4454A_6EAED269_7643AD67_8B15D241_E9F2E949_4B6F75B0_74994559:
	                (parameter_set == "hqc192")? 264'h01_E81DBD32_8EF6E80F_2B52A4EE_019E0D77_9EE086E3_D2A3326B_281B68FD_18EFD82D:
	                (parameter_set == "hqc256")? 480'h0001bbc7_30d8bc27_2f7c4082_b28d1b2f_e80890bf_f6048d63_ef98dbb4_f31f0c7b_d98db7ba_d26173c9_479fd720_65577b96_47943ff0_5b7c79c8_2731a731:
	                                             256'h0001B5FF_52E4454A_6EAED269_7643AD67_8B15D241_E9F2E949_4B6F75B0_74994559  
													
)
(
    input clk,
    input rst,
    input start,
    input [K-1:0] msg_in,
    output [N1-1:0] cdw_out,
    output reg done
    );
    

reg [K-1:0] msg;
wire[7:0] gate_value;
reg [N1-1:0] cdw_bytes;
wire [N1-K-1:0] cdw_out_int;
reg capture_cdw;

assign cdw_out = {msg,cdw_bytes[N1-K-1:0]};

always@(posedge clk)
begin
    if (init_msg) begin
        msg <= msg_in;
    end
    else if (shift_msg) begin
//        msg <= {msg[7:0],msg[K-1:8]};
        msg <= {msg[K-8-1:0],msg[K-1:K-8]};
    end
end



always@(posedge clk)
begin
    if (init_msg) begin
        cdw_bytes <= 0;
    end
    else if (capture_cdw) begin
        cdw_bytes <= cdw_out_int;
    end
end



assign gate_value = msg[K-1:K-8] ^ cdw_bytes[N1-K-1:N1-K-8];

wire done_gf_mul;
wire [G_x_WIDTH*8-1:0] gf_mul_out;
genvar i;

generate 
    for (i=G_x_WIDTH/8; i>0; i =i-1) begin:GF_MUL_SERIES
      gf_mul GFMUL 
      ( .clk(clk),
        .start(1),
        .in_1(gate_value),
        .in_2(G_x[8*i-1:8*i-8]),
        .out(gf_mul_out[8*i-1:8*i-8]),
        .done(done_gf_mul)
        );
    end
endgenerate 
 
  
  cdw_xor_tmp 
  #(.parameter_set(parameter_set))
  CDWXORTMP
  ( .cdw_in(cdw_bytes),
    .tmp_arr(gf_mul_out[N1-K-1:0]),
    .cdw_out(cdw_out_int)
    );  
    
reg init_msg;
reg shift_msg;

reg [4:0] count_msg_bytes = 0;
reg [3:0] state = 0;
parameter s_wait_start      =   0;
parameter s_gf_mult         =   1;
parameter s_mult_done       =   2;
parameter s_update_count    =   3;
parameter s_done            =   4;


always@(posedge clk)
begin
     if (rst) begin
        state <= s_wait_start;
        count_msg_bytes <= 0;
        done <= 0;
    end
    else begin
        if (state == s_wait_start) begin
            done <= 0;
            if (start) begin
                count_msg_bytes <= 0;
                state <= s_gf_mult;
			end
        end 
        
        else if (state == s_gf_mult) begin
              state <= s_mult_done;
              done <= 0;
        end
        
        else if (state == s_mult_done) begin
              state <= s_update_count;
              done <= 0;
        end
        
        else if (state == s_update_count) begin
              if (count_msg_bytes == K_BYTES-1) begin
                    state <= s_wait_start;
                    count_msg_bytes <= 0;
                    done <= 1;
              end
              else begin
                   state <= s_gf_mult;
                   count_msg_bytes <= count_msg_bytes + 1;
                    done <= 0;
              end
        end
        
//        else if (state == s_done) begin
//              state <= s_wait_start;
//              done <= 1;
//        end
        
        
    end 
end


always@(state, start) 
begin
    case (state)
     s_wait_start: 
     begin
        shift_msg <= 0;
        capture_cdw <= 0;
        if (start) begin
            init_msg <= 1;
        end  
        else begin
            init_msg <= 0;
        end
     end
     
     s_gf_mult:
     begin
            init_msg <= 0; 
            shift_msg <= 0; 
            capture_cdw <= 0;
     end
     
     s_mult_done:
     begin
            init_msg <= 0; 
            shift_msg <= 0;
            capture_cdw <= 0; 
     end
     
     s_update_count:
     begin
            init_msg <= 0; 
            shift_msg <= 1;
            capture_cdw <= 1;
     end
     
          
	  default: 
	  begin
	       init_msg <= 0; 
	       shift_msg <= 0; 
	  end         
      
    endcase

end 
    
    
endmodule
