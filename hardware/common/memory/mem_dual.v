/*
 * Dual-ported memory module.
 *
 * Public domain.
 *
 */

module mem_dual
#(
  parameter WIDTH = 8,
  parameter DEPTH = 64,
  parameter FILE = "",
  parameter INIT = 0
)
(
  input  wire                 clock,
  input  wire [WIDTH-1:0]     data_0,
  input  wire [WIDTH-1:0]     data_1,
  input  wire [`CLOG2(DEPTH)-1:0] address_0,
  input  wire [`CLOG2(DEPTH)-1:0] address_1,
  input  wire                 wren_0,
  input  wire                 wren_1,
  output reg  [WIDTH-1:0]     q_0,
  output reg  [WIDTH-1:0]     q_1
);

 (* ram_style = "block" *) reg [WIDTH-1:0] mem [0:DEPTH-1] /* synthesis ramstyle = "M20K" */;
//(* ram_style =  "registers" *)  reg [WIDTH-1:0] mem [0:DEPTH-1] /* synthesis ramstyle = "M20K" */;

  integer file;
  integer scan;
  integer i;

  initial
    begin
      // read file contents if FILE is given
      if (FILE != "")
        $readmemb(FILE, mem);

      // set all data to 0 if INIT is true
      if (INIT)
        for (i = 0; i < DEPTH; i = i + 1)
          mem[i] = {WIDTH{1'b0}};
   end

  always @ (posedge clock)
  begin
    if (wren_0)
      begin
        mem[address_0] <= data_0;
        q_0 <= data_0;
      end
    else
      q_0 <= mem[address_0];
  end

  always @ (posedge clock)
  begin
    if (wren_1)
      begin
        mem[address_1] <= data_1;
        q_1 <= data_1;
      end
    else
      q_1 <= mem[address_1];
  end

endmodule

