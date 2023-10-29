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


module hqc_kem_joint_design
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

	//files
    parameter FILE_PKSEED = "",	
	parameter FILE_SKSEED = "",	
	parameter FILE_THETA = "",	

														   																										   
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
     
     	// encapsulation constants
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
	
	parameter RAMDEPTH = (N+(RAMWIDTH-N%RAMWIDTH)%RAMWIDTH)/RAMWIDTH, //u RAM depth
	parameter LOG_RAMDEPTH = `CLOG2(RAMDEPTH),
     
     parameter CT_DESIGN = 2'b10, // CT_DESIGN = 1 Constant time design, CT_DESIGN = 0 Default Design 
	 parameter PARALLEL_ENCRYPT = 0
)
(
    input clk,
    input rst,
		
	input [1:0] operation,
//	KEYGEN operation = 2'b00 
//	ENCAP  operation = 2'b01 
//	DECAP operation  = 2'b10
	
	input start,
	output done,
	
	//keygen ports
	
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
	
	
	//encap ports
	
    input [32-1:0] m_in,
	input [`CLOG2((K-(32-K%32)%32)/32) -1:0] m_addr,
	input m_wen,
	
	
    input [1:0] encap_out_type,
    input encap_out_en,
    input [LOG_RAMDEPTH-1:0]encap_out_addr,
    output [127:0] encap_out,
    
    // decap and encap ports
    
    input [RAMWIDTH-1:0] h_0,
	input [RAMWIDTH-1:0] h_1,	
	output [`CLOG2(X)-1:0] h_addr_0,
	output [`CLOG2(X)-1:0] h_addr_1,
	
	input [RAMWIDTH-1:0] s_0,
	input [RAMWIDTH-1:0] s_1,	
	output [`CLOG2(X)-1:0] s_addr_0,
	output [`CLOG2(X)-1:0] s_addr_1,
    
    //decap ports
    input [1:0] decap_in_type,
    input [RAMWIDTH-1:0] decap_in,
	input [LOG_RAMDEPTH-1:0] decap_in_addr,
	input decap_in_wen,
	
	output [LOG_WEIGHT-1:0] y_addr,
	input [M-1:0] y,
	    
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
    output [RAMWIDTH-1:0] decap_out    
    );

parameter KEYGEN = 2'b00;
parameter ENCAPSULATION = 2'b01;
parameter DECAPSULATION = 2'b10;

wire shake_din_valid_kg; 
wire shake_din_ready_kg;
wire [31:0] shake_din_kg;
wire shake_dout_ready_kg;
wire [31:0] shake_dout_scram_kg;
wire shake_force_done_kg;
wire shake_dout_valid_kg;

wire shake_din_valid; 
wire shake_din_ready;
wire [31:0] shake_din;
wire shake_dout_ready;
wire [31:0] shake_dout_scram;
wire shake_force_done;
wire shake_dout_valid;

wire shake_din_valid_e; 
wire shake_din_ready_e;
wire [31:0] shake_din_e;
wire shake_dout_ready_e;
wire [31:0] shake_dout_scram_e;
wire shake_force_done_e;
wire shake_dout_valid_e;

wire shake_din_valid_d; 
wire shake_din_ready_d;
wire [31:0] shake_din_d;
wire shake_dout_ready_d;
wire [31:0] shake_dout_scram_d;
wire shake_force_done_d;
wire shake_dout_valid_d;


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

wire pm_start_kg;    
wire [M-1:0] pm_loc_in_kg;
wire [LOG_MAX_WEIGHT:0] pm_weight_kg;
wire [W_BY_X-1:0]pm_mux_word_0_kg;
wire [W_BY_X-1:0]pm_mux_word_1_kg;
wire pm_rd_dout_kg;
wire [`CLOG2(RAMSIZE/2)-1:0]pm_addr_result_kg;
wire pm_add_wr_en_kg;
wire [`CLOG2(RAMSIZE/2)-1:0] pm_add_addr_kg;
wire [RAMWIDTH-1:0] pm_add_in_kg;
wire [LOGW-1:0] pm_loc_addr_kg;
wire [W_BY_X-1:0]pm_dout_kg;
wire pm_valid_kg;
wire [ADDR_WIDTH-1:0]pm_addr_0_kg;
wire [ADDR_WIDTH-1:0]pm_addr_1_kg;

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

wire done_kg;
wire done_e;
wire done_d;

//encap signals coming from decap
wire e_start_encap;
wire [32-1:0] e_m_in;
wire [`CLOG2((K-(32-K%32)%32)/32) -1:0] e_m_addr;
wire e_m_wen;
wire e_done_encap;
wire [1:0] e_sel_out;
wire e_out_en;
wire [LOG_RAMDEPTH-1:0]e_out_addr;
wire [127:0] e_encap_dout;
wire e_u_v_in_wen;
wire [`CLOG2(RAMDEPTH)-1:0] e_u_v_in_addr;
wire [RAMWIDTH-1:0] e_u_v_in;
wire e_resume_encap;
wire e_enc_done;
wire encap_inside_decap;


assign done = (operation == KEYGEN)? done_kg :
              (operation == ENCAPSULATION)? done_e:
              (operation == DECAPSULATION)? done_d:
              0;

assign shake_din_valid  = (operation == KEYGEN)? shake_din_valid_kg :
                          (operation == ENCAPSULATION || encap_inside_decap)? shake_din_valid_e :
                          (operation == DECAPSULATION)? shake_din_valid_d : 
                           0;

assign shake_din_ready_kg  = (operation == KEYGEN)? shake_din_ready: 0;
assign shake_din_ready_e   = (operation == ENCAPSULATION || encap_inside_decap)? shake_din_ready: 0;
assign shake_din_ready_d   = (operation == DECAPSULATION)? shake_din_ready: 0;

assign shake_din         = (operation == KEYGEN)?  shake_din_kg:
                           (operation == ENCAPSULATION || encap_inside_decap)?  shake_din_e:
                           (operation == DECAPSULATION)?  shake_din_d:
                           0;
                            
assign shake_dout_ready  = (operation == KEYGEN)? shake_dout_ready_kg:
                           (operation == ENCAPSULATION || encap_inside_decap)? shake_dout_ready_e:
                           (operation == DECAPSULATION)? shake_dout_ready_d:
                           0;
                           
assign shake_dout_scram_kg  = shake_dout_scram;
assign shake_dout_scram_e   = shake_dout_scram;
assign shake_dout_scram_d   = shake_dout_scram;

assign shake_force_done  = (operation == KEYGEN)? shake_force_done_kg:
                           (operation == ENCAPSULATION || encap_inside_decap)? shake_force_done_e:
                           (operation == DECAPSULATION)? shake_force_done_d:
                           0;

assign shake_dout_valid_kg  = (operation == KEYGEN)? shake_dout_valid:
                              0;
                              
assign shake_dout_valid_e   = (operation == ENCAPSULATION || encap_inside_decap)? shake_dout_valid:
                              0;
                              
assign shake_dout_valid_d   = (operation == DECAPSULATION)? shake_dout_valid:
                               0;

    keygen #(.parameter_set(parameter_set), .N(N), .MEM_WIDTH(MEM_WIDTH), .FILE_PKSEED(FILE_PKSEED), .CT_DESIGN(CT_DESIGN), .FILE_SKSEED(FILE_PKSEED) )
    KEYGEN_MODULE  (
    .clk(clk),
    .rst(rst),
    
    .sk_seed_wen(sk_seed_wen),
    .sk_seed_addr(sk_seed_addr),
    .sk_seed(sk_seed),
    
    .pk_seed_wen(pk_seed_wen),
    .pk_seed_addr(pk_seed_addr),
    .pk_seed(pk_seed),
    
    .start((start && operation == KEYGEN)? 1 : 0),
    .done(done_kg),
    
    .keygen_out_en(keygen_out_en),
    .keygen_out_addr(keygen_out_addr),
    .keygen_out(keygen_out),
    .keygen_out_type(keygen_out_type),
    
 `ifdef SHARED
    //poly mult signals
    .pm_start(pm_start_kg),    
    .pm_loc_in(pm_loc_in_kg),
    .pm_weight(pm_weight_kg),
    .pm_mux_word_0(pm_mux_word_0_kg),
    .pm_mux_word_1(pm_mux_word_1_kg),
    .pm_rd_dout(pm_rd_dout_kg),
    .pm_addr_result(pm_addr_result_kg),
    .pm_add_wr_en(pm_add_wr_en_kg),
    .pm_add_addr(pm_add_addr_kg),
    .pm_add_in(pm_add_in_kg),
    
    .pm_loc_addr(pm_loc_addr_kg),
    .pm_addr_0(pm_addr_0_kg),
    .pm_addr_1(pm_addr_1_kg),
    .pm_valid(pm_valid_kg),
    .pm_dout(pm_dout_kg),
`endif

     //shake signals
    .shake_din_valid(shake_din_valid_kg),
    .shake_din_ready(shake_din_ready_kg),
    .shake_din(shake_din_kg),
    .shake_dout_ready(shake_dout_ready_kg),
    .shake_dout_scram(shake_dout_scram_kg),
    .shake_force_done(shake_force_done_kg),
    .shake_dout_valid(shake_dout_valid_kg)
    );

    encap #(.parameter_set(parameter_set), .CT_DESIGN(CT_DESIGN), .PARALLEL_ENCRYPT(PARALLEL_ENCRYPT), .FILE_THETA(FILE_THETA) )
    ENCAP_MODULE  (

    .clk(clk),
    .rst(rst),
    .start((start && operation == ENCAPSULATION)? 1 : (operation == DECAPSULATION)? e_start_encap: 0),
    
	.m_addr((operation == DECAPSULATION)? e_m_addr :m_addr),
    .m_wen((operation == DECAPSULATION)? e_m_wen :m_wen),
    .m_in((operation == DECAPSULATION)? e_m_in :m_in),
    .done(done_e),
        
    .h_0(h_0),
    .h_1(h_1),
    .h_addr_0(h_addr_0),
    .h_addr_1(h_addr_1),
    
    .s_0(s_0),
    .s_1(s_1),
    .s_addr_0(s_addr_0),
    .s_addr_1(s_addr_1),
	

	.encap_out_type((operation == DECAPSULATION)?e_sel_out :encap_out_type),
	.encap_out_en((operation == DECAPSULATION)?e_out_en :encap_out_en),
	.encap_out_addr((operation == DECAPSULATION)?e_out_addr :encap_out_addr),
	.encap_out(encap_out),

	.u_v_in_wen((operation == DECAPSULATION)?e_u_v_in_wen :0),
	.u_v_in_addr((operation == DECAPSULATION)?e_u_v_in_addr :0),
	.u_v_in((operation == DECAPSULATION)? e_u_v_in :0),
	.resume_encap((operation == DECAPSULATION)?e_resume_encap:1),
    .enc_done(e_enc_done),
    
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
    .shake_din_valid(shake_din_valid_e),
    .shake_din_ready(shake_din_ready_e),
    .shake_din(shake_din_e),
    .shake_dout_ready(shake_dout_ready_e),
    .shake_dout_scram(shake_dout_scram_e),
    .shake_force_done(shake_force_done_e),
    .shake_dout_valid(shake_dout_valid_e)
    );
    
 assign e_done_encap = done_e;
 assign e_encap_dout = encap_out;
    
  decap 
  #(.parameter_set(parameter_set))
  DECAP_MODULE
  ( .clk(clk),
    .rst(rst),
    .start((start && operation == DECAPSULATION)? 1 : 0),
    
	.decap_in_type(decap_in_type),
    .decap_in(decap_in),
    .decap_in_addr(decap_in_addr_reg),
    .decap_in_wen(decap_in_wen),
    
    .done(done_d),
    
    .y(y),
    .y_addr(y_addr),
    
    .encap_inside_decap(encap_inside_decap),
    
`ifdef SHARED
	.e_start_encap	(e_start_encap	),
	.e_m_in			(e_m_in			),
	.e_m_addr		(e_m_addr		),
	.e_m_wen		(e_m_wen		),
	.e_done_encap	(e_done_encap	),
	.e_sel_out		(e_sel_out		),
	.e_out_en		(e_out_en		),
	.e_out_addr		(e_out_addr		),
	.e_encap_dout	(e_encap_dout	),   
	.e_u_v_in_wen	(e_u_v_in_wen	),
	.e_u_v_in_addr	(e_u_v_in_addr	),
	.e_u_v_in		(e_u_v_in		),
	.e_resume_encap	(e_resume_encap	),
	.e_enc_done		(e_enc_done		),
`endif
//    .sel_hs(sel_hs),
    .u_0(u_0),
    .u_1(u_1),
    .u_addr_0(u_addr_0),
    .u_addr_1(u_addr_1),
    
    .v_0(v_0),
    .v_1(v_1),
    .v_addr_0(v_addr_0),
    .v_addr_1(v_addr_1),
	
    
	
	.decap_out_en(decap_out_en),
	.decap_out_addr(decap_out_addr),
	.decap_out(decap_out),
	
`ifdef SHARED
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
`endif
		
	//shake signals
    .shake_din_valid(shake_din_valid_d),
    .shake_din_ready(shake_din_ready_d),
    .shake_din(shake_din_d),
    .shake_dout_ready(shake_dout_ready_d),
    .shake_dout_scram(shake_dout_scram_d),
    .shake_force_done(shake_force_done_d),
    .shake_dout_valid(shake_dout_valid_d)
	
    );
    
     keccak_top
    SHAKE256(
    .clk(clk),
    .rst(rst),
    .din_valid(shake_din_valid),
    .din_ready(shake_din_ready),
    .din(shake_din),
    .dout_valid(shake_dout_valid),
    .dout_ready(shake_dout_ready),
    .dout(shake_dout_scram),
    .force_done(shake_force_done)
    );


 `ifdef SHARED
assign pm_start  = (operation == KEYGEN)? pm_start_kg: 
                   (operation == ENCAPSULATION || encap_inside_decap)? pm_start_e:
                   (operation == DECAPSULATION)? pm_start_d:
                   0;

assign pm_loc_in  = (operation == KEYGEN)? pm_loc_in_kg:
                   (operation == ENCAPSULATION || encap_inside_decap)? pm_loc_in_e:
                   (operation == DECAPSULATION)? pm_loc_in_d:
                   0;
                   
assign pm_weight  = (operation == KEYGEN)? pm_weight_kg:
                   (operation == ENCAPSULATION || encap_inside_decap)? pm_weight_e:
                   (operation == DECAPSULATION)? pm_weight_d:
                   0;
                   
assign pm_mux_word_0  = (operation == KEYGEN)? pm_mux_word_0_kg:
                   (operation == ENCAPSULATION || encap_inside_decap)? pm_mux_word_0_e:
                   (operation == DECAPSULATION)? pm_mux_word_0_d:
                   0;
                   
assign pm_mux_word_1  = (operation == KEYGEN)? pm_mux_word_1_kg:
                   (operation == ENCAPSULATION || encap_inside_decap)? pm_mux_word_1_e:
                   (operation == DECAPSULATION)? pm_mux_word_1_d:
                   0;
                   
assign pm_rd_dout  = (operation == KEYGEN)? pm_rd_dout_kg:
                   (operation == ENCAPSULATION || encap_inside_decap)? pm_rd_dout_e:
                   (operation == DECAPSULATION)? pm_rd_dout_d:
                   0;
                   
assign pm_addr_result  = (operation == KEYGEN)? pm_addr_result_kg:
                   (operation == ENCAPSULATION || encap_inside_decap)? pm_addr_result_e:
                   (operation == DECAPSULATION)? pm_addr_result_d:
                   0;
                   
assign pm_add_wr_en  = (operation == KEYGEN)? pm_add_wr_en_kg:
                   (operation == ENCAPSULATION || encap_inside_decap)? pm_add_wr_en_e:
                   (operation == DECAPSULATION)? pm_add_wr_en_d:
                   0;
                   
assign pm_add_addr  = (operation == KEYGEN)? pm_add_addr_kg:
                   (operation == ENCAPSULATION || encap_inside_decap)? pm_add_addr_e:
                   (operation == DECAPSULATION)? pm_add_addr_d:
                   0;
                   
assign pm_add_in  = (operation == KEYGEN)? pm_add_in_kg:
                    (operation == ENCAPSULATION || encap_inside_decap)? pm_add_in_e:
                    (operation == DECAPSULATION)? pm_add_in_d:
                    0;

assign pm_loc_addr_kg   = pm_loc_addr;
assign pm_addr_0_kg     = pm_addr_0;
assign pm_addr_1_kg     = pm_addr_1;
assign pm_valid_kg      = (operation == KEYGEN)? pm_valid:0;
assign pm_dout_kg       = pm_dout;

assign pm_loc_addr_e   = pm_loc_addr;
assign pm_addr_0_e     = pm_addr_0;
assign pm_addr_1_e     = pm_addr_1;
assign pm_valid_e      = (operation == ENCAPSULATION || encap_inside_decap)? pm_valid:0;
assign pm_dout_e       = pm_dout;

assign pm_loc_addr_d   = pm_loc_addr;
assign pm_addr_0_d     = pm_addr_0;
assign pm_addr_1_d     = pm_addr_1;
assign pm_valid_d      = (operation == DECAPSULATION)? pm_valid:0;
assign pm_dout_d       = pm_dout;

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
    
endmodule
