`timescale 1ns / 1ps
/*
 * 
 *
 * Copyright (C) 2022
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


module fixed_weight_cww
#( 

    parameter parameter_set = "hqc256",
    
                                        
    parameter N = (parameter_set == "hqc128")? 17_669:
				  (parameter_set == "hqc192")? 35_851:
			      (parameter_set == "hqc256")? 57_637: 
                                               17_669,
                                               
    parameter PARAM_N_HEX = (parameter_set == "hqc128")? 15'h4505:
				            (parameter_set == "hqc192")? 16'h8c0b:
			                (parameter_set == "hqc256")? 16'he125: 
                                                         15'h4505,
                                                       
    parameter M = (parameter_set == "hqc128")? 15:
				  (parameter_set == "hqc192")? 16:
			      (parameter_set == "hqc256")? 16: 
                                               15,    
    
   
//    parameter WEIGHT = (parameter_set == "hqc128")? 66:
//					   (parameter_set == "hqc192")? 100:
//					   (parameter_set == "hqc256")? 131:
//                                                    66,
   
   parameter WEIGHT = (parameter_set == "hqc128")? 75:
					   (parameter_set == "hqc192")? 114:
					   (parameter_set == "hqc256")? 149:
                                                    75,
   
   
   parameter FILE_SKSEED = "",
   
   // common parameters
     parameter BITS_FROM_SHAKE = (32*WEIGHT) + (64 - (32*WEIGHT)%64)%64,
	parameter squeeze = 32'h40000000 + BITS_FROM_SHAKE,
						  
	
													   																										   
	
    parameter UTILS_REJECTION_THRESHOLD = (parameter_set == "hqc128")? 24'hffdb89:
										  (parameter_set == "hqc192")? 24'hff7811:
										  (parameter_set == "hqc256")? 24'hffed0f:
                                                                       24'hffdb89,
																	   
	
	parameter LOG_WEIGHT = `CLOG2(WEIGHT),
    parameter E0_WIDTH = 32,
    parameter E1_WIDTH = 32,
    parameter SEED_SIZE = 320,
    
    parameter k_WIDTH = (parameter_set == "hqc128")? 18:
                        (parameter_set == "hqc192")? 17:
                         (parameter_set == "hqc256")? 17:
                                                      18
)
(
    input clk,
    input rst,
    input start,
    
//    input seed_valid,
    input [31:0] sk_seed,
    input [3:0] sk_seed_addr,
    input sk_seed_wen,
    
	//request_another_vector = 11 - Request additional Fixed Weight from same seed with next context
	//request_another_vector = 01 - Reset Fixed Weight Vector Module to start with fresh context
	//request can be made only after the generation of the first vector
	//After generating first vector read out the generated vector before generating new one
	
	input [1:0] request_another_vector,  
	
	output reg done,
    output valid_vector,
    
    output [M-1:0] error_loc, 
    input rd_error_loc, 
    input [LOG_WEIGHT - 1 : 0]rd_addr_error_loc,
    
    
    //shake signals
    output reg seed_valid_internal, 
    input wire seed_ready_internal,
    output wire [31:0] din_shake,
    output reg shake_out_capture_ready,
    input wire [31:0] dout_shake_scrambled,
    output reg force_done_shake,
    input wire dout_valid_sh_internal
    
    );

reg init;     
reg wr_en_ms;   
reg [LOG_WEIGHT:0] wr_addr_ms;
wire [(M-1):0] data_in_ms;    
wire rd_en_ms;    
wire [(LOG_WEIGHT - 1):0]rd_addr_ms;   
wire [(M-1):0]data_out_ms;    
wire collision_ms;    

wire dout_valid_sh       = 1'b0;    
reg shift_shake_op       = 1'b0;    

wire bml_not; //not of beyond_max_limit



// reg [(logrb-1):0] count_reg = 0;
wire [31:0] dout_shake;
reg [(M-1):0] shake_out_capture;

// shake signals
reg [1:0] shake_input_type;
wire [31:0] din_shake;
//wire [31:0] fblock;

// onegen signals
wire ready_onegen;
wire done_onegen;
reg start_onegen;
wire [(M-1):0]location;

// signals for the seed loading  
wire [31:0]seed_in;

reg [4:0]seed_addr;
reg seed_wr_en;
wire [31:0]seed_q;
reg initial_loading;
wire [3:0]addr_for_seed;
  

reg red_seed_valid =0;

reg [31:0] squeeze_more;

//assign  seed_in = (initial_loading)? seed: dout_shake_scrambled;
  
// assign addr_for_seed = (seed_wr_en)? l_seed_addr[3:0]: seed_addr[3:0]; 
 assign addr_for_seed = (sk_seed_wen)? sk_seed_addr: seed_addr[3:0]; 

 mem_single #(.WIDTH(32), .DEPTH(SEED_SIZE/32), .FILE(FILE_SKSEED)) mem_single_seed
 (
        .clock(clk),
        .data(sk_seed),
        .address(addr_for_seed),
        .wr_en(sk_seed_wen),
        .q(seed_q)
 );
 
                                                                                                      
 assign din_shake = (shake_input_type == 2'b01)? squeeze: //fblock including the generation of next seed  
                    (shake_input_type == 2'b10)? 32'h80000148: //seed length 320 + 8 bits
                    (shake_input_type == 2'b11)? 32'h00000002: // Domain Seperator
                     seed_q;
    


//assign dout_shake = {dout_shake_scrambled[7:0], dout_shake_scrambled[15:8], dout_shake_scrambled[23:16], dout_shake_scrambled[31:24]};
assign dout_shake = dout_shake_scrambled;


parameter BARRETT_CONSTANTS = (parameter_set == "hqc128")? "barrett_hqc_128.mem":
                              (parameter_set == "hqc192")? "barrett_hqc_192.mem":
                              (parameter_set == "hqc256")? "barrett_hqc_256.mem":
                                                          "barrett_hqc_128.mem";
                              

reg [`CLOG2(WEIGHT)-1:0] addr_bc;
wire [k_WIDTH-1:0] k_in;
 mem_single #(.WIDTH(32), .DEPTH(WEIGHT), .FILE(BARRETT_CONSTANTS) ) B_CONST
 (
        .clock(clk),
        .data(0),
        .address(addr_bc),
        .wr_en(0),
        .q(k_in)
 ); 

reg dout_valid_sh_internal_reg;
reg [31:0]dout_shake_reg;

always@(posedge clk) 
begin
    dout_valid_sh_internal_reg <= dout_valid_sh_internal;
    dout_shake_reg <= dout_shake;
//    n_minus_i_reg <= n_minus_i;
end 

always@(posedge clk) begin
    if (start || request_another_vector == 2'b11) begin
        addr_bc <= 0;
    end 
    else if (dout_valid_sh_internal) begin
        addr_bc <= addr_bc + 1;
    end
end


always@(posedge clk) begin
    if (start) begin
        n_minus_i <= N; 
    end 
    else if (dout_valid_sh_internal_reg) begin
        n_minus_i <= n_minus_i - 1;
    end
end

barrett_red_gen #(.parameter_set(parameter_set))
B_RED 
(   
    .clk(clk),
    .start(dout_valid_sh_internal_reg),
    .done(dout_reduced_valid),
    .a_in(dout_shake_reg),
    .k_in(k_in),
    .n_in(n_minus_i),
    .red_out(dout_shake_reduced)
);


reg [31:0] shake_output_counter;


wire [`CLOG2(WEIGHT)-1:0] addr_0,addr_1;
reg [`CLOG2(WEIGHT):0]  wr_addr, rd_addr;
reg wr_en_0, wr_en_1;
wire wr_en_1_reg;
reg swap;
reg duplicate_detected;
//assign addr_0 = wr_addr;
//assign addr_1 = rd_addr;

//assign addr_0 = (rd_error_loc)? rd_addr_error_loc: (swap)? wr_addr :rd_addr;
//assign addr_1 = (swap)?         rd_addr :wr_addr;

assign addr_0 = (rd_error_loc)? rd_addr_error_loc: wr_addr;
assign addr_1 = rd_addr;

wire [`CLOG2(N)-1:0]  mem_in_0, mem_in_1;
wire [`CLOG2(N)-1:0]  mem_out_0, mem_out_1;
wire [`CLOG2(N)-1:0]  mem_comp;
wire [`CLOG2(N)-1:0] dout_shake_reduced;

  assign mem_in_0 = WEIGHT - count;
  assign mem_in_1 = addr_1 + dout_shake_reduced;
//  assign mem_in_1 = addr_1 + dout_shake % n_minus_i;
 
 
  mem_dual #(.WIDTH(`CLOG2(N)), .DEPTH(WEIGHT), .FILE("test_input.inn")) loca_mem (
    .clock(clk),
    .data_0(mem_in_0),
    .data_1(mem_in_1),
    .address_0(addr_0),
    .address_1(addr_1),
    .wren_0(wr_en_0),
    .wren_1(wr_en_1),
//    .wren_1(dout_reduced_valid),
    .q_0(mem_out_0),
    .q_1(mem_out_1)
  );
  
assign error_loc = mem_out_0;

wire test_mem1_mem2;
assign test_mem1_mem2 = (mem_out_0 == mem_out_1)?1 :0;

assign mem_comp = duplicate_detected? mem_in_0: mem_out_0;

//always@(posedge clk)
//begin 

//end 

reg dout_shake_sel_red;


reg [LOG_WEIGHT-1 : 0] wr_addr_ms_reg_0,wr_addr_ms_reg_1;
reg [LOG_WEIGHT-1 : 0] count;


reg [`CLOG2(N)-1:0] n_minus_i, n_minus_i_reg;  

reg [4:0] state = 0;
// Below are states
parameter s_wait_for_shake         =   0;
parameter s_init_mem               =   1;
parameter s_load_shake             =   2;
parameter s_stall                =   3;
parameter s_swap                   =   4;
parameter s_wait_onegen            =   5;
parameter s_stall_first            =   6;
parameter s_done                   =  7;

wire dout_reduced_valid;

 always@(posedge clk)
 begin
//    dout_valid_sh_internal_reg <= dout_valid_sh_internal;
    if (rst) begin
        wr_addr <=  0;
        rd_addr <=  0;
        done <= 0;  
        state <= s_init_mem;
        force_done_shake <= 0;
        count <= 0;
        swap <= 0;
        duplicate_detected <=0;
        shake_out_capture_ready <= 0;
        
    end
    else begin
        if (state == s_init_mem) begin
           force_done_shake <= 0;
           count <= 2;
           swap <= 0;
           shake_out_capture_ready <= 1;
           if (dout_reduced_valid) begin
                rd_addr <= rd_addr + 1;
//                wr_addr <= wr_addr + 1;
                state <= s_load_shake;
           end
           done <= 0;
           duplicate_detected <=0;
        end
        
        else if  (state == s_load_shake) begin
            done <= 0;
            duplicate_detected <=0;
            force_done_shake <= 0;
//            if (wr_addr > WEIGHT - 1) begin
            if (rd_addr > WEIGHT - 1) begin
                state <= s_stall;
//                state <= s_done;
                wr_addr <= WEIGHT - 2;
                rd_addr <= WEIGHT - 1;
                swap <= 1;
                shake_out_capture_ready <= 0;
            end
            else begin
               shake_out_capture_ready <= 1;
               if (dout_reduced_valid) begin
//                    wr_addr <= wr_addr + 1;
                    rd_addr <= rd_addr + 1;
                    swap <= 0;
                    
                end 
            end
        end
        
        else if (state == s_stall) begin 
                state <= s_swap;
                swap <= 1;
                shake_out_capture_ready <= 0;
        end
        
        else if (state == s_swap) begin
            swap <= 1;
            shake_out_capture_ready <= 0;
            if (mem_out_0 == mem_out_1) begin
                duplicate_detected <=1;
            end
            else begin
                duplicate_detected <= 0;
            end       
            if (rd_addr == WEIGHT - 1 && wr_addr == 0) begin
                state <= s_done;
            end
            else if (rd_addr == WEIGHT-1) begin
                wr_addr <= wr_addr - 1;
                rd_addr <= WEIGHT - count;
                count <= count + 1; 
//                state <= s_stall;      
                state <= s_swap;      
            end 
            else begin   
                state <= s_swap;
                rd_addr <= rd_addr + 1;
            end
        end
        
        
        else if (state == s_done) begin
            state <= s_init_mem;
            done <= 1;
            force_done_shake <= 0;
            swap <= 0;
            duplicate_detected <= 0;
            shake_out_capture_ready <= 0;
            rd_addr <= 0;
            wr_addr <= 0;
        end
    
    end
 end
 

always@(state, dout_reduced_valid, wr_addr, rd_addr, mem_out_0, mem_out_1)
begin
    case (state)
    
        s_init_mem: begin
                        wr_en_0 <= 0;
                        if (dout_reduced_valid) begin
                            wr_en_1 <= 1;
                        end
                        else begin
                            wr_en_1 <=0;
                        end
                    end
 
         s_load_shake: begin
                        wr_en_0 <= 0;
                        if (dout_reduced_valid) begin
                            wr_en_1 <= 1;
                        end
                        else begin
                            wr_en_1 <=0;
                        end
                    end 
        
        s_stall:begin
                    wr_en_0 <= 0;
                    wr_en_1 <= 0;
                end
                
        s_swap: begin
                        wr_en_1 <= 0;
                        if (mem_comp == mem_out_1) begin
                            wr_en_0 <= 1;
                        end
                        else begin
                            wr_en_0 <=0;
                        end
                    end 
                      
        default: begin
                    wr_en_0 <=0;
                    wr_en_1 <= 0;
                end
    endcase
end








reg  [31:0] count_reg = 0;










reg [3:0] state_shake = 0;
parameter s_init_shake                  =   0;
parameter s_wait_for_shake_out_ready    =   1;
parameter s_shake_out_w                 =   2;
parameter s_shake_in_w                  =   3;
parameter s_load_new_seed               =   4;
parameter s_stall_0                     =   5;
parameter s_load_domain_sep             =   6;
parameter s_wait                        =   7;
parameter s_wait_for_collision_2        =   8;
parameter s_wait_for_collision_3        =   9;
parameter s_wait_for_collision_4        =   10;

reg [1:0] count_steps;
reg  seed_is_loaded_in_shake;
reg  shake_result_ready;
reg  seed_is_loaded_in_shake_off;

//shake parallel processing loading
always@(posedge clk)
begin

 //================start feeding the SHAKE with seed============================
     if (rst) begin
        state_shake <= s_init_shake;
        seed_addr <= 0;
        seed_is_loaded_in_shake <= 1'b0;
        shake_result_ready <= 1'b0;
    end
    else begin
       
        if (state_shake == s_init_shake) begin
            count_steps <= 0;
            seed_addr <= 0;
            seed_is_loaded_in_shake <= 1'b0;
            if (start) begin
                state_shake <= s_shake_out_w;
                shake_result_ready <= 1'b0;
            end
        end 
        
        else if (state_shake == s_shake_out_w) begin
             if (request_another_vector == 2'b01) begin
                state_shake <= s_init_shake;
                seed_is_loaded_in_shake <= 1'b0;
             end
             else begin
                if (count_steps == 1) begin
                    state_shake <= s_shake_in_w;
                    count_steps <= 0;
                end 
                else begin
                    state_shake <= s_shake_out_w;
                    count_steps <= count_steps + 1;
                end
             end
        end
        
        else if (state_shake == s_shake_in_w) begin
            if (request_another_vector == 2'b01) begin
                state_shake <= s_init_shake;
                seed_is_loaded_in_shake <= 1'b0;
            end
             else begin
                if (count_steps == 1) begin
                    state_shake <= s_load_new_seed;
                    count_steps <= 0;
                end 
                else begin
                    state_shake <= s_shake_in_w;
                    count_steps <= count_steps + 1;
                end
             end
        end
        
        else if (state_shake == s_load_new_seed) begin
            if (request_another_vector == 2'b01) begin
                state_shake <= s_init_shake;
                seed_is_loaded_in_shake <= 1'b0;
            end
            else begin
                if (seed_addr == SEED_SIZE/32) begin
                    seed_addr <= 0;
                    seed_is_loaded_in_shake <= 1'b1;
//                    state_shake <= s_init_shake;
                    state_shake <= s_wait;
                end 
                else begin
                    state_shake <= s_stall_0;
                    seed_addr <= seed_addr + 1;
                end
            end
        end
        
        else if (state_shake == s_stall_0) begin
              if (request_another_vector == 2'b01) begin
                state_shake <= s_init_shake;
                seed_is_loaded_in_shake <= 1'b0;
              end
//              else if (request_another_vector == 2'b11) begin
//                state_shake <= s_load_domain_sep;
//              end
              else begin
                state_shake <= s_load_new_seed;
                
              end
        end
      
        else if (state_shake == s_wait) begin
              if (request_another_vector == 2'b01) begin
                state_shake <= s_init_shake;
                seed_is_loaded_in_shake <= 1'b0;
              end
              else if (request_another_vector == 2'b11) begin
                state_shake <= s_load_domain_sep;
              end
        end
        
        else if (state_shake == s_load_domain_sep) begin
              if (request_another_vector == 2'b01) begin
                state_shake <= s_init_shake;
                seed_is_loaded_in_shake <= 1'b1;
              end
              else begin
                state_shake <= s_wait;
              end
        end
	

 //================end feeding the SHAKE with seed============================
 
    end 
end
 

 
always@(state_shake or count_steps or seed_addr or dout_valid_sh_internal or request_another_vector or seed_ready_internal) 
begin
    case (state_shake)
     s_init_shake: begin
                    seed_valid_internal <= 1'b0; 
                    shake_input_type <= 2'b00;
                  end 
            
     s_shake_out_w: begin
                       if (count_steps == 0) begin
                           shake_input_type <= 2'b01;
                           seed_valid_internal <= 1'b1;
                       end 
                       else begin
                           seed_valid_internal <= 1'b0; 
                       end 
                    end
     
     
     s_shake_in_w: begin
                       if (count_steps == 0) begin
                           shake_input_type <= 2'b10;
                                seed_valid_internal <= 1'b1;
                       end 
                       else begin
                           seed_valid_internal <= 1'b0; 
                       end 
                    end

      s_load_new_seed: begin
                            if (seed_addr < SEED_SIZE/32) begin
                                    seed_valid_internal <= 1'b1;
                                shake_input_type <= 2'b00;
                            end
                            else begin
                                    seed_valid_internal <= 1'b1;
                                shake_input_type <= 2'b11;
                            end
                       end
      
      
      s_wait: begin
                    seed_valid_internal <= 1'b0;
               end
               
      s_load_domain_sep: begin
                            shake_input_type <= 2'b01;
                           seed_valid_internal <= 1'b1;
                        end                     
      
	  default: seed_valid_internal <= 1'b0;
      
    endcase

end  
    
endmodule
