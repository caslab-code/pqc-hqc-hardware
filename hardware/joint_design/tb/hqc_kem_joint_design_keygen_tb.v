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

module hqc_kem_joint_design_keygen_tb
  #(
    parameter parameter_set = "hqc256",
    
    
    parameter N = (parameter_set == "hqc128")? 17_669:
				  (parameter_set == "hqc192")? 35_851:
			      (parameter_set == "hqc256")? 57_637: 
                                               17_669,
                                           
    parameter M = (parameter_set == "hqc128")? 15:
				  (parameter_set == "hqc192")? 16:
			      (parameter_set == "hqc256")? 16: 
                                               15, 
                                                                                       
    parameter WEIGHT = (parameter_set == "hqc128")? 66:
					   (parameter_set == "hqc192")? 100:
					   (parameter_set == "hqc256")? 131:
                                                    66,
    parameter LOG_WEIGHT = `CLOG2(WEIGHT),
    // common parameters
    parameter SEED_SIZE = 320,
    
    // memory related constants
	parameter MEM_WIDTH = 128,	
	parameter N_MEM = N + (MEM_WIDTH - N%MEM_WIDTH)%MEM_WIDTH, // Memory width adjustment for N
	parameter N_B = N + (8-N%8)%8, // Byte adjustment on N
	parameter N_Bd = N_B - N, // difference between N and byte adjusted N
	parameter N_MEMd = N_MEM - N_B, // difference between byte adjust and Memory adjusted N                                       
    
    parameter OUT_ADDR_WIDTH = (MEM_WIDTH <= 256)? `CLOG2(N_MEM/MEM_WIDTH) : LOG_WEIGHT,
    
    parameter CT_DESIGN = 2'b01                                  
  );

//output filenames
parameter sfilename =   (parameter_set == "hqc128") ? "S_output_128.out":
                        (parameter_set == "hqc192") ? "S_output_192.out":
                        (parameter_set == "hqc256") ? "S_output_256.out":
                                                      "S_output.out";
                                                       
parameter xfilename =   (parameter_set == "hqc128") ? "X_output_128.out":
                        (parameter_set == "hqc192") ? "X_output_192.out":
                        (parameter_set == "hqc256") ? "X_output_256.out":
                                                      "X_output.out";
                                                       
parameter yfilename =   (parameter_set == "hqc128") ? "Y_output_128.out":
                        (parameter_set == "hqc192") ? "Y_output_192.out":
                        (parameter_set == "hqc256") ? "Y_output_256.out":
                                                      "Y_output.out";                                                     

parameter randfilename =    (parameter_set == "hqc128") ? "vect_set_rand_output_128.out":
                            (parameter_set == "hqc192") ? "vect_set_rand_output_192.out":
                            (parameter_set == "hqc256") ? "vect_set_rand_output_256.out":
                                                          "vect_set_rand_output.out";

// input  
reg clk = 1'b0;
reg rst = 1'b0;

reg pk_seed_wen = 1'b0;
reg [3:0] pk_seed_addr = 4'b0;
reg [31:0] pk_seed = 32'b0;

reg sk_seed_wen = 1'b0;
reg [3:0] sk_seed_addr = 4'b0;
reg [31:0] sk_seed = 32'b0;

reg start = 1'b0;

// output
wire done;



//ram controls
reg [3:0] addr;
wire [31:0] seed_from_ram;


reg rand_out_rd = 0;	
reg [`CLOG2(N_MEM/MEM_WIDTH) - 1:0]rand_out_addr_0 = 0;
wire [MEM_WIDTH-1:0] rand_out_0;
reg [`CLOG2(N_MEM/MEM_WIDTH) - 1:0]rand_out_addr_1 = 0;
wire [MEM_WIDTH-1:0] rand_out_1;	

reg [1:0] out_type;	
reg out_rd;	
reg [OUT_ADDR_WIDTH - 1:0]out_addr;	
wire [MEM_WIDTH-1:0] out;
wire [MEM_WIDTH-1:0] out_rearrange;
wire [N_MEM%MEM_WIDTH-1:0] out_rearrange_trimmed;
 
  hqc_kem_joint_design #(.parameter_set(parameter_set), .N(N), .MEM_WIDTH(MEM_WIDTH), .CT_DESIGN(CT_DESIGN), .FILE_PKSEED("pk_seed.in"), .FILE_SKSEED("sk_seed.in") )
  DUT  (
    .clk(clk),
    .rst(rst),
    .operation(0),
    
    .sk_seed_wen(sk_seed_wen),
	.sk_seed_addr(sk_seed_addr),
	.sk_seed(sk_seed),
    
	.pk_seed_wen(pk_seed_wen),
	.pk_seed_addr(pk_seed_addr),
	.pk_seed(pk_seed),
	
	.start(start),
    .done(done),
    
    .keygen_out_en(out_rd),
    .keygen_out_addr(out_addr),
    .keygen_out(out),
    .keygen_out_type(out_type),
    
    	//Encap ports
	.m_addr(m_addr_reg),
    .m_wen(m_wen),
    .m_in(m_in),
    
    
    .u_0(u_0),
    .u_1(u_1),
    .u_addr_0(u_addr_0),
    .u_addr_1(u_addr_1),
    
    .v_0(v_0),
    .v_1(v_1),
    .v_addr_0(v_addr_0),
    .v_addr_1(v_addr_1),
        
    .h_0(h_0),
    .h_1(h_1),
    .h_addr_0(h_addr_0),
    .h_addr_1(h_addr_1),
    
    .s_0(s_0),
    .s_1(s_1),
    .s_addr_0(s_addr_0),
    .s_addr_1(s_addr_1),
	
	
	.encap_out_type(0),
	.encap_out_en(0),
	.encap_out_addr(0),
//	.encap_dout(0),

    //decap ports
	.decap_in_type(0),
    .decap_in(0),
    .decap_in_addr(0),
    .decap_in_wen(0),
        
    .y(0),
//    .y_addr(y_addr),
    
	
	
	.decap_out_en(0),
	.decap_out_addr(0)
//	.decap_out(decap_out)
    
  );
  


  integer start_time, end_time;
  integer vec_start_time, vec_end_time;
  //file descriptors
  integer outfile; 
  integer i,j;
  
  
  
  initial
    begin
    outfile = $fopen(sfilename,"w");
	start <= 1'b0;
    rst <= 1'b1;
    addr <= 0;
    out_rd <= 0;
    out_type <= 2'b00;
    # 20;
    rst <= 1'b0;
    #100
    start_time = $time;
    start <= 1'b1;
	
	#10
	
	start <= 1'b0;
      
      #10
      
      
       @(posedge DUT.KEYGEN_MODULE.VECTSETRAND.start);
       vec_start_time = $time;
       @(posedge DUT.KEYGEN_MODULE.VECTSETRAND.done);
      vec_end_time = $time -5;
      $display("Vector Set Random Clock Cycles:", (vec_end_time - vec_start_time)/10);
      
      
      @(posedge DUT.done);
      end_time = $time -5;
      $display("Total Clock Cycles:", (end_time - start_time)/10);
      
      #40
      out_type <= 2'b11;
      out_rd <= 1;
      for (i = 0; i <N_MEM/MEM_WIDTH; i = i+1) begin
        out_addr <= i;
        #20
        if (i== (N_MEM/MEM_WIDTH) -1) begin
            $fwrite(outfile,"%h",out_rearrange[MEM_WIDTH-1:N_MEMd]);  //write as hexadecimal
        end
        else begin
            $fwrite(outfile,"%h",out_rearrange);
        end
      end
      $fclose(outfile);
      
      #40
      
      outfile = $fopen(randfilename,"w");
      out_type <= 2'b10;
      out_rd <= 1;
      for (i = 0; i <N_MEM/MEM_WIDTH; i = i+1) begin
        out_addr <= i;
        #20
        if (i== (N_MEM/MEM_WIDTH) -1) begin
            $fwrite(outfile,"%h",out_rearrange[MEM_WIDTH-1:N_MEMd]);  //write as hexadecimal
        end
        else begin
            $fwrite(outfile,"%h",out_rearrange);
        end
      end
      $fclose(outfile);
      
      #40
      
      outfile = $fopen(xfilename,"w");
      out_type <= 2'b00;
      out_rd <= 1;
      for (i = 0; i < WEIGHT; i = i+1) begin
        out_addr <= i;
        #20
            $fdisplay(outfile,"%h",out[M-1:0]);  //write as hexadecimal
      end
      $fclose(outfile);
      
      
      #40
      
      outfile = $fopen(yfilename,"w");
      out_type <= 2'b01;
      out_rd <= 1;
      for (i = 0; i < WEIGHT; i = i+1) begin
        out_addr <= i;
        #20
            $fdisplay(outfile,"%h",out[M-1:0]);  //write as hexadecimal
      end
      $fclose(outfile);
      
      # 10000;
      $finish;
    end
  
  genvar k;
  generate
    for (k = 0; k < MEM_WIDTH/8; k=k+1) begin:vector_gen_rearrange
        assign out_rearrange[8*(k+1)-1:8*k] =  out[MEM_WIDTH-8*(k)-1:MEM_WIDTH-8*(k+1)];
    end
  endgenerate
  
   
   

         
  
always 
  # 5 clk = !clk;



  
 

endmodule

  
  
  
  
  
  
  