/*
 *
 * Copyright (C) 2023
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

module hqc_joint_design_encap_tb
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
	
	
	parameter N1 = 8*N1_BYTES,
	parameter K = 8*K_BYTES,
	
	parameter LOG_WEIGHT_ENC = `CLOG2(WEIGHT_ENC),
	parameter LOG_N1_BYTES = `CLOG2(N1_BYTES),
	
	parameter N = (parameter_set == "hqc128")? 17_669:
				  (parameter_set == "hqc192")? 35_851:
			      (parameter_set == "hqc256")? 57_637: 
                                               17_669,
                                               
	parameter M = (parameter_set == "hqc128")? 15:
				  (parameter_set == "hqc192")? 16:
			      (parameter_set == "hqc256")? 16: 
                                               15,
                                               
		//Poly_mult
	parameter RAMWIDTH = 128,
    parameter TWO_N = 2*N,
    parameter W_RAMWIDTH = TWO_N + (RAMWIDTH-TWO_N%RAMWIDTH)%RAMWIDTH, 
    parameter W = W_RAMWIDTH + RAMWIDTH*((W_RAMWIDTH/RAMWIDTH)%2),
    parameter X = W/RAMWIDTH,
    
    parameter MEM_WIDTH = RAMWIDTH,	
	parameter N_MEM = N + (MEM_WIDTH - N%MEM_WIDTH)%MEM_WIDTH, // Memory width adjustment for N 
	parameter N_B = N + (8-N%8)%8, // Byte adjustment on N
	parameter N_Bd = N_B - N, // difference between N and byte adjusted N
	parameter N_MEMd = N_MEM - N_B, // difference between byte adjust and Memory adjusted N
	
	parameter RAMDEPTH = (N+(RAMWIDTH-N%RAMWIDTH)%RAMWIDTH)/RAMWIDTH, //u RAM depth
	parameter LOG_RAMDEPTH = `CLOG2(RAMDEPTH),
	
	parameter CT_DESIGN = 2'b01,
	parameter PARALLEL_ENCRYPT = 1
										
);

parameter ufilename =   (parameter_set == "hqc128") ? "u_output_128.out":
                        (parameter_set == "hqc192") ? "u_output_192.out":
                        (parameter_set == "hqc256") ? "u_output_256.out":
                                                      "u_output.out";
                                                        
parameter vfilename =   (parameter_set == "hqc128") ? "v_output_128.out":
                        (parameter_set == "hqc192") ? "v_output_192.out":
                        (parameter_set == "hqc256") ? "v_output_256.out":
                                                      "v_output.out";
                                                        
parameter dfilename =   (parameter_set == "hqc128") ? "d_output_128.out":
                        (parameter_set == "hqc192") ? "d_output_192.out":
                        (parameter_set == "hqc256") ? "d_output_256.out":
                                                      "d_output.out";
                                                        
parameter ssfilename =  (parameter_set == "hqc128") ? "ss_output_128.out":
                        (parameter_set == "hqc192") ? "ss_output_192.out":
                        (parameter_set == "hqc256") ? "ss_output_256.out":
                                                      "ss_output.out";
                                                                                                            
// input  

reg clk =0;
reg rst;
reg start;
wire [31:0] m_in;
reg [`CLOG2((K+(32-K%32)%32)/32) - 1:0] m_addr, m_addr_reg;
wire  done;
reg  m_wen = 0;
reg  [LOG_WEIGHT_ENC-1:0] theta_addr=0;


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

wire [RAMWIDTH-1:0] h_0;
wire [RAMWIDTH-1:0] h_1;	
wire [`CLOG2(X)-1:0] h_addr_0;
wire [`CLOG2(X)-1:0] h_addr_1;

wire [RAMWIDTH-1:0] s_0;
wire [RAMWIDTH-1:0] s_1;	
wire [`CLOG2(X)-1:0] s_addr_0;
wire [`CLOG2(X)-1:0] s_addr_1;
wire  sel_hs;

reg sel_uv =0;
reg u_v_out_en = 0;
reg [`CLOG2(RAMDEPTH)-1:0] u_v_out_addr;
wire [RAMWIDTH-1:0] u_v_out;
wire [RAMWIDTH-1:0] u_v_out_rearrange;

reg [1:0] sel_out = 0;
reg out_en = 0;
reg [LOG_RAMDEPTH-1:0]out_addr = 0;
wire [127:0] encap_dout;

assign hs_0 = (sel_hs)? s_0: h_0;
assign hs_1 = (sel_hs)? s_1: h_1;
 
  hqc_kem_joint_design #(.parameter_set(parameter_set), .CT_DESIGN(CT_DESIGN), .PARALLEL_ENCRYPT(PARALLEL_ENCRYPT), .FILE_THETA("shake_test.in"))
  DUT  
  (
    .clk(clk),
    .rst(rst),
    .operation(1),
    .start(start),
    .done(done),
    
    //keygen ports
    .sk_seed_wen(0),
	.sk_seed_addr(0),
	.sk_seed(0),
	.pk_seed_wen(0),
	.pk_seed_addr(0),
	.pk_seed(0),
    .keygen_out_en(0),
    .keygen_out_addr(out_addr),
    .keygen_out(out),
    .keygen_out_type(0),
	
	//Encap ports
	.m_addr(m_addr_reg),
    .m_wen(m_wen),
    .m_in(m_in),
    
        
    .h_0(h_0),
    .h_1(h_1),
    .h_addr_0(h_addr_0),
    .h_addr_1(h_addr_1),
    
    .s_0(s_0),
    .s_1(s_1),
    .s_addr_0(s_addr_0),
    .s_addr_1(s_addr_1),
	
	
	.encap_out_type(sel_out),
	.encap_out_en(out_en),
	.encap_out_addr(out_addr),
	.encap_out(encap_dout)
    
  );
  


always@(posedge clk) begin
    m_addr_reg <= m_addr;
end
  
  
  integer start_time, end_time;
  integer encrypt_start_time, encrypt_end_time;
  integer m, outfile;
  integer i,j;
  initial
    begin
    rst <= 1;
    start <= 0;
    u_v_out_addr <= 0;
    out_en<= 0;
    sel_out <= 0;
    #100
    rst <= 0;
    #20
    m_addr <= 0;
    for(j=0; j<K/32; j=j+1) begin
        m_wen <= 1;
        #10
        m_addr <= m_addr +1;
    end
    #10 m_wen <= 0;
    start_time = $time;
    start <= 1; 

       
    #10

    start<=0;
    
    @(posedge DUT.ENCAP_MODULE.start_encrypt);
    encrypt_start_time = $time;


    @(posedge DUT.ENCAP_MODULE.done_encrypt);
    encrypt_end_time = $time-5;
    $display("Total Encrypt Clock Cycles:", (encrypt_end_time - encrypt_start_time)/10);
    
//    $finish;
    
//    @(posedge DUT.ENCRYPT.done_fw)
//    $finish;
    
    @(posedge done)       
    end_time = $time -5;
    $display("Total Clock Cycles:", (end_time - start_time)/10);
	    #100
	
	  outfile = $fopen(ufilename,"w");
      sel_out <= 2;
      out_en <= 1;
      for (i = 0; i <N_MEM/MEM_WIDTH; i = i+1) begin
        out_addr <= i;
        #20
        if (i== (N_MEM/MEM_WIDTH) -1) begin
            $fwrite(outfile,"%h",u_v_out_rearrange[MEM_WIDTH-1:N_MEMd]);  //write as hexadecimal
        end
        else begin
            $fwrite(outfile,"%h",u_v_out_rearrange);
        end
      end
      $fclose(outfile);
      
      #40
      outfile = $fopen(vfilename,"w");
      sel_out <= 3;
      out_en <= 1;
      for (i = 0; i <N_MEM/MEM_WIDTH - 1; i = i+1) begin
        out_addr <= i;
        #20
        if (i== (N_MEM/MEM_WIDTH) -1) begin
            $fwrite(outfile,"%h",u_v_out_rearrange[MEM_WIDTH-1:N_MEMd]);  //write as hexadecimal
        end
        else begin
            $fwrite(outfile,"%h",u_v_out_rearrange);
        end
      end
      $fclose(outfile);
      
      #40
      outfile = $fopen(dfilename,"w");
      sel_out <= 1;
      out_en <= 1;
      for (i = 0; i <16; i = i+1) begin
        out_addr <= i;
        #20
            $fwrite(outfile,"%h",u_v_out_rearrange[128-1:128-32]);
      end
      $fclose(outfile);

      #40
      outfile = $fopen(ssfilename,"w");
      sel_out <= 0;
      out_en <= 1;
      for (i = 0; i <16; i = i+1) begin
        out_addr <= i;
        #20
            $fwrite(outfile,"%h",u_v_out_rearrange[128-1:128-32]);
      end
      $fclose(outfile);

    # 100;
    $finish;
    
    end

  genvar k;
  generate
    for (k = 0; k < MEM_WIDTH/8; k=k+1) begin:vector_gen_rearrange
        assign u_v_out_rearrange[8*(k+1)-1:8*k] =  encap_dout[MEM_WIDTH-8*(k)-1:MEM_WIDTH-8*(k+1)];
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
 
 
 parameter FILE_MSG = (parameter_set == "hqc128")? "msg_128.in":
                      (parameter_set == "hqc192")? "msg_192.in":
                      (parameter_set == "hqc256")? "msg_256.in":
                                                   "msg_128.in";
                                                
  mem_single #(.WIDTH(32), .DEPTH((K+(32-K%32)%32)/32), .FILE(FILE_MSG)) MSG_MEM
  (
         .clock(clk),
         .data(0),
         .address(m_addr),
         .wr_en(0),
         .q(m_in)
  );

   
  
       
endmodule
  
  
  
  
  
  
  