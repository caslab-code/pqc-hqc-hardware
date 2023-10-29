/*
 * This file is the testbench for the XOR based Adder.
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
`include "clog2.v"

module xor_based_adder_tb  #(
    parameter parameter_set = "hqc128",
    
    
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
                                                                                  
                           
    // memory related constants
	parameter MEM_WIDTH = 128,	
	parameter N_MEM = N + (MEM_WIDTH - N%MEM_WIDTH)%MEM_WIDTH, // Memory width adjustment for N
	    
    parameter DEPTH = N_MEM/MEM_WIDTH,
    parameter LOG_DEPTH = `CLOG2(DEPTH),    
    parameter LOG_WEIGHT   = `CLOG2(WEIGHT)                                       
                                      
  );


// input  
reg clk = 1'b0;
reg rst = 1'b0;
wire [MEM_WIDTH-1:0] in_1;
wire [MEM_WIDTH-1:0] in_2;
reg start = 1'b0;

// output
wire done;


wire [LOG_DEPTH-1:0] in_addr;
wire in_rd_en;



wire [(MEM_WIDTH-1):0] add_out;
wire [LOG_DEPTH-1:0] add_out_addr;
wire add_out_valid;
 
  xor_based_adder #(.parameter_set(parameter_set), .WIDTH(MEM_WIDTH))
  DUT
   (
    .clk(clk),
    .rst(rst),
    
    .start(start),
    
    .in_1(in_1),
    .in_2(in_2),
    .in_addr(in_addr),
    .in_rd_en(in_rd_en),
    
    .add_out(add_out),
    .add_out_addr(add_out_addr),
    .add_out_valid(add_out_valid),
    .done(done)
    
    );

  
  integer start_time, end_time;
  
  initial
    begin
    rst <= 1'b1;
    # 20;
    rst <= 1'b0;
    #100
    start_time = $time;
    
    start = 1'b1;
    #10
    
    start = 1'b0;

    
    
    @(posedge done);
    end_time = $time -5;
    $display("Total Clock Cycles:", (end_time - start_time)/10);
      # 10;
      $finish;
    
    end
  
   parameter FILE_VECT_SET_RANDOM = (parameter_set == "hqc128") ? "h_128.in" :
                                    (parameter_set == "hqc192") ? "vect_set_random_192.out" :
                                    (parameter_set == "hqc256") ? "vect_set_random_256.out" :
                                                                  "vect_set_random_128.out";
 
     mem_dual #(.WIDTH(MEM_WIDTH), .DEPTH(N_MEM/MEM_WIDTH), .FILE(FILE_VECT_SET_RANDOM)) rand_mem (
    .clock(clk),
    .data_0(0),
    .data_1(add_out),
    .address_0(in_addr),
    .address_1(add_out_addr),
    .wren_0(0),
    .wren_1(add_out_valid),
    .q_0(in_1),
    .q_1()
  );   

 

 
  mem_single #(.WIDTH(MEM_WIDTH), .DEPTH(N_MEM/MEM_WIDTH), .FILE("h_128_mod.in") ) rand_mem_2
 (
        .clock(clk),
        .data(0),
        .address(in_addr),
        .wr_en(0),
        .q(in_2)
 );  
  
always 
  # 5 clk = !clk;
  
  
endmodule

  
  
  