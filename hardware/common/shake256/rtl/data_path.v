
/*
 * This is a module for cSHAKE, it is translated manually from data_path.vhd, 
 * which was developed by Bernhard Jungk <bernhard@projectstarfire.de>
 * 
 * Copyright (C): 2019
 * Author:        Shanquan Tian <shanquan.tian@yale.edu>
 *    
 * Updated to perform only SHAKE: Sanjay Deshpande <sanjay.deshpande@yale.edu>
 * Updated:       2021-04-19 
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


`include "clog2.v"// Used in cshake project only
//`include "../../cshake/clog2.v"// used with Gaussian Sampler
`include "keccak_pkg.v"
//`include "../../cshake/keccak_pkg.v"
`include "keccak_math.v"
//`include "../../cshake/keccak_math.v"

module data_path (
    input wire                           rst,
    input wire                           clk,
    input wire                           computation_en,
    input wire [`ROUND_COUNT_WIDTH-1:0]  round,
    input wire [`COUNTER_WIDTH-1:0]      reads,
    input wire                           bof,
    input wire                           absorb_data,
//    input wire                           absorb_cust, // sanjay SHAKE deletion
    input wire [`PARALLEL_SLICES-1:0]    din,
    input wire                           squeeze_output,
    input wire                           reset_ram,
    output reg [`WOUT-1:0]               dout,
    input wire                           mux256  
);

//parameter WOUT_DIV_PARALLEL_SLICES = `WOUT / `PARALLEL_SLICES;//2 maximum 32, `WOUT=32,`PARALLEL_SLICES=16, so it is 2  //SHANQUAN's edit 32
//parameter PARALLEL_SLICES_DIV_WOUT = `PARALLEL_SLICES / `WOUT; //0 maximum 2  //constant dout_idx_max    : natural := max(wout_div_parallel_slices, parallel_slices_div_wout)-1; //SHANQUAN's edit 32
//parameter DOUT_IDX_MAX = `MAX(WOUT_DIV_PARALLEL_SLICES, PARALLEL_SLICES_DIV_WOUT)-1; //SHANQUAN's edit 32
localparam  WOUT_DIV_PARALLEL_SLICES = `WOUT / `PARALLEL_SLICES;//2 maximum 32, `WOUT=32,`PARALLEL_SLICES=16, so it is 2  
localparam PARALLEL_SLICES_DIV_WOUT = `PARALLEL_SLICES / `WOUT; //0 maximum 2  //constant dout_idx_max    : natural := max(wout_div_parallel_slices, parallel_slices_div_wout)-1;
localparam DOUT_IDX_MAX = `MAX(WOUT_DIV_PARALLEL_SLICES, PARALLEL_SLICES_DIV_WOUT)-1;

//constant dout_idx_max : natural := max(WOUT_DIV_PARALLEL_SLICES, PARALLEL_SLICES_DIV_WOUT)-1;
//DOUT_IDX_MAX maximum = 31 , DOUT_IDX_MAX = 2-1 if PARALLEL_SLICES=16

wire [`PARALLEL_SLICES-1:0] rcout;
rc round_constants (
    .clk (clk),
    .rst (rst),
    .round (round),
    .rcout (rcout)
);

wire [`DATAPATH_WIDTH - 1:0] dout_ram;
wire [`DATAPATH_WIDTH - 1:0] rcin;
wire [`DATAPATH_WIDTH - 1:0] transform_out;
wire [4:0] transform_z0;
transform transform_calc(
    .clk(clk),
    .rst(rst),
    .computation_en(computation_en),
    .round(round),
    .din(dout_ram),
    .rcin(rcin),
    .dout(transform_out),
    .dout_z0(transform_z0)
);

wire absorb;
reg first_round;
reg last_round;
reg [24:0] we;
reg [`DATAPATH_WIDTH - 1:0] din_ram;
reg [4:0] din_z0;
//wire [`CLOG2(`MAX_SUB_ROUNDS+1)-1:0] raddr;// from VHDL range,
wire [31:0]  raddr;// from VHDL range,

//reg [24:0] we_reg;

//always@(posedge clk)
//begin
//    we_reg <= we;
//end

state_ram state_ram_instance(
    .clk(clk),
    .rst(reset_ram),
    .bof(bof),
    .absorb(absorb),
    .first_round(first_round),
    .last_round(last_round),
    .load_hash(squeeze_output),
    .computation_en(computation_en),
    .raddr(raddr),
    .dout(dout_ram),
    .we(we),
    .din(din_ram),
    .din_z0(din_z0)
);

//assign raddr = ({{(32-`COUNTER_WIDTH){1'b0}} ,reads} + 1'b1) % `NUM_SUB_ROUNDS;
assign raddr = (reads + 1'b1) & (`NUM_SUB_ROUNDS-1);// % `NUM_SUB_ROUNDS;// %4 Only power of 2
/*always @(*) begin 
  raddr = (reads + 1) % `NUM_SUB_ROUNDS;
end*/

wire [`CLOG2(DOUT_IDX_MAX+1)-1:0] dout_idx;
wire [`CLOG2(25)-1:0] dout_ram_idx;
reg [`WOUT - 1:0] dout_reg;
reg [`WOUT - 1:0] dout_internal;
wire [`CLOG2(`WIN/`PARALLEL_SLICES)-1:0] din_offset;

// Below are logics
//assign dout_idx = reads % ((DOUT_IDX_MAX + 1));// Not sure, VHDL used to_integer
assign dout_idx = reads & (DOUT_IDX_MAX);// Not sure, VHDL used to_integer


//DOUT_IDX_MAX + 1 maximum = 32 , now it is 2
// dout_idx range: 0, 1
//assign dout_ram_idx = reads / `NUM_SUB_ROUNDS;
//assign dout_ram_idx = reads >> `CLOG2(`NUM_SUB_ROUNDS); // SHANQUAN's edit 32
assign dout_ram_idx = reads >> `DIVCLOG2(`NUM_SUB_ROUNDS);
// NUM_SUB_ROUNDS = 4 , dout_ram_idx range 

integer i0;
always @(dout_internal) begin
    for (i0=0; i0 <= `WOUT / 8 - 1; i0 = i0 + 1) begin
      dout[i0 * 8 + 7 -: 8] = dout_internal[i0 * 8 + 7 -: 8];
    end
end
/*
generate
    genvar i;
    for (i = 0; i < `WOUT / 8; i = i + 1) begin : output_remix
        always @(dout_internal) begin
            dout[i * 8 + 7:i * 8] <= dout_internal[7 + i * 8:i * 8];
        end
    end
endgenerate
*/


always @(dout_ram or dout_idx or dout_ram_idx or dout_reg) begin:hash_output
    dout_internal = dout_reg;
    if((WOUT_DIV_PARALLEL_SLICES >= PARALLEL_SLICES_DIV_WOUT)) begin
      dout_internal[dout_idx * `PARALLEL_SLICES + `PARALLEL_SLICES - 1 -:
                    `PARALLEL_SLICES] = dout_ram[dout_ram_idx * `PARALLEL_SLICES + `PARALLEL_SLICES - 1 -:
                                                  `PARALLEL_SLICES];
    
      /*
      dout_internal[dout_idx * `PARALLEL_SLICES + `PARALLEL_SLICES - 1:
                    dout_idx * `PARALLEL_SLICES] <= dout_ram[dout_ram_idx * `PARALLEL_SLICES + `PARALLEL_SLICES - 1:dout_ram_idx * `PARALLEL_SLICES];
    */
    end
    else begin
      dout_internal <= dout_ram[dout_ram_idx * `PARALLEL_SLICES + dout_idx * `WOUT + `PARALLEL_SLICES - 1 -:
                                `PARALLEL_SLICES];

    /*
      dout_internal <= dout_ram[dout_ram_idx * `PARALLEL_SLICES + dout_idx * `WOUT + `PARALLEL_SLICES - 1:
                                dout_ram_idx * `PARALLEL_SLICES + dout_idx * `WOUT];*/
    end
end


always @(posedge clk) begin:hash_output_reg
    if((rst == 1'b1)) begin
      dout_reg <= {`WOUT{1'b0}};
    end
    else begin
      dout_reg <= dout_internal;
    end
end


generate 
    if (`SUB_READS_COUNT_WIDTH > 0 && `WIN > `PARALLEL_SLICES) begin: din_offset_g_0
        assign din_offset = reads[`SUB_READS_COUNT_WIDTH - 1:0];
    end
endgenerate
generate 
    if (`SUB_READS_COUNT_WIDTH <= 0 && `WIN == `PARALLEL_SLICES) begin: din_offset_le_0
        assign din_offset = 0;
    end
endgenerate



integer i_0;


//always @(absorb_data or absorb_cust or round  // sanjay SHAKE deletion
always @(absorb_data or round 
  or dout_ram or din or din_offset or transform_z0 
  or transform_out or mux256) begin:ram_input
    if((absorb_data == 1'b1)) begin
      din_ram = {`DATAPATH_WIDTH{1'b0}};
      // calculate in-lane offset
      // absorb part of the message

      // The for loop here ?
      if (mux256 == 1'b0) begin
        for (i_0 = 0; i_0 < `RATE_128/`NUM_SLICES; i_0 = i_0 + 1) begin
            din_ram[(((i_0 * `PARALLEL_SLICES)) + `PARALLEL_SLICES - 1) -:
                      `PARALLEL_SLICES] = din;
        end
      end else begin
        for (i_0 = 0; i_0 < `RATE_256/`NUM_SLICES; i_0 = i_0 + 1) begin
            din_ram[(((i_0 * `PARALLEL_SLICES)) + `PARALLEL_SLICES - 1) -:
                      `PARALLEL_SLICES] = din;
        end
      end




      din_z0 = {5{1'b0}};
      first_round = 1'b1;
      last_round = 1'b0;
    end
//    else if((absorb_cust == 1'b1)) begin // sanjay SHAKE deletion
//      din_ram = {`DATAPATH_WIDTH{1'b0}};
//      // calculate in-lane offset
//      // absorb part of the message
//      din_ram[`PARALLEL_SLICES - 1:0] = din;
//      din_z0 = {5{1'b0}};
//      first_round = 1'b1;
//      last_round = 1'b0;
//    end
    else begin
      din_ram = transform_out;
      din_z0 = transform_z0;
      //if(((round / `NUM_SUB_ROUNDS) == 0)) begin
//      if(((round >> `CLOG2(`NUM_SUB_ROUNDS)) == 0)) begin // SHANQUAN's edit 32 
      if(((round >> `DIVCLOG2(`NUM_SUB_ROUNDS)) == 0)) begin
        first_round = 1'b1;
      end
      else begin
        first_round = 1'b0;
      end

      //if(((round / `NUM_SUB_ROUNDS) == `KECCAK_ROUNDS)) begin
//      if(((round >> `CLOG2(`NUM_SUB_ROUNDS)) == `KECCAK_ROUNDS)) begin //SHANQUAN's edit 32 
      if(((round >> `DIVCLOG2(`NUM_SUB_ROUNDS)) == `KECCAK_ROUNDS)) begin
        last_round = 1'b1;
      end
      else begin
        last_round = 1'b0;
      end
    end
end

integer i_1;

//always @(absorb_cust or absorb_data or reads // sanjay SHAKE deletion
always @(absorb_data or reads 
  or computation_en or bof or mux256) begin:write_enables
    if (mux256 == 1'b0) begin
      for (i_1 = 0; i_1 < `RATE_128/`NUM_SLICES; i_1 = i_1 + 1) begin
        if((absorb_data == 1'b1 
//          && i_1 == (reads[(`COUNTER_WIDTH-1):`SUB_READS_COUNT_WIDTH] >> `CLOG2((`NUM_SLICES / `WIN)) ))  SHANQUAN's edit 32
          && i_1 == (reads[(`COUNTER_WIDTH-1):`SUB_READS_COUNT_WIDTH] >> `DIVCLOG2((`NUM_SLICES / `WIN)) )) 
          || computation_en == 1'b1) begin
          we[i_1] = 1'b1;
        end
        else begin
          we[i_1] = 1'b0;
        end
      end
      
      for (i_1=`RATE_128/`NUM_SLICES; i_1 <= 24; i_1 = i_1 + 1) begin
        if(((absorb_data == 1'b1 && bof == 1'b1) || computation_en == 1'b1)) begin
          we[i_1] = 1'b1;
        end
        else begin
          we[i_1] = 1'b0;
        end
      end
    end else begin
      for (i_1 = 0; i_1 < `RATE_256/`NUM_SLICES; i_1 = i_1 + 1) begin
        if((absorb_data == 1'b1 
//          && i_1 == (reads[(`COUNTER_WIDTH-1):`SUB_READS_COUNT_WIDTH] >> `CLOG2((`NUM_SLICES / `WIN)) )) // SHANQUAN's 32 bit edit 
          && i_1 == (reads[(`COUNTER_WIDTH-1):`SUB_READS_COUNT_WIDTH] >> `DIVCLOG2((`NUM_SLICES / `WIN)) )) 
          || computation_en == 1'b1) begin
          we[i_1] = 1'b1;
        end
        else begin
          we[i_1] = 1'b0;
        end
      end
      
      for (i_1=`RATE_256/`NUM_SLICES; i_1 <= 24; i_1 = i_1 + 1) begin
        if(((absorb_data == 1'b1 && bof == 1'b1) || computation_en == 1'b1)) begin
          we[i_1] = 1'b1;
        end
        else begin
          we[i_1] = 1'b0;
        end
      end
    end

    

    // for the customization string of cshake for qTESLA, we have a simplified absorption phase, 
    // i.e. everything except the first lane (first 64 bit) are initialized to 0.
//    if((absorb_cust == 1'b1)) begin // sanjay SHAKE deletion
//      we = {25{1'b1}};
//    end
end




assign rcin[`DATAPATH_WIDTH - 1:`PARALLEL_SLICES] = {(`DATAPATH_WIDTH - `PARALLEL_SLICES){1'b0}};
assign rcin[`PARALLEL_SLICES - 1:0] = rcout;

//assign absorb = absorb_cust | absorb_data; // sanjay SHAKE deletion
assign absorb = absorb_data;







endmodule


