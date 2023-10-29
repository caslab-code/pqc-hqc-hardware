/*------------------------------------------------------------------------------
File        : syncfifo.v
Author      : Ma'muri
Description : simple synchronous FIFO

------------------------------------------------------------------------------*/

module syncfifo
       #(parameter DW = 2*12,
         parameter AW = 7,
         parameter DEPTH = 1<<AW)
(
  input             clk_i,
  input             rst_ni,
  input             wr_i,
  input             rd_i,
  input   [DW-1:0]  din_i,
  output            empty_o,
  output            full_o,
  output  [DW-1:0]  dout_o
);


reg     [DW-1:0]    fifo[0:DEPTH-1];
reg     [DW-1:0]    rd_data, wr_data;
reg     [AW-1:0]    wr_addr=0, next_wr_addr=1, rd_addr=0, next_rd_addr=1;
reg                 full=0, empty=1, wr_rd=0;

wire                wr_v, rd_v;
wire    [AW-1:0]    wr_addr_plus_one, wr_addr_plus_two;

assign wr_v = wr_i & (~full | rd_i);
assign rd_v = rd_i & (~empty | wr_i);

assign wr_addr_plus_one = wr_addr + 1;
assign wr_addr_plus_two = wr_addr + 2;

//Full logic
always @(posedge clk_i)
if(~rst_ni)
  full <= 0;
else if(rd_i)
  full <= full & wr_i;
else if(wr_v)
  full <= full | (next_wr_addr == rd_addr);

assign full_o = full;

//write address
always @(posedge clk_i)
if(~rst_ni) begin
  wr_addr      <= 0;
  next_wr_addr <= 1;
end
else if(wr_v) begin
  wr_addr      <= wr_addr_plus_one;
  next_wr_addr <= wr_addr_plus_two;
end

//fifo write
always @(posedge clk_i)
if(wr_v)
  fifo[wr_addr] <= din_i;
  // fifo[wr_addr_plus_one] <= din_i;

//Empty logic
always @(posedge clk_i)
if(~rst_ni)
  empty <= 1;
else if(wr_i)
  empty <= rd_i? empty : 0;
else if(rd_v)
  empty <= empty | (next_rd_addr == wr_addr);

assign empty_o = empty;

//read address
always @(posedge clk_i)
if(~rst_ni) begin
  rd_addr      <= 0;
  next_rd_addr <= 1;
end
else if(rd_v)begin
  rd_addr      <= rd_addr + 1;
  next_rd_addr <= rd_addr + 2;
end

//data read
always @(posedge clk_i)
if(rd_v)
  rd_data <= fifo[rd_addr];

//write when empty or write and read before empty
always @(posedge clk_i)
if(~rst_ni) begin
  wr_rd   <= 0;
end
else if(wr_i & (empty | rd_v & (rd_addr == wr_addr))) begin
  wr_rd   <= 1;
  wr_data <= din_i;
end
else if(rd_i) begin
  wr_rd   <= 0;
end

assign dout_o = wr_rd? wr_data : rd_data;

endmodule