// =============================================================================
// ==                     Technology Innovation Institute                     ==
// =============================================================================
//
// fft_part1.v
// Part1 of additive fft
//
//
//
//
// 202207xx TII Hardware Team
//
// =============================================================================

module fft_part1 #(
    parameter DIN_W          = 32*8,
    parameter DOUT_W         = 4*8
    )(
    input                   clk_i,
    input                   rst_ni,
    input                   start_i,
    // output                  start_o,
    output                  busy_o,
    output                  done_o,

    //Input/output data
    input   [DIN_W-1:0]     din_i,
    input                   dout_read_i,
    output  [DOUT_W-1:0]    dout_o,
    output                  dout_valid_o
    );



reg     [32*8-1:0]  buff; //= {b0, b1,..., b31}
wire    [32*8-1:0]  next_buff_044, next_buff_111, next_buff_114, next_buff_144, next_buff_211, next_buff_214, next_buff_244;

wire    [32*8-1:0]  temp0, temp1, temp2, temp3, temp4, temp5, temp6, temp7, temp8;


wire    [7:0]       radix_a0, radix_a1, radix_a2, radix_a3;
wire    [7:0]       radix_b0, radix_b1, radix_b2, radix_b3;


reg             busy;
reg     [1:0]   round;
reg     [3:0]   cnt;
reg     [1:0]   k;
wire    [1:0]   last_k;
wire            round_en, last_round, cnt_en, last_cnt, k_en;
reg             done;


//Radix calculation
//Radix4
//Input: A0, A1, A2, A3
//Output: B0 = A0
//        B1 = A1^A2^A3
//        B2 = A2^A3
//        B3 = A3
assign {radix_a0, radix_a1, radix_a2, radix_a3} = (k==0 & round!=0)? {gf_out_d3, gf_out_d2, gf_out_d1, gf_out} :
                                                                     buff[(32-4)*8 +: 4*8];
assign radix_b0 = radix_a0;
assign radix_b1 = radix_a1 ^ radix_a2 ^ radix_a3;
assign radix_b2 = radix_a2 ^ radix_a3;
assign radix_b3 = radix_a3;


//
//Buffer
always @(posedge clk_i)
if(start_i)
  buff <= perm(din_i, 0,8,16,24,1,9,17,25,2,10,18,26,3,11,19,27,4,12,20,28,5,13,21,29,6,14,22,30,7,15,23,31);
else if(busy & round == 0)
  if(k==0 & cnt==7)
    buff <= perm(temp0, 0,4,8,12,16,20,24,28,1,5,9,13,17,21,25,29,2,6,10,14,18,22,26,30,3,7,11,15,19,23,27,31);
  else if(k==1 & cnt==7)
    buff <= perm(temp1, 0,2,4,6,8,10,12,14,16,18,20,22,24,26,28,30,1,3,5,7,9,11,13,15,17,19,21,23,25,27,29,31);
  else if(k==2 & cnt==7)
    buff <= perm(temp2, 0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31);
  else if(k==3 & cnt==7)
    buff <= perm(temp3, 0,4,8,12,1,5,9,13,2,6,10,14,3,7,11,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31);
  else
    buff <= next_buff_044;
else if(busy & round == 1)
  if(k==0)
    buff <= cnt==15? perm(temp4, 0,2,4,6,8,10,12,14,1,3,5,7,9,11,13,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31) :
            cnt[1:0]==3? next_buff_114 : next_buff_111;
  else if(k==1 & cnt==3)
    buff <= perm(temp5, 0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31);
  else if(k==2 & cnt==3)
    buff <= perm(temp6, 0,2,4,6,1,3,5,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31);
  else
    buff <= next_buff_144;
else if(busy & round == 2)
  if(k==0)
    buff <= cnt==7? perm(temp7, 0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31) :
            cnt[1:0]==3? next_buff_214 : next_buff_211;
  else if(k==1 & cnt==1)
    buff <= perm(temp8, 0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31);
  else
    buff <= next_buff_244;
else if(busy & round == 3)
  buff <= {radix_b0, radix_b1, radix_b2, radix_b3, buff[0 +: 28*8]};
else if(dout_read_i)
  buff <= {buff[0 +: 28*8], buff[28*8 +: 4*8]};

assign dout_o = buff[(32-4)*8 +: 4*8];

//round 0
assign temp0 = perm(next_buff_044, 0,4,8,12,16,20,24,28,1,5,9,13,17,21,25,29,2,6,10,14,18,22,26,30,3,7,11,15,19,23,27,31);
assign temp1 = perm(next_buff_044, 0,8,16,24,1,9,17,25,2,10,18,26,3,11,19,27,4,12,20,28,5,13,21,29,6,14,22,30,7,15,23,31);
assign temp2 = perm(next_buff_044, 0,16,1,17,2,18,3,19,4,20,5,21,6,22,7,23,8,24,9,25,10,26,11,27,12,28,13,29,14,30,15,31);
assign temp3 = perm(next_buff_044, 0,2,4,6,8,10,12,14,16,18,20,22,24,26,28,30,1,3,5,7,9,11,13,15,17,19,21,23,25,27,29,31);

//round 1
assign temp4 = perm(next_buff_114, 0,4,8,12,1,5,9,13,2,6,10,14,3,7,11,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31);
assign temp5 = perm(next_buff_144, 0,8,1,9,2,10,3,11,4,12,5,13,6,14,7,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31);
assign temp6 = perm(next_buff_144, 0,2,4,6,8,10,12,14,1,3,5,7,9,11,13,15,16,18,20,22,24,26,28,30,17,19,21,23,25,27,29,31);

//round 2
assign temp7 = perm(next_buff_214, 0,4,1,5,2,6,3,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31);
assign temp8 = perm(next_buff_244, 0,2,4,6,1,3,5,7,8,10,12,14,9,11,13,15,16,18,20,22,17,19,21,23,24,26,28,30,25,27,29,31);


assign next_buff_044 = {buff[0 +: 28*8], radix_b0, radix_b1, radix_b2, radix_b3};
assign next_buff_144 = {buff[16*8 +: 12*8], radix_b0, radix_b1, radix_b2, radix_b3, buff[0 +: 16*8]};
assign next_buff_114 = {buff[19*8 +: 12*8], radix_b0, radix_b1, radix_b2, radix_b3, buff[0 +: 16*8]};
assign next_buff_111 = {buff[16*8 +: 15*8], buff[31*8 +: 8], buff[0 +: 16*8]};
assign next_buff_244 = {buff[24*8 +: 4*8], radix_b0, radix_b1, radix_b2, radix_b3, buff[0 +: 24*8]};
assign next_buff_214 = {buff[27*8 +: 4*8], radix_b0, radix_b1, radix_b2, radix_b3, buff[0 +: 24*8]};
assign next_buff_211 = {buff[24*8 +: 7*8], buff[31*8 +: 8], buff[0 +: 24*8]};

reg     [223:0] bm_pow_R;
wire    [7:0]   gf_in1, gf_in2, gf_out;
reg     [7:0]   gf_out_d1, gf_out_d2, gf_out_d3;

//GF Mult
gfmul #(.REG_IN  (0),
        .REG_OUT (0))
GF_MUL(
    .clk   (clk_i        ),
    .start (1            ),
    .in_1  (gf_in1       ),
    .in_2  (gf_in2       ),
    .out   (gf_out       ),
    .done  (             )
);

assign gf_in1 = buff[31*8 +: 8];
assign gf_in2 = bm_pow_R[223 -:8];

always @(posedge clk_i)
  {gf_out_d3, gf_out_d2, gf_out_d1} <= {gf_out_d2, gf_out_d1, gf_out};

//Constants
always @(posedge clk_i)
if(start_i)
  bm_pow_R <= 224'h010d51ba_062efbbb_14e420bd_7862c0a9__01195c2f_12bf1194__011f486b;
else if(busy & k==0 & round!=0)
  bm_pow_R <= {bm_pow_R[223-8-1:0], bm_pow_R[223 -:8]};

//------------------------------------------------------------------------------
//Controller
always @(posedge clk_i)
if(~rst_ni)
  busy <= 0;
else if(start_i)
  busy <= 1;
else if(last_round)
  busy <= 0;

assign busy_o = busy;


always @(posedge clk_i)
if(~rst_ni | start_i | last_round)
  round <= 0;
else if(round_en)
  round <= round + 1;

always @(posedge clk_i)
if(~rst_ni | start_i | last_cnt | last_round)
  cnt <= 0;
else if(cnt_en)
  cnt <= cnt + 1;

always @(posedge clk_i)
if(~rst_ni | start_i | round_en)
  k <= 0;
else if(k_en)
  k <= k + 1;


assign cnt_en   = busy;
assign last_cnt = round==0 & cnt==7 | round==1 & (k==0? cnt==15 : cnt==3) |
                  round==2 & (k==0? cnt==7 : cnt==1) | round==3 & cnt==3;
assign round_en   = last_cnt & k==last_k;
assign last_round = round==3 & cnt==3;
assign k_en   = last_cnt;
assign last_k = 3 - round;

always @(posedge clk_i)
if(~rst_ni | start_i)
  done <= 0;
else
  done <= last_round;

assign done_o = done;


//Byte rotate left function
function [32*8-1:0] rolbyte32;
  input [32*8-1:0] x;
  input integer n;
  begin
    rolbyte32 = {x,x}>>((32-n)*8);
  end
endfunction

//Permutation function
function [32*8-1:0] perm;
  input [32*8-1:0] x;
  input integer n0 , n1 , n2 , n3 , n4 , n5 , n6 , n7 , n8 , n9 , n10, n11, n12, n13, n14, n15,
                n16, n17, n18, n19, n20, n21, n22, n23, n24, n25, n26, n27, n28, n29, n30, n31;
  begin
    perm[(32-0 -1)*8 +: 8] = x[(32-n0 -1)*8 +: 8];
    perm[(32-1 -1)*8 +: 8] = x[(32-n1 -1)*8 +: 8];
    perm[(32-2 -1)*8 +: 8] = x[(32-n2 -1)*8 +: 8];
    perm[(32-3 -1)*8 +: 8] = x[(32-n3 -1)*8 +: 8];
    perm[(32-4 -1)*8 +: 8] = x[(32-n4 -1)*8 +: 8];
    perm[(32-5 -1)*8 +: 8] = x[(32-n5 -1)*8 +: 8];
    perm[(32-6 -1)*8 +: 8] = x[(32-n6 -1)*8 +: 8];
    perm[(32-7 -1)*8 +: 8] = x[(32-n7 -1)*8 +: 8];
    perm[(32-8 -1)*8 +: 8] = x[(32-n8 -1)*8 +: 8];
    perm[(32-9 -1)*8 +: 8] = x[(32-n9 -1)*8 +: 8];
    perm[(32-10-1)*8 +: 8] = x[(32-n10-1)*8 +: 8];
    perm[(32-11-1)*8 +: 8] = x[(32-n11-1)*8 +: 8];
    perm[(32-12-1)*8 +: 8] = x[(32-n12-1)*8 +: 8];
    perm[(32-13-1)*8 +: 8] = x[(32-n13-1)*8 +: 8];
    perm[(32-14-1)*8 +: 8] = x[(32-n14-1)*8 +: 8];
    perm[(32-15-1)*8 +: 8] = x[(32-n15-1)*8 +: 8];
    perm[(32-16-1)*8 +: 8] = x[(32-n16-1)*8 +: 8];
    perm[(32-17-1)*8 +: 8] = x[(32-n17-1)*8 +: 8];
    perm[(32-18-1)*8 +: 8] = x[(32-n18-1)*8 +: 8];
    perm[(32-19-1)*8 +: 8] = x[(32-n19-1)*8 +: 8];
    perm[(32-20-1)*8 +: 8] = x[(32-n20-1)*8 +: 8];
    perm[(32-21-1)*8 +: 8] = x[(32-n21-1)*8 +: 8];
    perm[(32-22-1)*8 +: 8] = x[(32-n22-1)*8 +: 8];
    perm[(32-23-1)*8 +: 8] = x[(32-n23-1)*8 +: 8];
    perm[(32-24-1)*8 +: 8] = x[(32-n24-1)*8 +: 8];
    perm[(32-25-1)*8 +: 8] = x[(32-n25-1)*8 +: 8];
    perm[(32-26-1)*8 +: 8] = x[(32-n26-1)*8 +: 8];
    perm[(32-27-1)*8 +: 8] = x[(32-n27-1)*8 +: 8];
    perm[(32-28-1)*8 +: 8] = x[(32-n28-1)*8 +: 8];
    perm[(32-29-1)*8 +: 8] = x[(32-n29-1)*8 +: 8];
    perm[(32-30-1)*8 +: 8] = x[(32-n30-1)*8 +: 8];
    perm[(32-31-1)*8 +: 8] = x[(32-n31-1)*8 +: 8];
  end
endfunction




endmodule
