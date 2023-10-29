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


module keygen
#( 

    parameter parameter_set = "hqc128",
    
                                        
    parameter N = (parameter_set == "hqc128")? 17_669:
				  (parameter_set == "hqc192")? 35_851:
			      (parameter_set == "hqc256")? 57_637: 
                                               17_669,
    
    parameter N_32 = N + (32 - N%32)%32,                                           
    parameter PARAM_N_HEX = (parameter_set == "hqc128")? 15'h4505:
				            (parameter_set == "hqc192")? 16'h8c0b:
			                (parameter_set == "hqc256")? 16'he125: 
                                                         15'h4505,
                                                       
    parameter M = (parameter_set == "hqc128")? 15:
				  (parameter_set == "hqc192")? 16:
			      (parameter_set == "hqc256")? 16: 
                                               15,    
    
   
    parameter WEIGHT = (parameter_set == "hqc128")? 66:
					   (parameter_set == "hqc192")? 100:
					   (parameter_set == "hqc256")? 131:
                                                    66,
    
    parameter MAX_WEIGHT = (parameter_set == "hqc128")? 75: 
                           (parameter_set == "hqc192")? 114:
			               (parameter_set == "hqc256")? 149:
                                                        75,
	parameter LOG_WEIGHT = `CLOG2(WEIGHT),
	parameter FILE_PKSEED = "",	
	parameter FILE_SKSEED = "",	
													   																										   
	// memory related constants
	parameter MEM_WIDTH = 128,	
	parameter N_MEM = N + (MEM_WIDTH - N%MEM_WIDTH)%MEM_WIDTH, // Memory width adjustment for N
	parameter N_B = N + (8-N%8)%8, // Byte adjustment on N
	parameter N_Bd = N_B - N, // difference between N and byte adjusted N
	parameter N_MEMd = N_MEM - N_B, // difference between byte adjust and Memory adjusted N
	
	//Poly_mult
	parameter RAMWIDTH = MEM_WIDTH,
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
    parameter LOG_MAX_WEIGHT = `CLOG2(MAX_WEIGHT),
    
     parameter OUT_ADDR_WIDTH = (MEM_WIDTH <= 256)? `CLOG2(N_MEM/MEM_WIDTH) : LOG_WEIGHT,
     
     parameter CT_DESIGN = 1 // CT_DESIGN = 1 Constant time design, CT_DESIGN = 0 Default Design 
	
)
(
    input clk,
    input rst,
	
    input start,
	
	input [3:0]sk_seed_addr,
    input [31:0] sk_seed,
	input sk_seed_wen,
	
	input [3:0]pk_seed_addr,
    input [31:0] pk_seed,
	input pk_seed_wen,

	
	input [1:0] keygen_out_type,	// 00 - X, 01 - Y, 10 - vect_set_Random, 11 - S
	input keygen_out_en,	
	input [OUT_ADDR_WIDTH - 1:0]keygen_out_addr,	
	output [MEM_WIDTH-1:0] keygen_out,
	
	output reg done,
    
`ifdef SHARED
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
	input  [ADDR_WIDTH-1:0]pm_addr_1,
`endif
    
    
    //shake signals
    output reg shake_din_valid, 
    input wire shake_din_ready,
    output reg [31:0] shake_din,
    output wire shake_dout_ready,
    input wire [31:0] shake_dout_scram,
    output reg shake_force_done,
    input wire shake_dout_valid
    
    
    
    
    );



wire shake_din_valid_fw; 
wire shake_din_ready_fw;
wire [31:0] shake_din_fw;
wire shake_dout_ready_fw;
wire [31:0] shake_dout_scram_fw;
wire shake_force_done_fw;
wire shake_dout_valid_fw;

wire shake_din_valid_vr; 
wire shake_din_ready_vr;
wire [31:0] shake_din_vr;
wire shake_dout_ready_vr;
wire [31:0] shake_dout_scram_vr;
wire shake_force_done_vr;
wire shake_dout_valid_vr;


reg sel_fw;
reg start_fw;
wire done_fw;
reg start_vec_random;
wire done_vec_random;
reg [1:0] request_another_vector;
reg start_x_transfer;
wire rd_error_loc;
wire [LOG_WEIGHT-1:0] rd_addr_error_loc;
wire [M-1:0]error_loc;
reg sel_x = 0, sel_y = 0;
reg rd_x = 0, rd_y=0;
reg wen_x = 0;
wire [M-1:0] x_internal;


reg rand_out_rd = 0;	
wire [`CLOG2(X) - 1:0]rand_out_addr_0;
reg [`CLOG2(X) - 1:0]rand_out_addr_0_reg;
wire [MEM_WIDTH-1:0] rand_out_0;
wire [`CLOG2(X) - 1:0]rand_out_addr_1;
reg [`CLOG2(X) - 1:0]rand_out_addr_1_reg;
wire [MEM_WIDTH-1:0] rand_out_1;

assign keygen_out =(keygen_out_type == 2'b00)? {{(MEM_WIDTH-M){1'b0}},x_internal}:
            (keygen_out_type == 2'b01)? {{(MEM_WIDTH-M){1'b0}},error_loc}:
            (keygen_out_type == 2'b10)? rand_out_1: 
                                 pm_out;

always@(posedge clk)
begin
    if (sel_fw) begin
        shake_din_valid     <=  shake_din_valid_fw;
        shake_din           <=  shake_din_fw;
    end
    else begin
        shake_din_valid     <=  shake_din_valid_vr;
        shake_din           <=  shake_din_vr;
    end
end

assign shake_dout_ready = (sel_fw)? shake_dout_ready_fw: shake_dout_ready_vr;


assign shake_din_ready_fw = (sel_fw)? shake_din_ready : 1'b0;
assign shake_dout_scram_fw = shake_dout_scram;
assign shake_dout_valid_fw = (sel_fw)? shake_dout_valid : 1'b0;


assign shake_din_ready_vr = (!sel_fw)? shake_din_ready : 1'b0;
assign shake_dout_scram_vr = shake_dout_scram;
assign shake_dout_valid_vr = (!sel_fw)? shake_dout_valid : 1'b0;


assign rd_error_loc = (sel_x)? rd_x: rd_y;
assign rd_addr_error_loc = (sel_x)? x_addr: y_addr;

generate
    if (CT_DESIGN == 0) begin
      fixed_weight #(.parameter_set(parameter_set), .N(N), .M(M), .WEIGHT(WEIGHT), .FILE_SKSEED(FILE_SKSEED) )
      FIXEDWEIGHT  (
        .clk(clk),
        .rst(rst),
        .start(start_fw),
        .sk_seed(sk_seed),
        .sk_seed_addr(sk_seed_addr),
        .sk_seed_wen(sk_seed_wen),
        
        .done(done_fw),
        .request_another_vector(request_another_vector),
        
        .error_loc(error_loc), 
        .rd_error_loc(((keygen_out_type == 2'b01)&&keygen_out_en==1'b1)?keygen_out_en:rd_error_loc), 
        .rd_addr_error_loc(((keygen_out_type == 2'b01)&&keygen_out_en==1'b1)?keygen_out_addr[LOG_WEIGHT-1:0]:rd_addr_error_loc),
           
            //shake signals
        .seed_valid_internal(shake_din_valid_fw),
        .seed_ready_internal(shake_din_ready_fw),
        .din_shake(shake_din_fw),
        .shake_out_capture_ready(shake_dout_ready_fw),
        .dout_shake_scrambled(shake_dout_scram_fw),
        .force_done_shake(shake_force_done_fw),
        .dout_valid_sh_internal(shake_dout_valid_fw)
      );
     end 
  
    else if (CT_DESIGN == 1) begin
        fixed_weight_ct #(.parameter_set(parameter_set), .N(N), .M(M), .WEIGHT(WEIGHT), .FILE_SKSEED(FILE_SKSEED) )
      FIXEDWEIGHT  (
        .clk(clk),
        .rst(rst),
        .start(start_fw),
        .sk_seed(sk_seed),
        .sk_seed_addr(sk_seed_addr),
        .sk_seed_wen(sk_seed_wen),
        
        .done(done_fw),
        .request_another_vector(request_another_vector),
        
        .error_loc(error_loc), 
        .rd_error_loc(((keygen_out_type == 2'b01)&&keygen_out_en==1'b1)?keygen_out_en:rd_error_loc), 
        .rd_addr_error_loc(((keygen_out_type == 2'b01)&&keygen_out_en==1'b1)?keygen_out_addr[LOG_WEIGHT-1:0]:rd_addr_error_loc),
           
            //shake signals
        .seed_valid_internal(shake_din_valid_fw),
        .seed_ready_internal(shake_din_ready_fw),
        .din_shake(shake_din_fw),
        .shake_out_capture_ready(shake_dout_ready_fw),
        .dout_shake_scrambled(shake_dout_scram_fw),
        .force_done_shake(shake_force_done_fw),
        .dout_valid_sh_internal(shake_dout_valid_fw)
      );
    end
endgenerate

vect_set_random #(.parameter_set(parameter_set), .N(N), .MEM_WIDTH(MEM_WIDTH), .FILE_PKSEED(FILE_PKSEED) )
  VECTSETRAND  (
    .clk(clk),
    .rst(rst),
    
	.rand_out_rd(rand_out_rd),
	.rand_out_addr_0(rand_out_addr_0[`CLOG2(N_MEM/MEM_WIDTH) - 1:0]),
	.rand_out_0(rand_out_0),
	.rand_out_addr_1(((keygen_out_type == 2'b10)&&keygen_out_en==1'b1)?keygen_out_addr:rand_out_addr_1[`CLOG2(N_MEM/MEM_WIDTH) - 1:0]),
	.rand_out_1(rand_out_1),
    
	.pk_seed_wen(pk_seed_wen),
	.pk_seed_addr(pk_seed_addr),
	.pk_seed(pk_seed),
	
	.start(start_vec_random),
    .done(done_vec_random),
    
        //shake signals
    .shake_din_valid(shake_din_valid_vr),
    .shake_din_ready(shake_din_ready_vr),
    .shake_din(shake_din_vr),
    .shake_dout_ready(shake_dout_ready_vr),
    .shake_dout_scram(shake_dout_scram_vr),
    .shake_force_done(shake_force_done_vr),
    .shake_dout_valid(shake_dout_valid_vr)
  );
  
 
 wire [LOG_WEIGHT-1:0] loc_rd_addr;
 wire loc_rd_en;
 
 mem_single #(.WIDTH(M), .DEPTH(WEIGHT) ) x_mem
 (
        .clock(clk),
        .data(error_loc),
        .address(((keygen_out_type == 2'b00)&&keygen_out_en==1'b1)?keygen_out_addr[LOG_WEIGHT-1:0]:loc_rd_en?loc_rd_addr:x_addr_reg),
        .wr_en(wen_x),
        .q(x_internal)
 );
 
 
wire done_poly_mult;
reg start_poly_mult = 0;
wire [LOG_WEIGHT-1:0] y_addr;
wire [MEM_WIDTH-1:0] mux_word_0, mux_word_1;


always@(posedge clk) begin
   rand_out_addr_0_reg <= rand_out_addr_0; 
   rand_out_addr_1_reg <= rand_out_addr_1; 
end 

//poly_mult opt 0 
assign mux_word_0 = (rand_out_addr_0_reg> (X + X%2)/2 - 1)? 0: rand_out_0;
assign mux_word_1 = (rand_out_addr_1_reg> (X + X%2)/2 - 1)? 0: rand_out_1; 


`ifdef SHARED
    assign pm_start      = start_poly_mult;
    assign pm_loc_in     = error_loc;
    assign pm_weight     = WEIGHT;
    assign pm_mux_word_0 = mux_word_0;
    assign pm_mux_word_1 = mux_word_1;
    assign pm_rd_dout    = (keygen_out_type == 2'b11 && keygen_out_en == 1'b1)? keygen_out_en:pm_rd_en;
    assign pm_addr_result= (keygen_out_type == 2'b11 && keygen_out_en == 1'b1)? keygen_out_addr:pm_rd_addr;
    assign pm_add_wr_en  = add_out_valid;
    assign pm_add_addr   = add_out_addr;
    assign pm_add_in     = add_out;
    
    assign y_addr = pm_loc_addr;
    assign rand_out_addr_0 = pm_addr_0;
    assign rand_out_addr_1 = pm_addr_1;
    assign done_poly_mult = pm_valid;
    assign pm_out = pm_dout;

`endif

`ifndef SHARED
   poly_mult #(
  .parameter_set(parameter_set),
  .MAX_WEIGHT(MAX_WEIGHT),
  .N(N),
  .M(M),
  .W(W),
  .RAMWIDTH(RAMWIDTH),
  .X(X)
  
  )
  POLY_MULT  (
		.clk(clk),
		.rst(rst),
		.start(start_poly_mult),
				
		// Shift Position loading
		.loc_addr(y_addr),
		.loc_in(error_loc),
		.weight(WEIGHT),
		
		// Random Vector Loading
		.mux_word_0(mux_word_0),
		.mux_word_1(mux_word_1),
		.addr_0(rand_out_addr_0),
		.addr_1(rand_out_addr_1),
		
		.valid(done_poly_mult),
		.addr_result(((keygen_out_type == 2'b11)&&keygen_out_en==1'b1)?keygen_out_addr:pm_rd_addr),
		.rd_dout(((keygen_out_type == 2'b11)&&keygen_out_en==1'b1)?keygen_out_en:pm_rd_en),
		
		.dout(pm_out),

        .add_in(add_out),
		.add_addr(add_out_addr),
		.add_wr_en(add_out_valid)
  );
`endif  
 
 wire [MEM_WIDTH-1:0] pm_out;
 wire [`CLOG2(N_MEM/MEM_WIDTH) - 1:0] pm_rd_addr;
 wire pm_rd_en;
 
 wire [MEM_WIDTH-1:0] add_out;
 wire [`CLOG2(N_MEM/MEM_WIDTH) - 1:0] add_out_addr;
 wire add_out_valid;
 
 reg start_adder;
 wire done_adder;
 
 
   loc_based_adder #(.parameter_set(parameter_set), .WIDTH(MEM_WIDTH))
  LOC_BASED_ADDER
   (
    .clk(clk),
    .rst(rst),
    
    .start(start_adder),
    
    .loc_rd_addr(loc_rd_addr),
    .loc_rd_en(loc_rd_en),
    .location(x_internal),
    
    .pm_rd_addr(pm_rd_addr),
    .pm_rd_en(pm_rd_en),
    .pm_in(pm_out),
    
    .add_out(add_out),
    .add_out_addr(add_out_addr),
    .add_out_valid(add_out_valid),
    .done(done_adder)
    
    );
 

reg [`CLOG2(N_MEM/MEM_WIDTH)-1:0]pk_rand_addr = 0;
reg [3:0] state = 0;
parameter s_wait_start  =   0;
parameter s_gen_x =   1;
parameter s_gen_y =   2;
parameter s_clear_shake =   3;
parameter s_gen_vec_random = 4;
parameter s_h_mul_y = 5;
parameter s_x_plus_hy = 6;
parameter s_done = 7;
parameter s_wait_for_x_transfer= 8;



always@(posedge clk)
begin

     if (rst) begin
        state <= s_wait_start;
        request_another_vector <= 2'b00;
        rand_out_rd <= 1'b0;
        rd_y <= 1'b0;
    end
    else begin
        if (state == s_wait_start) begin
            done <= 1'b0;
            rd_y <= 1'b0;
            rand_out_rd <= 1'b0;
            request_another_vector <= 2'b00;
            shake_force_done <= 1'b0;
            if (start) begin
				state <= s_gen_x;				
			end 
        end 
        
        else if (state == s_gen_x) begin
            done <= 1'b0;
            rd_y <= 1'b0;
            rand_out_rd <= 1'b0;
            shake_force_done <= 1'b0;
               if (done_fw) begin
                  if (CT_DESIGN == 0) begin
                    state <= s_gen_y;
                    request_another_vector <= 2'b11;
                  end
                  else begin
                    state <= s_wait_for_x_transfer;
                    request_another_vector <= 2'b00;
                  end
               end
               else begin
                  request_another_vector <= 2'b00;
               end
        end
        
        else if (state == s_wait_for_x_transfer) begin
            if (x_transfer_done == 1) begin
                state <= s_gen_y;
                 request_another_vector <= 2'b11;
            end
        end
        
        else if (state == s_gen_y) begin
           done <= 1'b0;
           rd_y <= 1'b0;
           rand_out_rd <= 1'b0;
           if (done_fw) begin
              state <= s_clear_shake;
              request_another_vector <= 2'b10;
              shake_force_done <= 1'b1;
           end
           else begin
              request_another_vector <= 2'b00;
              shake_force_done <= 1'b0;
           end
        end
        
        
        
        else if (state == s_clear_shake) begin
            shake_force_done <= 1'b0;
            rand_out_rd <= 1'b0;
            rd_y <= 1'b0;
            request_another_vector <= 2'b00;
            if (shake_din_ready) begin
                state <= s_gen_vec_random;
            end
        end
        
        
        else if (state == s_gen_vec_random) begin
           request_another_vector <= 2'b00;
           if (done_vec_random) begin
              state <= s_h_mul_y;
              shake_force_done <= 1'b1;
              rand_out_rd <= 1'b1;
              rd_y <= 1'b1;
           end
           else begin
              shake_force_done <= 1'b0;
              rand_out_rd <= 1'b0;
              rd_y <= 1'b0;
           end
        end
        
        else if (state == s_h_mul_y) begin
           request_another_vector <= 2'b00;
           shake_force_done <= 1'b0;
           done <= 1'b0;
           if (done_poly_mult) begin
              state <= s_x_plus_hy;
              rand_out_rd <= 1'b0;
              rd_y <= 1'b0;
           end
           else begin
             rand_out_rd <= 1'b1;
             rd_y <= 1'b1;
           end
        end
        
        else if (state == s_x_plus_hy) begin
            request_another_vector <= 2'b00;
            shake_force_done <= 1'b0;
            rd_y <= 1'b0;
            rd_x <= 1'b0;
            rand_out_rd <= 1'b0;
            if (done_adder) begin
                state <= s_done;
                done <= 1'b1;
                rand_out_rd <= 1'b0;
            end
            else begin
                done <= 1'b0;
            end
        end
        
        else if (state == s_done) begin
               request_another_vector <= 2'b00;
               done <= 1'b0;
               shake_force_done <= 1'b0;
               rand_out_rd <= 1'b0;
        end
        
    end 
end

always@(state, start, done_fw, done_vec_random, shake_din_ready, done_poly_mult) 
begin
    case (state)
     s_wait_start: 
     begin
        
        start_vec_random <= 1'b0;  
        start_x_transfer <= 1'b0;
        start_poly_mult <= 1'b0;
        start_adder <= 1'b0;
        if (start) begin
            start_fw <= 1'b1;
            sel_fw <= 1'b1;
        end
        else begin
            start_fw <= 1'b0;
            sel_fw <= 1'b0;
        end
     end 
     
     s_gen_x: 
     begin
        start_poly_mult <= 1'b0;
        start_vec_random <= 1'b0;
        sel_fw <= 1'b1;   
        start_adder <= 1'b0;
        if (done_fw) begin
            start_x_transfer <= 1'b1;
        end
        else begin
            start_fw <= 1'b0;
            start_x_transfer <= 1'b0;
        end
     end
     
     s_gen_y: 
     begin
        start_poly_mult <= 1'b0;
        start_fw <= 1'b0;
        start_x_transfer <= 1'b0;
        start_vec_random <= 1'b0; 
        start_adder <= 1'b0;  
        if (done_fw) begin
            sel_fw <= 1'b0;
        end
        else begin 
            sel_fw <= 1'b1;
        end
     end
     
     s_clear_shake:
     begin
        start_adder <= 1'b0;
        start_poly_mult <= 1'b0;
        if (shake_din_ready) begin
            start_vec_random <= 1'b1; 
        end
        else begin
            start_vec_random <= 1'b0; 
        end
     end
     
     s_gen_vec_random: 
     begin
        sel_fw <= 1'b0;  
        start_fw <= 1'b0;
        start_x_transfer <= 1'b0;
        start_vec_random <= 1'b0; 
        start_adder <= 1'b0;
        if (done_vec_random) begin
            // polymult signals
            start_poly_mult <= 1'b1;
        end
        else begin
            start_poly_mult <= 1'b0;
        end
     end 
     
     s_h_mul_y: 
     begin
        sel_fw <= 1'b0;  
        start_fw <= 1'b0;
        start_x_transfer <= 1'b0;
        start_vec_random <= 1'b0; 
         start_poly_mult <= 1'b0;
        if (done_poly_mult) begin
            // adder signals
            start_adder <= 1'b1;
        end
        else begin
            start_adder <= 1'b0;
        end
     end 
     
     s_x_plus_hy: 
     begin
        sel_fw <= 1'b0;  
        start_fw <= 1'b0;
        start_x_transfer <= 1'b0;
        start_vec_random <= 1'b0; 
        start_adder <= 1'b0;
	 end
      
	  default: 
	  begin
	       start_x_transfer <= 1'b0;
	       start_vec_random <= 1'b0; 
	       start_fw <= 1'b0; 
	       sel_fw <= 1'b0;
	       start_poly_mult <= 1'b0;
	       
	  end         
      
    endcase

end 


reg [3:0] trx_state = 0;
parameter trx_wait_start  =   0;
parameter trx_tranfer =   1;
parameter trx_done =   2;
reg [LOG_WEIGHT-1:0] x_addr, x_addr_reg = 0;
reg x_transfer_done;
always@(posedge clk)
begin
    x_addr_reg <= x_addr;
end

always@(posedge clk)
begin

     if (rst) begin
        trx_state <= trx_wait_start;
        x_addr <= 0;
        x_transfer_done <= 1'b0;
    end
    else begin
        if (trx_state == trx_wait_start) begin
            x_transfer_done <= 1'b0;
            if (start_x_transfer) begin
				trx_state <= trx_tranfer;
				x_addr <= x_addr+1;				
			end 
			else begin
			    x_addr <= 0;
			end
        end 
        
        else if (trx_state == trx_tranfer) begin
              x_transfer_done <= 1'b0;
              if (x_addr == WEIGHT-1) begin
                  trx_state <= trx_done;
              end 
              else begin
                  x_addr <= x_addr+1;	
              end
        end
        
        else if (trx_state == trx_tranfer) begin
                  trx_state <= trx_done;
                  x_transfer_done <= 1'b0;
        end
        
        else if (trx_state == trx_done) begin
                  trx_state <= trx_wait_start;
                  x_transfer_done <= 1'b1;
        end
        
    end 
end


always@(trx_state, start_x_transfer) 
begin
    case (trx_state)
     trx_wait_start: 
     begin
        wen_x <= 1'b0;
        if (start_x_transfer) begin
            sel_x <= 1'b1;
            rd_x <= 1'b1;
        end
        else begin
            sel_x <= 1'b0;
            rd_x <= 1'b0;
        end
     end
     
     trx_tranfer:
     begin
        sel_x <= 1'b1;
        rd_x <= 1'b1;
        wen_x <= 1'b1;
     end 
     
     trx_done:
     begin
        wen_x <= 1'b1;
        
     end
     
	  default: 
	  begin
	       wen_x <= 1'b0;
	       rd_x <= 1'b0; 
	       sel_x <= 1'b0; 
	  end         
      
    endcase

end 

    
endmodule
