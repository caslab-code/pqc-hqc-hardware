// =============================================================================
// ==                     Technology Innovation Institute                     ==
// =============================================================================
//
// add_fft.v
// Additive FFT
//
//
//
//
// 202207xx TII Hardware Team
//
// =============================================================================

module add_fft #(
    parameter DIN_W          = 32*8,
    parameter AW             = 8,
    parameter DW             = 8
    )(
    input                   clk_i,
    input                   rst_ni,
    input                   start_i,
    output                  start_o,
    // output                  busy_o,
    output                  done_o,

    //Input/output data
    input   [DIN_W-1:0]     din_i,
    output  [DW-1:0]        ram_din_o,
    output  [AW-1:0]        ram_addr_o,
    output                  ram_wr
    );

integer ii;
reg     [DIN_W-1:0]   fft1_din;
wire            fft1_busy;
wire            fft1_done;
wire    [7:0]   fft1_dout;
wire            fft1_dout_rd;

reg     [7:0]   cnt;
reg             cnt_en;
wire    [7:0]   bf_a0, bf_a1, bf_a2, bf_a3;
reg     [7:0]   a2_buf;
wire            bf_din_vld;
wire    [7:0]   bf_dout;
wire            bf_dout_vld;

wire            fft2_start_in, fft2_start_out;
wire            fft2_busy;
wire            fft2_done;
wire    [7:0]   fft2_din;
reg             fft2_din_vld;
wire    [7:0]   fft2_dout;
wire            fft2_dout_vld;

reg     [7:0]   fft2_cnt;
reg     [7:0]   cnt_out;

//swap input data
//din = {din31, ..., din1, din0}
//fft_din = {din0, din1, ..., din31}
always @(*)
begin
for(ii=0; ii<DIN_W/8; ii=ii+1)
  fft1_din[ii*8 +: 8] = din_i[(DIN_W/8-ii-1)*8 +: 8];
end

fft_part1 #(
    .DIN_W        (DIN_W),
    .DOUT_W       (4*8  ))
FFT_PART1(
    .clk_i        (clk_i    ),
    .rst_ni       (rst_ni   ),
    .start_i      (start_i  ),
    // .start_o      (),
    .busy_o       (fft1_busy),
    .done_o       (fft1_done),
    .din_i        (fft1_din  ),
    .dout_read_i  (fft1_dout_rd),
    .dout_o       (fft1_dout),
    .dout_valid_o ()
    );


assign fft1_dout_rd = cnt[4:0]==23 & cnt_en;
assign {bf_a0, bf_a1, bf_a2, bf_a3} = fft1_dout;
assign bf_din_vld = cnt[4:0]==0 & cnt_en;

//FFT1 output
always @(posedge clk_i)
if(~rst_ni | start_i | fft1_done | cnt==255)
  cnt <= 0;
else if(cnt_en)
  cnt <= cnt + 1;

always @(posedge clk_i)
if(~rst_ni | start_i | cnt==255)
  cnt_en <= 0;
else if(fft1_done)
  cnt_en <= 1;

always @(posedge clk_i)
if(cnt[4:0]==15 & cnt_en)
  a2_buf <= bf_a2;

fft_leaves_butterfly BUTTERFLY (
    .clk_i        (clk_i    ),
    .rst_ni       (rst_ni   ),
    .start_i      (bf_din_vld),
    .busy_o       (),
    .a0_i         (bf_a0    ),
    .a1_i         (bf_a1    ),
    .dout_o       (bf_dout  ),
    .dout_valid_o (bf_dout_vld)
    );


always @(posedge clk_i)
if(~rst_ni | start_i | fft2_start_in | fft2_cnt==255)
  fft2_cnt <= 0;
else if(fft2_din_vld)
  fft2_cnt <= fft2_cnt + 1;


always @(posedge clk_i)
if(~rst_ni | start_i | fft2_cnt==255)
  fft2_din_vld <= 0;
else if(fft2_start_in)
  fft2_din_vld <= 1;


assign fft2_start_in = cnt==4;
assign fft2_din = fft2_cnt[4]? a2_buf : bf_dout;

fft_part2 FFT_PART2(
    .clk_i        (clk_i    ),
    .rst_ni       (rst_ni   ),
    .start_i      (fft2_start_in),
    .start_o      (fft2_start_out),
    .busy_o       (fft2_busy ),
    .done_o       (fft2_done ),
    .din_i        (fft2_din  ),
    .din_valid_i  (fft2_din_vld),
    .dout_o       (fft2_dout ),
    .dout_valid_o (fft2_dout_vld)
    );

//Output
always @(posedge clk_i)
if(~rst_ni | start_i | fft2_start_out | cnt_out==255)
  cnt_out <= 0;
else if(fft2_dout_vld)
  cnt_out <= cnt_out + 1;

assign ram_addr_o = cnt_out;
assign ram_din_o  = fft2_dout;
assign ram_wr     = fft2_dout_vld;
assign done_o     = fft2_done;

endmodule