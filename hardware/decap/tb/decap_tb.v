/*
 *
 * Copyright (C) 2022
 * Authors: Sanjay Deshpande <sanjay.deshpande@yale.edu>
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

`timescale 1ns/1ps

module decap_tb
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
	parameter LOG_D_RAMDEPTH = `CLOG2(D_RAMDEPTH)											
);


parameter ssfilename =  (parameter_set == "hqc128") ? "ss_output_128.out":
                        (parameter_set == "hqc192") ? "ss_output_192.out":
                        (parameter_set == "hqc256") ? "ss_output_256.out":
                                                      "ss_output.out";
                                                                                                            
// input  

reg clk =0;
reg rst;
reg start;
reg [1:0] decap_in_type;
wire [RAMWIDTH-1:0] decap_in;
reg [LOG_RAMDEPTH-1:0] decap_in_addr, decap_in_addr_reg;
reg decap_in_wen;


 //shake signals
wire shake_din_valid;
wire shake_din_ready;
wire [31:0] shake_din;
wire shake_dout_ready;
wire [31:0] shake_dout_scram;
wire shake_force_done;
wire shake_dout_valid;

wire [RAMWIDTH-1:0] hs_0;
wire [RAMWIDTH-1:0] hs_1;	
wire [`CLOG2(X)-1:0] hs_addr_0;
wire [`CLOG2(X)-1:0] hs_addr_1;
wire  sel_hs;

wire [RAMWIDTH-1:0] h_0;
wire [RAMWIDTH-1:0] h_1;	
wire [`CLOG2(X)-1:0] h_addr_0;
wire [`CLOG2(X)-1:0] h_addr_1;

wire [RAMWIDTH-1:0] s_0;
wire [RAMWIDTH-1:0] s_1;	
wire [`CLOG2(X)-1:0] s_addr_0;
wire [`CLOG2(X)-1:0] s_addr_1;

wire [32-1:0] u_v_out_rearrange;

reg [1:0] sel_out = 0;
reg out_en = 0;
reg [LOG_RAMDEPTH-1:0]out_addr = 0;
wire [32-1:0] decap_out;

wire [M-1:0] y;
wire [LOG_WEIGHT-1:0] y_addr;

assign hs_0 = (sel_hs)? s_0: h_0;
assign hs_1 = (sel_hs)? s_1: h_1;

//assign decap_in = (decap_in_type == 2)? u_out:
//                  (decap_in_type == 3)? v_out:  
assign decap_in =  (decap_in_type == 1)? d_out:  
                    0;  
 
  decap 
  #(.parameter_set(parameter_set))
  DUT
  ( .clk(clk),
    .rst(rst),
    .start(start),
    
	.decap_in_type(decap_in_type),
    .decap_in(decap_in),
    .decap_in_addr(decap_in_addr_reg),
    .decap_in_wen(decap_in_wen),
    
    .done(done),
    
    .y(y),
    .y_addr(y_addr),
    
//    .sel_hs(sel_hs),
    .h_0(h_0),
    .h_1(h_1),
    .h_addr_0(h_addr_0),
    .h_addr_1(h_addr_1),
    
    .s_0(s_0),
    .s_1(s_1),
    .s_addr_0(s_addr_0),
    .s_addr_1(s_addr_1),
	
	.u_0(u_0),
    .u_1(u_1),
    .u_addr_0(u_addr_0),
    .u_addr_1(u_addr_1),
    
    .v_0(v_0),
    .v_1(v_1),
    .v_addr_0(v_addr_0),
    .v_addr_1(v_addr_1),

	
	.decap_out_en(out_en),
	.decap_out_addr(out_addr),
	.decap_out(decap_out),
		
	//shake signals
    .shake_din_valid(shake_din_valid),
    .shake_din_ready(shake_din_ready),
    .shake_din(shake_din),
    .shake_dout_ready(shake_dout_ready),
    .shake_dout_scram(shake_dout_scram),
    .shake_force_done(shake_force_done),
    .shake_dout_valid(shake_dout_valid)
	
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

always@(posedge clk)
begin
    decap_in_addr_reg <= decap_in_addr;
end
  
  integer start_time, end_time;
  integer decode_start_time, decode_end_time;
  integer m, outfile;
  integer i,j;
  initial
    begin
    rst <= 1;
    start <= 0;
    decap_in_wen <= 0;
    decap_in_type <= 2;
    out_en<= 0;
    sel_out <= 0;
    #100
    rst <= 0;
    #20 // loading u
    decap_in_addr <= 0;
    for(j=0; j < RAMDEPTH; j=j+1) begin
        decap_in_wen <= 1;
        #10
        decap_in_addr <= decap_in_addr +1;
    end
    #10 decap_in_wen <= 0;
    
    #20 // loading v
    decap_in_addr <= 0;
    decap_in_type <= 3;
    for(j=0; j < RAMDEPTH-1; j=j+1) begin
        decap_in_wen <= 1;
        #10
        decap_in_addr <= decap_in_addr +1;
    end
    #10 decap_in_wen <= 0;
    
    #20 // loading v
    decap_in_addr <= 0;
    decap_in_type <= 1;
    for(j=0; j < 16; j=j+1) begin
        decap_in_wen <= 1;
        #10
        decap_in_addr <= decap_in_addr +1;
    end
    #10 decap_in_wen <= 0;
    
    start_time = $time;
    start <= 1; 

       
    #10

    start<=0;
    
    @(posedge DUT.DECRYPT.done_u_minus_vy) 
    decode_start_time = $time;
    
    @(posedge DUT.DECRYPT.done) 
    decode_end_time = $time;
    $display("Decode Clock Cycles:", (decode_end_time - decode_start_time)/10);

    @(posedge DUT.done)       
    end_time = $time -5;
    $display("Total Clock Cycles:", (end_time - start_time)/10);
	    #100
	

      #40
      outfile = $fopen(ssfilename,"w");
      out_en <= 1;
      for (i = 0; i <16; i = i+1) begin
        out_addr <= i;
        #20
            $fwrite(outfile,"%h",u_v_out_rearrange);
      end
      $fclose(outfile);

    # 100;
    $finish;
    
    end

  genvar k;
  generate
    for (k = 0; k < 32/8; k=k+1) begin:vector_gen_rearrange
        assign u_v_out_rearrange[8*(k+1)-1:8*k] =  decap_out[32-8*(k)-1:32-8*(k+1)];
    end
  endgenerate
  
always 
    #5 clk <= ~clk;

wire [RAMWIDTH-1:0] h_0;
wire [RAMWIDTH-1:0] h_1;

parameter H_FILE = (parameter_set == "hqc128")? "h_128.in":
                   (parameter_set == "hqc192")? "h_192.in":
                   (parameter_set == "hqc256")? "h_256.in":
                                                "h_128.in";
                                                
parameter S_FILE = (parameter_set == "hqc128")? "s_128.in":
                   (parameter_set == "hqc192")? "s_192.in":
                   (parameter_set == "hqc256")? "s_256.in":
                                                "s_128.in";

   mem_dual #(.WIDTH(RAMWIDTH), .DEPTH(N_MEM/MEM_WIDTH), .FILE(H_FILE)) h_mem (
    .clock(clk),
    .data_0(0),
    .data_1(0),
    .address_0(h_addr_0),
    .address_1(h_addr_1),
    .wren_0(0),
    .wren_1(0),
    .q_0(h_0),
    .q_1(h_1)
  );
  
wire [RAMWIDTH-1:0] s_0;
wire [RAMWIDTH-1:0] s_1;  
   mem_dual #(.WIDTH(RAMWIDTH), .DEPTH(N_MEM/MEM_WIDTH), .FILE(S_FILE)) s_mem (
    .clock(clk),
    .data_0(0),
    .data_1(0),
    .address_0(s_addr_0),
    .address_1(s_addr_1),
    .wren_0(0),
    .wren_1(0),
    .q_0(s_0),
    .q_1(s_1)
  );
  
parameter U_FILE = (parameter_set == "hqc128")? "u_128.in":
                   (parameter_set == "hqc192")? "u_192.in":
                   (parameter_set == "hqc256")? "u_256.in":
                                                "u_128.in";
                                                
parameter V_FILE = (parameter_set == "hqc128")? "v_128.in":
                   (parameter_set == "hqc192")? "v_192.in":
                   (parameter_set == "hqc256")? "v_256.in":
                                                "v_128.in";
  
parameter D_FILE = (parameter_set == "hqc128")? "d_128.in":
                   (parameter_set == "hqc192")? "d_192.in":
                   (parameter_set == "hqc256")? "d_256.in":
                                                "d_128.in";
                                                
wire [RAMWIDTH-1:0] u_1,u_0;
wire [LOG_RAMDEPTH-1:0] u_addr_0, u_addr_1;
wire [RAMWIDTH-1:0] v_1,v_0;
wire [LOG_RAMDEPTH-1:0] v_addr_0, v_addr_1;
  


  mem_dual #(.WIDTH(RAMWIDTH), .DEPTH(RAMDEPTH), .FILE(U_FILE)) U_MEM (
    .clock(clk),
    .data_0(0),
    .data_1(0),
    .address_0(u_addr_0),
    .address_1(u_addr_1),
    .wren_0(0),
    .wren_1(0),
    .q_0(u_0),
    .q_1(u_1)
  );
  
   mem_dual #(.WIDTH(RAMWIDTH), .DEPTH(RAMDEPTH), .FILE(V_FILE)) V_MEM (
    .clock(clk),
    .data_0(0),
    .data_1(0),
    .address_0(v_addr_0),
    .address_1(v_addr_1),
    .wren_0(0),
    .wren_1(0),
    .q_0(v_0),
    .q_1(v_1)
  );


  
wire [32-1:0] d_out;
                                                
  mem_single #(.WIDTH(32), .DEPTH(16), .FILE(D_FILE)) D_MEM
  (
         .clock(clk),
         .data(0),
         .address(decap_in_addr[3:0]),
         .wr_en(0),
         .q(d_out)
  ); 
  
 parameter Y_FILE = (parameter_set == "hqc128")? "y_128.in":
                   (parameter_set == "hqc192")? "y_192.in":
                   (parameter_set == "hqc256")? "y_256.in":
                                                "y_128.in";
                                                 
     mem_single #(.WIDTH(M), .DEPTH(WEIGHT), .FILE(Y_FILE)) Y_MEM
  (
         .clock(clk),
         .data(0),
         .address(y_addr),
         .wr_en(0),
         .q(y)
  );
  
       
endmodule
  
  
  
  
  
  