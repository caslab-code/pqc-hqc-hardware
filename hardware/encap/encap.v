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


module encap
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
    
    // memory related constants
	parameter MEM_WIDTH = RAMWIDTH,	
	parameter N_MEM = N + (MEM_WIDTH - N%MEM_WIDTH)%MEM_WIDTH, // Memory width adjustment for N
	parameter N_B = N + (8-N%8)%8, // Byte adjustment on N
	parameter N_Bd = N_B - N, // difference between N and byte adjusted N
	parameter N_MEMd = N_MEM - N_B, // difference between byte adjust and Memory adjusted N
	 
	parameter RAMDEPTH = (N+(RAMWIDTH-N%RAMWIDTH)%RAMWIDTH)/RAMWIDTH, //u RAM depth
	parameter LOG_RAMDEPTH = `CLOG2(RAMDEPTH),
	parameter LOGX = `CLOG2(X), 
    parameter Y = X/2,
	parameter LOGW = `CLOG2(W),
	parameter W_BY_X = W/X, 
	parameter W_BY_Y = W/Y, // This number needs to be a power of 2 for optimized synthesis
	parameter RAMSIZE = X,
	parameter ADDR_WIDTH = `CLOG2(RAMSIZE),
    parameter LOG_MAX_WEIGHT = `CLOG2(WEIGHT_ENC),
	
	
	
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
	
	
     
     parameter CT_DESIGN = 2'b01, // CT_DESIGN = 01 Constant time design, CT_DESIGN = 10 Constant Weight Word design, CT_DESIGN = 00 Default Design 
	parameter PARALLEL_ENCRYPT = 0 // PARALLEL_ENCRYPT = 1 Two Poly mults running in parallel inside Encrypt , PARALLEL_ENCRYPT = 0 One Poly mult operating sequential inside Encrypt 

	    
													
)
(
    input clk,
    input rst,
    input start,
	
    input [32-1:0] m_in,
	input [`CLOG2((K-(32-K%32)%32)/32) -1:0] m_addr,
	input m_wen,
	
    output reg done,
	
//	output sel_hs,
//	input [RAMWIDTH-1:0] hs_0,
//	input [RAMWIDTH-1:0] hs_1,	
//	output [`CLOG2(X)-1:0] hs_addr_0,
//	output [`CLOG2(X)-1:0] hs_addr_1,
	
`ifdef VIRTUAL_PINS
	// synthesis translate_off
`endif
	input [RAMWIDTH-1:0] h_0,
	input [RAMWIDTH-1:0] h_1,
`ifdef VIRTUAL_PINS	
	// synthesis translate_on
`endif
	
	output [`CLOG2(X)-1:0] h_addr_0,
	output [`CLOG2(X)-1:0] h_addr_1,

`ifdef VIRTUAL_PINS	
	// synthesis translate_off
`endif
	input [RAMWIDTH-1:0] s_0,
	input [RAMWIDTH-1:0] s_1,
`ifdef VIRTUAL_PINS
	// synthesis translate_on
`endif	
	output [`CLOG2(X)-1:0] s_addr_0,
	output [`CLOG2(X)-1:0] s_addr_1,
	
    input [1:0] encap_out_type,
    input encap_out_en,
    input [LOG_RAMDEPTH-1:0]encap_out_addr,
    output [127:0] encap_out,
    
    input u_v_in_wen,
	input [`CLOG2(RAMDEPTH)-1:0] u_v_in_addr,

`ifdef VIRTUAL_PINS
	// synthesis translate_off
`endif
	input [RAMWIDTH-1:0] u_v_in,
`ifdef VIRTUAL_PINS	
	// synthesis translate_on
`endif
	input  resume_encap,
	output enc_done,
  
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
    input  wire shake_force_done_ack,
    input  wire shake_dout_valid
	
    );
   
wire shake_din_valid_fw; 
wire shake_din_ready_fw;
wire [31:0] shake_din_fw;
wire shake_dout_ready_fw;
wire [31:0] shake_dout_scram_fw;
wire shake_force_done_fw;
wire shake_dout_valid_fw;

reg shake_din_valid_h; 
wire shake_din_ready_h;
wire [31:0] shake_din_h;
reg shake_dout_ready_h;
wire [31:0] shake_dout_scram_h;
wire shake_force_done_h;
wire shake_dout_valid_h;

reg hash_processing =0;
reg fixed_weight_processing =0;

assign encap_out = (encap_out_type ==0)?{0, shake_din_h}:
                    (encap_out_type ==1)?{0, d_out}:
                                  u_v_int;  

assign shake_din_valid = (hash_processing)? shake_din_valid_h: shake_din_valid_fw;
assign shake_din_ready_fw = shake_din_ready;
assign shake_din = (hash_processing)? shake_din_h:shake_din_fw;
assign shake_dout_ready = (shake_dout_ready_h)? 1'b1: shake_dout_ready_fw;
assign shake_dout_scram_fw = shake_dout_scram;

assign shake_dout_valid_fw = (fixed_weight_processing)? shake_dout_valid: 0;
assign shake_din_ready_h = shake_din_ready;
assign shake_dout_scram_h = shake_dout_scram;
assign shake_dout_valid_h = shake_dout_valid;

wire [`CLOG2(HASH_RAMDEPTH)-1:0] hash_addr;
reg [`CLOG2(HASH_RAMDEPTH)-1:0] h_addr;
reg [`CLOG2(HASH_RAMDEPTH)-1:0] hash_in_addr;

wire [31:0] m_out;
wire [`CLOG2((K+(32-K%32)%32)/32) -1:0] msg_addr;
reg [`CLOG2((K+(32-K%32)%32)/32) -1:0] m_addr_int;


assign msg_addr = (m_wen)? m_addr:
                           m_addr_int;
  mem_single #(.WIDTH(32), .DEPTH((K+(32-K%32)%32)/32)) MSG_MEM
  (
         .clock(clk),
         .data({m_in[7:0],m_in[15:8],m_in[23:16],m_in[31:24]}),
         .address(msg_addr),
         .wr_en(m_wen),
         .q(m_out)
  );
  
  reg [LOG_D_RAMDEPTH-1:0] d_addr;
  reg d_wen;
  wire [31:0] d_out;
  mem_single #(.WIDTH(32), .DEPTH(D_RAMDEPTH)) D_MEM
  (
         .clock(clk),
//         .data({shake_dout_scram[7:0],shake_dout_scram[15:8],shake_dout_scram[23:16],shake_dout_scram[31:24]}),
         .data(shake_dout_scram),
         .address((encap_out_type ==1 && encap_out_en)? encap_out_addr[3:0]:d_addr),
         .wr_en(d_wen),
         .q(d_out)
  );
  
  
reg theta_wen;
reg [3:0] theta_addr;
reg start_encrypt;
wire done_encrypt;
reg [K-1:0] msg_in;

reg init_msg_in;
reg shift_msg_in; 
wire done_fixed_weight;



always@(posedge clk) begin
    if (init_msg_in) begin
        msg_in <= 0;
    end
    else if (shift_msg_in) begin
        msg_in <= {m_out, msg_in[K-1:32]};
    end
end 
 
wire [RAMWIDTH-1:0] u_v_int;
reg [`CLOG2(RAMDEPTH)-1:0] u_v_out_addr_int;
reg u_v_out_en_int;
reg sel_uv_int;

assign enc_done = done_encrypt; 

wire sel_uv_to_enc;
assign sel_uv_to_enc = (encap_out_type==2 && (encap_out_en || u_v_in_wen))? 0 : 
                       (encap_out_type==3 && (encap_out_en || u_v_in_wen))? 1'b1 : 
                       sel_uv? 1'b1:  
                       0;
wire u_v_out_en;
assign u_v_out_en = u_v_out_en_int?1'b1:encap_out_en;

wire [`CLOG2(RAMDEPTH)-1:0] u_v_out_addr;
assign u_v_out_addr = u_v_out_en_int? u_v_out_addr_int:
                                      encap_out_addr;

generate
    if (PARALLEL_ENCRYPT == 1) begin
    encrypt_parallel 
        //    encrypt 
          #(.parameter_set(parameter_set), .CT_DESIGN(CT_DESIGN))
          ENCRYPT
          ( .clk(clk),
            .rst(rst),
            .start(start_encrypt),
            .msg_in(msg_in),
            
            .theta_addr(theta_addr),
            .theta_wen(theta_wen),
            .theta(shake_dout_scram_h),
            
            .done(done_encrypt),
            
            .h_0(h_0),
            .h_1(h_1),
            .h_addr_0(h_addr_0),
            .h_addr_1(h_addr_1),
            
            .s_0(s_0),
            .s_1(s_1),
            .s_addr_0(s_addr_0),
            .s_addr_1(s_addr_1),
            
            .sel_uv(sel_uv_to_enc),
            .u_v_out(u_v_int),
            .u_v_out_en(u_v_out_en),
            .u_v_out_addr(u_v_out_addr),
            
            .u_v_in_wen(u_v_in_wen),
            .u_v_in_addr(u_v_in_addr),
            .u_v_in(u_v_in),
            .done_fixed_weight(done_fixed_weight),
            
            
            `ifdef SHARED
                //poly mult signals
                .pm_start(pm_start),    
                .pm_loc_in(pm_loc_in),
                .pm_weight(pm_weight),
                .pm_mux_word_0(pm_mux_word_0),
                .pm_mux_word_1(pm_mux_word_1),
                .pm_rd_dout(pm_rd_dout),
                .pm_addr_result(pm_addr_result),
                .pm_add_wr_en(pm_add_wr_en),
                .pm_add_addr(pm_add_addr),
                .pm_add_in(pm_add_in),
                
                .pm_loc_addr(pm_loc_addr),
                .pm_addr_0(pm_addr_0),
                .pm_addr_1(pm_addr_1),
                .pm_valid(pm_valid),
                .pm_dout(pm_dout),
            `endif
            
            //shake signals
            .shake_din_valid(shake_din_valid_fw),
            .shake_din_ready(shake_din_ready_fw),
            .shake_din(shake_din_fw),
            .shake_dout_ready(shake_dout_ready_fw),
            .shake_dout_scram(shake_dout_scram_fw),
            .shake_force_done(shake_force_done_fw),
            .shake_dout_valid(shake_dout_valid_fw)
            
            );
     end

    else if (PARALLEL_ENCRYPT == 0) begin
            encrypt 
          #(.parameter_set(parameter_set), .CT_DESIGN(CT_DESIGN))
          ENCRYPT
          ( .clk(clk),
            .rst(rst),
            .start(start_encrypt),
            .msg_in(msg_in),
            
            .theta_addr(theta_addr),
            .theta_wen(theta_wen),
            .theta(shake_dout_scram_h),
            
            .done(done_encrypt),
            
            
            .h_0(h_0),
            .h_1(h_1),
            .h_addr_0(h_addr_0),
            .h_addr_1(h_addr_1),
            
            .s_0(s_0),
            .s_1(s_1),
            .s_addr_0(s_addr_0),
            .s_addr_1(s_addr_1),
            
            .sel_uv(sel_uv_to_enc),
            .u_v_out(u_v_int),
            .u_v_out_en(u_v_out_en),
            .u_v_out_addr(u_v_out_addr),
            
            .u_v_in_wen(u_v_in_wen),
            .u_v_in_addr(u_v_in_addr),
            .u_v_in(u_v_in),
            
            .done_fixed_weight(done_fixed_weight),
            
            `ifdef SHARED
                //poly mult signals
                .pm_start(pm_start),    
                .pm_loc_in(pm_loc_in),
                .pm_weight(pm_weight),
                .pm_mux_word_0(pm_mux_word_0),
                .pm_mux_word_1(pm_mux_word_1),
                .pm_rd_dout(pm_rd_dout),
                .pm_addr_result(pm_addr_result),
                .pm_add_wr_en(pm_add_wr_en),
                .pm_add_addr(pm_add_addr),
                .pm_add_in(pm_add_in),
                
                .pm_loc_addr(pm_loc_addr),
                .pm_addr_0(pm_addr_0),
                .pm_addr_1(pm_addr_1),
                .pm_valid(pm_valid),
                .pm_dout(pm_dout),
            `endif
            
            //shake signals
            .shake_din_valid(shake_din_valid_fw),
            .shake_din_ready(shake_din_ready_fw),
            .shake_din(shake_din_fw),
            .shake_dout_ready(shake_dout_ready_fw),
            .shake_dout_scram(shake_dout_scram_fw),
            .shake_force_done(shake_force_done_fw),
            .shake_dout_valid(shake_dout_valid_fw)
            
            );
    end 
endgenerate

reg [RAMWIDTH-1:0]u_v;
reg cap_uv;
reg shift_uv;

always@(posedge clk)
begin
    if (cap_uv) begin
        u_v <= u_v_int;
    end
    else if (shift_uv) begin
        u_v <= {{32{1'b0}}, u_v[RAMWIDTH-1:32]};
    end
end

wire [31:0] hash_mem_in;
reg [31:0] shake_support_vector;
reg [31:0] shake_output_size;
reg [31:0] shake_input_size;
reg [31:0] shake_domain_sep;
reg [2:0] shake_in_type;
reg hash_mem_wen =0;



assign hash_mem_in = (shake_in_type == 0)? shake_support_vector:
                     (shake_in_type == 1)? m_out:
                     (shake_in_type == 2)? u_v[63:32]:
                     (shake_in_type == 3)? u_v_int[31:0]:
                     (shake_in_type == 4)? {u_v[64-HASH_LB_SIZE-1:64-HASH_LB_SIZE-32]}:
                     (shake_in_type == 5)? {u_v_int[32-HASH_LB_SIZE-1:0], u_v_reg}:
                     (shake_in_type == 6)? {{(32-HASH_RAMBITS_8%32){1'b0}}, 8'h05, u_v_reg}:
//                                           {shake_dout_scram[7:0],shake_dout_scram[15:8],shake_dout_scram[23:16],shake_dout_scram[31:24]};
                                           {shake_dout_scram};


reg [HASH_LB_SIZE - 1:0] u_v_reg;

always@(posedge clk) begin
    if (last_block_capture) begin
        u_v_reg <= u_v[HASH_LB_SIZE - 1:0];
    end
    else if (block_capture) begin
        u_v_reg <= u_v[63:64-HASH_LB_SIZE];    
    end
end


always@(posedge clk)
begin
    if (start) begin
        count_hash_inputs_test <= 0;
    end
    else if (hash_mem_wen == 1 && shake_in_type != 0) begin
        count_hash_inputs_test <= count_hash_inputs_test + 1;
    end 
end

wire [5:0] chi_mod_34;
wire chi_mod34_neq_0;
  mod34 
  MOD34_BARRETT
  ( 
    .a_i(count_hash_inputs),
    .c_o(chi_mod_34)
    );

assign chi_mod34_neq_0 = (chi_mod_34==0)? 0:1;

assign hash_addr = (hash_mem_wen)?          hash_in_addr:
                   (encap_out_en && encap_out_type == 0)? {0,encap_out_addr}: 
                                            h_addr;
  mem_single #(.WIDTH(32), .DEPTH(HASH_RAMDEPTH)) HASH_MEM
  (
         .clock(clk),
         .data(hash_mem_in),
         .address(hash_addr),
         .wr_en(hash_mem_wen),
         .q(shake_din_h)
  );
//reg [`CLOG2(HASH_RAMBITS_32/32)-1:0] count_hash_inputs;
reg [12-1:0] count_hash_inputs;
reg [`CLOG2(HASH_RAMBITS_32/32)-1:0] count_hash_inputs_test;
reg [3:0] count_uv_blocks;
reg cap_uv_reg;
reg sel_uv;

reg [4:0] state = 0;
parameter s_wait_start = 0;
parameter s_load_m_in_size = 1;
parameter s_load_m_out_size = 2;
parameter s_load_m = 3;
parameter s_load_last_m = 4;
parameter s_comp_theta = 5;
parameter s_save_theta = 6;
parameter s_encrypt = 7;
parameter s_wait_done_fw = 8;
parameter s_update_hram_d = 9;
parameter s_comp_d = 10;
parameter s_save_d = 11;
parameter s_save_last_d = 12;
parameter s_wait_done_enc = 13;
parameter s_load_u = 14;
parameter s_save_u = 15;
parameter s_load_dom_sep = 16;
parameter s_load_v = 17;
parameter s_save_v = 18;
parameter s_load_dom_sep_v = 19;
parameter s_stall_0 = 20;
parameter s_append_05 = 21;
parameter s_comp_ss = 22;
parameter s_wait_ss = 23;
parameter s_stall_1 = 24;
parameter s_wait_for_resume_encap = 25;
parameter s_done = 31;
always@(posedge clk)
begin
    if (rst) begin
        state <= s_wait_start;
        m_addr_int <= 0;
        done <= 1'b0;
        total_shake_input_count <= 0;
        shake_support_vector <= 0;
        shake_dout_ready_h <= 0;
        d_addr <= 0;
        u_v_out_addr_int <= 0;
        sel_uv_int <= 0;
        count_uv_blocks <= 0;
        u_v_out_en_int <= 0;
        count_hash_inputs <= 0;
        sel_uv <= 0;
        fixed_weight_processing <= 0;
    end
    else begin
        if (state == s_wait_start) begin
            m_addr_int <= 0;
            hash_in_addr <= 0;
            theta_addr <= 0;
            done <= 1'b0;
            shake_dout_ready_h <= 0;
            d_addr <= 0;
            u_v_out_addr_int <= 0;
            sel_uv_int <= 0;
            count_uv_blocks <= 0;
            u_v_out_en_int <= 0;
            sel_uv <= 0;
            fixed_weight_processing <= 0;
            if (start) begin
                state <= s_load_m_out_size;
                shake_support_vector <= 32'h40000140;               
                total_shake_input_count <= 2 + ((K+8)+(32-(K+8)%32)%32)/32; 
            end
        end
        
        else if (state == s_load_m_out_size) begin
            done <= 1'b0;
            m_addr_int <= 0;
            theta_addr <= 0;
            hash_in_addr <= hash_in_addr + 1;
            state <= s_load_m_in_size;
            shake_support_vector <= THETA_D_DOMSEP;
            shake_dout_ready_h <= 0;
            d_addr <= 0;
            u_v_out_addr_int <= 0;
            sel_uv_int <= 0;
            count_uv_blocks <= 0;
            u_v_out_en_int <= 0;
            sel_uv <= 0;
            fixed_weight_processing <= 0;
        end
        
        else if (state == s_load_m_in_size) begin
            done <= 1'b0;
            theta_addr <= 0;
            m_addr_int <= m_addr_int+1;
            hash_in_addr <= hash_in_addr + 1;
            state <= s_load_m;
            shake_support_vector <= 32'h00000003;
            shake_dout_ready_h <= 0;
            d_addr <= 0;
            u_v_out_addr_int <= 0;
            sel_uv_int <= 0;
            count_uv_blocks <= 0;
            u_v_out_en_int <= 0;
            count_hash_inputs <= count_hash_inputs + 1;
            sel_uv <= 0;
            fixed_weight_processing <= 0;
        end
        
        
        
        else if (state == s_load_m) begin
            done <= 1'b0;
            theta_addr <= 0;
            shake_dout_ready_h <= 0;
            d_addr <= 0;
            u_v_out_addr_int <= 0;
            sel_uv_int <= 0;
            count_uv_blocks <= 0;
            u_v_out_en_int <= 0;
            count_hash_inputs <= count_hash_inputs + 1;
            fixed_weight_processing <= 0;
            sel_uv <= 0;
            if (m_addr_int == ((K+(32-K%32)%32)/32)-1) begin
                state <= s_load_last_m;
                hash_in_addr <= hash_in_addr + 1;
                m_addr_int <= 0;
            end
            else begin
                state <= s_load_m;
                m_addr_int <= m_addr_int + 1;
                hash_in_addr <= hash_in_addr + 1;
            end
        end
        
        else if (state == s_load_last_m) begin
            state <= s_comp_theta;
            hash_in_addr <= hash_in_addr + 1;
            theta_addr <= 0;
            shake_dout_ready_h <= 0;
            d_addr <= 0;
            u_v_out_addr_int <= 0;
            sel_uv_int <= 0;
            count_uv_blocks <= 0;
            u_v_out_en_int <= 0;
            sel_uv <= 0;
            fixed_weight_processing <= 0;
            
        end
        
        else if (state == s_comp_theta) begin
            state <= s_save_theta;
            theta_addr <= 0;
            shake_dout_ready_h <= 1;
            d_addr <= 0;
            u_v_out_addr_int <= 0;
            sel_uv_int <= 0;
            count_uv_blocks <= 0;
            u_v_out_en_int <= 0;
            sel_uv <= 0;
            fixed_weight_processing <= 0;
        end
        
        else if(state == s_save_theta) begin
            shake_dout_ready_h <= 1;
            shake_support_vector <= 32'h00000004;
            d_addr <= 0;
            u_v_out_addr_int <= 0;
            sel_uv_int <= 0;
            count_uv_blocks <= 0;
            u_v_out_en_int <= 0;
            sel_uv <= 0;
            fixed_weight_processing <= 0;
            if (theta_addr < 10) begin
                if (shake_dout_valid_h) begin
                    theta_addr <= theta_addr + 1;
                end
            end
            else begin
                state <= s_stall_1;
                theta_addr <= 0;
            end
       end 
        
        else if (state == s_stall_1) begin
            state <= s_encrypt;
        end
        
        else if (state == s_encrypt) begin
            shake_dout_ready_h <= 0;
            state <= s_wait_done_fw;
            hash_in_addr <= 0;
            shake_support_vector <= 32'h40000200;
            d_addr <= 0;
            u_v_out_addr_int <= 0;
            count_uv_blocks <= 0;
            u_v_out_en_int <= 0;
            sel_uv <= 0;
            fixed_weight_processing <= 1;
        end
        
        else if (state == s_wait_done_fw) begin
            shake_dout_ready_h <= 0;
            d_addr <= 0;
            u_v_out_addr_int <= 0;
            sel_uv_int <= 0;
            count_uv_blocks <= 0;
            u_v_out_en_int <= 0;
            sel_uv <= 0;
            if (done_fixed_weight) begin
                state <= s_update_hram_d;
                fixed_weight_processing <= 0;
            end
            else begin
                fixed_weight_processing <= 1;
            end
        end
        
        else if (state == s_update_hram_d) begin
                state <= s_comp_d;
                shake_dout_ready_h <= 1;
                d_addr <= 0;
                u_v_out_addr_int <= 0;
                sel_uv_int <= 0;
                count_uv_blocks <= 0;
                u_v_out_en_int <= 0;
                sel_uv <= 0;
                fixed_weight_processing <= 0;
        end
        
        else if (state == s_comp_d) begin
                state <= s_save_d;
                shake_dout_ready_h <= 1;
                d_addr <= 0;
                u_v_out_addr_int <= 0;
                sel_uv_int <= 0;
                count_uv_blocks <= 0;
                u_v_out_en_int <= 0;
                sel_uv <= 0;
        end
        
        else if (state == s_save_d) begin
            shake_dout_ready_h <= 1;
            hash_in_addr <= 1;
            shake_support_vector <= 32'h00000440;
            u_v_out_addr_int <= 0;
            sel_uv_int <= 0;
            count_uv_blocks <= 0;
            u_v_out_en_int <= 0;
            sel_uv <= 0;
            if (d_addr == D_RAMDEPTH-2) begin
                    state <= s_save_last_d;
                    if (shake_dout_valid_h) begin
                        d_addr <= d_addr + 1;
                    end
            end
            else begin
                if (shake_dout_valid_h) begin
                    d_addr <= d_addr + 1;
                end
            end
            
//            if (d_addr == D_RAMDEPTH-2) begin
//                    shake_dout_ready_h <= 0;
//            end
//            else begin
//                    shake_dout_ready_h <= 1;
//            end
        end
        
        else if (state == s_save_last_d) begin
            shake_dout_ready_h <= 1;
            u_v_out_addr_int <= 0;
            sel_uv_int <= 0;
            count_uv_blocks <= 0;
            u_v_out_en_int <= 0;
            sel_uv <= 0;
            if (shake_dout_valid_h) begin
                state <= s_wait_done_enc;
                d_addr <= 0;
                hash_in_addr <= K/32 + 2;
            end 
        end
        
         else if (state == s_wait_done_enc) begin
           shake_dout_ready_h <= 0;
           u_v_out_addr_int <= 0;
           sel_uv_int <= 0;
           count_uv_blocks <= 0;
           sel_uv <= 0;
           u_v_out_en_int <= 0;
           total_shake_input_count <= HASH_RAMDEPTH;
           if (done_encrypt) begin
//                state <= s_load_u;
                state <= s_wait_for_resume_encap;
           end
        end
        
        //========================================
        else if (state == s_wait_for_resume_encap) begin
           shake_dout_ready_h <= 0;
           u_v_out_addr_int <= 0;
           sel_uv_int <= 0;
           count_uv_blocks <= 0;
           sel_uv <= 0;
            if (resume_encap) begin
               state <= s_load_u;
               u_v_out_en_int <= 1;    
            end
        end
        
        //========================================
        
        else if (state == s_load_u) begin
           shake_dout_ready_h <= 0;
           u_v_out_en_int <= 1;
           
           
           if (count_hash_inputs < HASH_M_U_32/32-1) begin
                sel_uv <= 0;
                
                    hash_in_addr <= hash_in_addr+1;
               
                if (chi_mod34_neq_0) begin
//                if (count_hash_inputs%34 != 0) begin
                    count_hash_inputs <= count_hash_inputs + 1;
                    if (count_uv_blocks < 3) begin
                        state <= s_save_u;
                        count_uv_blocks <= count_uv_blocks + 1;
                    end
                    else begin
                        state <= s_load_u;
                        count_uv_blocks <= 0;
                    end
                end
                else begin
                    state <= s_load_dom_sep;
                end
            
           end
           else begin
                state <= s_stall_0;
                sel_uv <= 1;
                u_v_out_addr_int <= 0;
           end
        end
        
        else if (state == s_save_u) begin
           shake_dout_ready_h <= 0;
           u_v_out_en_int <= 1;
           if (count_hash_inputs < HASH_M_U_32/32-1) begin
               hash_in_addr <= hash_in_addr+1;
           end
           
           if (count_hash_inputs < HASH_M_U_32/32-1) begin
           
               sel_uv <= 0;
               if (chi_mod34_neq_0) begin             
//               if (count_hash_inputs%34 != 0) begin             
                       count_hash_inputs <= count_hash_inputs + 1;
                   if (count_uv_blocks < 3) begin
                        state <= s_save_u;
                            count_uv_blocks <= count_uv_blocks + 1;
                   end
                   else begin
                        state <= s_load_u;
                        count_uv_blocks <= 0;
                   end
    
                end
                else begin
                    state <= s_load_dom_sep;
                end
                
               if (count_uv_blocks == 1) begin
                   if (u_v_out_addr_int < (N + (128-N%128)%128)/128 - 1) begin
                        u_v_out_addr_int <= u_v_out_addr_int + 1;
                   end
               end
               end
           else begin
              state <= s_stall_0;
              sel_uv <= 1;
              u_v_out_addr_int <= 0;  
           end
        end
        
        else if (state == s_load_dom_sep) begin
           shake_dout_ready_h <= 0;
           u_v_out_en_int <= 1;
           hash_in_addr <= hash_in_addr+1;
           count_hash_inputs <= count_hash_inputs + 1;
           sel_uv <= 0;
           if (count_uv_blocks < 3) begin
                state <= s_save_u;
                count_uv_blocks <= count_uv_blocks + 1;
           end
           else begin
                state <= s_load_u;
                count_uv_blocks <= 0;
           end
        end
       
       else if (state == s_stall_0) begin
            sel_uv <= 1;
            shake_dout_ready_h <= 0;
            u_v_out_en_int <= 1;
            state <= s_load_v;
            count_uv_blocks <= 0;
       end
       
   else if (state == s_load_v) begin
           shake_dout_ready_h <= 0;
           u_v_out_en_int <= 1;
           
           
           if (count_hash_inputs < HASH_RAMBITS_32/32 - 1) begin
                sel_uv <= 1;
                if (chi_mod34_neq_0) begin
//                if (count_hash_inputs%34 != 0) begin
                    count_hash_inputs <= count_hash_inputs + 1;
                    if (count_uv_blocks < 3) begin
                        state <= s_save_v;
                        count_uv_blocks <= count_uv_blocks + 1;
                    end
                    else begin
                        state <= s_load_v;
                        count_uv_blocks <= 0;
                    end
                end
                else begin
                    state <= s_load_dom_sep_v;
                
                end
                hash_in_addr <= hash_in_addr+1;
           end
           else begin
                state <= s_append_05;
                sel_uv <= 1;
                u_v_out_addr_int <= 0;
           end
           
           if (hash_in_addr > HASH_RAMDEPTH - 34 -1) begin
                    shake_support_vector <= HASH_LB_DOMSEP; 
           end
           else begin
                shake_support_vector <= 32'h00000440;
           end
        end
        
        else if (state == s_save_v) begin
           shake_dout_ready_h <= 0;
           u_v_out_en_int <= 1;
           if (count_hash_inputs <= HASH_RAMBITS_32/32 -1) begin
               hash_in_addr <= hash_in_addr+1;
               sel_uv <= 1;
               if (chi_mod34_neq_0) begin
//               if (count_hash_inputs%34 != 0) begin
                   count_hash_inputs <= count_hash_inputs + 1;    
                   if (count_uv_blocks < 3) begin
                        state <= s_save_v;
                        count_uv_blocks <= count_uv_blocks + 1;
                   end
                   else begin
                        state <= s_load_v;
                        count_uv_blocks <= 0;
                   end
    
                end
                else begin
                    state <= s_load_dom_sep_v;
                end
                
               if (count_uv_blocks == 1) begin
                   u_v_out_addr_int <= u_v_out_addr_int + 1;
               end
               
               if (hash_in_addr > HASH_RAMDEPTH - 34 -1) begin
                            shake_support_vector <= HASH_LB_DOMSEP; 
                end
                else begin
                    shake_support_vector <= 32'h00000440;
                end
            end
            else begin
               state <= s_load_v;   
            end
        end
        
        else if (state == s_load_dom_sep_v) begin
           shake_dout_ready_h <= 0;
           u_v_out_en_int <= 1;
           hash_in_addr <= hash_in_addr+1;
           count_hash_inputs <= count_hash_inputs + 1;
           sel_uv <= 1;
           if (count_uv_blocks < 3) begin
                state <= s_save_v;
                count_uv_blocks <= count_uv_blocks + 1;
           end
           else begin
                state <= s_load_v;
                count_uv_blocks <= 0;
           end
        end
        
        else if (state == s_append_05) begin
            state <= s_comp_ss;
             
        end
        
        else if (state == s_comp_ss) begin
            state <= s_wait_ss;
            shake_dout_ready_h <= 1;
            hash_in_addr <= 0;
        end 
        
        else if (state == s_wait_ss) begin
            shake_dout_ready_h <= 1;
            if (hash_in_addr == 16) begin
                state <= s_done;
            end
            else begin
                if (shake_dout_valid_h) begin
                    hash_in_addr <= hash_in_addr + 1;
                end
            end
        end        
        
        else if (state == s_done) begin
            state <= s_wait_start;
            done <= 1'b1; 
        end
        
    end
 cap_uv_reg <= cap_uv;   
end
  
reg block_capture, last_block_capture;

always@(state, shake_dout_valid_h, done_encrypt, done_fixed_weight, count_hash_inputs, cap_uv_reg, count_uv_blocks, theta_addr)
begin

case(state)
    s_wait_start: begin
        hash_mem_wen <= 0;
        shake_in_type <= 0;
        start_hash <= 0; 
        theta_wen <= 0;
        start_encrypt <= 0;
        init_msg_in <= 0;      
        shift_msg_in <= 0;
        shake_force_done <= 0;
        d_wen <= 0;
        cap_uv <= 0;
        shift_uv <= 0;
        block_capture <= 0;      
        last_block_capture <= 0;      
    end
    
    s_load_m_out_size: begin
        hash_mem_wen <= 1;
        shake_in_type <= 0;
        start_hash <= 0;
        theta_wen <= 0;
        start_encrypt <= 0;
        init_msg_in <= 1;
        shift_msg_in <= 0;
        shake_force_done <= 0;
        d_wen <= 0;
        cap_uv <= 0;
        shift_uv <= 0; 
        block_capture <= 0;
    end
    
    s_load_m_in_size: begin
        hash_mem_wen <= 1;
        shake_in_type <= 0;
        start_hash <= 0;
        theta_wen <= 0;
        start_encrypt <= 0;
        init_msg_in <= 0;
        shift_msg_in <= 0; 
        shake_force_done <= 0;
        d_wen <= 0;
        cap_uv <= 0;
        shift_uv <= 0;
    end
    
    s_load_m: begin
        hash_mem_wen <= 1;
        shake_in_type <= 1;
        theta_wen <= 0;
        start_encrypt <= 0;
        init_msg_in <= 0;
        shift_msg_in <= 1; 
        shake_force_done <= 0;
        d_wen <= 0;
        cap_uv <= 0;
        shift_uv <= 0;
    end
    
    s_load_last_m: begin
        hash_mem_wen <= 1;
        shake_in_type <= 1;
        theta_wen <= 0;
        start_encrypt <= 0;
        init_msg_in <= 0;
        shift_msg_in <= 1; 
        shake_force_done <= 0;
        d_wen <= 0;
        cap_uv <= 0;
        shift_uv <= 0;
    end
    
    s_comp_theta: begin
        hash_mem_wen <= 1;
        shake_in_type <= 0;
        start_hash <= 1;
        theta_wen <= 0;
        start_encrypt <= 0;
        init_msg_in <= 0;
        shift_msg_in <= 0; 
        shake_force_done <= 0;
        d_wen <= 0;
        cap_uv <= 0;
        shift_uv <= 0;
    end
    
    s_save_theta: begin
        hash_mem_wen <= 0;
        start_hash <= 0;  
        start_encrypt <= 0; 
        init_msg_in <= 0;
        shift_msg_in <= 0;
        shake_force_done <= 0; 
        d_wen <= 0;
        cap_uv <= 0;
        shift_uv <= 0;
        if (shake_dout_valid_h) begin
            theta_wen <= 1;
        end
        else begin
            theta_wen <= 0;
        end
        if (theta_addr == 10) begin
            shake_force_done <= 1;
        end
    end
    
    s_stall_1: begin
        shake_force_done <= 0;
        theta_wen <= 0;
        hash_mem_wen <= 1;
    end
    
    s_encrypt: begin
        hash_mem_wen <= 1;
        start_hash <= 0;  
        start_encrypt <= 1;
        shake_force_done <= 0;
        d_wen <= 0;
        cap_uv <= 0;
        shift_uv <= 0;
    end
    
    s_wait_done_fw: begin
        hash_mem_wen <= 0;
        start_hash <= 0;  
        start_encrypt <= 0;
        init_msg_in <= 0;
        shift_msg_in <= 0; 
        d_wen <= 0;
        cap_uv <= 0;
        shift_uv <= 0;
        if (done_fixed_weight) begin
            shake_force_done <= 0; 
        end
        else begin
            shake_force_done <= 0;
        end
    end
    
    s_update_hram_d: begin
        hash_mem_wen <= 1;
        start_hash <= 0;  
        start_encrypt <= 0;
        init_msg_in <= 0;
        shift_msg_in <= 0;
        shake_force_done <= 1;
        d_wen <= 0; 
        cap_uv <= 0;
        shift_uv <= 0;    
    end
    
    s_comp_d: begin
        hash_mem_wen <= 0;
        start_hash <= 1;  
        start_encrypt <= 0;
        init_msg_in <= 0;
        shift_msg_in <= 0;
        shake_force_done <= 0;
        d_wen <= 0;
        cap_uv <= 0;
        shift_uv <= 0;     
    end
    
    s_save_d: begin
        hash_mem_wen <= 0;
        start_hash <= 0;  
        start_encrypt <= 0;
        init_msg_in <= 0;
        shift_msg_in <= 0;
        shake_force_done <= 0;
        cap_uv <= 0;
        shift_uv <= 0;
        if (shake_dout_valid_h) begin
            d_wen <= 1;
        end
        else begin
            d_wen <= 0;
        end     
    end
    
    s_save_last_d: begin
        
        start_hash <= 0;  
        start_encrypt <= 0;
        init_msg_in <= 0;
        shift_msg_in <= 0;
        
        cap_uv <= 0;
        shift_uv <= 0;
        if (shake_dout_valid_h) begin
            d_wen <= 1;
            hash_mem_wen <= 1;
            shake_force_done <= 0;
        end
        else begin
            d_wen <= 0;
            hash_mem_wen <= 0;
            shake_force_done <= 0;
        end
    end
    
    s_load_u: begin
        shake_force_done <= 0;
        if (count_hash_inputs < HASH_M_U_32/32 -1) begin
            hash_mem_wen <= 1;
            block_capture <= 0;
        end
        else begin
            hash_mem_wen <= 0;
            block_capture <= 0;
        end
        start_hash <= 0;  
        start_encrypt <= 0;
        init_msg_in <= 0;
        shift_msg_in <= 0;
        shake_force_done <= 0;
        d_wen <= 0;
        cap_uv <= 1;
        shift_uv <= 0;
        if (count_hash_inputs%34 == 0) begin
            shake_in_type <= 0;
        end
        else if (count_hash_inputs%34 != 0 && count_uv_blocks == 0) begin
            shake_in_type <= 3;
        end
        else begin 
            shake_in_type <= 2;
        end
    end
    
    s_save_u: begin
        if (count_hash_inputs < HASH_M_U_32/32-1) begin
            hash_mem_wen <= 1;
        end
        start_hash <= 0;  
        start_encrypt <= 0;
        init_msg_in <= 0;
        shift_msg_in <= 0;
        shake_force_done <= 0;
        d_wen <= 0;
        cap_uv <= 0;
        
        if (count_hash_inputs%34 != 0) begin
            shake_in_type <= 2;
            shift_uv <= 1;
        end
        else begin 
            shake_in_type <= 0;
            shift_uv <= 0;
        end
    end
    
    s_load_dom_sep:begin
        hash_mem_wen <= 1;
        start_hash <= 0;  
        start_encrypt <= 0;
        init_msg_in <= 0;
        shift_msg_in <= 0;
        shake_force_done <= 0;
        d_wen <= 0;
               
        if (cap_uv_reg) begin
            shake_in_type <= 3;
            cap_uv <= 1;
            shift_uv <= 0;
        end
        else begin   
            shake_in_type <= 2;
            shift_uv <= 1;
            cap_uv <= 0;
        end   
    end
    s_stall_0: begin
        hash_mem_wen <= 0;
        cap_uv <= 0;
        shift_uv <= 0;
        last_block_capture <= 1;
        block_capture <= 0;
        shake_force_done <= 1;
    end
    
    
     s_load_v: begin
        shake_force_done <= 0;
        if (count_hash_inputs < HASH_RAMBITS_32/32 - 1) begin
            hash_mem_wen <= 1;
        end
        else begin
            hash_mem_wen <= 0;
        end
        
        if (count_hash_inputs%34 == 0 && count_hash_inputs < HASH_RAMBITS_32/32 - 1) begin
            block_capture <= 0;
        end
        else if (count_hash_inputs >= HASH_RAMBITS_32/32 -1) begin
            block_capture <= 0;
        end
        else begin
            block_capture <= 1;
        end
        
        start_hash <= 0;  
        start_encrypt <= 0;
        init_msg_in <= 0;
        shift_msg_in <= 0;
        shake_force_done <= 0;
        d_wen <= 0;
        cap_uv <= 1;
        shift_uv <= 0;        
        last_block_capture <= 0;
        if (count_hash_inputs%34 == 0) begin
            shake_in_type <= 0;
        end
        else if (count_hash_inputs%34 != 0) begin
            shake_in_type <= 5;
        end
        else begin 
            shake_in_type <= 4;
        end
    end
    
    s_save_v: begin
        hash_mem_wen <= 1;
        start_hash <= 0;  
        start_encrypt <= 0;
        init_msg_in <= 0;
        shift_msg_in <= 0;
        shake_force_done <= 0;
        d_wen <= 0;
        cap_uv <= 0;
        
        if (count_hash_inputs%34 != 0) begin
            shake_in_type <= 4;
            shift_uv <= 1;
            block_capture <= 1;
        end
        else begin 
            shake_in_type <= 0;
            shift_uv <= 0;
            block_capture <= 0;
        end
    end
    
    s_load_dom_sep_v:begin
        hash_mem_wen <= 1;
        start_hash <= 0;  
        start_encrypt <= 0;
        init_msg_in <= 0;
        shift_msg_in <= 0;
        shake_force_done <= 0;
        d_wen <= 0;
        block_capture <= 1;       
        if (cap_uv_reg) begin
            shake_in_type <= 5;
            cap_uv <= 1;
            shift_uv <= 0;
        end
        else begin   
            shake_in_type <= 4;
            shift_uv <= 1;
            cap_uv <= 0;
        end   
    end
    
    s_append_05: begin
        hash_mem_wen <= 1;
        shake_in_type <= 6;
        start_encrypt <= 0;
        init_msg_in <= 0;
        shift_msg_in <= 0;
        shake_force_done <= 0;
        d_wen <= 0;
        start_hash <= 0;
    end   
    
    s_comp_ss: begin
        hash_mem_wen <= 0;
        start_hash <= 1;
        shake_in_type <= 7;
        start_encrypt <= 0;
        init_msg_in <= 0;
        shift_msg_in <= 0;
        shake_force_done <= 0;
        d_wen <= 0;
    end
    
    s_wait_ss: begin
        shake_in_type <= 7;
        start_hash <= 0;
        start_encrypt <= 0;
        init_msg_in <= 0;
        shift_msg_in <= 0;
        shake_force_done <= 0;
        d_wen <= 0;
        if (shake_dout_valid_h) begin
            hash_mem_wen <= 1;  
        end
        else begin
            hash_mem_wen <= 0;
        end
    end
    
    s_done: begin
        hash_mem_wen <= 0;
        start_hash <= 0;  
        start_encrypt <= 0;
        init_msg_in <= 0;
        shift_msg_in <= 0;
        shake_force_done <= 0;
        d_wen <= 0;
    end
   
   default: begin
        hash_mem_wen <= 0;
        start_hash <= 0;
        shake_in_type <= 0;
        theta_wen <= 0;
        init_msg_in <= 0;
        shift_msg_in <= 0; 
        shake_force_done <= 0;
        block_capture <= 0;
        last_block_capture <= 0;
        d_wen <= 0;
   end
    
endcase

end


reg [3:0] h_state = 0;
parameter h_wait_start  =   0;
parameter h_check_shake_ready =   1;
parameter h_first_block =   2;
parameter h_second_block =   3;
parameter h_load_shake =   4;
parameter h_stall =   5;

reg [3:0] count_shake_input;
reg [`CLOG2(HASH_RAMDEPTH)-1:0] total_shake_input_count  = HASH_RAMDEPTH;
reg done_hash_load;
reg start_hash;


always@(posedge clk)
begin

     if (rst) begin
        h_state <= h_wait_start;
        done_hash_load <= 1'b0;
        h_addr <= 0;
        hash_processing <= 1'b0;
    end
    else begin
        if (h_state == h_wait_start) begin
            h_addr <= 0;
            done_hash_load <= 1'b0;
            if (start_hash) begin
				h_state <= h_check_shake_ready;
				hash_processing <= 1'b1;				
			end
			else begin 
			    hash_processing <= 1'b0;
			end 
        end
        
        else if (h_state == h_check_shake_ready) begin
            hash_processing <= 1'b1;
            if (shake_din_ready_h) begin
                h_state <= h_first_block;
                h_addr <= h_addr + 1;
            end
        end
        
        else if (h_state == h_first_block) begin
           hash_processing <= 1'b1;
           h_addr <= h_addr + 1;
           h_state <= h_second_block;
           done_hash_load <= 1'b0;
	    end
	    
	    else if (h_state == h_second_block) begin
           hash_processing <= 1'b1;
           h_state <= h_load_shake;
           done_hash_load <= 1'b0;
	    end  
		
		else if (h_state == h_load_shake) begin
	       if (h_addr == total_shake_input_count) begin
	           h_addr <= 0;
	           h_state <= h_wait_start;
	           done_hash_load <= 1'b1;
	           hash_processing <= 1'b0;
	       end
	       else begin
	           done_hash_load <= 1'b0;
	           hash_processing <= 1'b1;     
	           if (shake_din_ready_h) begin
	             h_state <= h_stall; 
	           end
	           else begin
	           end
	       end
	    end
	    
	    else if (h_state == h_stall) begin
	       hash_processing <= 1'b1;
	       h_state <= h_load_shake;
	        h_addr <= h_addr+1;
	    end
			
    end 
end

always@(h_state, start_hash, shake_din_ready_h) 
begin
    case (h_state)
     h_wait_start: 
     begin
        shake_din_valid_h <= 1'b0;
        if (start_hash) begin
    
        end
        else begin

        end
     end
     
      h_first_block:
     begin
        if (shake_din_ready_h) begin
           shake_din_valid_h <= 1'b1;
       end
       else begin
           shake_din_valid_h <= 1'b0;
       end
     end
     
     h_second_block:
     begin
        if (shake_din_ready_h) begin
           shake_din_valid_h <= 1'b1;
       end
       else begin
           shake_din_valid_h <= 1'b0;
       end
     end
     
     h_load_shake:
     begin
        if (shake_din_ready_h) begin
           shake_din_valid_h <= 1'b0;
       end
       else begin
           shake_din_valid_h <= 1'b0;
       end
     end
   
    h_stall:
    begin
        if (shake_din_ready_h) begin
           shake_din_valid_h <= 1'b1;
       end
       else begin
           shake_din_valid_h <= 1'b0;
       end
    end
   
     
      
	  default: 
	  begin
	   shake_din_valid_h <= 1'b0;

	  end         
      
    endcase

end 

endmodule
