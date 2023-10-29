// =============================================================================
// ==                     Technology Innovation Institute                     ==
// =============================================================================
//
// hqc_rmdecod_expnsum.v
// Expand and Sum module of RM Decoding for HQC
//
//
//
// 202207xx TII Hardware Team
//
// =============================================================================

module hqc_rmdecod_expnsum #(

    parameter PARAM_SECURITY = 128,
    parameter MULTIPLICITY   = (PARAM_SECURITY == 128)? 3 : 5,
    parameter NWIDTH         = (PARAM_SECURITY == 128)? 2 : 3
    )(
    input                   clk_i,
    input                   rst_ni,
    input                   start_i,
    output                  start_ready_o,
    input   [127:0]         din_i,
    input                   din_valid_i,
    output                  din_ready_o,
    output                  dout_start_o,
    output  [NWIDTH-1:0]    dout0_o,
    output  [NWIDTH-1:0]    dout1_o,
    output                  dout_valid_o,
    input                   dout_ready_i
    );

integer                 ii;
reg                     din_ready;
reg                     start_ready;
reg                     dout_valid;
reg                     dout_start;
reg     [NWIDTH-1:0]    dout0, dout1;
wire    [NWIDTH-1:0]    add_out0, add_out1;

reg     [MULTIPLICITY*128-128-1:0]  din_buf;
reg     [MULTIPLICITY*128-1:0]      dout_buf;

wire            last_din;
reg     [2:0]   cnt;
reg     [7:0]   cnt_out;
reg             cnt_out_en;

//Input Buffer
always @(posedge clk_i)
if(din_valid_i & din_ready_o)
  din_buf <= {din_i, din_buf[128 +: MULTIPLICITY*128-128-128]};

//Input Buffer
always @(posedge clk_i)
if(din_valid_i & din_ready_o & last_din)
  dout_buf <= {din_i, din_buf};
else if(cnt_out_en)
  for(ii=0; ii<MULTIPLICITY; ii=ii+1)
    dout_buf[ii*128 +: 128] <= {2'd0, dout_buf[(ii*128+2) +: 126]};


//Adder
generate
if(MULTIPLICITY==3)
begin
  assign add_out0 = dout_buf[0] + dout_buf[128] + dout_buf[256];
  assign add_out1 = dout_buf[1] + dout_buf[129] + dout_buf[257];
end
else if(MULTIPLICITY==5)
begin
  assign add_out0 = dout_buf[0] + dout_buf[128] + dout_buf[256] + dout_buf[384] + dout_buf[512];
  assign add_out1 = dout_buf[1] + dout_buf[129] + dout_buf[257] + dout_buf[385] + dout_buf[513];
end

endgenerate

always @(posedge clk_i)
if(cnt_out_en)
begin
  dout0 <= add_out0;
  dout1 <= add_out1;
end

assign dout0_o = dout0;
assign dout1_o = dout1;

//------------------------------------------------------------------------------
//Controller
//Input
always @(posedge clk_i)
if(~rst_ni | start_i | last_din)
  cnt <= 0;
else if(din_valid_i & din_ready_o)
  cnt <= cnt + 1;

assign last_din = cnt==(MULTIPLICITY*128/128-1) & din_valid_i & din_ready_o;

always @(posedge clk_i)
  din_ready <= start_ready;

assign din_ready_o = din_ready;

always @(posedge clk_i)
if(~rst_ni | cnt_out==(59))
  start_ready <= 1;
else if(cnt==(MULTIPLICITY*128/128-2) & din_valid_i & din_ready_o)
  start_ready <= 0;

assign start_ready_o = start_ready;

//output
always @(posedge clk_i)
  dout_start <= last_din;

assign dout_start_o = dout_start;

always @(posedge clk_i)
if(~rst_ni | last_din)
  cnt_out <= 0;
else if(cnt_out_en)
  cnt_out <= cnt_out + 1;

always @(posedge clk_i)
if(~rst_ni | cnt_out==63 & ~last_din)
  cnt_out_en <= 0;
else if(last_din)
  cnt_out_en <= 1;

always @(posedge clk_i)
begin
  dout_valid <= cnt_out_en;
end

assign dout_valid_o = dout_valid;

endmodule
