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


module loc_based_adder
    #(

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
    
    
    parameter WIDTH = 32,
    parameter N_MEM = N + (WIDTH - N%WIDTH)%WIDTH, // Memory width adjustment for N
    
    parameter DEPTH = N_MEM/WIDTH,
    parameter LOG_DEPTH = `CLOG2(DEPTH),    
    parameter LOG_WEIGHT   = `CLOG2(WEIGHT)
    
    
    )
    (
    input clk,
    input rst,
    
    input [(M-1):0] location,
    output reg [LOG_WEIGHT-1:0] loc_rd_addr,
    output reg loc_rd_en,
    
    input [(WIDTH-1):0] pm_in,
    output  [LOG_DEPTH-1:0] pm_rd_addr,
    output reg pm_rd_en,
    
    input start,
    
    output wire [(WIDTH-1):0] add_out,
    output wire [LOG_DEPTH-1:0] add_out_addr,
    output wire add_out_valid,
    
    output reg done
    
    
    );
    
reg [(M-1):0] location_reg;
reg [WIDTH-1:0] add_out_reg;
reg [WIDTH-1:0] pm_in_reg;
wire [WIDTH-1:0] gen_one;

reg  [WIDTH-1:0] gen_one_reg;
wire [LOG_DEPTH -1:0] decode_addr;

reg add_out_valid_reg;


reg [LOG_DEPTH-1:0] add_out_addr_reg;
reg done_reg;
reg done_reg_reg;

// Below are states
parameter s_wait_start             =   0;//
parameter s_load_loc               =   1;//
parameter s_stall               =   2;//
parameter s_stall_1               =   3;//

reg [3:0] state     = 0;


  genvar i;
  generate
    for (i = 0; i < WIDTH; i=i+1) begin:vector_gen
        assign gen_one[i] = (i == location_reg[`CLOG2(WIDTH-1)-1:0]) ? 1'b1 : 1'b0; //test 
    end
  endgenerate


  
  always@(posedge clk)
  begin
    gen_one_reg = gen_one;
  end 
  
  
    always@(posedge clk)
  begin
    location_reg = location;
  end 
  
  
  
//assign add_out = gen_one_reg ^ pm_in;
assign add_out = gen_one ^ pm_in; 

assign add_out_valid = add_out_valid_reg;
assign add_out_addr = add_out_addr_reg;

  always@(posedge clk)
  begin
    if (pm_rd_en == 1'b1) begin
        add_out_addr_reg <= decode_addr;
    end
  end  
    
  assign decode_addr = location[M-1:`CLOG2(WIDTH)];
  assign pm_rd_addr = decode_addr;

  

always@(posedge clk)
begin
    if (rst) begin
        state <= s_wait_start;
        loc_rd_addr <= 0;
        add_out_valid_reg <= 0;
        done_reg<= 0;
    end
    else begin

         
         if (state == s_wait_start) begin
            add_out_valid_reg <= 0;
            loc_rd_addr <= 0;
            done_reg<= 0;
            if (start) begin 
                state <=  s_load_loc;                 
            end
         end
         
         else if (state == s_stall_1) begin
            state <=  s_load_loc;
            add_out_valid_reg <= 0;
            done_reg<= 0; 
         end
         
         else if (state == s_load_loc) begin
            done_reg<= 0; 
            if (loc_rd_addr == WEIGHT-1) begin
                state <= s_stall;
                add_out_valid_reg <= 1;
            end
            else begin
                loc_rd_addr <= loc_rd_addr + 1;
                add_out_valid_reg <= 1;
                state <= s_stall_1;
            end  
         end
         
          else if (state == s_stall) begin
            state <=  s_wait_start;
            add_out_valid_reg <= 0;
            done_reg <= 1;
         end
    end
    done_reg_reg <= done_reg;   
    done <= done_reg_reg;   
end 

always@(state  or start)
begin
    case (state)

      
      s_wait_start: begin

                        if (start) begin
                            loc_rd_en <= 1'b1;
                            pm_rd_en <= 1'b0;
                        end
                        else begin
                            loc_rd_en <= 1'b0;
                            pm_rd_en <= 1'b0;
                        end
                    end  
                    
      
                  
      s_load_loc: begin
                    loc_rd_en <= 1'b1;
                    pm_rd_en <= 1'b1;
                  end 
      
      s_stall_1: begin
                    loc_rd_en <= 1'b1;
                    pm_rd_en <= 1'b1;
                  end 
       
       s_stall: begin
                    loc_rd_en <= 1'b0;
                    pm_rd_en <= 1'b1;
                   end
                  
   
      default: begin
                loc_rd_en <= 1'b0;
                pm_rd_en <= 1'b0;
      end
    endcase

end     
endmodule
