// =============================================================================
// ==                     Technology Innovation Institute                     ==
// =============================================================================
//
// hqc_rsdecod_zpoly.v
// Compute polynomial z(x) module of RS Decoding for HQC
//
//
//
// 202207xx TII Hardware Team
//
// =============================================================================

module hqc_rsdecod_zpoly #(

    parameter PARAM_SECURITY = 128,
    parameter PARAM_DELTA    = (PARAM_SECURITY == 128)? 15:
                               (PARAM_SECURITY == 192)? 16:
                               (PARAM_SECURITY == 256)? 29 : 15,
    parameter SYN_W          = 8*PARAM_DELTA,
    parameter DIN_W          = 8*(PARAM_DELTA+1),
    parameter DOUT_W         = 8*(PARAM_DELTA+1)
    )(
    input                   clk_i,
    input                   rst_ni,
    input   [SYN_W-1:0]     synd_i,  //syndrome, first DELTA syndromes
    input   [DIN_W-1:0]     sigma_i, //sigma
    input                   start_i,
    input   [7:0]           deg_sigma_i, //degree of sigma
    output                  busy_o,
    output  [DOUT_W-1:0]    dout_o, //z poly
    output                  dout_valid_o
    );

reg     [DOUT_W-1:0]    dout;
reg     [SYN_W-1:0]     syndrome_buf1, syndrome_buf2;
reg     [DIN_W-1:0]     sigma_buf;

reg     [7:0]   i_sigma, z_buf;
wire    [7:0]   z, gf_mul_out;
wire            mask;

reg     [5:0]   i_cnt, j_cnt;
wire            i_cnt_en, j_cnt_en, j_cnt_end, busy_end;
reg             busy, dout_valid;


//First D syndromes = {m[D-1],m[D-2],...,m[1],m[0]} with m[i] in byte
//Syndromes buffer from input, shift right in each i_cnt
always @(posedge clk_i)
if(start_i)
  syndrome_buf1 <= synd_i;
else if(i_cnt_en)
  syndrome_buf1 <= {syndrome_buf1[7:0], syndrome_buf1[8*PARAM_DELTA-1:8]};

//Syndromes buffer from buffer1, shift left in each j_cnt
always @(posedge clk_i)
if(i_cnt_en)
  syndrome_buf2 <= syndrome_buf1;
else if(j_cnt_en)
  syndrome_buf2 <= {syndrome_buf2[8*PARAM_DELTA-8-1:0], syndrome_buf2[8*PARAM_DELTA-1 -: 8]};


//Sigma buffer from input in start or each i_cnt, shift right in each j_cnt
always @(posedge clk_i)
if(start_i | i_cnt_en)
  sigma_buf <= sigma_i;
else if(j_cnt_en)
  sigma_buf <= {sigma_buf[7:0], sigma_buf[8*PARAM_DELTA-1:8]};

always @(posedge clk_i)
if(i_cnt_en)
  i_sigma <= (i_cnt==0)? sigma_buf[15:8] : sigma_buf[23:16];

//Calculate z poly
always @(posedge clk_i)
if(start_i)
  dout <= 'h0;
else if(i_cnt_en)
  dout <= {z, dout[DOUT_W-1:8]};

assign dout_o = dout;

assign z = (i_cnt==0)? 1 :
           mask? ((j_cnt==0)? i_sigma ^ syndrome_buf2[7:0] :
                              z_buf ^ gf_mul_out) :
                 0;

always @(posedge clk_i)
if(j_cnt_en)
  z_buf <= mask? z : 0;

assign mask = (i_cnt < (deg_sigma_i+1));


//gf_mul(sigma[j], syndrome[i-j-1])
gfmul #(.REG_IN  (0),
        .REG_OUT (0))
GF_MUL(
    .clk   (clk_i             ),
    .start (1                 ),
    .in_1  (syndrome_buf2[7:0]),
    .in_2  (sigma_buf[7:0]    ),
    .out   (gf_mul_out        ),
    .done  (                  )
);


//------------------------------------------------------------------------------
//Controller
//Input Counter
always @(posedge clk_i)
if(~rst_ni | busy_end)
  busy <= 0;
else if(start_i)
  busy <= 1;

assign busy_o = busy;

always @(posedge clk_i)
if(~rst_ni | start_i | busy_end)
  i_cnt <= 0;
else if(i_cnt_en)
  i_cnt <= i_cnt + 1;

assign i_cnt_en = j_cnt_end & busy;
assign busy_end = (i_cnt==PARAM_DELTA) & i_cnt_en;


always @(posedge clk_i)
if(~rst_ni | start_i | i_cnt_en)
  j_cnt <= 0;
else if(j_cnt_en)
  j_cnt <= j_cnt + 1;

assign j_cnt_en  = busy;
assign j_cnt_end = (i_cnt==0)? 0 : (i_cnt-1);


always @(posedge clk_i)
  dout_valid <= busy_end;

assign dout_valid_o = dout_valid;



endmodule
