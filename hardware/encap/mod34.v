/*------------------------------------------------------------------------------
File        : mod34.v
Author      : Sanjay Deshpande

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

module mod34 

        ( 
        input [11:0] a_i, 
        input [5:0] c_o);
        
    

                
        wire [18:0] a121;
		wire [6:0]t;
		wire [12:0]tN;
		wire [13:0] c_temp;
		wire [5:0] cN;
        // assign a121 = 121*a_i;
        
        assign a121 = {a_i, 7'd0} -{a_i, 3'd0} + a_i;
        
        assign t = a121[18:12];     //a121>>12
        
        // assign tN = t*34;
        assign  tN = {t, 5'd0} + {t, 1'd0};
        
        
        assign c_temp = a_i - tN; //a-t*N
          
        assign cN = c_temp[5:0] + 34;
        
        //Check if c_temp < 0
        assign c_o = c_temp[13]? cN[5:0] : c_temp[5:0];
    

endmodule


