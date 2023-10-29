/*------------------------------------------------------------------------------

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

File        : hqc_barrett.v
Author      : Ma'Muri, Sanjay Deshpande

Description : Implement barret reduction for HQC


Based on algorithm:
---
Reduction N

Input: a and m=floor(2^k/N)+1 = 475, k=23

Output: c = a mod q

1. t <-- (a<<8 + 3a<<6 + 3a<<3 + 3a) >>23   --- m*a<<k
2. c <-- a - (t<<14 + 5t<<8 + 5t)           --- a - t*N
3. if (c <0 )
4.   c <-- c+N
5. end if
6. return c
---
------------------------------------------------------------------------------*/

// `ifdef NO_DSP
(* use_dsp48 = "no" *)
// `endif

module hqc_barrett_red 
        #(    
           parameter parameter_set ="hqc128",
           parameter N = (parameter_set == "hqc128")? 17_669:
				          (parameter_set == "hqc192")? 35_851:
			              (parameter_set == "hqc256")? 57_637: 
                                                       17_669,
                                                       
           parameter M = (parameter_set == "hqc128")? 15:
				         (parameter_set == "hqc192")? 16:
			             (parameter_set == "hqc256")? 16: 
                                                      15
                                                                                              
        )
        (input clk_i, 
        input [23:0] a_i, 
        input [M-1:0] c_o);
        

generate
    if (parameter_set =="hqc128") begin
    
        reg     [23:0]  a_r;
        wire    [25:0]      a3;     //3*a
        wire    [29:0]      a37;    //37*a
        wire    [32:0]      a475;   //475*a
        reg     [9:0]       t;      //a475>>23
        wire    [12:0]      t5;     //5*t
        wire    [24:0]      tN;     //t*N
        reg     [15:0]      c_temp; //a-tN
        wire    [16:0]      cN;     //c_temp+N
        
        always @(posedge clk_i)
          a_r <= a_i;
        
        
        // assign a475 = 475*a_r;
        
        assign a37 = {a_i, 5'd0} + {a_i, 2'd0} + a_i;
        assign a475 = {a_i, 9'd0} - a37;
        
        always @(posedge clk_i)
          t <= a475[32:23];     //a475>>23
        
        // assign tN = t*N;
        
        assign t5 = {t, 2'd0} + t;
        
        assign  tN = {t, 14'd0} + {t5, 8'd0} + t5;
        
        always @(posedge clk_i)
          c_temp <= a_r[15:0] - tN[15:0]; //a-t*N
          
        assign cN = c_temp[14:0] + N;
        
        //Check if c_temp < 0
        assign c_o = c_temp[15]? cN[14:0] : c_temp[14:0];
     end
    
    else if(parameter_set == "hqc192") begin
        reg     [23:0]   a_r;
        wire    [25:0]      a3;     //7*a
        wire    [23+4:0] a11;    //11*a
        wire    [23+7:0] a117;   //117*a
        reg     [9:0]    t;      //a117>>23
        wire    [9+11:0] t1029;     //1029*t
        wire    [24:0]      tN;     //t*N
        reg     [16:0]      c_temp; //a-tN
        wire    [17:0]      cN;     //c_temp+N
        
        always @(posedge clk_i)
          a_r <= a_i;
        // assign a117 = 117*a_r;
        
        // all = (a<<3) + (a<<1) + a)
        assign a11 = {a_i, 3'd0} + {a_i, 1'd0} + a_i;
        
        //a117 = (a<<7) - a11
        assign a117 = {a_i, 7'd0} - a11;
        
        
        always @(posedge clk_i)
          t <= a117[30:22];     //a117>>22
        
        // assign tN = t*N; t*35851 = t*36880 - t*1029
        assign t1029 = {t, 10'd0} + {t, 2'd0} +  t;
        assign  tN = ({t, 15'd0} + {t, 12'd0} + {t, 4'd0}) - t1029;
        
        always @(posedge clk_i)
          c_temp <= a_r[16:0] - tN[16:0]; //a-t*N
        
        assign cN = c_temp[15:0] + N;
        
        //Check if c_temp < 0
        assign c_o = c_temp[16]? cN[15:0] : c_temp[15:0];
    end
    
    else if (parameter_set == "hqc256") begin
        reg     [23:0]   a_r;
        wire    [23+7:0] a73;   //117*a
        reg     [9:0]    t;      //a117>>23
        wire    [9+13:0] t8192;     //1029*t
        wire    [24:0]      tN;     //t*N
        reg     [16:0]      c_temp; //a-tN
        wire    [17:0]      cN;     //c_temp+N
        
        always @(posedge clk_i)
          a_r <= a_i;
        // assign a73 = 73*a_r;
        
        //a73 = (a<<6)+(a<<3)+ a
        assign a73 = {a_i, 6'd0} + {a_i, 3'd0} + a_i;
        
        
        always @(posedge clk_i)
          t <= a73[30:22];     //a117>>22
        
        // assign tN = t*N; t*35851 = t*65829 - t*8192
        assign t8192 = {t, 13'd0};
        assign  tN = ({t, 16'd0} + {t, 8'd0} + {t, 5'd0}+ {t, 2'd0} + t) - t8192;
        
        always @(posedge clk_i)
          c_temp <= a_r[16:0] - tN[16:0]; //a-t*N
        
        assign cN = c_temp[15:0] + N;
        
        //Check if c_temp < 0
        assign c_o = c_temp[16]? cN[15:0] : c_temp[15:0];
     end
endgenerate

endmodule


