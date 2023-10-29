`timescale 1ns / 1ps
/*
 * 
 *
 * Copyright (C) 2022
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


module decap
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
   
   parameter WEIGHT = (parameter_set == "hqc128")? 66:
					   (parameter_set == "hqc192")? 100:
					   (parameter_set == "hqc256")? 131:
                                                    66,
    parameter LOG_WEIGHT = `CLOG2(WEIGHT),
	
	parameter WEIGHT_ENC =  (parameter_set == "hqc128")? 75:
							(parameter_set == "hqc192")? 114:
							(parameter_set == "hqc256")? 149: 
														 75,
	
	parameter N = (parameter_set == "hqc128")? 17_669:
				  (parameter_set == "hqc192")? 35_851:
			      (parameter_set == "hqc256")? 57_637: 
                                               17_669,
    
    parameter N1N2 = (parameter_set == "hqc128")? 17_664:
				     (parameter_set == "hqc192")? 35_840:
			         (parameter_set == "hqc256")? 57_600: 
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
	parameter FILE_MSG = "",
	
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
	
	// Hash Ram Depth Computation
	parameter HASH_RAMBITS = K + N + N1N2 + 8,
	parameter HASH_RAMBITS_8 = HASH_RAMBITS + (8-HASH_RAMBITS%8)%8,
	parameter HASH_M_U = K + N,
	parameter HASH_M_U_8 = HASH_M_U + (8-HASH_M_U%8)%8,
	parameter HASH_M_U_32 = HASH_M_U_8 + (32-HASH_M_U_8%32)%32,
	
	parameter HASH_LB_SIZE = HASH_RAMBITS_8%32 - 8,
	parameter HASH_RAMBITS_32 = HASH_RAMBITS + (32-HASH_RAMBITS%32)%32,
//	parameter HASH_RAM_DOMSEP = 33, //(HASH_RAMBITS+(1088-HASH_RAMBITS)%1088)/1088,
	parameter HASH_RAM_DOMSEP = (HASH_RAMBITS+(1088-HASH_RAMBITS%1088)%1088)/1088,
	parameter HASH_RAMDEPTH = 1 + (HASH_RAMBITS_32/32) + HASH_RAM_DOMSEP,   //includes memory locations for the domain seperators 
	parameter HASH_LB_DOMSEP = (parameter_set == "hqc128")? 32'h80000290:
	                           (parameter_set == "hqc192")? 32'h80000058:
	                           (parameter_set == "hqc256")? 32'h800000b0:
	                                                        32'h80000290,
    
    
    parameter THETA_D_DOMSEP = (parameter_set == "hqc128")? 32'h80000088:
	                           (parameter_set == "hqc192")? 32'h800000c8:
	                           (parameter_set == "hqc256")? 32'h80000108:
	                                                        32'h80000088,
	// D Ram constants
	parameter D_SIZE = 512,
	parameter D_RAMDEPTH = 512/32,
	parameter LOG_D_RAMDEPTH = `CLOG2(D_RAMDEPTH),
	
	parameter PARALLEL_ENCRYPT = 0

	    
													
)
(
    input clk,
    input rst,
    input start,
	
    input [1:0] decap_in_type,
    input [RAMWIDTH-1:0] decap_in,
	input [LOG_RAMDEPTH-1:0] decap_in_addr,
	input decap_in_wen,
	
	output [LOG_WEIGHT-1:0] y_addr,
	input [M-1:0] y,
	
	
    output reg done,
    
	input [RAMWIDTH-1:0] u_0,
	input [RAMWIDTH-1:0] u_1,	
	output [`CLOG2(X)-1:0] u_addr_0,
	output [`CLOG2(X)-1:0] u_addr_1,
	
	input [RAMWIDTH-1:0] v_0,
	input [RAMWIDTH-1:0] v_1,	
	output [`CLOG2(X)-1:0] v_addr_0,
	output [`CLOG2(X)-1:0] v_addr_1,
	
	
    
    input decap_out_en,
    input [LOG_RAMDEPTH-1:0]decap_out_addr,
    output [RAMWIDTH-1:0] decap_out,

`ifndef SHARED_ENCAP	
    input [RAMWIDTH-1:0] h_0,
	input [RAMWIDTH-1:0] h_1,	
	output [`CLOG2(X)-1:0] h_addr_0,
	output [`CLOG2(X)-1:0] h_addr_1,
	
    input [RAMWIDTH-1:0] s_0,
	input [RAMWIDTH-1:0] s_1,	
	output [`CLOG2(X)-1:0] s_addr_0,
	output [`CLOG2(X)-1:0] s_addr_1,
`endif
    
`ifdef SHARED_ENCAP
    output e_start_encap,
    output [32-1:0] e_m_in,
	output [`CLOG2((K-(32-K%32)%32)/32) -1:0] e_m_addr,
	output e_m_wen,
	
    input e_done_encap,
    output [1:0] e_sel_out,
    output e_out_en,
    output [LOG_RAMDEPTH-1:0]e_out_addr,
    input [127:0] e_encap_dout,
    
    output e_u_v_in_wen,
	output [`CLOG2(RAMDEPTH)-1:0] e_u_v_in_addr,
	output [RAMWIDTH-1:0] e_u_v_in,
	output  e_resume_encap,
	input e_enc_done,
`endif

 `ifdef SHARED_ENCAP
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

`ifdef SHARED_ENCAP  
   output reg encap_inside_decap,
`endif
//	output [RAMWIDTH-1:0] e_h_0,
//	output [RAMWIDTH-1:0] e_h_1,	
//	input [`CLOG2(X)-1:0] e_h_addr_0,
//	input [`CLOG2(X)-1:0] e_h_addr_1,
	
//	output [RAMWIDTH-1:0] e_s_0,
//	output [RAMWIDTH-1:0] e_s_1,	
//	input [`CLOG2(X)-1:0] e_s_addr_0,
//	input [`CLOG2(X)-1:0] e_s_addr_1, 
    
    
	//shake signals
    output wire  shake_din_valid, 
    input  wire shake_din_ready,
    output wire  [31:0] shake_din,
    output wire  shake_dout_ready,
    input  wire [31:0] shake_dout_scram,
    output shake_force_done,
    input  wire shake_dout_valid
	
    );
  



reg resume_encap;
reg m_wen;
wire [31:0] m_in;
wire done_encap;
reg [`CLOG2((K+(32-K%32)%32)/32):0] m_addr;

reg [1:0]sel_out;
reg encap_out_en;
reg [LOG_RAMDEPTH-1:0]encap_out_addr;
wire [RAMWIDTH-1:0]encap_dout;

reg u_v_in_wen, u_v_in_wen_reg;
reg [LOG_RAMDEPTH-1:0] u_v_in_addr, u_v_in_addr_reg;
wire [RAMWIDTH-1:0] u_v_in;
wire [K-1:0] decypted_msg, decypted_msg_rearranged;

wire [31:0] d_out;

`ifndef SHARED_ENCAP
    wire pm_start_e;    
    wire [M-1:0] pm_loc_in_e;
    wire [LOG_MAX_WEIGHT:0] pm_weight_e;
    wire [W_BY_X-1:0]pm_mux_word_0_e;
    wire [W_BY_X-1:0]pm_mux_word_1_e;
    wire pm_rd_dout_e;
    wire [`CLOG2(RAMSIZE/2)-1:0]pm_addr_result_e;
    wire pm_add_wr_en_e;
    wire [`CLOG2(RAMSIZE/2)-1:0] pm_add_addr_e;
    wire [RAMWIDTH-1:0] pm_add_in_e;
    wire [LOGW-1:0] pm_loc_addr_e;
    wire [W_BY_X-1:0]pm_dout_e;
    wire pm_valid_e;
    wire [ADDR_WIDTH-1:0]pm_addr_0_e;
    wire [ADDR_WIDTH-1:0]pm_addr_1_e;
    
    wire pm_start;    
    wire [M-1:0] pm_loc_in;
    wire [LOG_MAX_WEIGHT:0] pm_weight;
    wire [W_BY_X-1:0]pm_mux_word_0;
    wire [W_BY_X-1:0]pm_mux_word_1;
    wire pm_rd_dout;
    wire [`CLOG2(RAMSIZE/2)-1:0]pm_addr_result;
    wire pm_add_wr_en;
    wire [`CLOG2(RAMSIZE/2)-1:0] pm_add_addr;
    wire [RAMWIDTH-1:0] pm_add_in;
    wire [LOGW-1:0] pm_loc_addr;
    wire [W_BY_X-1:0]pm_dout;
    wire pm_valid;
    wire [ADDR_WIDTH-1:0]pm_addr_0;
    wire [ADDR_WIDTH-1:0]pm_addr_1;
    
    reg encap_inside_decap;
`endif

wire pm_start_d;    
wire [M-1:0] pm_loc_in_d;
wire [LOG_MAX_WEIGHT:0] pm_weight_d;
wire [W_BY_X-1:0]pm_mux_word_0_d;
wire [W_BY_X-1:0]pm_mux_word_1_d;
wire pm_rd_dout_d;
wire [`CLOG2(RAMSIZE/2)-1:0]pm_addr_result_d;
wire pm_add_wr_en_d;
wire [`CLOG2(RAMSIZE/2)-1:0] pm_add_addr_d;
wire [RAMWIDTH-1:0] pm_add_in_d;
wire [LOGW-1:0] pm_loc_addr_d;
wire [W_BY_X-1:0]pm_dout_d;
wire pm_valid_d;
wire [ADDR_WIDTH-1:0]pm_addr_0_d;
wire [ADDR_WIDTH-1:0]pm_addr_1_d;

  mem_single #(.WIDTH(32), .DEPTH(16)) D_MEM
  (
         .clock(clk),
         .data(decap_in[31:0]),
         .address(encap_out_en? encap_out_addr[3:0]:decap_in_addr[3:0]),
         .wr_en(decap_in_wen && decap_in_type == 1),
         .q(d_out)
  );
  
 wire [RAMWIDTH-1:0]u_out, u_out_1; 

  
  assign u_addr_0 = dec_uv? uv_addr_0_dec: copy_uv ? u_v_in_addr :encap_out_en? encap_out_addr : decap_in_addr;
  assign u_addr_1 = uv_addr_1_dec;
  
  assign v_addr_0 = dec_uv? uv_addr_0_dec: copy_uv ? u_v_in_addr :encap_out_en? encap_out_addr: decap_in_addr;
  assign v_addr_1 = uv_addr_1_dec;
  

wire [RAMWIDTH-1:0] uv_0_dec;
wire [RAMWIDTH-1:0] uv_1_dec;
wire [`CLOG2(X)-1:0] uv_addr_0_dec;
wire [`CLOG2(X)-1:0] uv_addr_1_dec;
wire sel_uv_dec;

//assign uv_0_dec = sel_uv_dec? v_out : u_out;
//assign uv_1_dec = sel_uv_dec? v_out_1 : u_out_1;

assign uv_0_dec = sel_uv_dec? v_0 : u_0;
assign uv_1_dec = sel_uv_dec? v_1 : u_1;

  decrypt 
  #(.parameter_set(parameter_set))
  DECRYPT
  ( .clk(clk),
    .rst(rst),
    .start(start_decrypt),

    .done(done_decrypt),
    
    .y_addr(y_addr),
    .y(y),
    
    .uv_0(uv_0_dec),
    .uv_1(uv_1_dec),
    .uv_addr_0(uv_addr_0_dec),
    .uv_addr_1(uv_addr_1_dec),
	.sel_uv(sel_uv_dec),
	
//`ifdef SHARED
    //poly mult signals
    .pm_start(pm_start_d),    
    .pm_loc_in(pm_loc_in_d),
    .pm_weight(pm_weight_d),
    .pm_mux_word_0(pm_mux_word_0_d),
    .pm_mux_word_1(pm_mux_word_1_d),
    .pm_rd_dout(pm_rd_dout_d),
    .pm_addr_result(pm_addr_result_d),
    .pm_add_wr_en(pm_add_wr_en_d),
    .pm_add_addr(pm_add_addr_d),
    .pm_add_in(pm_add_in_d),
    
    .pm_loc_addr(pm_loc_addr_d),
    .pm_addr_0(pm_addr_0_d),
    .pm_addr_1(pm_addr_1_d),
    .pm_valid(pm_valid_d),
    .pm_dout(pm_dout_d),
//`endif
	
	.dout(decypted_msg)
    );

reg u_neq = 0;
always@(posedge clk)
begin
    if (verify_u_reg) begin
        if (u_0 == encap_dout) begin
            u_neq <= 0;
        end
        else begin
            u_neq <= 1;
        end
    end
end


reg v_neq = 0;
always@(posedge clk)
begin
    if (verify_v) begin
        if (v_0 == encap_dout) begin
            v_neq <= 0;
        end
        else begin
            v_neq <= 1;
        end
    end
end

reg d_neq = 0;
always@(posedge clk)
begin
    if (verify_d) begin
        if (d_out == encap_dout[31:0]) begin
            d_neq <= 0;
        end
        else begin
            d_neq <= 1;
        end
    end
end


  genvar i;
  generate
    for (i = 0; i < K/8; i=i+1) begin:vector_gen_rearrange
        assign decypted_msg_rearranged[8*(i+1)-1:8*i] =  decypted_msg[K-8*(i)-1:K-8*(i+1)];
    end
  endgenerate

reg capture_msg;
reg load_msg;
reg [K-1:0] msg_in;

always@(posedge clk)
begin
	if (capture_msg) begin
		msg_in <= decypted_msg_rearranged;
//		msg_in <= MSG_IN_CONST;
	end
	else if (load_msg) begin
		msg_in <= {msg_in[K-32-1:0],32'h00000000};
	end
end

assign m_in = msg_in[K-1:K-32];
assign u_v_in = (sel_out == 2)? u_0: v_0;
assign decap_out = encap_dout;

`ifdef SHARED_ENCAP
    //outputs
    assign e_start_encap	= start_encap;
    assign e_m_in           = m_in;
    assign e_m_addr         = m_addr[`CLOG2((K+(32-K%32)%32)/32) - 1:0];
    assign e_m_wen		    = m_wen;
    assign e_sel_out        = decap_out_en?0:sel_out;
    assign e_out_en         = decap_out_en?1:encap_out_en;
    assign e_out_addr       = decap_out_en?{0,decap_out_addr}:encap_out_addr;
    assign e_u_v_in_wen     = u_v_in_wen_reg;
    assign e_u_v_in_addr    = u_v_in_addr_reg;
    assign e_u_v_in         = u_v_in;
    assign e_resume_encap   = resume_encap;
	
	//inputs
	assign done_encrypt =   e_enc_done;
    assign done_encap =   e_done_encap;
	assign encap_dout=   e_encap_dout;
    
    
    //poly mult from decrypt
    assign pm_start  = pm_start_d;
    assign pm_loc_in  = pm_loc_in_d;                  
    assign pm_weight  = pm_weight_d;                  
    assign pm_mux_word_0  = pm_mux_word_0_d;                  
    assign pm_mux_word_1  = pm_mux_word_1_d;                   
    assign pm_rd_dout  = pm_rd_dout_d;                   
    assign pm_addr_result  = pm_addr_result_d;                   
    assign pm_add_wr_en  = pm_add_wr_en_d;                   
    assign pm_add_addr  = pm_add_addr_d;                   
    assign pm_add_in  = pm_add_in_d;  
    
    assign pm_loc_addr_d   = pm_loc_addr;
    assign pm_addr_0_d     = pm_addr_0;
    assign pm_addr_1_d     = pm_addr_1;
    assign pm_valid_d      = pm_valid;
    assign pm_dout_d       = pm_dout;
    
`endif 

`ifndef SHARED_ENCAP
  encap 
  #(.parameter_set(parameter_set), .PARALLEL_ENCRYPT(PARALLEL_ENCRYPT))
  ENCAP_FOR_RENCRYPT
  ( .clk(clk),
    .rst(rst),
    .start(start_encap),
    
	.m_addr(m_addr[`CLOG2((K+(32-K%32)%32)/32) - 1:0]),
    .m_wen(m_wen),
//    .m_in({m_in[7:0],m_in[15:8],m_in[23:16],m_in[31:24]}),
    .m_in(m_in),
    
    .done(done_encap),
    
	// public key port    
    .h_0(h_0),
    .h_1(h_1),
    .h_addr_0(h_addr_0),
    .h_addr_1(h_addr_1),
    
    .s_0(s_0),
    .s_1(s_1),
    .s_addr_0(s_addr_0),
    .s_addr_1(s_addr_1),
	
	
	.encap_out_type(decap_out_en?0:sel_out),
	
	.encap_out_en(decap_out_en?1:encap_out_en),
	.encap_out_addr(decap_out_en?{0,decap_out_addr}:encap_out_addr),
	.encap_out(encap_dout),

	.u_v_in_wen(u_v_in_wen_reg),
	.u_v_in_addr(u_v_in_addr_reg),
	.u_v_in(u_v_in),
	
	.enc_done(done_encrypt),
	.resume_encap(resume_encap),
	
`ifdef SHARED
    //poly mult signals
    .pm_start(pm_start_e),    
    .pm_loc_in(pm_loc_in_e),
    .pm_weight(pm_weight_e),
    .pm_mux_word_0(pm_mux_word_0_e),
    .pm_mux_word_1(pm_mux_word_1_e),
    .pm_rd_dout(pm_rd_dout_e),
    .pm_addr_result(pm_addr_result_e),
    .pm_add_wr_en(pm_add_wr_en_e),
    .pm_add_addr(pm_add_addr_e),
    .pm_add_in(pm_add_in_e),
    
    .pm_loc_addr(pm_loc_addr_e),
    .pm_addr_0(pm_addr_0_e),
    .pm_addr_1(pm_addr_1_e),
    .pm_valid(pm_valid_e),
    .pm_dout(pm_dout_e),
`endif
		
	//shake signals
    .shake_din_valid(shake_din_valid),
    .shake_din_ready(shake_din_ready),
    .shake_din(shake_din),
    .shake_dout_ready(shake_dout_ready),
    .shake_dout_scram(shake_dout_scram),
    .shake_force_done(shake_force_done),
    .shake_dout_valid(shake_dout_valid)
	
    );
 

assign pm_start  = encap_inside_decap? pm_start_e:pm_start_d;
assign pm_loc_in  = encap_inside_decap? pm_loc_in_e:pm_loc_in_d;                  
assign pm_weight  = encap_inside_decap? pm_weight_e:pm_weight_d;                  
assign pm_mux_word_0  = encap_inside_decap? pm_mux_word_0_e:pm_mux_word_0_d;                  
assign pm_mux_word_1  = encap_inside_decap? pm_mux_word_1_e:pm_mux_word_1_d;                   
assign pm_rd_dout  = encap_inside_decap? pm_rd_dout_e:pm_rd_dout_d;                   
assign pm_addr_result  = encap_inside_decap? pm_addr_result_e:pm_addr_result_d;                   
assign pm_add_wr_en  = encap_inside_decap? pm_add_wr_en_e:pm_add_wr_en_d;                   
assign pm_add_addr  = encap_inside_decap? pm_add_addr_e:pm_add_addr_d;                   
assign pm_add_in  = encap_inside_decap? pm_add_in_e:pm_add_in_d;  
  

assign pm_loc_addr_e   = pm_loc_addr;
assign pm_addr_0_e     = pm_addr_0;
assign pm_addr_1_e     = pm_addr_1;
assign pm_valid_e      = (encap_inside_decap)? pm_valid:0;
assign pm_dout_e       = pm_dout;

assign pm_loc_addr_d   = pm_loc_addr;
assign pm_addr_0_d     = pm_addr_0;
assign pm_addr_1_d     = pm_addr_1;
assign pm_valid_d      = (encap_inside_decap)? 0: pm_valid;
assign pm_dout_d       = pm_dout;
 
  
   poly_mult #(
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
		.start(pm_start),
		.loc_addr(pm_loc_addr),
		.loc_in(pm_loc_in),
		.weight(pm_weight),
		.mux_word_0(pm_mux_word_0),
		.mux_word_1(pm_mux_word_1),
		.addr_0(pm_addr_0),
		.addr_1(pm_addr_1),
		.valid(pm_valid),
		.addr_result(pm_addr_result),
		.rd_dout(pm_rd_dout),				
		.dout(pm_dout),
        .add_in(pm_add_in),
		.add_addr(pm_add_addr),
		.add_wr_en(pm_add_wr_en)
  );
 
`endif 


reg [4:0] state = 0;
parameter s_wait_start 			= 0;
parameter s_wait_decrypt_done 	= 1;
parameter s_copy_msg_encap 		= 2;
parameter s_wait_encrypt_done 	= 3;
parameter s_compare_u_up 		= 4;
parameter s_compare_v_vp 		= 5;
parameter s_compare_d_dp 		= 6;
parameter s_copy_u 				= 7;
parameter s_copy_v 				= 8;
parameter s_resume_encap 		= 9;
parameter s_done_encap 			= 10;
parameter s_done 			    = 11;

reg verify_u, verify_u_reg;
reg verify_v;
reg verify_d;
reg copy_uv;
reg dec_uv;

always@(posedge clk)
begin
    if (rst) begin
        state <= s_wait_start;
		m_addr <= 0;
		encap_out_en <= 0;
		encap_out_addr <= 0;
		sel_out <= 0;
		done <= 0;
		verify_u <= 0;
		verify_v <= 0;
		verify_d <= 0;
		copy_uv <= 0;
		dec_uv <= 0;
		u_v_in_addr <= 0;
		
    end
    else begin
        if (state == s_wait_start) begin
			m_addr <= 0;
			encap_out_en <= 0;
			encap_out_addr <= 0;
			sel_out <= 0;
			verify_u <= 0;
			verify_v <= 0;
			verify_d <= 0;
			copy_uv <= 0;
		    u_v_in_addr <= 0;
		    
            if (start) begin
				state <= s_wait_decrypt_done;
				dec_uv <= 1;
            end
            else begin
                dec_uv <= 0;
            end
        end
		
		else if (state == s_wait_decrypt_done) begin
			
			encap_out_en <= 0;
			encap_out_addr <= 0;
			sel_out <= 0;
			verify_u <= 0;
			verify_v <= 0;
			verify_d <= 0;
			copy_uv <= 0;
    		u_v_in_addr <= 0;
    		
    		if (done_decrypt) begin
    		  dec_uv <= 0;
    		  state <= s_copy_msg_encap;
    		end
    		else begin
    		  dec_uv <= 1;
    		end
		end
		
		else if (state == s_copy_msg_encap) begin
		    encap_out_en <= 0;
		    encap_out_addr <= 0;
		    sel_out <= 0;
		    verify_u <= 0;
		    verify_v <= 0;
		    verify_d <= 0;
		    copy_uv <= 0;
    		u_v_in_addr <= 0;
			if (m_addr < K/32 -1) begin
				m_addr <=  m_addr + 1;
				state <= s_copy_msg_encap;
			end
			else begin
				state <= s_wait_encrypt_done;
				m_addr <= 0;
			end
		end
		
		else if (state == s_wait_encrypt_done) begin
		    sel_out <= 2;
		    encap_out_addr <= 0;
		    verify_d <= 0;
		    verify_v <= 0;
		    copy_uv <= 0;
    		u_v_in_addr <= 0;
			if (done_encrypt) begin
				state <= s_compare_u_up;
				encap_out_en <= 1;
				verify_u <= 1; 
			end
			else begin 
			    encap_out_en <= 0;
			    verify_u <= 0;				
			end
		end
		
		else if (state == s_compare_u_up) begin
		  verify_v <= 0;
		  verify_d <= 0;
		  copy_uv <= 0;
    		u_v_in_addr <= 0;
		  if (encap_out_addr < RAMDEPTH - 1) begin
		      sel_out <= 2;
		      encap_out_addr <= encap_out_addr + 1;
		      verify_u <= 1;
		      
		  end
		  else begin
			  sel_out <= 2;
			  state <= s_compare_v_vp;
			  encap_out_addr <= 0;
			  verify_u <= 0;
		  end
		end
		
		else if (state == s_compare_v_vp) begin
		  verify_u <= 0;
		  verify_v <= 1;
		  verify_d <= 0;
		  sel_out <= 3;
		  copy_uv <= 0;
    	  u_v_in_addr <= 0;
		  if (encap_out_addr < RAMDEPTH - 2) begin
		      encap_out_addr <= encap_out_addr + 1;		      
		  end
		  else begin
			  state <= s_compare_d_dp;
			  encap_out_addr <= 0;
		  end
		end
		
		else if (state == s_compare_d_dp) begin
		  verify_u <= 0;
		  verify_v <= 0;
		  verify_d <= 1;
		  sel_out <= 1;
    	  u_v_in_addr <= 0;
		  if (encap_out_addr < 15) begin
		      encap_out_addr <= encap_out_addr + 1;
		      copy_uv <= 0;		      
		  end
		  else begin
			  state <= s_copy_u;
			  encap_out_addr <= 0;
			  copy_uv <= 1;
		  end
		end
		
		else if (state == s_copy_u) begin
		  sel_out <= 2;
		  verify_u <= 0;
          verify_v <= 0;
          verify_d <= 0;
          encap_out_en <= 0;
		  if (u_v_in_addr < RAMDEPTH - 1) begin
		      u_v_in_addr  <= u_v_in_addr + 1;
		  end
		  else begin
		      u_v_in_addr <= 0;
		      state <=  s_copy_v;
		  end
		end
		
		else if (state == s_copy_v) begin
		  sel_out <= 3;
		  verify_u <= 0;
          verify_v <= 0;
          verify_d <= 0;
          encap_out_en <= 0;
		  if (u_v_in_addr < RAMDEPTH - 2) begin
		      u_v_in_addr  <= u_v_in_addr + 1;
		  end
		  else begin
		      u_v_in_addr <= 0;
		      state <=  s_resume_encap;
		  end
		end
		
		else if (state == s_resume_encap) begin
		  sel_out <= 0;
		  verify_u <= 0;
          verify_v <= 0;
          verify_d <= 0;
          encap_out_en <= 0;
          encap_out_en <= 0; 
          state <= s_done_encap;
		end

		else if (state == s_done_encap) begin
		  sel_out <= 0;
		  verify_u <= 0;
          verify_v <= 0;
          verify_d <= 0;
          encap_out_en <= 0;
          encap_out_en <= 0;
          if (done_encap) begin
            state <= s_wait_start;
            done <= 1;
          end 
		end
		
		
//		else if (state == s_done) begin
//            done <= 1;
//            verify_u <= 0;
//            verify_v <= 0;
//            verify_d <= 0;
//        end
    end 
    verify_u_reg <= verify_u;
    u_v_in_addr_reg <= u_v_in_addr;
    u_v_in_wen_reg <= u_v_in_wen;
end
  
reg start_decrypt;
wire done_decrypt;
reg start_encap;
wire done_encrypt;


always@(state, start, done_decrypt, done_encrypt, m_addr, done_encap)
begin

case(state)
    s_wait_start: 
    begin
        capture_msg <= 0;
        load_msg <= 0;
        m_wen <= 0;
        start_encap <= 1'b0; 
        resume_encap <= 0;
        u_v_in_wen <= 0;
        encap_inside_decap <=0;
        if (start) begin
            start_decrypt <= 1'b1;
        end
        else begin
            start_decrypt <= 1'b0;
        end
    end
    
    s_wait_decrypt_done:
    begin
        load_msg <= 0;
        m_wen <= 0;
        start_decrypt <= 1'b0;
        start_encap <= 1'b0; 
        resume_encap <= 0;
        u_v_in_wen <= 0;
        encap_inside_decap <=0;
        if (done_decrypt) begin
            capture_msg <= 1'b1;
        end
        else begin
            capture_msg <= 1'b0;
        end
    end
    
    s_copy_msg_encap:
    begin
        m_wen <= 1;
        capture_msg <= 1'b0;
        start_encap <= 1'b0; 
        load_msg <= 1;
        resume_encap <= 0;
        u_v_in_wen <= 0;
        start_decrypt <= 1'b0;
        if (m_addr == K/32 - 1) begin
            start_encap <= 1;
            encap_inside_decap <=1;
        end
        else begin
            start_encap <= 1'b0;
            encap_inside_decap <=1;
        end
    end

    s_wait_encrypt_done: 
    begin
        m_wen <= 0;
        capture_msg <= 1'b0;
        load_msg <= 1'b0;
        start_encap <= 1'b0;
        resume_encap <= 0; 
        u_v_in_wen <= 0;
        start_decrypt <= 1'b0;
        encap_inside_decap <=1;
    end
    
    s_copy_u: begin
        u_v_in_wen <= 1;
        m_wen <= 0;
        capture_msg <= 1'b0;
        load_msg <= 1'b0;
        start_encap <= 1'b0;
        resume_encap <= 0; 
        u_v_in_wen <= 0; 
        start_decrypt <= 1'b0;
        encap_inside_decap <=1;
    end
    
    s_copy_v: begin
        u_v_in_wen <= 1;
        m_wen <= 0;
        capture_msg <= 1'b0;
        load_msg <= 1'b0;
        start_encap <= 1'b0;
        resume_encap <= 0; 
        u_v_in_wen <= 0; 
        start_decrypt <= 1'b0;
        encap_inside_decap <=1;
    end
    
    s_resume_encap:
    begin
        u_v_in_wen <= 0;
        m_wen <= 0;
        capture_msg <= 1'b0;
        load_msg <= 1'b0;
        start_encap <= 1'b0;
        resume_encap <= 1; 
        u_v_in_wen <= 0;
        start_decrypt <= 1'b0;
        encap_inside_decap <=1;
    end
    
    s_done_encap:
    begin
        u_v_in_wen <= 0;
        m_wen <= 0;
        capture_msg <= 1'b0;
        load_msg <= 1'b0;
        start_encap <= 1'b0;
        resume_encap <= 0; 
        u_v_in_wen <= 0;
        start_decrypt <= 1'b0;
        encap_inside_decap <=1;
    end
    
//    s_done: begin
//        start_decrypt <= 0;
//        capture_msg <= 0;
//        load_msg <= 0;
//        start_encap <= 0;
//        m_wen <= 0;
//        resume_encap <= 0;
//        u_v_in_wen <= 0;
//    end

   
   default: 
   begin
        start_decrypt <= 0;
        capture_msg <= 0;
        load_msg <= 0;
        start_encap <= 0;
        m_wen <= 0;
        resume_encap <= 0;
        u_v_in_wen <= 0;
        start_decrypt <= 1'b0;
        encap_inside_decap <=0;
   end
    
endcase

end




endmodule
