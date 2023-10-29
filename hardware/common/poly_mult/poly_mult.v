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
//`include "clog2.v"

module poly_mult
#( 

    parameter parameter_set = "hqc128",
    
    parameter MAX_WEIGHT = (parameter_set == "hqc128")? 75: 
                           (parameter_set == "hqc192")? 114:
			               (parameter_set == "hqc256")? 149:
			               (parameter_set == "bike")? 71:
                                                        4,
                                                        
    parameter WEIGHT = (parameter_set == "hqc128")? 66: 
                       (parameter_set == "hqc192")? 100:
			           (parameter_set == "hqc256")? 131:
			           (parameter_set == "bike")? 71:
                                                    4,
    
    parameter N = (parameter_set == "hqc128")? 17_669:
				  (parameter_set == "hqc192")? 35_851:
			      (parameter_set == "hqc256")? 57_637: 
			      (parameter_set == "bike")?  12_323: 
                                               31,
    
    parameter M = (parameter_set == "hqc128")? 15:
				  (parameter_set == "hqc192")? 16:
			      (parameter_set == "hqc256")? 16: 
			      (parameter_set == "bike")?   14: 
                                               4, 
                                               
    parameter RAMWIDTH = 128, // Width of each chunk W needs to be divided in to. Best to choose a 2 power
    parameter TWO_N = 2*N,
    parameter W_RAMWIDTH = TWO_N + (RAMWIDTH-TWO_N%RAMWIDTH)%RAMWIDTH, 
//    parameter W_RAMWIDTH = N + (RAMWIDTH-N%RAMWIDTH)%RAMWIDTH, 
    parameter W = W_RAMWIDTH + RAMWIDTH*((W_RAMWIDTH/RAMWIDTH)%2),
    parameter X = W/RAMWIDTH,
    
    parameter LOGX = `CLOG2(X), 
    parameter Y = X/2,
	parameter LOGW = `CLOG2(W),
	parameter W_BY_X = W/X, 
	parameter W_BY_Y = W/Y, // This number needs to be a power of 2 for optimized synthesis
	parameter RAMSIZE = X,
	parameter ADDR_WIDTH = `CLOG2(RAMSIZE),
    parameter LOG_MAX_WEIGHT = `CLOG2(MAX_WEIGHT)
)
(
    input clk,
    input rst,
    input start,
    
	
	// Shift value (location of 1 fro  FixedWeight vector) loading
	input [M-1:0] loc_in,
    input [LOG_MAX_WEIGHT:0] weight,
	output reg [LOGW-1:0] loc_addr,
	
	// Random Bit Vector loading 
	input [W_BY_X-1:0]mux_word_0,
	input [W_BY_X-1:0]mux_word_1,
	output  [ADDR_WIDTH-1:0]addr_0,
	output  [ADDR_WIDTH-1:0]addr_1,
	
    // Mul result
	output reg valid,
	input rd_dout,
    input [`CLOG2(RAMSIZE/2)-1:0]addr_result,
	output [W_BY_X-1:0]dout,
	
	//adder ports
	input add_wr_en,
	input [`CLOG2(RAMSIZE/2)-1:0] add_addr,
	input [RAMWIDTH-1:0] add_in
    
    );

wire [W_BY_X-1:0]dshift;

wire [W_BY_Y-1:0]mux_word;
wire [W_BY_X-1:0]mux_word_0;
wire [W_BY_X-1:0]mux_word_1;

reg wren_0 = 0;
reg wren_1 = 0;

wire [ADDR_WIDTH-1:0] RAMSIZE_minus_shift;

reg [ADDR_WIDTH-1:0]addr_0_reg = 0;
reg [ADDR_WIDTH-1:0]addr_1_reg = 0;

wire [LOGW-1:0]shift_int;
wire [W_BY_Y-1:0]outa;

wire [LOGW-1:0]shift_mul_chunks;
wire [LOGW-1:0]shift_mul_chunks_plus_1;
wire [`CLOG2(W_BY_X):0]shift_int_mask;

reg [ADDR_WIDTH:0] count_chunks=0;
wire [ADDR_WIDTH:0] count_chunks_reg;

reg [ADDR_WIDTH+1:0] count_chunks_inter_mem=0;

wire [W_BY_X-1:0] mask;

wire [LOGW-1:0]shift;

reg [M-1:0] loc_in_reg;

assign addr_0 = addr_0_reg;
assign addr_1 = addr_1_reg;

always@(posedge clk)
begin
    loc_in_reg <= loc_in;
end
  
assign shift = loc_in_reg;
//assign shift = loc_in;
assign mux_word = {mux_word_0,mux_word_1};
assign shift_int = shift % (W_BY_X);


genvar position;
generate
for (position = 0; position < W_BY_Y; position=position+1) begin:u_shift_a
	assign outa[position] = (position >= shift_int) ? mux_word[(position - shift_int)%W_BY_Y] : 1'b0; 
end
endgenerate

 


assign dshift = outa[W_BY_Y-1:W_BY_X];





reg [1:0] inter_mem_wr_delay = 0;

reg [W_BY_X-1:0] din_0_intermediate; 
reg [W_BY_X-1:0] din_1_intermediate;
wire [ADDR_WIDTH-1:0] addr_0_intermediate_mux;
wire [ADDR_WIDTH-1:0] addr_1_intermediate_mux;
reg wren_0_intermediate;
reg wren_1_intermediate;
wire [W_BY_X-1:0] q_0_intermediate;
wire [W_BY_X-1:0] q_1_intermediate;



// interleaved reduction logic


wire [W_BY_X-1:0] din_0;
reg [W_BY_X-1:0] qout_1_reg;
wire [W_BY_X-1:0] din_1;
wire [W_BY_X-1:0] qout_0;
wire [W_BY_X-1:0] qout_1;
reg [W_BY_X-1:0] dshift_reg;
reg [W_BY_X-1:0] dshift_reg_reg;

wire [W_BY_X-1:0] adjusted_msb;
wire [W_BY_X-1:0] adjusted_last_msb;
wire [W_BY_X-1:0] last_lsb;
wire [W_BY_X-1:0] adjusted_lsb;
wire [W_BY_X-1:0] lsb_xor_msb_high;

wire [W_BY_X-1:0] xor_in_0;
wire [W_BY_X-1:0] xor_in_1;

parameter DIFF_BITS = (W_BY_X - (N)%W_BY_X)%W_BY_X;
reg [ADDR_WIDTH-1:0] addr_0_intermediate_reg;

always@(posedge clk) 
begin
    dshift_reg <= dshift;
    dshift_reg_reg <= dshift_reg;
    qout_1_reg <= qout_1;
    addr_0_intermediate_reg <= addr_0_intermediate;
end


assign adjusted_msb = (addr_0_intermediate_reg == RAMSIZE/2 - 2)?{{(DIFF_BITS){1'b0}},dshift_reg[(RAMWIDTH-DIFF_BITS)-1:0]} : 
                                                                 {dshift_reg[RAMWIDTH-DIFF_BITS-1: 0], dshift_reg_reg[RAMWIDTH-1:RAMWIDTH-DIFF_BITS]};

assign adjusted_lsb = qout_1_reg;

assign xor_in_0 = (addr_0_intermediate < RAMSIZE/2 - 1)? dshift_reg : adjusted_lsb;
assign xor_in_1 = (addr_0_intermediate < RAMSIZE/2 - 1)? qout_1_reg : adjusted_msb;


assign din_0 = (state == S_CLEAR_INTER_MEM)? 0: xor_in_0 ^ xor_in_1;
            
 
 
reg [ADDR_WIDTH-1:0] addr_0_int_red_mem;
reg [ADDR_WIDTH-1:0] addr_1_int_red_mem;


assign dout = qout_0;
               
mem_dual #(.WIDTH(W_BY_X), .DEPTH(RAMSIZE/2)) INTERLEAVED_RED_MEM (
    .clock(clk),
    .data_0(din_0),
    .data_1(add_wr_en? add_in: 0),
    .address_0(rd_dout? addr_result :addr_0_int_red_mem),
    .address_1(add_wr_en? add_addr: addr_1_int_red_mem),
    .wren_0(wren_0_intermediate),
    .wren_1(add_wr_en? add_wr_en: wren_1_intermediate),
    .q_0(qout_0),
    .q_1(qout_1)
  );



reg [ADDR_WIDTH-1:0] addr_0_intermediate;

assign RAMSIZE_minus_shift = (RAMSIZE - shift[LOGW-1:LOGW-ADDR_WIDTH]);

reg [3:0] state = 0;
// Below are states
parameter S_WAIT_START_L            =   0;
parameter S_CLEAR_INTER_MEM         =   1;
parameter S_LOAD_DONE_L	         =   2;
parameter S_ADDR_SETTING            =   3;
parameter S_SHIFT_L                 =   4;
parameter S_MUL_DONE                =   5;
parameter S_REDUCTION_START         =   6;
parameter S_WAIT_REDUCTION          =   7;
parameter S_REDUCTION_DONE          =   8;

parameter S_STALL          =   9;



assign count_chunks_reg = addr_0_intermediate + 1;

always@(posedge clk)
begin
    if (rst) begin
        state <= S_WAIT_START_L;
		addr_0_reg <=  0;
		addr_1_reg <=  0;
		count_chunks <= 0;
		loc_addr <= 0;
		valid <= 1'b0;
		
		//intermediate mem
		din_0_intermediate <= 0; 
        din_1_intermediate <= 0;
        addr_0_intermediate <= 0;
//        addr_1_intermediate <= 1;
        wren_0_intermediate <= 0;
        wren_1_intermediate <= 0;
        count_chunks_inter_mem <= 0;
        
        addr_0_int_red_mem <= 0;
        addr_1_int_red_mem <= 0;
    end
    else if (rd_dout == 0) begin
		
        if (state == S_WAIT_START_L) begin
			count_chunks <=0;
			valid <= 1'b0;
			
			//intermediate mem
            din_0_intermediate <= 0; 
            din_1_intermediate <= 0;
            addr_0_intermediate <= 0;
//            addr_1_intermediate <= 1;
            wren_0_intermediate <= 0;
            wren_1_intermediate <= 0;
            count_chunks_inter_mem <= 0;
            inter_mem_wr_delay <= 0;
            
            addr_0_int_red_mem <= 0;
            addr_1_int_red_mem <= 1;
			
			if (start) begin
			    state <= S_CLEAR_INTER_MEM; 
				
				if (shift[LOGW-1:LOGW-ADDR_WIDTH] == 0) begin
				    addr_0_reg <=0;
				end
				else begin
				    if (RAMSIZE_minus_shift > Y - 1) begin
                        addr_0_reg <= 0;
                    end
                    else begin
                        addr_0_reg <=RAMSIZE_minus_shift;
                    end
				end
				
				if (shift[LOGW-1:LOGW-ADDR_WIDTH] == RAMSIZE-1) begin
				    addr_1_reg <=0;
				end
				else begin
				    if (RAMSIZE_minus_shift > Y - 1) begin
                        addr_1_reg <= RAMSIZE-1;
                     end
                     else begin
                        addr_1_reg <=(RAMSIZE_minus_shift - 1);
                     end
				end
				
				loc_addr <= 0;	
				din_0_intermediate <= 0; 
                din_1_intermediate <= 0;
				addr_0_intermediate <= 0;
				wren_0_intermediate <= 1;
                wren_1_intermediate <= 1;
			end
        end 
        
        
        else if (state == S_CLEAR_INTER_MEM) begin
			if (count_chunks_inter_mem == RAMSIZE/4) begin
			    state <= S_ADDR_SETTING;
				count_chunks_inter_mem <= 0;
                addr_0_intermediate <= 0;
				wren_0_intermediate <= 0;
                wren_1_intermediate <= 0;
			end
			else begin
				//clear the intermediate mem
                din_0_intermediate <= 0; 
                din_1_intermediate <= 0;
                wren_0_intermediate <= 1;
                wren_1_intermediate <= 1;
                count_chunks_inter_mem <= count_chunks_inter_mem +1;
                
                if (addr_0_intermediate + 2 == RAMSIZE/2) begin
                    addr_0_intermediate <=0;
                    addr_0_int_red_mem <=0;
                end
                else begin
                   addr_0_intermediate <= (addr_0_intermediate + 2);
                   addr_0_int_red_mem <=  (addr_0_int_red_mem + 2);
                end
                
                if (addr_1_int_red_mem + 2 == RAMSIZE/2-1) begin
                    addr_1_int_red_mem <=0;
                end
                else begin
                    addr_1_int_red_mem <= (addr_1_int_red_mem + 2);
                end
                
                
			end	
		end
        
        
        else if (state == S_ADDR_SETTING) begin
            
            if (shift[LOGW-1:LOGW-ADDR_WIDTH] == 0) begin
                addr_0_reg <=0;
            end
            else begin
                    if (RAMSIZE_minus_shift > Y - 1) begin
                        addr_0_reg <= 0;
                    end
                    else begin
                        addr_0_reg <=RAMSIZE_minus_shift;
                    end
            end
            
            if (shift[LOGW-1:LOGW-ADDR_WIDTH] == RAMSIZE-1) begin
                addr_1_reg <=0;
            end
            else begin
                if (RAMSIZE_minus_shift > Y - 1) begin
                    addr_1_reg <= RAMSIZE-1;
                 end
                 else begin
                    addr_1_reg <=(RAMSIZE_minus_shift - 1);
                 end
            end
            
            
		    state <= S_SHIFT_L;

            inter_mem_wr_delay <= 0;
            wren_0_intermediate <= 0;
            addr_0_intermediate <= (loc_in/RAMWIDTH - 1);
            
            addr_0_int_red_mem <= (loc_in/RAMWIDTH - 1);
            addr_1_int_red_mem <= (loc_in/RAMWIDTH);
        end
		
		else if (state == S_STALL) begin
		   state <= S_SHIFT_L;
		end
		
		else if (state == S_SHIFT_L) begin
            // read the intermediate value and xor with the shifted values
            if (inter_mem_wr_delay == 0) begin
                wren_0_intermediate <= 0;
                addr_0_intermediate <= (addr_0_intermediate + 1);
                inter_mem_wr_delay <= 1;
                
                if (addr_0_int_red_mem == RAMSIZE/2 - 1) begin
                    addr_0_int_red_mem <= 0;
                end
                else begin
                    addr_0_int_red_mem <= (addr_0_int_red_mem + 1);
                end
                if (addr_1_int_red_mem == RAMSIZE/2 - 1) begin
                    addr_1_int_red_mem <= 0;
                end
                else begin
                    addr_1_int_red_mem <= (addr_1_int_red_mem + 1);
                end
                
                
            end else if (inter_mem_wr_delay == 1) begin
                wren_0_intermediate <= 1;
                inter_mem_wr_delay <= 2;
                
                if (addr_1_int_red_mem == RAMSIZE/2 - 1) begin
                    addr_1_int_red_mem <= 0;
                end
                else begin
                    addr_1_int_red_mem <= (addr_1_int_red_mem + 1);
                end
                
            end else if (inter_mem_wr_delay == 2) begin
                wren_0_intermediate <= 1;
                addr_0_intermediate <= (addr_0_intermediate + 1);
                
                if (addr_0_int_red_mem == RAMSIZE/2 - 1) begin
                    addr_0_int_red_mem <= 0;
                end
                else begin
                    addr_0_int_red_mem <= (addr_0_int_red_mem + 1);
                end
                if (addr_1_int_red_mem == RAMSIZE/2 - 1) begin
                    addr_1_int_red_mem <= 0;
                end
                else begin
                    addr_1_int_red_mem <= (addr_1_int_red_mem + 1);
                end
            end

			if (count_chunks == RAMSIZE/2) begin
			    state <= S_LOAD_DONE_L;
			    loc_addr <= loc_addr + 1;
				
                if (shift[LOGW-1:LOGW-ADDR_WIDTH] == 0) begin
                    addr_0_reg <=0;
                end
                else begin
                     addr_0_reg <=RAMSIZE_minus_shift;
                end
                
                if (shift[LOGW-1:LOGW-ADDR_WIDTH] == RAMSIZE-1) begin
                    addr_1_reg <=0;
                end
                else begin
                      addr_1_reg <=(RAMSIZE_minus_shift - 1);
                end
				
				count_chunks <= 0;
			end
			else begin
				
				if (addr_0_reg + 1 == RAMSIZE) begin
                    addr_0_reg <=0;
                end
                else begin
                   addr_0_reg <= (addr_0_reg + 1);
                end
                
                if (addr_1_reg + 1 == RAMSIZE) begin
                    addr_1_reg <=0;
                end
                else begin
                    addr_1_reg <= (addr_1_reg + 1);
                end
									   	       	        
				count_chunks <= count_chunks +1;
			end	
		end
        
        
		else if (state == S_LOAD_DONE_L) begin
		    addr_0_intermediate <= (addr_0_intermediate + 1);
            
            if (addr_0_int_red_mem == RAMSIZE/2 - 1) begin
                    addr_0_int_red_mem <= 0;
            end
            else begin
                addr_0_int_red_mem <= (addr_0_int_red_mem + 1);
            end
            if (addr_1_int_red_mem == RAMSIZE/2 - 1) begin
                addr_1_int_red_mem <= 0;
            end
            else begin
                addr_1_int_red_mem <= (addr_1_int_red_mem + 1);
            end
			
			if (loc_addr < weight) begin
                state <= S_ADDR_SETTING;
            end
            else begin
                state <= S_MUL_DONE;
            end
		end
		
		
		else if (state == S_MUL_DONE) begin
            wren_0_intermediate <= 0;
            valid <= 1'b1;
            state <= S_WAIT_START_L;
		end

    end 
end 


endmodule
