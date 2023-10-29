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


module v_minus_uy
#( 

    parameter parameter_set = "hqc256",
                                                   
    parameter N1_BYTES =    (parameter_set == "hqc128")? 46:
				            (parameter_set == "hqc192")? 56:
				            (parameter_set == "hqc256")? 90:
				                                         46,
	
	
	parameter MAX_WEIGHT =  (parameter_set == "hqc128")? 75:
							(parameter_set == "hqc192")? 114:
							(parameter_set == "hqc256")? 149: 
														 75,
	
	parameter N = (parameter_set == "hqc128")? 17_669:
				  (parameter_set == "hqc192")? 35_851:
			      (parameter_set == "hqc256")? 57_637: 
                                               17_669,
                                               
	parameter M = (parameter_set == "hqc128")? 15:
				  (parameter_set == "hqc192")? 16:
			      (parameter_set == "hqc256")? 16: 
                                               15,
	
	parameter N1 = 8*N1_BYTES,
	
	parameter LOG_MAX_WEIGHT = `CLOG2(MAX_WEIGHT),
	parameter LOG_N1_BYTES = `CLOG2(N1_BYTES),
	
		
    parameter WEIGHT = (parameter_set == "hqc128")? 66:
					   (parameter_set == "hqc192")? 100:
					   (parameter_set == "hqc256")? 131:
                                                    66,
    parameter LOG_WEIGHT = `CLOG2(WEIGHT),

	
		//Poly_mult
	parameter RAMWIDTH = 128,
    parameter TWO_N = 2*N,
    parameter W_RAMWIDTH = TWO_N + (RAMWIDTH-TWO_N%RAMWIDTH)%RAMWIDTH, 
    parameter W = W_RAMWIDTH + RAMWIDTH*((W_RAMWIDTH/RAMWIDTH)%2),
    parameter X = W/RAMWIDTH,
    parameter LOGX = `CLOG2(X), 
    parameter Y = X/2,
	parameter LOGW = `CLOG2(W),
	parameter W_BY_X = W/X, 
	parameter W_BY_Y = W/Y, // This number needs to be a power of 2 for optimized synthesis
    parameter RAMSIZE = X,
	parameter ADDR_WIDTH = `CLOG2(RAMSIZE),

    
    	// memory related constants
	parameter MEM_WIDTH = RAMWIDTH,	
	parameter N_MEM = N + (MEM_WIDTH - N%MEM_WIDTH)%MEM_WIDTH, // Memory width adjustment for N
	parameter N_B = N + (8-N%8)%8, // Byte adjustment on N
	parameter N_Bd = N_B - N, // difference between N and byte adjusted N
	parameter N_MEMd = N_MEM - N_B, // difference between byte adjust and Memory adjusted N
	 
	parameter RAMDEPTH = (N+(RAMWIDTH-N%RAMWIDTH)%RAMWIDTH)/RAMWIDTH, //u RAM depth
	parameter LOG_RAMDEPTH = `CLOG2(RAMDEPTH)
														
)
(
    input clk,
    input rst,
    input start,
	
    output reg done,
	
	input [LOG_WEIGHT-1:0] y_addr,
	input [M-1:0] y,
	
	input [RAMWIDTH-1:0] uv_0,
	input [RAMWIDTH-1:0] uv_1,	
	output [`CLOG2(X)-1:0] uv_addr_0,
	output [`CLOG2(X)-1:0] uv_addr_1,
	output reg sel_uv, // sel_hs = 0 input is h, sel_hs = 1 input is s 
	
	input out_en,
	input [`CLOG2(RAMDEPTH)-1:0] out_addr,
	output [RAMWIDTH-1:0] u_minus_vy_out,
	
	// poly mult ports
	output pm_start,    
	output [M-1:0] pm_loc_in,
    output [LOG_MAX_WEIGHT:0] pm_weight,
	output [W_BY_X-1:0]pm_mux_word_0,
	output [W_BY_X-1:0]pm_mux_word_1,
	output pm_rd_dout,
    output [`CLOG2(RAMSIZE/2)-1:0]pm_addr_result,
	output pm_add_wr_en,
	output [`CLOG2(RAMSIZE/2)-1:0] pm_add_addr,
	output [RAMWIDTH-1:0] pm_add_in,
	
	input [LOGW-1:0] pm_loc_addr,
	input [W_BY_X-1:0]pm_dout,
	input pm_valid,
	input  [ADDR_WIDTH-1:0]pm_addr_0,
	input  [ADDR_WIDTH-1:0]pm_addr_1
		
    );
   



wire [`CLOG2(X)-1:0] uv_addr_0_mul;  
wire [RAMWIDTH-1:0] uv_in_0;
wire [RAMWIDTH-1:0] uv_in_1;
wire [RAMWIDTH-1:0] pm_out;
reg start_poly_mult;
wire done_poly_mult;
reg poly_mult_on;

assign u_minus_vy_out = pm_out;



assign uv_addr_0 = (sel_uv)? xor_add_addr: uv_addr_0_mul;

// Non Optimized Polymult
//assign uv_in_0 = (uv_addr_0_mul <= X/2)? uv_0 : 0;
//assign uv_in_1 = (uv_addr_1 <= X/2)? uv_1 : 0;

//polymult optimization
reg  [`CLOG2(X)-1:0] uv_addr_0_mul_reg;
reg  [`CLOG2(X)-1:0] uv_addr_1_reg;
always@(posedge clk) begin
   uv_addr_0_mul_reg <= uv_addr_0_mul; 
   uv_addr_1_reg <= uv_addr_1; 
end

assign uv_in_0 = (uv_addr_0_mul_reg> (X + X%2)/2 - 1)? 0: uv_0;
assign uv_in_1 = (uv_addr_1_reg> (X + X%2)/2 - 1)? 0: uv_1;


assign pm_start      = start_poly_mult;
assign pm_loc_in     = y;
assign pm_weight     = WEIGHT;
assign pm_mux_word_0 = uv_in_0;
assign pm_mux_word_1 = uv_in_1;
assign pm_rd_dout    = out_en? 1'b1 :xor_add_en;
assign pm_addr_result= out_en? out_addr : xor_add_addr;
assign pm_add_wr_en  = xor_add_out_valid;
assign pm_add_addr   = xor_add_out_addr;
assign pm_add_in     = xor_add_out;

assign y_addr = pm_loc_addr;
assign uv_addr_0_mul = pm_addr_0;
assign uv_addr_1 = pm_addr_1;
assign done_poly_mult = pm_valid;
assign pm_out = pm_dout;                         

// poly_mult_opt_1 #(
//// poly_mult #(
//  .parameter_set(parameter_set),
//  .MAX_WEIGHT(MAX_WEIGHT),
//  .N(N),
//  .M(M),
//  .W(W),
//  .RAMWIDTH(RAMWIDTH),
//  .X(X)
  
//  )
//  POLY_MULT  (
//		.clk(clk),
//		.rst(rst),
//		.start(start_poly_mult),
				
//		// Shift Position loading
//		.loc_addr(y_addr),
//		.loc_in(y),
//		.weight(WEIGHT),
		
//		// Random Vector Loading
//		.mux_word_0(uv_in_0),
//		.mux_word_1(uv_in_1),
//		.addr_0(uv_addr_0_mul),
////		.addr_0(uv_addr_0),
//		.addr_1(uv_addr_1),
		
//		.valid(done_poly_mult),
//		.addr_result(out_en? out_addr : xor_add_addr),
//		.rd_dout(out_en? 1'b1 :xor_add_en),
//		.dout(pm_out),
		
//        .add_in(xor_add_out),
//		.add_addr(xor_add_out_addr),
//		.add_wr_en(xor_add_out_valid)
//  );


 wire [RAMWIDTH-1:0] pm_out;
 wire [`CLOG2(N_MEM/MEM_WIDTH) - 1:0] pm_rd_addr;
 wire pm_rd_en;
 
 wire [MEM_WIDTH-1:0] add_out;
 wire [`CLOG2(N_MEM/MEM_WIDTH) - 1:0] add_out_addr;
 wire add_out_valid;
 

  
  reg start_adder;
  wire done_adder;
  wire [RAMWIDTH-1:0] add_in_1;
  wire [RAMWIDTH-1:0] add_in_2;
  wire xor_add_en;
  wire [LOG_RAMDEPTH-1:0] xor_add_addr;
  
  wire [RAMWIDTH-1:0]  xor_add_out;
  wire [LOG_RAMDEPTH-1:0] xor_add_out_addr;
  wire xor_add_out_valid;
  
  assign add_in_1 = pm_out;
  assign add_in_2 = uv_0;
   
  xor_based_adder #(.parameter_set(parameter_set), .N(N) , .WIDTH(RAMWIDTH))
  XOR_BASED_ADDER
   (
    .clk(clk),
    .rst(rst),
    
    .start(start_adder),
    
    .in_1(add_in_1),
    .in_2(add_in_2),
    .in_addr(xor_add_addr),
    .in_rd_en(xor_add_en),
    
    .add_out(xor_add_out),
    .add_out_addr(xor_add_out_addr),
    .add_out_valid(xor_add_out_valid),
    .done(done_adder)
    
    );


reg [3:0] state = 0;
parameter s_wait_start  =   0;
parameter s_u_mul_y =   1;
parameter s_v_minus_uy =   2;
parameter s_done =   3;




always@(posedge clk)
begin

     if (rst) begin
        state <= s_wait_start;
        sel_uv <= 0;
        done <= 1'b0;
        
    end
    else begin
        if (state == s_wait_start) begin
            sel_uv <= 0;
            done <= 1'b0;
            if (start) begin
                state <= s_u_mul_y;
            end
        end 
        
        else if (state == s_u_mul_y) begin
            done <= 1'b0;
           if (done_poly_mult) begin
                state <= s_v_minus_uy;
//                state <= s_done;
                sel_uv <= 1;
           end
           else begin
                sel_uv <= 0;
           end
        end
        
        else if (state == s_v_minus_uy) begin
            sel_uv <= 1;
             done <= 1'b0;
		    if (done_adder) begin
                state <= s_done;
            end
		end

		else if (state == s_done) begin
		      state <= s_wait_start;
		      sel_uv <= 0;
		      done <= 1'b1;
		end
        
    end 
end

always@(state, start, done_poly_mult, done_adder) 
begin
    case (state)
     s_wait_start: 
     begin
        start_adder <= 0;
        if (start) begin
            start_poly_mult <= 1;
        end
        else begin
            start_poly_mult <= 0;
        end
     end
     
     s_u_mul_y: 
     begin
        start_poly_mult <= 0;
        if (done_poly_mult) begin
            start_adder <= 1;
        end
        else begin
            start_adder <= 0;
        end
     end
     
     s_v_minus_uy: 
     begin
        start_poly_mult <= 0;
        start_adder <= 0;
     end 
     
     s_done: 
     begin
        start_poly_mult <= 0;
        start_adder <= 0;
     end 
     
   
     
      
	  default: 
	  begin
        start_poly_mult <= 0;
        start_adder <= 0;
	  end         
      
    endcase

end 


endmodule
