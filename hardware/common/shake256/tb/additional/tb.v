
/*
 * This is a module for cSHAKE, it is translated manually from tb.vhd, 
 * which was developed by Bernhard Jungk <bernhard@projectstarfire.de>
 * 
 * Copyright (C): 2019
 * Author:        Shanquan Tian <shanquan.tian@yale.edu>
 * Updated:       2019-06-17
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



module cshake_tb;

`include "testvectors.v"
// here `WIN should be 32

reg clk = 1'b0;
always 
  #20 clk = !clk;

reg rst;
integer start_time;

initial begin
    rst = 1'b1;
    #100;
    rst = 1'b0;
    start_time = $time;
    $display("/************ Some Parameters **************/");
    $display("PARALLEL_SLICES = %d", `PARALLEL_SLICES);
`ifdef PARALLEL_SLICES_LARGER_THAN_1
    $display("PARALLEL_SLICES_LARGER_THAN_1 was defined!");
`endif
    $display("/*******************************************/\n");
    $display("/*********** Experiment Result *************/");
end

integer din_endTime;
always @(negedge din_valid) begin
  din_endTime <= $time;
end


reg din_valid;
wire din_ready;
reg [`WIN - 1:0] din;
wire dout_valid;
reg dout_ready;
wire [`WOUT - 1:0] dout; 

keccak_top cshake_simple
(
    .rst(rst),
    .clk(clk),
    .din_valid(din_valid),
    .din_ready(din_ready),
    .din(din),
    .dout_valid(dout_valid),
    .dout_ready(dout_ready),
	.force_done(force_done),
    .dout(dout)
);

reg [31:0] counter_din = 0;
reg [31:0] wait_counter_din = 0;
parameter MAX_WAIT_COUNTER_DIN = 10;
reg [31:0] counter_dout = 0;
reg [31:0] wait_counter_dout = 0;
parameter MAX_WAIT_COUNTER_DOUT = 10;


always @(posedge clk) begin
    if((rst == 1'b1)) begin
      din <= {`WIN{1'b0}};
      counter_din <= 0;
      wait_counter_din <= 0;
    end
    else begin
      //if(counter_din < testvector_input'length and wait_counter_din = max_wait_counter_din) then
      if((counter_din < TESTVECTOR_INPUT_SIZE && wait_counter_din == MAX_WAIT_COUNTER_DIN)) begin
        if((din_valid == 1'b0 || din_ready == 1'b1)) begin
          //din <= TESTVECTOR_INPUT[(counter_din+1)*`WIN-1-:`WIN];
          din <= TESTVECTOR_INPUT[(counter_din)*`WIN+:`WIN];
          din_valid <= 1'b1;
          wait_counter_din <= 0;
          counter_din <= counter_din + 1'b1;
        end
      end
      else begin
        if((din_ready == 1'b1)) begin
          din_valid <= 1'b0;
        end
        if((din_valid == 1'b 0 && wait_counter_din < MAX_WAIT_COUNTER_DIN)) begin
          wait_counter_din <= wait_counter_din + 1'b1;
        end
      end
    end
end

reg [31:0] counter_doutValid = 0;
always @(posedge clk) begin
    if((rst == 1'b1)) begin
      dout_ready <= 1'b1;
      counter_dout <= 0;
      wait_counter_dout <= 0;
      counter_doutValid <= 0;
    end
    else begin
      //if(counter_dout >= testvector_output'length) then
      if((counter_dout >= TESTVECTOR_OUTPUT_SIZE)) begin
        if (counter_doutValid != 0) begin
          $display("Success, simulation ended! Runnign cycles = %d", ($time-start_time)/40);
          $display("         Runnign cycles of %6d outputs = %d\n", counter_doutValid, ($time- din_endTime)/40);
          $finish;
        end
        else begin
          $display("Failure, no valid output!\n");
          $finish;
        end
        
      end
      //elsif(counter_dout < testvector_output'length and wait_counter_dout = max_wait_counter_dout) then
      else if((counter_dout < TESTVECTOR_OUTPUT_SIZE && wait_counter_dout == MAX_WAIT_COUNTER_DOUT)) begin
        dout_ready <= 1'b1;
        wait_counter_dout <= 0;
      end
      else begin
        if((dout_valid == 1'b1)) begin
          counter_doutValid <= counter_doutValid + 1'b1;
          //assert(dout = testvector_output(counter_dout)) report "Failure, dout is not correct!" severity failure;
          //[(counter_din+1)*`WIN-1-:`WIN]
          //if (dout != TESTVECTOR_OUTPUT[(counter_dout+1)*`WOUT-1-:`WOUT]) begin 
          if (dout != TESTVECTOR_OUTPUT[(counter_dout)*`WOUT +:`WOUT]) begin 
            $display("Failure, dout is not correct!\n dout = %h , TESTVECTOR_OUTPUT = %h\n ", dout, TESTVECTOR_OUTPUT[(counter_dout)*`WOUT +:`WOUT]);
            $finish;
          end

          if ( ^dout === 1'bx) begin
            $display("Failure, dout is %b!\n", dout);
            $finish;
          end

        end



        if((dout_valid == 1'b1 && dout_ready == 1'b1)) begin
          if((MAX_WAIT_COUNTER_DOUT > 0)) begin
            dout_ready <= 1'b0;
          end
          //assert(dout = testvector_output(counter_dout)) report "Failure, dout is not correct!" severity failure;
          //if (dout != TESTVECTOR_OUTPUT[(counter_dout+1)*`WOUT-1-:`WOUT]) begin 
          if (dout != TESTVECTOR_OUTPUT[(counter_dout)*`WOUT +:`WOUT]) begin 
            $display("Failure, dout is not correct!\n dout = %h , TESTVECTOR_OUTPUT = %h\n ", dout, TESTVECTOR_OUTPUT[(counter_dout)*`WOUT +:`WOUT]);
            $finish;
          end
          if ( ^dout === 1'bx) begin
            $display("Failure, dout is %b!\n", dout);
            $finish;
          end
          counter_dout <= counter_dout + 1'b1;
        end


        if((dout_ready == 1'b0 && wait_counter_dout < MAX_WAIT_COUNTER_DOUT)) begin
          wait_counter_dout <= wait_counter_dout + 1'b1;
        end
      end
    end
end




endmodule // cshake_tb
