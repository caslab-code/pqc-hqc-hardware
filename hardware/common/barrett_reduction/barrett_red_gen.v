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

`include "clog2.v"

module barrett_red_gen
    #(

    parameter parameter_set = "hqc256",
    
    
    parameter N = (parameter_set == "hqc128")? 17_669:
				  (parameter_set == "hqc192")? 35_851:
			      (parameter_set == "hqc256")? 57_637: 
                                               17_669,
    
    
    parameter k_WIDTH = (parameter_set == "hqc128")? 18:
					   (parameter_set == "hqc192")? 17:
					   (parameter_set == "hqc256")? 17:
                                                    18
    
    
    )
    (
    input  clk,
    input  start,
    input  [31:0] a_in,
    input  [`CLOG2(N)-1:0] n_in,
    input  [k_WIDTH - 1: 0] k_in,
    output [`CLOG2(N)-1:0] red_out,
    output done
    );
    


//reg [16+k_WIDTH-1:0]  t0;
//reg [16+k_WIDTH-1:0]  t1;
wire [32+k_WIDTH-1:0]  t;
wire [k_WIDTH-1:0] t_shift_32;
wire [`CLOG2(N)+k_WIDTH-1:0] t_mul_n_in;
//wire [`CLOG2(N):0] c;
//wire [`CLOG2(N):0] c_plus_n_in;

reg [`CLOG2(N):0] c;
reg [`CLOG2(N):0] c_reg;
reg [`CLOG2(N):0] c_plus_n_in;

wire [63:0]  ak;
wire [31:0]  a_in_reg;
wire [`CLOG2(N)-1:0]  n_in_reg;
reg [`CLOG2(N)-1:0]  n_in_reg_reg;
wire [63:0]  tn;

reg [31:0]  a_in_reg_0;
reg [31:0]  a_in_reg_1;
reg [31:0]  a_in_reg_2;
reg [31:0]  a_in_reg_3;

reg [31:0]  n_in_reg_0;
reg [31:0]  n_in_reg_1;
reg [31:0]  n_in_reg_2;
reg [31:0]  n_in_reg_3;

wire done_0;
wire done_1;
reg done_2;
reg done_3;




always@(posedge clk) 
begin
    n_in_reg_0 <= n_in;
    n_in_reg_1 <= n_in_reg_0;
    n_in_reg_2 <= n_in_reg_1;
    n_in_reg_3 <= n_in_reg_2;
end

karatsuba_small #(.A_WIDTH(32), .B_WIDTH(32))
KM_1(
    .clk(clk),
    .start(start),
    .done(done_0),
    .a_in(a_in),
    .b_in({0,k_in}),
    .ab_out(ak),
    .a_in_reg_out(a_in_reg) 
);

assign t = ak[32+k_WIDTH-1:0];

assign t_shift_32 = t[32+k_WIDTH-1:32];


karatsuba_small #(.A_WIDTH(32), .B_WIDTH(32))
KM_2(
    .clk(clk),
    .start(done_0),
    .done(done_1),
    .a_in({0,n_in_reg_3}),
    .b_in({0,t_shift_32}),
    .ab_out(tn),
    .a_in_reg_out(n_in_reg) 
);

always@(posedge clk) 
begin
    a_in_reg_0 <= a_in_reg;
    a_in_reg_1 <= a_in_reg_0;
    a_in_reg_2 <= a_in_reg_1;
    a_in_reg_3 <= a_in_reg_2;
    n_in_reg_reg <= n_in_reg;
end

assign t_mul_n_in = tn[`CLOG2(N)+k_WIDTH-1:0];


always@(posedge clk) 
begin
    c <= a_in_reg_3 - t_mul_n_in;
    c_reg <= c;
    c_plus_n_in <= c + n_in_reg_reg;
    done_2 <= done_1;
    done_3 <= done_2;
end


assign red_out = (c_reg[`CLOG2(N)])? c_plus_n_in : c_reg;
assign done = done_3;
  
endmodule

//karatsuba
//wire [63:0] ab;
//wire [15:0] a0, a1;
//wire [15:0] b0, b1;

//reg [15:0] a0_reg, a1_reg;
//reg [15:0] b0_reg, b1_reg;

//reg [31:0] a0b0, a1b1;
//reg [17:0] add_a0a1, add_b0b1;
//reg [31:0] a0b0_reg, a1b1_reg;
//reg [31:0] a0b0_reg_reg, a1b1_reg_reg;

//reg [32:0] add_a0b0_a1b1;
//reg [33:0] mul_a0a1_b0b1;

//reg [33:0] sub_mul_ab_add_ab;

//assign a0 = a_in[15:0];
//assign a1 = a_in[31:16];
//assign b0 = k_in[15:0];
//assign b1 = k_in[k_WIDTH-1:16];


//always@(posedge clk)
//begin
//    a0_reg = a0;
//    a1_reg = a1;
//    b0_reg = b0;
//    b1_reg = b1;
//    a0b0 <= a0*b0;
//    a1b1 <= a1*b1;
//    add_a0a1 <= a0 + a1;
//    add_b0b1 <= b0 + b1;
//end


//always@(posedge clk)
//begin
//    a0b0_reg <= a0b0;
//    a1b1_reg <= a1b1;
//    add_a0b0_a1b1 <= a0b0 + a1b1;
//    mul_a0a1_b0b1 <= add_a0a1 * add_b0b1;
//end

//always@(posedge clk)
//begin
//    a0b0_reg_reg <= a0b0_reg;
//    a1b1_reg_reg <= a1b1_reg;
//    sub_mul_ab_add_ab <= mul_a0a1_b0b1 - add_a0b0_a1b1;
//end
//assign ab = a0b0_reg_reg + {sub_mul_ab_add_ab, 16'h0000} + {a1b1_reg_reg, 32'h00000000};

//assign t = a_in * k_in;

//assign t_shift_32 = t[32+k_WIDTH-1:32];

//assign t_mul_n_in = t_shift_32 * n_in;

//assign c = a_in - t_mul_n_in;

//assign c_plus_n_in = c + n_in;

//assign red_out = (c[`CLOG2(N)])? c_plus_n_in : c;