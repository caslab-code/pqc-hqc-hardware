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

//`include "clog2.v"

module karatsuba_small
# (
    A_WIDTH = 32,
    B_WIDTH = 32,
    MAX_AB = (A_WIDTH > B_WIDTH)? A_WIDTH : B_WIDTH
    )
    (
    input  clk,
    input  start,
    output reg done,
    
    input  [A_WIDTH-1:0] a_in,
    input  [B_WIDTH-1:0] b_in,

    output reg [A_WIDTH+B_WIDTH-1:0] ab_out,
    output reg [A_WIDTH-1:0] a_in_reg_out
    );
    



//karatsuba
reg  [A_WIDTH-1:0]a_in_reg, a_in_reg_reg, a_in_reg_reg_reg;
wire [A_WIDTH+B_WIDTH-1:0] ab;
wire [A_WIDTH/2 - 1:0] a0, a1;
wire [B_WIDTH/2 - 1:0] b0, b1;


reg [(A_WIDTH + B_WIDTH)/2 - 1:0] a0b0, a1b1;
reg [MAX_AB/2:0] add_a0a1, add_b0b1;
reg [(A_WIDTH + B_WIDTH)/2 - 1:0] a0b0_reg, a1b1_reg;
reg [(A_WIDTH + B_WIDTH)/2 - 1:0] a0b0_reg_reg, a1b1_reg_reg;

reg [(A_WIDTH + B_WIDTH)/2:0] add_a0b0_a1b1;

reg [(A_WIDTH + B_WIDTH)/2 + 1:0] mul_a0a1_b0b1;
reg [(A_WIDTH + B_WIDTH)/2 + 1:0] sub_mul_ab_add_ab;

reg done_reg_0;
reg done_reg_1;
reg done_reg_2;

assign a0 = a_in[A_WIDTH/2 - 1:0];
assign a1 = a_in[A_WIDTH - 1:A_WIDTH/2];
assign b0 = b_in[B_WIDTH/2 - 1:0];
assign b1 = b_in[B_WIDTH - 1:B_WIDTH/2];


always@(posedge clk)
begin
    a_in_reg <= a_in;
    a0b0 <= a0*b0;
    a1b1 <= a1*b1;
    add_a0a1 <= a0 + a1;
    add_b0b1 <= b0 + b1;
    done_reg_0 <= start;
end


always@(posedge clk)
begin
    a_in_reg_reg <= a_in_reg;
    a0b0_reg <= a0b0;
    a1b1_reg <= a1b1;
    add_a0b0_a1b1 <= a0b0 + a1b1;
    mul_a0a1_b0b1 <= add_a0a1 * add_b0b1;
    done_reg_1 <= done_reg_0;
end

always@(posedge clk)
begin
    a_in_reg_reg_reg <= a_in_reg_reg;
    a0b0_reg_reg <= a0b0_reg;
    a1b1_reg_reg <= a1b1_reg;
    sub_mul_ab_add_ab <= mul_a0a1_b0b1 - add_a0b0_a1b1;
    done_reg_2 <= done_reg_1;
end

always@(posedge clk)
begin
 ab_out <= a0b0_reg_reg + {sub_mul_ab_add_ab, {{MAX_AB/2}{1'b0}}} + {a1b1_reg_reg, {{MAX_AB}{1'b0}}};
 a_in_reg_out <= a_in_reg_reg_reg;
 done <= done_reg_2;
end
  
endmodule
