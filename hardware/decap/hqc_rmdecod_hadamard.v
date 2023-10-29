// =============================================================================
// ==                     Technology Innovation Institute                     ==
// =============================================================================
//
// hqc_rmdecod_hadamard.v
// Hadamard module of RM Decoding for HQC
//
//
//
// 202207xx TII Hardware Team
//
// =============================================================================


module hqc_rmdecod_hadamard #(

    parameter PARAM_SECURITY = 128,
    parameter MULTIPLICITY   = (PARAM_SECURITY == 128)? 3 : 5,
    parameter DIN_W          = (PARAM_SECURITY == 128)? 2 : 3,
    parameter DOUT_W         = 1 + DIN_W + 7
    )(
    input                   clk_i,
    input                   rst_ni,
    input                   start_i,
    input   [DIN_W-1:0]     din0_i,
    input   [DIN_W-1:0]     din1_i,
    input                   din_valid_i,
    output                  dout_start_o,
    output  [DOUT_W-1:0]    dout0_o,
    output  [DOUT_W-1:0]    dout1_o,
    output                  dout_valid_o
    );

wire                    start[0:7];
wire    [DOUT_W-1:0]    data0[0:7];
wire    [DOUT_W-1:0]    data1[0:7];
wire                    data_valid[0:7];

reg                     dout_start_d;

reg     [DOUT_W-1:0]    dout0_d;
reg     [DOUT_W-1:0]    dout1_d;
reg                     dout_valid_d;
wire    [DOUT_W-1:0]    dout0_t;
wire    [DOUT_W-1:0]    dout1_t;
wire                    dout_valid_t;

genvar      ii;

//Input assignment
assign data0[0]      = {8'd0, din0_i};
assign data1[0]      = {8'd0, din1_i};
assign start[0]      = start_i;
assign data_valid[0] = din_valid_i;


//Delayed output start
always @(posedge clk_i)
  dout_start_d <= start[7];

always @(posedge clk_i)
begin
  dout0_d      <= dout0_t;
  dout1_d      <= dout1_t;
  dout_valid_d <= dout_valid_t;
end

//Outputs assignment
assign dout_start_o  = dout_start_d;

// fix the first entry to get the half Hadamard transform
// transform[0] -= 64 * MULTIPLICITY;
// only for the first hadamard output
assign dout0_t      = dout_start_d? (data0[7]-64*MULTIPLICITY) : data0[7];
assign dout1_t      = data1[7];
assign dout_valid_t = data_valid[7];

assign dout0_o      = dout0_d;
assign dout1_o      = dout1_d;
assign dout_valid_o = dout_valid_d;


//Layer connections
generate
  for(ii=0;ii<7;ii=ii+1)
  begin: HADAMARD_LAYER
    hadamard_layer #(.NN(DIN_W+1+ii))
    HL(
        .clk_i        (clk_i           ),
        .rst_ni       (rst_ni          ),
        .start_i      (start[ii]       ),
        .din0_i       (data0[ii][DIN_W+ii:0]       ),
        .din1_i       (data1[ii][DIN_W+ii:0]       ),
        .din_valid_i  (data_valid[ii]  ),
        .dout_start_o (start[ii+1]     ),
        .dout0_o      (data0[ii+1][DIN_W+ii+1:0]     ),
        .dout1_o      (data1[ii+1][DIN_W+ii+1:0]     ),
        .dout_valid_o (data_valid[ii+1]));
  end
endgenerate


endmodule


module hadamard_layer #(

    parameter NN        = 3,
    parameter MM        = NN + 1
    )(
    input               clk_i,
    input               rst_ni,
    input               start_i,
    input   [NN-1:0]    din0_i,
    input   [NN-1:0]    din1_i,
    input               din_valid_i,
    output              dout_start_o,
    output  [MM-1:0]    dout0_o,
    output  [MM-1:0]    dout1_o,
    output              dout_valid_o
    );

reg                 dout_valid;
reg     [MM-1:0]    add_out0, add_out1;

wire                fifo_f0_wr;
wire                fifo_f0_rd;
wire    [MM-1:0]    fifo_f0_din;
wire                fifo_f0_empty;
wire                fifo_f0_full;
wire    [MM-1:0]    fifo_f0_dout;

wire                fifo_f1_wr;
wire                fifo_f1_rd;
wire    [MM-1:0]    fifo_f1_din;
wire                fifo_f1_empty;
wire                fifo_f1_full;
wire    [MM-1:0]    fifo_f1_dout;

wire                fifo_s0_wr;
wire                fifo_s0_rd;
wire    [MM-1:0]    fifo_s0_din;
wire                fifo_s0_empty;
wire                fifo_s0_full;
wire    [MM-1:0]    fifo_s0_dout;

wire                fifo_s1_wr;
wire                fifo_s1_rd;
wire    [MM-1:0]    fifo_s1_din;
wire                fifo_s1_empty;
wire                fifo_s1_full;
wire    [MM-1:0]    fifo_s1_dout;


reg     [5:0]   cnt_in, cnt_out;
wire            last_din;
reg             even_in_d, odd_in_d;
wire            cnt_out_start;
reg             cnt_out_en;
reg             dout_start;
reg             second_half_out;



//------------------------------------------------------------------------------
//Calculation
always @(posedge clk_i)
if(din_valid_i)
begin
  add_out0 <= {din0_i[NN-1], din0_i} + {din1_i[NN-1], din1_i};
  add_out1 <= {din0_i[NN-1], din0_i} - {din1_i[NN-1], din1_i};
end


//------------------------------------------------------------------------------
//FIFOs
//FIFO first half, even
syncfifo #(.DW    (MM   ),
           .AW    (5    )) //0,2...,62; 32 addr
FIFO_F0
( .clk_i   (clk_i        ),
  .rst_ni  (rst_ni       ),
  .wr_i    (fifo_f0_wr   ),
  .rd_i    (fifo_f0_rd   ),
  .din_i   (fifo_f0_din  ),
  .empty_o (fifo_f0_empty),
  .full_o  (fifo_f0_full ),
  .dout_o  (fifo_f0_dout ));

assign fifo_f0_wr  = even_in_d;
assign fifo_f0_rd  = ~cnt_out[5] & cnt_out_en;
assign fifo_f0_din = add_out0;


//FIFO first half, odd
syncfifo #(.DW    (MM   ),
           .AW    (5    )) //1,3...,63; 32 addr
FIFO_F1
( .clk_i   (clk_i        ),
  .rst_ni  (rst_ni       ),
  .wr_i    (fifo_f1_wr   ),
  .rd_i    (fifo_f1_rd   ),
  .din_i   (fifo_f1_din  ),
  .empty_o (fifo_f1_empty),
  .full_o  (fifo_f1_full ),
  .dout_o  (fifo_f1_dout ));

assign fifo_f1_wr  = odd_in_d;
assign fifo_f1_rd  = ~cnt_out[5] & cnt_out_en;
assign fifo_f1_din = add_out0;

//FIFO second half, even
syncfifo #(.DW    (MM   ),
           .AW    (5    )) //0,2...,62; 32 addr
FIFO_S0
( .clk_i   (clk_i        ),
  .rst_ni  (rst_ni       ),
  .wr_i    (fifo_s0_wr   ),
  .rd_i    (fifo_s0_rd   ),
  .din_i   (fifo_s0_din  ),
  .empty_o (fifo_s0_empty),
  .full_o  (fifo_s0_full ),
  .dout_o  (fifo_s0_dout ));

assign fifo_s0_wr  = even_in_d;
assign fifo_s0_rd  = cnt_out[5] & cnt_out_en;
assign fifo_s0_din = add_out1;

//FIFO second half, odd
syncfifo #(.DW    (MM   ),
           .AW    (5    )) //1,3...,63; 32 addr
FIFO_S1
( .clk_i   (clk_i        ),
  .rst_ni  (rst_ni       ),
  .wr_i    (fifo_s1_wr   ),
  .rd_i    (fifo_s1_rd   ),
  .din_i   (fifo_s1_din  ),
  .empty_o (fifo_s1_empty),
  .full_o  (fifo_s1_full ),
  .dout_o  (fifo_s1_dout ));

assign fifo_s1_wr  = odd_in_d;
assign fifo_s1_rd  = cnt_out[5] & cnt_out_en;
assign fifo_s1_din = add_out1;

//------------------------------------------------------------------------------
//Controller
//Input Counter
always @(posedge clk_i)
if(~rst_ni | start_i | last_din)
  cnt_in <= 0;
else if(din_valid_i)
  cnt_in <= cnt_in + 1;

always @(posedge clk_i)
begin
  even_in_d <= ~cnt_in[0] & din_valid_i;
  odd_in_d  <=  cnt_in[0] & din_valid_i;
end

assign last_din = cnt_in==63 & din_valid_i;

//Output Counter
always @(posedge clk_i)
if(~rst_ni | cnt_out_start | cnt_out==63)
  cnt_out <= 0;
else if(cnt_out_en)
  cnt_out <= cnt_out + 1;

assign cnt_out_start = cnt_in==32 & din_valid_i;

always @(posedge clk_i)
if(~rst_ni | cnt_out==63 & ~cnt_out_start)
  cnt_out_en <= 0;
else if(cnt_out_start)
  cnt_out_en <= 1;

always @(posedge clk_i)
  second_half_out <= cnt_out_en & cnt_out[5];

always @(posedge clk_i)
begin
  dout_start <= cnt_out_start;
  dout_valid <= cnt_out_en;
end

//Outputs assignment
assign dout0_o = second_half_out? fifo_s0_dout : fifo_f0_dout;
assign dout1_o = second_half_out? fifo_s1_dout : fifo_f1_dout;

assign dout_start_o = dout_start;
assign dout_valid_o = dout_valid;

endmodule