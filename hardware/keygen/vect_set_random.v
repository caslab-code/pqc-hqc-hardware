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

`include "keccak_pkg.v"

module vect_set_random
#( 

    parameter parameter_set = "hqc128",
    
                                        
    parameter N = (parameter_set == "hqc128")? 17_669:
				  (parameter_set == "hqc192")? 35_851:
			      (parameter_set == "hqc256")? 57_637: 
                                               17_669,
    
    parameter N_32 = N + (32 - N%32)%32,    //32-bit because of SHAKE interface                                       
   
	parameter FILE_PKSEED = "",
   // common parameters
    
	
	
													   																										   
	// memory related constants
	parameter MEM_WIDTH = 128,	//Minimum Width = 64, tested for widths 64, 128, 256
	parameter N_MEM = N + (MEM_WIDTH - N%MEM_WIDTH)%MEM_WIDTH, // Memory width adjustment for N
	parameter N_B = N + (8-N%8)%8, // Byte adjustment on N
	parameter N_Bd = N_B - N, // difference between N and byte adjusted N
	parameter N_MEMd = N_MEM - N_B, // difference between byte adjust and Memory adjusted N
    
    parameter SEED_SIZE = 320,
    parameter squeeze = 32'h40000000 | N_32,
    parameter mask = (parameter_set == "hqc128")? 32'h1f000000:
					 (parameter_set == "hqc192")? 32'hff030000:
					 (parameter_set == "hqc256")? 32'h1f000000:
                                                  32'h1f000000,
    // parameters for handling last block                                    
    parameter LAST_BLOCK_SIZE = N%128,
    parameter L_BLOCKS = LAST_BLOCK_SIZE + (32 - LAST_BLOCK_SIZE%32)%32
                                                  
)
(
    input clk,
    input rst,
	
    input start,
	
	input [3:0]pk_seed_addr,
    input [31:0] pk_seed,
	input pk_seed_wen,
	
	
	input rand_out_rd,	
	input [`CLOG2(N_MEM/MEM_WIDTH) - 1:0]rand_out_addr_0,	
	output [MEM_WIDTH-1:0] rand_out_0,
	input [`CLOG2(N_MEM/MEM_WIDTH) - 1:0]rand_out_addr_1,	
	output [MEM_WIDTH-1:0] rand_out_1,	
	output reg done,
    
    //shake signals
    output reg shake_din_valid, 
    input wire shake_din_ready,
    output wire [31:0] shake_din,
    output reg shake_dout_ready,
    input wire [31:0] shake_dout_scram,
    output reg shake_force_done,
    input wire shake_dout_valid
    
    );




parameter BLOCKS_IN_MEM_WIDTH = MEM_WIDTH/32;
parameter LOG_BIM = `CLOG2(BLOCKS_IN_MEM_WIDTH);

wire [31:0] dout_shake;

// shake signals
reg [1:0] shake_input_type;
wire [31:0] shake_din;


// signals for the seed loading  
reg [4:0]seed_addr;
wire [31:0]seed_q;
wire [3:0]addr_for_seed;
 reg done_reg; 
  
 assign addr_for_seed = (pk_seed_wen)? pk_seed_addr: seed_addr[3:0]; 

 mem_single #(.WIDTH(32), .DEPTH(SEED_SIZE/32), .FILE(FILE_PKSEED) ) mem_pk_seed
 (
        .clock(clk),
        .data(pk_seed),
        .address(addr_for_seed),
        .wr_en(pk_seed_wen),
        .q(seed_q)
 );
 
                                                                                                      
 assign shake_din = (shake_input_type == 2'b01)? squeeze: //fblock including the generation of next seed  
                    (shake_input_type == 2'b10)? 32'h80000148: //seed length 320 + 8 bits
                    (shake_input_type == 2'b11)? 32'h00000002: // Domain Seperator
                     seed_q;
    


assign dout_shake = {shake_dout_scram[7:0], shake_dout_scram[15:8], shake_dout_scram[23:16], shake_dout_scram[31:24]};


 wire [`CLOG2(N_MEM/MEM_WIDTH)-1:0] rmem_addr;
 reg [`CLOG2(N_MEM/MEM_WIDTH)-1:0]  rmem_addr_rev;
 reg rmem_wen;
 reg sel_rmem, sel_rmem_reg;
 wire [32 - 1:0] rmem_data, rmem_data_rearrange;
 
 wire [MEM_WIDTH-1:0] rmem_out_0, rmem_out_1;

 

assign rmem_addr = rand_out_rd? rand_out_addr_0: rmem_addr_rev;
assign rmem_data = (pk_rand_addr == N_32/32 - 1)?{mask & dout_shake}: dout_shake;
  
 
    mem_dual #(.WIDTH(MEM_WIDTH), .DEPTH(N_MEM/MEM_WIDTH)) rand_mem (
     .clock(clk),
     .data_0(rand_mem_in),
     .data_1(rand_mem_in),
     .address_0(rmem_addr),
     .address_1(rand_out_addr_1),
     .wren_0(wr_en_rand),
     .wren_1(0),
     .q_0(rmem_out_0),
     .q_1(rmem_out_1)
   );

assign rand_out_0 = rmem_out_0;
assign rand_out_1 = rmem_out_1;

assign rmem_data_rearrange = {rmem_data[7:0], rmem_data[15:8], rmem_data[23:16], rmem_data[31:24]};

reg [MEM_WIDTH-1:0] rand_out_rearrange, rand_out_rearrange_reg;
wire [MEM_WIDTH-1:0] rand_mem_in;
reg wr_en_rand;
reg shake_dout_valid_reg;

always@(posedge clk)
begin
    if (shake_dout_valid) begin
        if (pk_rand_addr[LOG_BIM-1:0] == 0) begin
            rand_out_rearrange <= {rmem_data_rearrange,{(MEM_WIDTH-32){1'b0}}};
        end
        else begin
            rand_out_rearrange <= {rmem_data_rearrange,rand_out_rearrange[MEM_WIDTH-1:32]};
        end
    end   
    else if (done_reg) begin
           rand_out_rearrange <=  {{(MEM_WIDTH-L_BLOCKS){1'b0}},rand_out_rearrange[L_BLOCKS-1:0]}; 
    end
end


generate
    if (parameter_set =="hqc256" && MEM_WIDTH == 64) begin
        assign rand_mem_in = (done == 1)?  rand_out_rearrange_reg: 
                                           rand_out_rearrange;
    end
    else begin
        assign rand_mem_in = (done == 1)?  {{(MEM_WIDTH-N_32%MEM_WIDTH){1'b0}},rand_out_rearrange_reg[MEM_WIDTH-1:MEM_WIDTH - N_32%MEM_WIDTH]}: 
                                                                     rand_out_rearrange;
    end
endgenerate

always@(posedge clk)
begin
    pk_rand_addr_reg <= pk_rand_addr;
    rmem_addr_rev <= (pk_rand_addr[`CLOG2(N_32/32)-1:LOG_BIM]);
end

generate
    if (`PARALLEL_SLICES > 16) begin
        always@(posedge clk)
        begin
            if ((pk_rand_addr[LOG_BIM-1:0] == BLOCKS_IN_MEM_WIDTH-1) || done_reg) begin
                wr_en_rand <= 1'b1;
            end
            else begin
                wr_en_rand <= 1'b0;
            end
        end
    end
    else begin
         always@(posedge clk)
        begin
            if ((pk_rand_addr_reg[LOG_BIM-1:0] == BLOCKS_IN_MEM_WIDTH-1 && pk_rand_addr[LOG_BIM-1:0] == BLOCKS_IN_MEM_WIDTH-1) || done_reg) begin 
                wr_en_rand <= 1'b1;
            end
            else begin
                wr_en_rand <= 1'b0;
            end
        end
   end
endgenerate 



always@(posedge clk)
begin
        rand_out_rearrange_reg <= rand_out_rearrange;
        shake_dout_valid_reg <= shake_dout_valid;
end



reg [`CLOG2(N_32/32)-1:0]pk_rand_addr = 0;
reg [`CLOG2(N_32/32)-1:0]pk_rand_addr_reg = 0;
reg [3:0] pk_state = 0;
parameter pk_wait_start  =   0;
parameter pk_load_rand =   1;
parameter pk_stall_0 = 2;



//Public Key related Random vector loading
always@(posedge clk)
begin
     if (rst) begin
        pk_state <= pk_wait_start;
        pk_rand_addr <= 0;
        done_reg <= 1'b0;
        shake_dout_ready <= 1'b0;
    end
    else begin
        if (pk_state == pk_wait_start) begin
            done_reg <= 1'b0;
            shake_dout_ready <= 1'b1;
            if (shake_dout_valid) begin
				pk_state <= pk_load_rand;
				pk_rand_addr <= pk_rand_addr + 1;				
			end
			else begin
			    pk_rand_addr <= 0;
			end 
        end 
        
        else if (pk_state == pk_load_rand) begin
            done_reg <= 1'b0;
            shake_dout_ready <= 1'b1;
            if (pk_rand_addr < N_32/32 - 1) begin
                if (shake_dout_valid) begin
                    pk_state <= pk_load_rand;
                    pk_rand_addr <= pk_rand_addr + 1;				
                end
			end
			else begin
			     pk_state <= pk_stall_0;
			end
        end
        
        else if (pk_state == pk_stall_0) begin
			 pk_state <= pk_wait_start;
			 done_reg <= 1'b1;
			 shake_dout_ready <= 1'b0;
	    end 
    end 
    done <= done_reg;
    sel_rmem_reg <= sel_rmem;
end

always@(pk_state or pk_rand_addr or shake_dout_valid) 
begin
    case (pk_state)
     pk_wait_start: 
     begin
         sel_rmem <= 1'b0;
         if (shake_dout_valid) begin
            rmem_wen <= 1;
        end
        else begin
            rmem_wen <= 0;
        end
     end 
     
     pk_load_rand: 
     begin
        sel_rmem <= 1'b0;
        if (shake_dout_valid) begin
            rmem_wen <= 1;
        end
        else begin
            rmem_wen <= 0;
        end
     end 
     
     pk_stall_0: 
     begin
        sel_rmem <= 1'b1;
        if (shake_dout_valid) begin
            rmem_wen <= 1;
        end
        else begin
            rmem_wen <= 0;
        end
     end 
             
	 default: 
	 begin
	       rmem_wen <= 0;
	       sel_rmem <= 1'b0;
	 end            
    endcase
end 


reg [3:0] state_shake = 0;
parameter s_init_shake                  =   0;
parameter s_wait_for_shake_out_ready    =   1;
parameter s_shake_out_w                 =   2;
parameter s_shake_in_w                  =   3;
parameter s_load_new_seed               =   4;
parameter s_stall_0                     =   5;

reg [1:0] count_steps;
reg  shake_result_ready;


//shake parallel processing loading
always@(posedge clk)
begin

     if (rst) begin
        state_shake <= s_init_shake;
        seed_addr <= 0;
        shake_result_ready <= 1'b0;
        shake_force_done <= 1'b0;
    end
    else begin
       
        if (state_shake == s_init_shake) begin
            count_steps <= 0;
            seed_addr <= 0;
            if (start) begin
                state_shake <= s_shake_out_w;
                shake_result_ready <= 1'b0;
                shake_force_done <= 1'b0;
            end
        end 
        
        else if (state_shake == s_shake_out_w) begin
            shake_force_done <= 1'b0;
			if (count_steps == 1) begin
				state_shake <= s_shake_in_w;
				count_steps <= 0;
			end 
			else begin
				state_shake <= s_shake_out_w;
				count_steps <= count_steps + 1;
			end
        end
        
        else if (state_shake == s_shake_in_w) begin
            shake_force_done <= 1'b0;
			if (count_steps == 1) begin
				state_shake <= s_load_new_seed;
				count_steps <= 0;
			end 
			else begin
				state_shake <= s_shake_in_w;
				count_steps <= count_steps + 1;
			end
             
        end
        
        else if (state_shake == s_load_new_seed) begin
            shake_force_done <= 1'b0;
			if (seed_addr == SEED_SIZE/32) begin
				seed_addr <= 0;
				state_shake <= s_init_shake;
			end 
			else begin
				state_shake <= s_stall_0;
				seed_addr <= seed_addr + 1;
			end
            
        end
        
        else if (state_shake == s_stall_0) begin
                shake_force_done <= 1'b0;
                state_shake <= s_load_new_seed;
        end
		
		
 
    end 
end
 
 
always@(state_shake or count_steps or seed_addr) 
begin
    case (state_shake)
     s_init_shake: begin
                    shake_din_valid <= 1'b0; 
                    shake_input_type <= 2'b00;
                  end 
            
     s_shake_out_w: begin
                       if (count_steps == 0) begin
                           shake_input_type <= 2'b01;
                           shake_din_valid <= 1'b1;
                       end 
                       else begin
                           shake_din_valid <= 1'b0; 
                       end 
                    end
     
     
     s_shake_in_w: begin
                       if (count_steps == 0) begin
                           shake_input_type <= 2'b10;
                           shake_din_valid <= 1'b1;
                       end 
                       else begin
                           shake_din_valid <= 1'b0; 
                       end 
                    end

      s_load_new_seed: begin
                            if (seed_addr < SEED_SIZE/32) begin
                                shake_din_valid <= 1'b1;
                                shake_input_type <= 2'b00;
                            end
                            else begin
                                shake_din_valid <= 1'b1;
                                shake_input_type <= 2'b11;
                            end
                       end
      
                            
      s_stall_0: begin
                            shake_din_valid <= 1'b0;
                            shake_input_type <= 2'b00;
                       end 
	

      
	  default: shake_din_valid <= 1'b0;
      
    endcase

end  
    
endmodule
