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


module fixed_weight_ct
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
   
   parameter WEIGHT = (parameter_set == "hqc128")?   75:
					   (parameter_set == "hqc192")? 114:
					   (parameter_set == "hqc256")? 149:
                                                    75,
  
   parameter NO_OF_CTX = 2,  
   
   parameter FILE_SKSEED = "",
   
   // common parameters
   
   parameter NUM_OF_FW_VEC = 2,
    
   parameter BITS_FROM_SHAKE = (24*WEIGHT) + (64 - (24*WEIGHT)%64)%64,
   parameter squeeze_0 = (32'h40000000) + BITS_FROM_SHAKE*NO_OF_CTX*NUM_OF_FW_VEC,
   parameter squeeze_1 = (32'h40000000) + BITS_FROM_SHAKE*NO_OF_CTX*NUM_OF_FW_VEC,
   parameter squeeze_2 = (32'h40000000) + BITS_FROM_SHAKE*NO_OF_CTX*NUM_OF_FW_VEC,
   parameter squeeze_3 = (32'h40000000) + BITS_FROM_SHAKE*NO_OF_CTX*NUM_OF_FW_VEC,
													   																										   
	
    parameter UTILS_REJECTION_THRESHOLD = (parameter_set == "hqc128")? 24'hffdb89:
										  (parameter_set == "hqc192")? 24'hff7811:
										  (parameter_set == "hqc256")? 24'hffed0f:
                                                                       24'hffdb89,
																	   
	
	parameter LOG_WEIGHT = `CLOG2(WEIGHT),
	parameter LOG_W_CTX = `CLOG2(WEIGHT*NO_OF_CTX*NUM_OF_FW_VEC),
    parameter E0_WIDTH = 32,
    parameter E1_WIDTH = 32,
    parameter SEED_SIZE = 320
    
    
    
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
	
	output done,
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

reg [4:0] state = 0;
// Below are states
parameter s_initialize             =   0;
parameter s_wait_start             =   1;
parameter s_load_shake             =   2;
parameter s_stall_1                =   3;
parameter s_wait_sort              =   4;
parameter s_wait_onegen            =   5;
parameter s_stall_first            =   6;
parameter s_test                   =  7;

wire [31:0] dout_shake;
reg [(M-1):0] shake_out_capture;

// shake signals
reg [1:0] shake_input_type;
wire [31:0] din_shake;

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
  
reg dout_valid_sh_internal_reg = 0;

reg red_seed_valid =0;

reg [31:0] squeeze_more;


 assign addr_for_seed = (sk_seed_wen)? sk_seed_addr: seed_addr[3:0]; 

 mem_single #(.WIDTH(32), .DEPTH(SEED_SIZE/32), .FILE(FILE_SKSEED)) mem_single_seed
 (
        .clock(clk),
        .data(sk_seed),
        .address(addr_for_seed),
        .wr_en(sk_seed_wen),
        .q(seed_q)
 );
 
                                                                                                      
 assign din_shake = (shake_input_type == 2'b01)? squeeze_more: //Output Length of SHAKE256 
                    (shake_input_type == 2'b10)? 32'h80000148: //Input/Seed length plus Domain Separator length =  320 + 8 bits
                    (shake_input_type == 2'b11)? 32'h00000002: // Domain Seperator
                     seed_q;
    


assign dout_shake = {dout_shake_scrambled[7:0], dout_shake_scrambled[15:8], dout_shake_scrambled[23:16], dout_shake_scrambled[31:24]};

reg [31:0] dout_shake_reg;

wire [23:0]dout_shake_0;
wire [23:0]dout_shake_1;
wire [23:0]dout_shake_2;
wire [23:0]dout_shake_3;

always@(posedge clk)
begin
    if (dout_valid_sh_internal) begin
        dout_shake_reg <= dout_shake;
    end
end 

assign dout_shake_0 = dout_shake[31:8];
assign dout_shake_1 = {dout_shake_reg[7:0], dout_shake[31:16]};
assign dout_shake_2 = {dout_shake_reg[15:0], dout_shake[31:24]};
assign dout_shake_3 = dout_shake_reg[23:0];

wire [23:0] dout_shake_sel;
reg [31:0] shake_output_counter;



assign dout_shake_sel = (sel_ctx == 2'b00)? dout_shake_0:
                        (sel_ctx == 2'b01)? dout_shake_1:
                        (sel_ctx == 2'b10)? dout_shake_2: 
                                            dout_shake_3;

wire [LOG_W_CTX-1:0] addr_ctx_0,addr_ctx_1;
reg [LOG_W_CTX:0] wr_addr_ctx, rd_addr_ctx;
reg [LOG_W_CTX:0] count_red;
reg wr_en_shake_ctx;
wire [23:0] shake_ctx_out;

assign addr_ctx_0 = wr_addr_ctx[LOG_W_CTX-1:0];
assign addr_ctx_1 = rd_addr_ctx[LOG_W_CTX-1:0];

wire rejection_threshold_pass;
 
 
  mem_dual #(.WIDTH(24), .DEPTH(NUM_OF_FW_VEC*NO_OF_CTX*WEIGHT)) shake_ctx (
    .clock(clk),
    .data_0(dout_shake_sel),
    .data_1(0),
    .address_0(addr_ctx_0),
    .address_1(addr_ctx_1),
    .wren_0(wr_en_shake_ctx),
    .wren_1(0),
    // .q_0(shake_ctx_out)
    .q_1(shake_ctx_out)
  );
  

reg dout_shake_sel_red;


assign rejection_threshold_pass = shake_ctx_out < UTILS_REJECTION_THRESHOLD ? 1'b1 : 1'b0;


  
  hqc_barrett_red 
  #(.parameter_set(parameter_set))
  reduction
  ( .clk_i(clk),
    .a_i(shake_ctx_out),
    .c_o(data_in_ms)
    );

reg [LOG_WEIGHT-1 : 0] wr_addr_ms_reg_0,wr_addr_ms_reg_1;
reg wr_en_ms_reg_0, wr_en_ms_reg_1;

//pipelining logic
always@(posedge clk)
begin
    wr_en_ms_reg_0 <= wr_en_ms;
    wr_en_ms_reg_1 <= wr_en_ms_reg_0; 
end 

always@(posedge clk)
begin
    wr_addr_ms_reg_0 <= wr_addr_ms[(LOG_WEIGHT - 1):0];
    wr_addr_ms_reg_1 <= wr_addr_ms_reg_0; 
end 


 wire [LOG_WEIGHT-1 : 0]loca_addr;
 assign loca_addr = rd_error_loc? rd_addr_error_loc:
                    rd_en_ms ? rd_addr_ms : 
							   wr_addr_ms_reg_1;
							   
 mem_single #(.WIDTH(M), .DEPTH(WEIGHT) ) loca_mem
 (
        .clock(clk),
        .data(data_in_ms),
        .address(loca_addr),
        .wr_en(wr_en_ms_reg_1),
        .q(data_out_ms)
 );

assign error_loc = data_out_ms;
assign location = data_out_ms;
 
 reg init_mem_onegen; 
  
  onegen_ct #(.M(M), .WIDTH(E1_WIDTH),  .DEPTH((N+(E1_WIDTH-N%E1_WIDTH)%E1_WIDTH)/E1_WIDTH), .E0_WIDTH(E0_WIDTH), .E0_DEPTH((N+(E0_WIDTH-N%E0_WIDTH)%E0_WIDTH)/E0_WIDTH), .WEIGHT(WEIGHT)) onegen_instance (
    .clk(clk),
    .rst(rst),
    .init_mem(init_mem_onegen),
    .location(location),
    .start(start_onegen),
    .rd_addr(rd_addr_ms),
    .rd_en(rd_en_ms),
    .collision(collision_ms),
    .valid(valid_vector),
    .ready(ready_onegen),
    .done(done_onegen)
    );
    
assign done = done_onegen;

//weight counter
reg weight_counter_init;
reg [LOG_WEIGHT:0] weight_count;
reg decrease_weight_count;

always@(posedge clk)
begin
    if (weight_counter_init) begin
        weight_count = 0;
    end
    else if (wr_en_ms) begin
        weight_count = weight_count + 1;
    end
	else if (decrease_weight_count) begin
		weight_count = weight_count - 1;
	end
end


wire mod_weight_zero;
wire mod_weight_minus_1;

assign mod_weight_zero = (wr_addr_ctx == 0 || wr_addr_ctx == WEIGHT || wr_addr_ctx == 2*WEIGHT || wr_addr_ctx == 3*WEIGHT || wr_addr_ctx == 4*WEIGHT || wr_addr_ctx == 5*WEIGHT )? 1 :0;

assign mod_weight_minus_1 = (wr_addr_ctx == WEIGHT-1 || wr_addr_ctx == 2*WEIGHT-1 || wr_addr_ctx == 3*WEIGHT-1 || wr_addr_ctx == 4*WEIGHT-1 || wr_addr_ctx == 5*WEIGHT-1 || wr_addr_ctx == 6*WEIGHT-1 )? 1 :0;



reg [4:0] ctx_state, preserve_ctx_state = 0;
// Below are states
parameter s_ctx_wait_valid             =   0;
parameter s_ctx_first	               =   1;
parameter s_ctx_second                 =   2;
parameter s_ctx_third	               =   3;
parameter s_ctx_fourth				   =   4;
parameter s_ctx_done				   =   5;
parameter s_ctx_reset                  =   6;

reg  [31:0] count_reg = 0;

reg [1:0] sel_ctx;

always@(posedge clk)
begin
    if (rst) begin
        ctx_state <= s_ctx_wait_valid;
        shake_output_counter <= 0;
        wr_addr_ctx <= 0;
    end
    else begin
		
        if (ctx_state == s_ctx_wait_valid) begin
            if (wr_addr_ctx <= NUM_OF_FW_VEC*NO_OF_CTX*WEIGHT-1) begin	
                if (dout_valid_sh_internal) begin
                   ctx_state <= s_ctx_first;
                   wr_addr_ctx <= wr_addr_ctx+1;
                end
            end
            else begin
                ctx_state <= s_ctx_done;
                shake_out_capture_ready <= 1'b1;
			end  
	   end
         
        
        else if (ctx_state == s_ctx_first) begin
            if (mod_weight_zero) begin
                ctx_state <= s_ctx_wait_valid;
            end
            else if (wr_addr_ctx <= NUM_OF_FW_VEC*NO_OF_CTX*WEIGHT-1) begin
                if (dout_valid_sh_internal) begin
                   ctx_state <= s_ctx_second;
                   wr_addr_ctx <= wr_addr_ctx+1;
                end
            end
				else begin
					ctx_state <= s_ctx_done;
				end  
			end
		
		
		else if (ctx_state == s_ctx_second) begin
            if (mod_weight_zero) begin
                ctx_state <= s_ctx_wait_valid;
              
            end
            else if (wr_addr_ctx <= NUM_OF_FW_VEC*NO_OF_CTX*WEIGHT-1) begin
                if (dout_valid_sh_internal) begin
                   if (mod_weight_minus_1) begin
                        ctx_state <= s_ctx_reset;
                   end
                   else begin
                        wr_addr_ctx <= wr_addr_ctx+1;   
                        ctx_state <= s_ctx_third;
                   end
                end
                else begin
                end
            end
            else begin
                ctx_state <= s_ctx_done;
            end  
			
		end
		
		else if (ctx_state == s_ctx_third) begin
            if (mod_weight_zero) begin
                ctx_state <= s_ctx_wait_valid;
            end
            else if (mod_weight_minus_1) begin
                ctx_state <= s_ctx_reset;
            end
            else if (wr_addr_ctx <= NUM_OF_FW_VEC*NO_OF_CTX*WEIGHT-1) begin
                   ctx_state <= s_ctx_wait_valid;
                   wr_addr_ctx <= wr_addr_ctx+1;
            end
            else begin
                if (dout_valid_sh_internal) begin
                   ctx_state <= s_ctx_done;
                end
            end 			
		end
		
		else if (ctx_state == s_ctx_reset) begin
		    if (dout_valid_sh_internal) begin
                wr_addr_ctx <= wr_addr_ctx + 1;
                ctx_state <= s_ctx_wait_valid;   // discarding final bits	
            end
		end
		
		else if (ctx_state == s_ctx_done) begin
            wr_addr_ctx <= 0;
            ctx_state <= s_ctx_wait_valid;   // discarding final bits	
		end
        
    end 
end 


always@(ctx_state or dout_valid_sh_internal or wr_addr_ctx or mod_weight_zero) 
begin
    case (ctx_state)
    s_ctx_wait_valid: begin
                    start_red <= 1'b0;
					sel_ctx <= 2'b00;
					shake_out_capture_ready <= 1'b1;
					if(dout_valid_sh_internal) begin
						wr_en_shake_ctx <= 1'b1;
					end
					else begin
						wr_en_shake_ctx <= 1'b0;
					end
					
                  end 
            
	s_ctx_first: begin
					start_red <= 1'b0;
					sel_ctx <= 2'b01;
					if(dout_valid_sh_internal) begin
						wr_en_shake_ctx <= 1'b1;
					end
					else begin
						wr_en_shake_ctx <= 1'b0;
					end
					
					if (mod_weight_zero) begin 
					   shake_out_capture_ready <= 1'b0; 
					end
					else begin				
					   shake_out_capture_ready <= 1'b1;
					end
				end
    
	s_ctx_second: begin
					start_red <= 1'b0;
					sel_ctx <= 2'b10;
					if(dout_valid_sh_internal) begin
						wr_en_shake_ctx <= 1'b1;
					end
					else begin
						wr_en_shake_ctx <= 1'b0;
					end
					
					if (mod_weight_minus_1) begin 
					   shake_out_capture_ready <= 1'b1; 
					end
					else begin					
					   shake_out_capture_ready <= 1'b0;
					end
					
				end
	
	s_ctx_third: begin	
                    start_red <= 1'b0;
                    sel_ctx <= 2'b11;
                    wr_en_shake_ctx <= 1'b1;					
					shake_out_capture_ready <= 1'b1;
				end
	
	s_ctx_reset: begin	
						start_red <= 1'b0;
						sel_ctx <= 2'b00;
						wr_en_shake_ctx <= 1'b0;
						shake_out_capture_ready <= 1'b1;
				end
				
	s_ctx_done: begin
					start_red <= 1'b1;
					wr_en_shake_ctx <= 1'b0;
					shake_out_capture_ready <= 1'b1; 
				end
				
      default: begin 
				wr_en_shake_ctx <= 1'b0;
				start_red <= 1'b0;
				shake_out_capture_ready <= 1'b0;
			   end
    endcase

end 

reg start_red =0;
reg [4:0] red_state = 0;
reg squeeze_ctrl = 0;
parameter s_red_wait	             =   0;
parameter s_red_stall_0	             =   1;
parameter s_red_move	             =   2;
parameter s_red_stall_1	             =   3;
parameter s_red_stall_1_1	         =   12;
parameter s_red_stall_1_2	         =   13;
parameter s_red_check_weight	     =   4;
parameter s_red_wait_2				 =	 5;
parameter s_red_wait_for_collision	 =	 6;
parameter s_red_move_2	 			 =	 7;
parameter s_red_done	             =   8;
parameter s_red_stall_2	             =   9;
parameter s_red_move_3	             =   10;
parameter s_red_wait_3	             =   11;
parameter s_red_wait_from_second    = 14;

always@(posedge clk)
begin
    if (rst) begin
        red_state <= s_red_wait;
		rd_addr_ctx <=0;
		count_red <= 0;
		wr_addr_ms <= 0;
    end
    else begin

        if (red_state == s_red_wait) begin   
			if (start_red) begin
				red_state <= s_red_stall_0;
				rd_addr_ctx <= 0;
				wr_addr_ms <= 0;
				count_red <=0;
			end
        end 
        
         if (red_state == s_red_wait_from_second) begin   
			if (request_another_vector == 2'b11) begin
			     red_state <= s_red_stall_0;
			     wr_addr_ms <= 0;
				 count_red <=0;
			end
			else if (request_another_vector == 2'b01) begin
                red_state <= s_red_wait;
			end
        end 
		
		else if (red_state == s_red_stall_0) begin   
				red_state <= s_red_move;
				rd_addr_ctx <= rd_addr_ctx+1;
				count_red <= count_red + 1;
				wr_addr_ms <= 0;
        end 
        
        
		else if (red_state == s_red_move) begin   
			if (count_red < NO_OF_CTX*WEIGHT-1) begin
				red_state <= s_red_move;
				count_red <= count_red + 1;
				if (weight_count < WEIGHT) begin
                    rd_addr_ctx <= rd_addr_ctx + 1;
                end
                if (weight_count < WEIGHT) begin
                    if (rejection_threshold_pass) begin
                        wr_addr_ms <= wr_addr_ms+1;
                    end
               end
			end
			else begin
				red_state <= s_red_check_weight;
				if (rejection_threshold_pass) begin
    				wr_addr_ms <= wr_addr_ms+1;
    			end				
			end		
        end 
		
		else if (red_state == s_red_stall_1) begin   
				red_state <= s_red_stall_1_1;
				
        end
        
        // additional stalls to handle the pipeline from the barrett reduction
        else if (red_state == s_red_stall_1_1) begin   
				red_state <= s_red_stall_1_2;
				
        end
        
        else if (red_state == s_red_stall_1_2) begin   
				red_state <= s_red_check_weight;
				
        end 
		
		else if (red_state == s_red_check_weight) begin
			if ((weight_count < WEIGHT)  && (rd_addr_ctx ==  NUM_OF_FW_VEC*NO_OF_CTX*WEIGHT-1)) begin
				    red_state <= s_red_wait_3;
				    rd_addr_ctx <= 0;
			end
			
			else if (weight_count == WEIGHT) begin
			    if (ready_onegen) begin
				    red_state <= s_red_wait_for_collision;
				end
			end 
			else begin
				red_state <= s_red_wait_2;
			end 
		end
		
		else if (red_state == s_red_wait_3) begin
			if (start_red == 1'b1) begin
				red_state <= s_red_move;
				rd_addr_ctx <= rd_addr_ctx+1;
				wr_addr_ms <= wr_addr_ms+1;				
			end
		end 
		
		else if (red_state == s_red_wait_2) begin
			if (start_red == 1'b1 && rd_addr_ctx == 0) begin
				red_state <= s_red_move;
				rd_addr_ctx <= rd_addr_ctx+1;				
			end
			else if (rd_addr_ctx > 0 ) begin
				red_state <= s_red_move;
				rd_addr_ctx <= rd_addr_ctx+1;
			end
		end 

		else if (red_state == s_red_wait_for_collision) begin
			if (collision_ms == 1) begin
				wr_addr_ms <= rd_addr_ms;
				red_state <= s_red_stall_2;
				count_red <= count_red - 1;
				if (rd_addr_ctx ==  NUM_OF_FW_VEC*NO_OF_CTX*WEIGHT-1) begin
    				rd_addr_ctx <= 0;
    			end
			end
			else if (done_onegen) begin
				wr_addr_ms <= 0;
				if (rd_addr_ctx == WEIGHT) begin 
				   rd_addr_ctx <= WEIGHT; 
				end
				else if (rd_addr_ctx > WEIGHT && rd_addr_ctx <= 2*WEIGHT) begin 
				   rd_addr_ctx <= 2*WEIGHT; 
				end
				else if (rd_addr_ctx > 2*WEIGHT && rd_addr_ctx <= 3*WEIGHT) begin 
				   rd_addr_ctx <= 3*WEIGHT; 
				end
				else begin
				    rd_addr_ctx <= 0;
                end				
				red_state <= s_red_wait_from_second;
				count_red <= 0;
			end 
		end 
		
		else if (red_state == s_red_stall_2) begin   
				red_state <= s_red_check_weight;
        end
		
		else if (red_state == s_red_move_2) begin   
				rd_addr_ctx <= rd_addr_ctx + 1;
				red_state <= s_red_stall_1;
        end 
        
		
		else if (red_state == s_red_done) begin
			if (force_done_shake) begin
				red_state <= s_red_wait;
				rd_addr_ctx <= 0;
				wr_addr_ms <= 0;
			end
		end
		
    end 
end 


always@(red_state or rejection_threshold_pass or weight_count or collision_ms or ready_onegen or rd_addr_ctx) 
begin
    case (red_state)
		s_red_wait: begin
			squeeze_ctrl <= 1'b0;
			wr_en_ms <= 1'b0;
			weight_counter_init <= 1'b1;
			decrease_weight_count <= 1'b0;
			start_onegen <= 1'b0;

		end
		
		s_red_wait_from_second: begin
			squeeze_ctrl <= 1'b0;
			wr_en_ms <= 1'b0;
			weight_counter_init <= 1'b1;
			decrease_weight_count <= 1'b0;
			start_onegen <= 1'b0;
		end
		
		s_red_stall_0: begin
			wr_en_ms <= 1'b0;
			weight_counter_init <= 1'b0;
			decrease_weight_count <= 1'b0;
			start_onegen <= 1'b0;
			squeeze_ctrl <= 1'b0;

		end
		
		s_red_move: begin
			weight_counter_init <= 1'b0;
			decrease_weight_count <= 1'b0;
			squeeze_ctrl <= 1'b0;
			start_onegen <= 1'b0;

			if (rejection_threshold_pass && (weight_count<= WEIGHT-1)) begin
				wr_en_ms <= 1'b1;
			end
			else begin
				wr_en_ms <= 1'b0;
			end
		end
		
		s_red_stall_1: begin
			weight_counter_init <= 1'b0;
			decrease_weight_count <= 1'b0;
			start_onegen <= 1'b0;
			squeeze_ctrl <= 1'b0;
			if (rejection_threshold_pass && (weight_count<= WEIGHT-1)) begin
				wr_en_ms <= 1'b1;
			end
			else begin
				wr_en_ms <= 1'b0;
			end
		end
		
		s_red_stall_1_1: begin
		      weight_counter_init <= 1'b0;
			  decrease_weight_count <= 1'b0;
			  start_onegen <= 1'b0;
			  squeeze_ctrl <= 1'b0;
			  wr_en_ms <= 1'b0;
		
		end
		 
		s_red_stall_1_2: begin
		      weight_counter_init <= 1'b0;
			  decrease_weight_count <= 1'b0;
			  start_onegen <= 1'b0;
			  squeeze_ctrl <= 1'b0;
			  wr_en_ms <= 1'b0;
		end
		
		s_red_check_weight: begin
			decrease_weight_count <= 1'b0;
			weight_counter_init <= 1'b0;
			wr_en_ms <= 1'b0;
			if (weight_count < WEIGHT && rd_addr_ctx == 0) begin
			    start_onegen <= 1'b0;
				squeeze_ctrl <= 1'b1;
			end
			else if (weight_count < WEIGHT && rd_addr_ctx == NUM_OF_FW_VEC*NO_OF_CTX*WEIGHT-1) begin
			     start_onegen <= 1'b0;
				 squeeze_ctrl <= 1'b1;
			end 
			else begin
			    squeeze_ctrl <= 1'b0;
			    if (ready_onegen && weight_count == WEIGHT) begin
    				start_onegen <= 1'b1;
    			end
    			else begin
    			    start_onegen <= 1'b0;
    			end
			end
			
		end
		
		s_red_wait_for_collision: begin
			weight_counter_init <= 1'b0;
			wr_en_ms <= 1'b0;
			start_onegen <= 1'b0;
			if (collision_ms) begin
				decrease_weight_count <= 1'b1;
			end
			else begin
				decrease_weight_count <= 1'b0;
			end
			
		
		end
		
		s_red_stall_2: begin
		     weight_counter_init <= 1'b0;
			decrease_weight_count <= 1'b0;
			start_onegen <= 1'b0;
			squeeze_ctrl <= 1'b0;
			wr_en_ms <= 1'b0;

		end
		
		s_red_move_2: begin
			weight_counter_init <= 1'b0;
			decrease_weight_count <= 1'b0;
			start_onegen <= 1'b0;
			squeeze_ctrl <= 1'b0;

			if (rejection_threshold_pass && (weight_count<= WEIGHT-1)) begin
				wr_en_ms <= 1'b1;
			end
			else begin
				wr_en_ms <= 1'b0;
			end
		end
		
		s_red_done: begin
			weight_counter_init <= 1'b0;
			wr_en_ms <= 1'b0;
			decrease_weight_count <= 1'b0;
			start_onegen <= 1'b0;
			squeeze_ctrl <= 1'b0;

		end
		
      default: 	begin 
					wr_en_ms <= 1'b0;
					start_onegen <= 1'b0;
					squeeze_ctrl <= 1'b0;
				end
    endcase

end

always@(posedge clk)
begin
    dout_valid_sh_internal_reg <= dout_valid_sh_internal;
end




reg [3:0] state_shake = 0;
parameter s_init_shake                  =   0;
parameter s_wait_for_shake_out_ready    =   1;
parameter s_shake_out_w                 =   2;
parameter s_shake_in_w                  =   3;
parameter s_load_new_seed               =   4;
parameter s_stall_0                     =   5;
parameter s_load_domain_sep             =   6;
parameter s_wait_for_collision_1        =   7;
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
			squeeze_more <= squeeze_0;
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
					state_shake <= s_wait_for_collision_1;
					squeeze_more <= squeeze_1;
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
			  else begin
				state_shake <= s_load_new_seed;
			  end
        end
		
		else if (state_shake == s_wait_for_collision_1) begin
			if (request_another_vector == 2'b01) begin
                state_shake <= s_init_shake;
            end
            else begin
				squeeze_more <= squeeze_1;
				if (squeeze_ctrl) begin
					state_shake <= s_wait_for_collision_2;
				end  
			end
		end
		
		else if (state_shake == s_wait_for_collision_2) begin
			if (request_another_vector == 2'b01) begin
                state_shake <= s_init_shake;
            end
            else begin
				squeeze_more <= squeeze_2;
				if (squeeze_ctrl) begin
					state_shake <= s_wait_for_collision_3;	
				end  
			end
		end
		
		else if (state_shake == s_wait_for_collision_3) begin
			if (request_another_vector == 2'b01) begin
                state_shake <= s_init_shake;
            end
            else begin
				squeeze_more <= squeeze_3;
				if (squeeze_ctrl) begin
					state_shake <= s_wait_for_collision_4;
				end  
			end
		end
		
		else if (state_shake == s_wait_for_collision_4) begin
			if (request_another_vector == 2'b01) begin
                state_shake <= s_init_shake;
            end
            else begin
				squeeze_more <= squeeze_0;
				if (squeeze_ctrl) begin
					state_shake <= s_wait_for_collision_1;	
				end  
			end
		end
 
    end 
end
 

 
always@(state_shake or count_steps or seed_addr or dout_valid_sh_internal or squeeze_ctrl or request_another_vector or seed_ready_internal) 
begin
    case (state_shake)
     s_init_shake: begin
                    seed_valid_internal <= 1'b0; 
                    shake_input_type <= 2'b00;
                    init_mem_onegen <= 1'b0;
                  end 
            
     s_shake_out_w: begin
					init_mem_onegen <= 1'b1;
                       if (count_steps == 0) begin
                           shake_input_type <= 2'b01;
                           seed_valid_internal <= 1'b1;
                       end 
                       else begin
                           seed_valid_internal <= 1'b0; 
                       end 
                    end
     
     
     s_shake_in_w: begin
					   init_mem_onegen <= 1'b0;
                       if (count_steps == 0) begin
                           shake_input_type <= 2'b10;
                           seed_valid_internal <= 1'b1;
                       end 
                       else begin
                           seed_valid_internal <= 1'b0; 
                       end 
                    end

      s_load_new_seed: begin
							init_mem_onegen <= 1'b0;
                            if (seed_addr < SEED_SIZE/32) begin
                                seed_valid_internal <= 1'b1;
                                shake_input_type <= 2'b00;
                            end
                            else begin
                                seed_valid_internal <= 1'b1;
                                shake_input_type <= 2'b11;
                            end
                       end
      
                            
      s_stall_0: begin
                            seed_valid_internal <= 1'b0;
                            shake_input_type <= 2'b00;
							init_mem_onegen <= 1'b0;
                       end 
	  
	  s_wait_for_collision_1: begin
								shake_input_type <= 2'b01;
                                if (squeeze_ctrl) begin
                                    seed_valid_internal <= 1'b1;
                                end
                                else begin
                                    seed_valid_internal <= 1'b0;
                                end
                                if (request_another_vector == 2'b11) begin
                                    init_mem_onegen<= 1'b1;
                                end
                                else begin
                                    init_mem_onegen<= 1'b0;
                                end
							 end
	
	  s_wait_for_collision_2: begin
								shake_input_type <= 2'b01;
                                if (squeeze_ctrl) begin
                                    seed_valid_internal <= 1'b1;
                                end
                                else begin
                                    seed_valid_internal <= 1'b0;
                                end
								if (request_another_vector == 2'b11) begin
                                    init_mem_onegen<= 1'b1;
                                end
                                else begin
                                    init_mem_onegen<= 1'b0;
                                end
						      end
	  
	  s_wait_for_collision_3: begin
								shake_input_type <= 2'b01;
                                if (squeeze_ctrl) begin
                                    seed_valid_internal <= 1'b1;
                                end
                                else begin
                                    seed_valid_internal <= 1'b0;
                                end
								if (request_another_vector == 2'b11) begin
                                    init_mem_onegen<= 1'b1;
                                end
                                else begin
                                    init_mem_onegen<= 1'b0;
                                end
							 end
	
	  s_wait_for_collision_4: begin
								shake_input_type <= 2'b01;
                                if (squeeze_ctrl) begin
                                    seed_valid_internal <= 1'b1;
                                end
                                else begin
                                    seed_valid_internal <= 1'b0;
                                end
								if (request_another_vector == 2'b11) begin
                                    init_mem_onegen<= 1'b1;
                                end
                                else begin
                                    init_mem_onegen<= 1'b0;
                                end
						      end
      
	  default: seed_valid_internal <= 1'b0;
      
    endcase

end  
    
endmodule
