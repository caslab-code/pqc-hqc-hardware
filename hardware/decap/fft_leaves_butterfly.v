// =============================================================================
// ==                     Technology Innovation Institute                     ==
// =============================================================================
//
// fft_leaves_butterfly.v
// Subroutine of the fft function that computes the last butterflies over 16 coeffs
//
//
//
//
// 202207xx TII Hardware Team
//
// =============================================================================

module fft_leaves_butterfly #(

    parameter DIN_W          = 8,
    parameter DOUT_W         = 8
    )(
    input                   clk_i,
    input                   rst_ni,
    input                   start_i,
    output                  busy_o,

    //Input/output data
    input   [DIN_W-1:0]     a0_i,
    input   [DIN_W-1:0]     a1_i,
    output  [DOUT_W-1:0]    dout_o,
    output                  dout_valid_o
    );

reg     [7:0]           dout, dout_prev;
reg     [4*8-1:0]       tmp;
wire    [7:0]           t0, t01, t012, t0123, tmp_out;
wire    [7:0]           gf_in, gf_out;

reg     [3:0]   cnt;
reg             init_state, compute_state;
reg             busy, dout_valid;

//t0 = gfmul(0x08, a1), t1 = gfmul(0x54, a1), t2 = gfmul(0x9d, a1), t3 = gfmul(0x4e, a1)
//after init state: tmp = {t0, t0^t1, t0^t1^t2, t0^t1^t2^t3}
always @(posedge clk_i)
if(start_i)
  tmp <= 32'h0;
  // betas_tmp <= {8'h08, 8'h54, 8'h9d, 8'h4e};
else if(init_state)
  tmp <= {tmp[23:0], gf_out^tmp[7:0]};

assign {t0, t01, t012, t0123} = tmp;
assign tmp_out = (cnt==7)? t0123 :
                 (cnt==3 | cnt==11)? t012 :
                 (cnt==1 | cnt==5 | cnt==9 | cnt==13)? t01 : t0;

always @(posedge clk_i)
if(start_i|init_state)
  dout <= a0_i;
else if(compute_state & cnt!=15)
  dout <= dout ^ tmp_out;

assign dout_o = dout;


//Calculate dd
//dd = gf_mul(d,inv_dp)
gfmul #(.REG_IN  (0),
        .REG_OUT (0))
DD_MUL(
    .clk   (clk_i        ),
    .start (1            ),
    .in_1  (a1_i         ),
    .in_2  (gf_in        ),
    .out   (gf_out       ),
    .done  (             )
);

assign gf_in = cnt==0? 8'h08 :
               cnt==1? 8'h54 :
               cnt==2? 8'h9d : 8'h4e;


//------------------------------------------------------------------------------
//Controller
//Input Counter
always @(posedge clk_i)
if(~rst_ni)
  busy <= 0;
else if(start_i)
  busy <= 1;
else if(compute_state & cnt==15)
  busy <= 0;

assign busy_o = busy;

always @(posedge clk_i)
if(~rst_ni | start_i | init_state & cnt==3 | compute_state & cnt==15)
  cnt <= 0;
else if(busy)
  cnt <= cnt + 1;

always @(posedge clk_i)
if(~rst_ni)
  init_state <= 0;
else if(start_i)
  init_state <= 1;
else if(init_state & cnt==3)
  init_state <= 0;

always @(posedge clk_i)
if(~rst_ni | start_i)
  compute_state <= 0;
else if(init_state & cnt==3)
  compute_state <= 1;
else if(compute_state & cnt==15)
  compute_state <= 0;

assign dout_valid_o = compute_state;


endmodule
