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


module encrypt
#( 

    parameter parameter_set = "hqc256",
                                                   
    parameter N1_BYTES =    (parameter_set == "hqc128")? 46:
				            (parameter_set == "hqc192")? 56:
				            (parameter_set == "hqc256")? 90:
				                                         46,
	
	parameter K_BYTES = (parameter_set == "hqc128")? 16:
				        (parameter_set == "hqc192")? 24:
			            (parameter_set == "hqc256")? 32: 
                                                     16,
	
	parameter WEIGHT_ENC =  (parameter_set == "hqc128")? 75:
							(parameter_set == "hqc192")? 114:
							(parameter_set == "hqc256")? 149: 
														 75,
	
	parameter N = (parameter_set == "hqc128")? 17_669:
				  (parameter_set == "hqc192")? 35_851:
			      (parameter_set == "hqc256")? 57_637: 
                                               17_669,
    
    parameter N1N2 = (parameter_set == "hqc128")? 17_664:
				     (parameter_set == "hqc192")? 35_851:
			         (parameter_set == "hqc256")? 57_637: 
                                                  17_669,
                                               
	parameter M = (parameter_set == "hqc128")? 15:
				  (parameter_set == "hqc192")? 16:
			      (parameter_set == "hqc256")? 16: 
                                               15,
	
	parameter N1 = 8*N1_BYTES,
	parameter K = 8*K_BYTES,
	
	parameter LOG_WEIGHT_ENC = `CLOG2(WEIGHT_ENC),
	parameter LOG_N1_BYTES = `CLOG2(N1_BYTES),
	
	parameter FILE_THETA = "",
	
	parameter shake_squeeze = (parameter_set == "hqc128")? 32'h40000740:
						      (parameter_set == "hqc192")? 32'h40000ac0:
						      (parameter_set == "hqc256")? 32'h40000e00:
								    					   32'h40000740,


	
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
    parameter LOG_MAX_WEIGHT = `CLOG2(WEIGHT_ENC),
    
    	// memory related constants
	parameter MEM_WIDTH = RAMWIDTH,	
	parameter N_MEM = N + (MEM_WIDTH - N%MEM_WIDTH)%MEM_WIDTH, // Memory width adjustment for N
	parameter N_B = N + (8-N%8)%8, // Byte adjustment on N
	parameter N_Bd = N_B - N, // difference between N and byte adjusted N
	parameter N_MEMd = N_MEM - N_B, // difference between byte adjust and Memory adjusted N
	 
	parameter RAMDEPTH = (N+(RAMWIDTH-N%RAMWIDTH)%RAMWIDTH)/RAMWIDTH, //u RAM depth
	parameter LOG_RAMDEPTH = `CLOG2(RAMDEPTH),
	
	parameter COPIES_OF_CDW = (parameter_set == "hqc128")? 3 : 5,
	
	parameter CT_DESIGN = 2'b10  
													
)
(
    input clk,
    input rst,
    input start,
    input [K-1:0] msg_in,
    
	input [3:0]theta_addr,
    input [31:0] theta,
	input theta_wen,
	
    output reg done,
	
//	input [RAMWIDTH-1:0] hs_0,
//	input [RAMWIDTH-1:0] hs_1,	
//	output [`CLOG2(X)-1:0] hs_addr_0,
//	output [`CLOG2(X)-1:0] hs_addr_1,
//	output reg sel_hs, // sel_hs = 0 input is h, sel_hs = 1 input is s 
	
	input [RAMWIDTH-1:0] s_0,
	input [RAMWIDTH-1:0] s_1,	
	output [`CLOG2(X)-1:0] s_addr_0,
	output [`CLOG2(X)-1:0] s_addr_1,
	
	input [RAMWIDTH-1:0] h_0,
	input [RAMWIDTH-1:0] h_1,	
	output [`CLOG2(X)-1:0] h_addr_0,
	output [`CLOG2(X)-1:0] h_addr_1,
	
	
	input sel_uv,  // sel_uv = 0 output is u, sel_uv = 1 output is v
	input u_v_out_en,
	input [`CLOG2(RAMDEPTH)-1:0] u_v_out_addr,
	output [RAMWIDTH-1:0] u_v_out,
	
	input u_v_in_wen,
	input [`CLOG2(RAMDEPTH)-1:0] u_v_in_addr,
	input [RAMWIDTH-1:0] u_v_in,
	
	output reg done_fixed_weight,

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
    output wire  shake_din_valid, 
    input  wire shake_din_ready,
    output wire  [31:0] shake_din,
    output wire  shake_dout_ready,
    input  wire [31:0] shake_dout_scram,
    output reg shake_force_done,
    input  wire shake_dout_valid
	
    );

reg sel_hs; // sel_hs = 0 input is h, sel_hs = 1 input is s 
wire [RAMWIDTH-1:0] hs_0;
wire [RAMWIDTH-1:0] hs_1;	
wire  [`CLOG2(X)-1:0] hs_addr_0;
wire  [`CLOG2(X)-1:0] hs_addr_1;
  
reg start_fw;   
wire done_fw;
reg [1:0] request_another_vector;
//reg rd_error_loc;
//reg [LOG_WEIGHT_ENC-1:0] rd_addr_error_loc;
wire [M-1:0]error_loc;

wire shake_din_valid_fw; 
wire shake_din_ready_fw;
wire [31:0] shake_din_fw;
wire shake_dout_ready_fw;
wire [31:0] shake_dout_scram_fw;
wire shake_force_done_fw;
wire shake_dout_valid_fw;

reg sel_fw;
reg start_encode;
wire done_encode;

assign shake_din_valid = shake_din_valid_fw;
assign shake_din_ready_fw = shake_din_ready;
assign shake_din = shake_din_fw;
assign shake_dout_ready = shake_dout_ready_fw;
assign shake_dout_scram_fw = shake_dout_scram;
assign shake_dout_valid_fw = shake_dout_valid;



wire rd_error_loc;
wire [LOG_WEIGHT_ENC-1:0] rd_addr_error_loc;

assign rd_error_loc = (rd_fw|sel_e)? 1'b1: 1'b0;

assign rd_addr_error_loc = sel_fw? fw_addr: 
                           sel_e? r1_e_rd_addr: 
                           0;
generate
    if (CT_DESIGN == 2'b00) begin
      fixed_weight #(
      .parameter_set(parameter_set), 
      .N(N), 
      .M(M), 
      .WEIGHT(WEIGHT_ENC), 
      .FILE_SKSEED(FILE_THETA), 
      .squeeze_0(shake_squeeze),
      .squeeze_1(shake_squeeze),
      .squeeze_2(shake_squeeze),
      .squeeze_3(shake_squeeze)
      )
      FIXEDWEIGHT  (
        .clk(clk),
        .rst(rst),
        .start(start_fw),
        .sk_seed(theta),
        .sk_seed_addr(theta_addr),
        .sk_seed_wen(theta_wen),
        
        .done(done_fw),
        .request_another_vector(request_another_vector),
        
        .error_loc(error_loc), 
//        .rd_error_loc((rd_fw|sel_e)? 1'b1: 1'b0), 
        .rd_error_loc(rd_error_loc), 
//        .rd_addr_error_loc(sel_fw? fw_addr: sel_e? e_rd_addr: 0),
        .rd_addr_error_loc(rd_addr_error_loc),
           
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
 
    else if (CT_DESIGN == 2'b01) begin 
        fixed_weight_ct #(
      .parameter_set(parameter_set), 
      .N(N), 
      .M(M), 
      .WEIGHT(WEIGHT_ENC), 
      .FILE_SKSEED(FILE_THETA), 
//      .squeeze_0(shake_squeeze),
//      .squeeze_1(shake_squeeze),
//      .squeeze_2(shake_squeeze),
//      .squeeze_3(shake_squeeze),
      .NUM_OF_FW_VEC(3)      
      )
      FIXEDWEIGHT  (
        .clk(clk),
        .rst(rst),
        .start(start_fw),
        .sk_seed(theta),
        .sk_seed_addr(theta_addr),
        .sk_seed_wen(theta_wen),
        
        .done(done_fw),
        .request_another_vector(request_another_vector),
        
        .error_loc(error_loc), 
//        .rd_error_loc((rd_fw|sel_e)? 1'b1: 1'b0), 
        .rd_error_loc(rd_error_loc), 
//        .rd_addr_error_loc(sel_fw? fw_addr: sel_e? e_rd_addr: 0),
        .rd_addr_error_loc(rd_addr_error_loc),
           
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
    
    
   else if (CT_DESIGN == 2'b10) begin 
        fixed_weight_cww #(
      .parameter_set(parameter_set), 
      .N(N), 
      .M(M), 
      .WEIGHT(WEIGHT_ENC), 
      .FILE_SKSEED(FILE_THETA)
      )
      FIXEDWEIGHT  (
        .clk(clk),
        .rst(rst),
        .start(start_fw),
        .sk_seed(theta),
        .sk_seed_addr(theta_addr),
        .sk_seed_wen(theta_wen),
        
        .done(done_fw),
        .request_another_vector(request_another_vector),
        
        .error_loc(error_loc), 
        .rd_error_loc(rd_error_loc), 
        .rd_addr_error_loc(rd_addr_error_loc),
           
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

assign u_v_out = (sel_uv)? pm_out : u_out;
 
wire [127:0] cdw_out;
reg  cdw_out_en = 0;
wire  [LOG_N1_BYTES-1:0] cdw_out_addr;
  
   concat_code 
   #(.parameter_set(parameter_set))
   ENCODE
   ( .clk(clk),
     .rst(rst),
     .start(start_encode),
     .msg_in(msg_in[K-1:0]),
    
	 .cdw_out_addr(cdw_out_addr),
     .cdw_out_en(xor_add_en),
     .cdw_out(cdw_out),
    
     .done(done_encode)
     );
	
  mem_single #(.WIDTH(M), .DEPTH(WEIGHT_ENC) ) r1_mem
  (
         .clock(clk),
         .data(error_loc),
         .address(rd_fw?fw_addr_reg:r1_e_rd_addr),
         .wr_en(wen_fw & en_r1),
         .q(r1_internal)
  );
 
  mem_single #(.WIDTH(M), .DEPTH(WEIGHT_ENC) ) r2_mem
  (
         .clock(clk),
         .data(error_loc),
         .address(rd_fw?fw_addr_reg:loc_addr),
         .wr_en(wen_fw & en_r2),
         .q(r2_internal)
  );

wire [RAMWIDTH-1:0] u_out;
  mem_single #(.WIDTH(RAMWIDTH), .DEPTH(RAMDEPTH)) u_mem
  (
         .clock(clk),
         .data(u_v_in_wen ? u_v_in : pm_out),
         .address(u_v_out_en? u_v_out_addr : u_v_in_wen? u_v_in_addr : u_cpy_addr_reg),
         .wr_en((u_v_in_wen && sel_uv == 0)? 1: wen_u),
         .q(u_out)
  );
  
wire [RAMWIDTH-1:0] hs_in_0;
wire [RAMWIDTH-1:0] hs_in_1;
reg sel_r1 = 0;
reg sel_r2 = 0;
reg sel_e  = 0;
wire [M-1:0] r1_internal; 
wire [M-1:0] r2_internal;
wire [M-1:0] error;
wire [LOG_WEIGHT_ENC-1:0] loc_addr, r1_e_rd_addr;
wire [RAMWIDTH-1:0] pm_out;
reg start_poly_mult_r2h;
reg start_poly_mult_sr2;
wire done_poly_mult;

assign h_addr_0 = (sel_hs == 0)? hs_addr_0 : 0;
assign h_addr_1 = (sel_hs == 0)? hs_addr_1 : 0;
assign s_addr_0 = (sel_hs == 1)? hs_addr_0 : 0;
assign s_addr_1 = (sel_hs == 1)? hs_addr_1 : 0;

assign hs_0 = (sel_hs == 1)? s_0 : h_0;
assign hs_1 = (sel_hs == 1)? s_1 : h_1;

//assign hs_in_0 = (hs_addr_0 <= X/2)? hs_0 : 0;
//assign hs_in_1 = (hs_addr_1 <= X/2)? hs_1 : 0;
                         
assign error = r2_internal;



// poly_mult optimization

reg  [`CLOG2(X)-1:0] hs_addr_0_reg;
reg  [`CLOG2(X)-1:0] hs_addr_1_reg;
always@(posedge clk) begin
   hs_addr_0_reg <= hs_addr_0; 
   hs_addr_1_reg <= hs_addr_1; 
end

assign hs_in_0 = (hs_addr_0_reg> (X + X%2)/2 - 1)? 0: hs_0;
assign hs_in_1 = (hs_addr_1_reg> (X + X%2)/2 - 1)? 0: hs_1;

`ifdef SHARED
    assign pm_start      = start_poly_mult_r2h|start_poly_mult_sr2;
    assign pm_loc_in     = error;
    assign pm_weight     = WEIGHT_ENC;
    assign pm_mux_word_0 = hs_in_0;
    assign pm_mux_word_1 = hs_in_1;
    assign pm_rd_dout    = (copy_u|u_v_out_en|xor_add_en|pm_rd_en)? 1'b1: 1'b0;
    assign pm_addr_result= copy_u? u_cpy_addr: xor_add_en? xor_add_addr : u_v_out_en? u_v_out_addr: pm_rd_addr;
    assign pm_add_wr_en  = (u_v_in_wen && sel_uv == 1)? 1 : xor_add_en? xor_add_out_valid: add_out_valid;
    assign pm_add_addr   = (u_v_in_wen && sel_uv == 1)? u_v_in_addr :xor_add_en? xor_add_out_addr : add_out_addr;
    assign pm_add_in     = (u_v_in_wen && sel_uv == 1)? u_v_in : xor_add_en? xor_add_out : add_out;
    
    assign loc_addr = pm_loc_addr;
    assign hs_addr_0 = pm_addr_0;
    assign hs_addr_1 = pm_addr_1;
    assign done_poly_mult = pm_valid;
    assign pm_out = pm_dout;

`endif

`ifndef SHARED
 poly_mult #(
// poly_mult #(
  .parameter_set(parameter_set),
  .MAX_WEIGHT(WEIGHT_ENC),
  .N(N),
  .M(M),
  .W(W),
  .RAMWIDTH(RAMWIDTH),
  .X(X)
  
  )
  POLY_MULT  (
		.clk(clk),
		.rst(rst),
		.start(start_poly_mult_r2h|start_poly_mult_sr2),
				
		// Shift Position loading
		.loc_addr(loc_addr),
		.loc_in(error),
		.weight(WEIGHT_ENC),
		
		// Random Vector Loading
		.mux_word_0(hs_in_0),
		.mux_word_1(hs_in_1),
		.addr_0(hs_addr_0),
		.addr_1(hs_addr_1),
		
		.valid(done_poly_mult),
		.addr_result(copy_u? u_cpy_addr: xor_add_en? xor_add_addr : u_v_out_en? u_v_out_addr: pm_rd_addr),
		.rd_dout((copy_u|u_v_out_en|xor_add_en|pm_rd_en)? 1'b1: 1'b0),
		.dout(pm_out),
		
        .add_in((u_v_in_wen && sel_uv == 1)? u_v_in : xor_add_en? xor_add_out : add_out),
		.add_addr((u_v_in_wen && sel_uv == 1)? u_v_in_addr :xor_add_en? xor_add_out_addr : add_out_addr),
		.add_wr_en((u_v_in_wen && sel_uv == 1)? 1 : xor_add_en? xor_add_out_valid: add_out_valid)
  );
`endif

 wire [RAMWIDTH-1:0] pm_out;
 wire [`CLOG2(N_MEM/MEM_WIDTH) - 1:0] pm_rd_addr;
 wire pm_rd_en;
 
 wire [MEM_WIDTH-1:0] add_out;
 wire [`CLOG2(N_MEM/MEM_WIDTH) - 1:0] add_out_addr;
 wire add_out_valid;
 
 reg start_adder_r1r2h;
 reg start_adder_sr2_plus_e;
 wire done_loc_based_adder;
 wire r1_e_rd_en;
 
  loc_based_adder #(.parameter_set(parameter_set), .WIDTH(RAMWIDTH), .WEIGHT(WEIGHT_ENC), .N(N))
  LOC_BASED_ADDER
   (
    .clk(clk),
    .rst(rst),
    
    .start(start_adder_r1r2h | start_adder_sr2_plus_e),
    
    .loc_rd_addr(r1_e_rd_addr),
    .loc_rd_en(r1_e_rd_en),
    .location(sel_r1_hr2? r1_internal: sel_e? error_loc : r1_internal),
    
    .pm_rd_addr(pm_rd_addr),
    .pm_rd_en(pm_rd_en),
    .pm_in(pm_out),
    
    .add_out(add_out),
    .add_out_addr(add_out_addr),
    .add_out_valid(add_out_valid),
    .done(done_loc_based_adder)
    
    );
  
  reg start_adder_mG;
  wire done_xor_adder;
  wire [RAMWIDTH-1:0] add_in_1;
  wire [RAMWIDTH-1:0] add_in_2;
  wire xor_add_en;
  wire [LOG_RAMDEPTH-1:0] xor_add_addr;
  
  wire [RAMWIDTH-1:0]  xor_add_out;
  wire [LOG_RAMDEPTH-1:0] xor_add_out_addr;
  wire xor_add_out_valid;
  
  assign add_in_1 = pm_out;
  assign add_in_2 = cdw_out;
  assign cdw_out_addr = xor_add_addr/COPIES_OF_CDW;
   
  xor_based_adder #(.parameter_set(parameter_set), .N(N) , .WIDTH(RAMWIDTH))
  XOR_BASED_ADDER
   (
    .clk(clk),
    .rst(rst),
    
    .start(start_adder_mG),
    
    .in_1(add_in_1),
    .in_2(add_in_2),
    .in_addr(xor_add_addr),
    .in_rd_en(xor_add_en),
    
    .add_out(xor_add_out),
    .add_out_addr(xor_add_out_addr),
    .add_out_valid(xor_add_out_valid),
    .done(done_xor_adder)
    
    );


reg [3:0] state = 0;
parameter s_wait_start  =   0;
parameter s_gen_r1 =   1;
parameter s_gen_r2 =   2;
parameter s_gen_e  =   3;
parameter s_done   =   4;
parameter s_wait_r1_transfer = 5;
parameter s_wait_r2_transfer = 6;

reg en_r1;
reg en_r2;
reg en_e;


//always@(posedge clk)
//begin

//     if (rst) begin
//        state <= s_wait_start;
//        request_another_vector <= 2'b00;
//        en_r1 <= 0;
//        en_r2 <= 0;
//        en_e <= 0;
//        r2_done <= 0;
//        done_fixed_weight <= 0;
//    end
//    else begin
//        if (state == s_wait_start) begin
//            en_r1 <= 0;
//            en_r2 <= 0;
//            en_e <= 0;;
//            r2_done <= 0;
//            done_fixed_weight <= 0;
//            request_another_vector <= 2'b00;
//            shake_force_done <= 1'b0;
//            if (start) begin
//				state <= s_gen_r1;				
//			end 
//        end 
		
//		else if (state == s_gen_r1) begin
//		      en_r2 <= 0;
//		      en_e <= 0;
//		      r2_done <= 0;
//		      done_fixed_weight <= 0;
//		      if (done_fw) begin
//			     state <= s_gen_r2;
//			     en_r1 <= 1;
//			     request_another_vector <= 2'b11;
//			  end
//			  else begin 
//			     state <= s_gen_r1;
//			     en_r1 <= 0;
//			     request_another_vector <= 2'b00;
//			  end
//		end
		
//		else if (state == s_gen_r2) begin
//		      r2_done <= 0;
//		      done_fixed_weight <= 0;
//		      if (done_fw_transfer) begin
//		          en_r1 <= 0;    
//		      end
//		      en_e <= 0;
//		      if (done_fw) begin
//			     state <= s_gen_e;
//			     en_r2 <= 1;
//			     request_another_vector <= 2'b11;
//			  end
//			  else begin 
//			     state <= s_gen_r2;
//			     en_r2 <= 0;
//			     request_another_vector <= 2'b00;
//			  end
//		end
		
//		else if (state == s_gen_e) begin
//		      en_r1 <= 0;
//		      done_fixed_weight <= 0;
//		      if (done_fw_transfer) begin
//		          en_r2 <= 0;
//		          r2_done <= 1;    
//		      end
//		      else begin
//		          r2_done <= 0;
//		      end
//		      request_another_vector <= 2'b00;
//		      if (done_fw) begin
//			     state <= s_done;
//			     en_e <= 1;
//			  end
//			  else begin 
//			     state <= s_gen_e;
//			     en_e <= 0;
//			  end
//		end
		
//		else if (state == s_done) begin
//		      state <= s_wait_start;
//		      en_r1 <= 0;
//		      en_r2 <= 0;
//		      r2_done <= 0;
//		      done_fixed_weight <= 1; 
//		end
        
//    end 
//end

//always@(state, start, done_fw, shake_din_ready) 
//begin
//    case (state)
//     s_wait_start: 
//     begin
//        start_fw_transfer <= 0;
//        if (start) begin
//            start_fw <= 1'b1;
//            start_encode <= 1'b1;
//        end
//        else begin
//            start_fw <= 1'b0;
//            start_encode <= 1'b0;
//        end
//     end
     
//     s_gen_r1: 
//     begin
//        start_fw <= 0;
//        start_encode <= 1'b0;
//        if (done_fw) begin
//            start_fw_transfer <= 1'b1;
//        end
//        else begin
//            start_fw_transfer <= 1'b0;
//        end
//     end
     
//     s_gen_r2: 
//     begin
//        start_fw <= 0;
//        start_encode <= 1'b0;
//        if (done_fw) begin
//            start_fw_transfer <= 1'b1;
//        end
//        else begin
//            start_fw_transfer <= 1'b0;
//        end
//     end 
     
//     s_gen_e: 
//     begin
//        start_fw <= 0;
//        start_encode <= 1'b0;
//        start_fw_transfer <= 1'b0;
//     end 
     
   
     
      
//	  default: 
//	  begin
//	       start_fw <= 1'b0;
//	       start_encode <= 1'b0; 
//	       start_fw_transfer <= 1'b0;
//	  end         
      
//    endcase

//end 

always@(posedge clk)
begin

     if (rst) begin
        state <= s_wait_start;
        request_another_vector <= 2'b00;
        en_r1 <= 0;
        en_r2 <= 0;
        en_e <= 0;
        r2_done <= 0;
        done_fixed_weight <= 0;
    end
    else begin
        if (state == s_wait_start) begin
            en_r1 <= 0;
            en_r2 <= 0;
            en_e <= 0;;
            r2_done <= 0;
            done_fixed_weight <= 0;
            request_another_vector <= 2'b00;
            shake_force_done <= 1'b0;
            if (start) begin
				state <= s_gen_r1;				
			end 
        end 
		
		else if (state == s_gen_r1) begin
		      en_r2 <= 0;
		      en_e <= 0;
		      r2_done <= 0;
		      done_fixed_weight <= 0;
		      if (done_fw) begin
			     if (CT_DESIGN == 0) begin
                     state <= s_gen_r2;
                     en_r1 <= 1;
                     request_another_vector <= 2'b11;
			     end 
			     else begin
			         state <= s_wait_r1_transfer;
                     en_r1 <= 1;
                     request_another_vector <= 2'b00;
			     end
			  end
			  else begin 
			     state <= s_gen_r1;
			     en_r1 <= 0;
			     request_another_vector <= 2'b00;
			  end
		end
		
		else if (state == s_wait_r1_transfer) begin
		      if (done_fw_transfer) begin
		          state <= s_gen_r2;
		          en_r1 <= 0;
		          request_another_vector <= 2'b11;    
		      end
		end
		
		else if (state == s_gen_r2) begin
		      r2_done <= 0;
		      done_fixed_weight <= 0;
		      if (done_fw_transfer) begin
		          en_r1 <= 0;    
		      end
		      en_e <= 0;
		      if (done_fw) begin
		          if (CT_DESIGN == 0) begin
                     state <= s_gen_e;
                     en_r2 <= 1;
                     request_another_vector <= 2'b11;
                  end
                  else begin
                     state <= s_wait_r2_transfer;
                     en_r2 <= 1;
                     request_another_vector <= 2'b00;
                  end
			  end
			  else begin 
			     state <= s_gen_r2;
			     en_r2 <= 0;
			     request_another_vector <= 2'b00;
			  end
		end
		
		else if (state == s_wait_r2_transfer) begin
		      if (done_fw_transfer) begin
		          state <= s_gen_e;
		          en_r2 <= 0;
		          request_another_vector <= 2'b11;
		          r2_done <= 1;    
		      end
		end
		
		else if (state == s_gen_e) begin
		      en_r1 <= 0;
		      done_fixed_weight <= 0;
		      if (done_fw_transfer) begin
		          en_r2 <= 0;
		          r2_done <= 1;    
		      end
		      else begin
		          r2_done <= 0;
		      end
		      request_another_vector <= 2'b00;
		      if (done_fw) begin
			     state <= s_done;
			     en_e <= 1;
			  end
			  else begin 
			     state <= s_gen_e;
			     en_e <= 0;
			  end
		end
		
		else if (state == s_done) begin
		      state <= s_wait_start;
		      en_r1 <= 0;
		      en_r2 <= 0;
		      r2_done <= 0; 
		      done_fixed_weight <= 1;
		end
        
    end 
end

always@(state, start, done_fw, shake_din_ready) 
begin
    case (state)
     s_wait_start: 
     begin
        start_fw_transfer <= 0;
        if (start) begin
            start_fw <= 1'b1;
            start_encode <= 1'b1;
        end
        else begin
            start_fw <= 1'b0;
            start_encode <= 1'b0;
        end
     end
     
     s_gen_r1: 
     begin
        start_fw <= 0;
        start_encode <= 1'b0;
        if (done_fw) begin
            start_fw_transfer <= 1'b1;
        end
        else begin
            start_fw_transfer <= 1'b0;
        end
     end
     
     s_wait_r1_transfer:
     begin
        start_fw_transfer <= 1'b0;
     end
     
     s_gen_r2: 
     begin
        start_fw <= 0;
        start_encode <= 1'b0;
        if (done_fw) begin
            start_fw_transfer <= 1'b1;
        end
        else begin
            start_fw_transfer <= 1'b0;
        end
     end 
     
     s_wait_r2_transfer:
     begin
        start_fw_transfer <= 1'b0;
     end
     
     s_gen_e: 
     begin
        start_fw <= 0;
        start_encode <= 1'b0;
        start_fw_transfer <= 1'b0;
     end 
     
   
     
      
	  default: 
	  begin
	       start_fw <= 1'b0;
	       start_encode <= 1'b0; 
	       start_fw_transfer <= 1'b0;
	  end         
      
    endcase

end 

 reg wen_fw, sel_fw, rd_fw;
 reg start_fw_transfer;
 reg done_fw_transfer;
 reg [3:0] trx_state = 0;
 parameter trx_wait_start  =   0;
 parameter trx_tranfer =   1;
 parameter trx_done =   2;
 reg [LOG_WEIGHT_ENC-1:0] fw_addr, fw_addr_reg;
 
 
 always@(posedge clk)
 begin
     fw_addr_reg <= fw_addr;
 end

 always@(posedge clk)
 begin

      if (rst) begin
         trx_state <= trx_wait_start;
         fw_addr <= 0;
         done_fw_transfer <= 1'b0;
     end
     else begin
         if (trx_state == trx_wait_start) begin
            done_fw_transfer <= 1'b0;
             if (start_fw_transfer) begin
				 trx_state <= trx_tranfer;
				 fw_addr <= fw_addr+1;				
			 end 
			 else begin
			     fw_addr <= 0;
			 end
         end 
        
         else if (trx_state == trx_tranfer) begin
               done_fw_transfer <= 1'b0;
               if (fw_addr == WEIGHT_ENC-1) begin
                   trx_state <= trx_done;
               end 
               else begin
                   fw_addr <= fw_addr+1;	
               end
         end
        
         else if (trx_state == trx_tranfer) begin
                   trx_state <= trx_done;
                   done_fw_transfer <= 1'b0;
         end
        
         else if (trx_state == trx_done) begin
                   trx_state <= trx_wait_start;
                   done_fw_transfer <= 1'b1;
         end
        
     end 
 end


 always@(trx_state, start_fw_transfer) 
 begin
     case (trx_state)
      trx_wait_start: 
      begin
         wen_fw <= 1'b0;
         if (start_fw_transfer) begin
             sel_fw <= 1'b1;
             rd_fw <= 1'b1;
         end
         else begin
             sel_fw <= 1'b0;
             rd_fw <= 1'b0;
         end
      end
     
      trx_tranfer:
      begin
         sel_fw <= 1'b1;
         rd_fw <= 1'b1;
         wen_fw <= 1'b1;
      end 
     
      trx_done:
      begin
         wen_fw <= 1'b1;
      end
     
	   default: 
	   begin
	        wen_fw <= 1'b0;
	        rd_fw <= 1'b0; 
	        sel_fw <= 1'b0; 
	   end         
      
     endcase

 end 
 
reg [3:0] u_state = 0;
parameter u_wait_start  =   0;   
parameter u_r2_mul_h    =   1;   
parameter u_r1_plus_r2h  =   2;   
parameter u_move_u_bram = 3;

reg r2_done =0;
reg u_done =0;
reg [LOG_RAMDEPTH-1:0] u_cpy_addr, u_cpy_addr_reg;
reg wen_u;
reg copy_u;
reg sel_r1_hr2;
always@(posedge clk)
begin
    
    
    u_cpy_addr_reg <= u_cpy_addr; 
    if (rst) begin
        u_state <= u_wait_start;
        u_done <= 1'b0;
        u_cpy_addr <= 0;
    end
    else begin
        if (u_state == u_wait_start) begin
            u_done <= 1'b0;
            u_cpy_addr <= 0;
            if (r2_done) begin
                u_state <= u_r2_mul_h;
            end
        end
        
        else if (u_state == u_r2_mul_h) begin
            u_done <= 1'b0;
            u_cpy_addr <= 0;
            if (done_poly_mult) begin
                u_state <= u_r1_plus_r2h;       
                
            end
        end
        
        else if (u_state == u_r1_plus_r2h) begin
           if (done_loc_based_adder) begin
            u_state <= u_move_u_bram;
            u_done <= 1'b0;
            u_cpy_addr <= u_cpy_addr + 1; 
           end 
        end
        
        else if (u_state == u_move_u_bram) begin
            if (u_cpy_addr == RAMDEPTH) begin
                u_cpy_addr <= 0;
                u_state <= u_wait_start;
                u_done <= 1'b1;
            end
            else begin
                u_cpy_addr <= u_cpy_addr + 1;
                u_done <= 1'b0;
            end
        end
    end
end

always@(u_state, r2_done, done_poly_mult, done_loc_based_adder)
begin

case(u_state)

u_wait_start : begin
                    start_adder_r1r2h <= 1'b0;
                    copy_u <= 1'b0;
                    wen_u <= 1'b0;
                    sel_r1_hr2 <= 0;
                    if (r2_done) begin
                        start_poly_mult_r2h <= 1'b1;
                        sel_r2 <= 1'b1;
                    end
                    else begin
                        start_poly_mult_r2h <= 1'b0;
                        sel_r2 <= 1'b0;
                    end
               end

u_r2_mul_h : begin
                    start_poly_mult_r2h <= 1'b0;
                    copy_u <= 1'b0;
                    wen_u <= 1'b0;
                    if (done_poly_mult) begin
                        sel_r2 <= 1'b0;
                        start_adder_r1r2h <= 1'b1;
                        sel_r1_hr2 <= 1;
                    end
                    else begin
                        sel_r2 <= 1'b1;
                        start_adder_r1r2h <= 1'b0;
                        sel_r1_hr2 <= 0;
                    end
               end

u_r1_plus_r2h : begin
                    start_adder_r1r2h <= 1'b0;
                    start_poly_mult_r2h <= 1'b0;
                    sel_r2 <= 1'b0;
                    wen_u <= 1'b0;
                    if (done_loc_based_adder) begin
                       copy_u <= 1'b1;
                       sel_r1_hr2 <= 0;    
                    end
                    else begin 
                        copy_u <= 1'b0;
                        sel_r1_hr2 <= 1;
                    end    
                end

u_move_u_bram: begin
                    sel_r1_hr2 <= 0;
                    start_adder_r1r2h <= 1'b0;
                    start_poly_mult_r2h <= 1'b0;
                    sel_r2 <= 1'b0;
                    copy_u <= 1'b1;
                    wen_u <= 1'b1;
               end

default: begin
            start_poly_mult_r2h <= 1'b0;
            sel_r2 <= 1'b0;
            sel_r1_hr2 <= 0;
            wen_u <= 1'b0;
            copy_u <= 1'b0;
        end
endcase
end
 

reg [3:0] v_state = 0;
parameter v_wait_start  =   0;   
parameter v_s_mul_r2    =   1;   
parameter v_e_plus_sr2  =   2;   
parameter v_mG_plus_sr2_plus_e  =   3;   

reg sel_r2_sr2 =0;
always@(posedge clk)
begin
    
    if (rst) begin
        v_state <= v_wait_start;
        done <= 0;
        sel_e <= 0;
    end
    else begin
        if (v_state == v_wait_start) begin
            done <= 0;
            sel_e <= 0;
            if (u_done) begin
                v_state <= v_s_mul_r2;
                sel_hs <= 1'b1;
            end
            else begin
                sel_hs <= 1'b0;
            end
        end
        
        else if (v_state == v_s_mul_r2) begin
            sel_hs <= 1'b1;
            if (done_poly_mult) begin
                v_state <= v_e_plus_sr2;
                sel_e <= 1;
            end
        end
        
        else if (v_state == v_e_plus_sr2) begin
            done <= 0;
            if (done_loc_based_adder) begin
                v_state <= v_mG_plus_sr2_plus_e;
                sel_e <= 0;
            end
        end
        
        else if (v_state == v_mG_plus_sr2_plus_e) begin
            sel_e <= 0;
            if (done_xor_adder) begin
                v_state <= v_wait_start;
                done <= 1;
            end
        end
    end
end

always@(v_state, u_done, done_poly_mult, done_loc_based_adder, done_xor_adder)
begin

    case(v_state)
    
    v_wait_start: begin
                    start_adder_sr2_plus_e <= 1'b0;
                    start_adder_mG <= 1'b0;
                    if (u_done) begin
                        start_poly_mult_sr2 <= 1'b1;
                        sel_r2_sr2 <= 1'b1;
                    end
                    else begin
                       start_poly_mult_sr2 <= 1'b0;
                       sel_r2_sr2 <= 1'b0; 
                    end
                 end
     
     v_s_mul_r2: begin
                    sel_r2_sr2 <= 1'b1;
                    start_adder_mG <= 1'b0;
                    start_poly_mult_sr2 <= 1'b0;
                    if (done_poly_mult) begin
                        start_adder_sr2_plus_e <= 1'b1;
                    end
                    else begin
                         start_adder_sr2_plus_e <= 1'b0;
                    end
                 end
    
    v_e_plus_sr2: begin
                    sel_r2_sr2 <= 1'b1;
                    start_adder_sr2_plus_e <= 1'b0;
                    start_poly_mult_sr2 <= 1'b0;
                    if (done_loc_based_adder) begin
                        start_adder_mG <= 1'b1;
                    end
                    else begin
                        start_adder_mG <= 1'b0;
                    end
                  end
                  
    v_mG_plus_sr2_plus_e: begin
                    sel_r2_sr2 <= 1'b1;
                    start_adder_mG <= 1'b0;
                    start_adder_sr2_plus_e <= 1'b0;
                    start_poly_mult_sr2 <= 1'b0;
                  end              
    default: begin
              sel_r2_sr2 <= 1'b0;
              start_poly_mult_sr2 <= 1'b0;
              start_adder_sr2_plus_e <= 1'b0;  
            end
    endcase

end

endmodule
