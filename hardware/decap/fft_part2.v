// =============================================================================
// ==                     Technology Innovation Institute                     ==
// =============================================================================
//
// fft_part2.v
// Part2 of additive fft
//
//
//
//
// 202207xx TII Hardware Team
//
// =============================================================================

module fft_part2 #(
    parameter DIN_W          = 8,
    parameter DOUT_W         = 8
    )(
    input                   clk_i,
    input                   rst_ni,
    input                   start_i,
    output                  start_o,
    output                  busy_o,
    output                  done_o,

    //Input/output data
    input   [DIN_W-1:0]     din_i,
    input                   din_valid_i,
    output  [DOUT_W-1:0]    dout_o,
    output                  dout_valid_o
    );


wire                    start[0:4];
wire                    busy[0:3];
wire                    done[0:3];
wire    [DOUT_W-1:0]    data[0:4];
wire                    data_vld[0:4];

assign start[0]    = start_i;
assign data[0]     = din_i;
assign data_vld[0] = din_valid_i;

assign start_o = start[4];
assign busy_o  = busy[3];
assign done_o  = done[3];
assign dout_o  = data[4];
assign dout_valid_o = data_vld[4];

//Layer connections
genvar ii;
generate
  for(ii=0;ii<4;ii=ii+1)
  begin: ROUND
    fft_part2_round #(
        .ROUND          (ii ),
        .DIN_W          (DIN_W ),
        .DOUT_W         (DOUT_W))
    FFT_ROUND(
        .clk_i          (clk_i         ),
        .rst_ni         (rst_ni        ),
        .start_i        (start[ii]     ),
        .start_o        (start[ii+1]   ),
        .busy_o         (busy[ii]      ),
        .done_o         (done[ii]      ),
        .din_i          (data[ii]      ),
        .din_valid_i    (data_vld[ii]  ),
        .dout_o         (data[ii+1]    ),
        .dout_valid_o   (data_vld[ii+1])
    );
  end
endgenerate

endmodule


//FFT Layer/Round
module fft_part2_round #(

    parameter ROUND          = 0,
    parameter DIN_W          = 8,
    parameter DOUT_W         = 8
    )(
    input                   clk_i,
    input                   rst_ni,
    input                   start_i,
    output                  start_o,
    output                  busy_o,
    output                  done_o,

    //Input/output data
    input   [DIN_W-1:0]     din_i,
    input                   din_valid_i,
    output  [DOUT_W-1:0]    dout_o,
    output                  dout_valid_o
    );

reg     [7:0]   din_d;
wire    [7:0]   bi, bi_N2, bi_out;
reg     [7:0]   dout;


wire    [7:0]   fifo_din, fifo_dout;
wire            fifo_wr, fifo_rd, fifo_empty, fifo_full;

reg     [7:0]   g; //gamma sums
wire    [7:0]   gf_out;


reg             start_d, din_valid_d, busy;
reg     [7:0]   cnt_in, cnt_in_d, cnt_out;
wire            last_din, last_dout, cnt_out_start;
reg             last_dout_d1, last_dout_d2;
reg             dout_en, dout_en_d, cnt_out_start_d;




//Input
always @(posedge clk_i)
if(din_valid_i)
  din_d       <= din_i;

//FIFO (feedback registers)
syncfifo #(.DW    (8      ),
           .AW    (4+ROUND))
FIFO_FFT
( .clk_i   (clk_i        ),
  .rst_ni  (rst_ni       ),
  .wr_i    (fifo_wr   ),
  .rd_i    (fifo_rd   ),
  .din_i   (fifo_din  ),
  .empty_o (fifo_empty),
  .full_o  (fifo_full ),
  .dout_o  (fifo_dout ));

assign fifo_wr  = din_valid_d;
assign fifo_rd  = cnt_in[4+ROUND] | dout_en & cnt_out!=255;
assign fifo_din = cnt_in_d[4+ROUND]? bi_N2 : din_d;


//GF Mult
gfmul #(.REG_IN  (0),
        .REG_OUT (0))
GF_MUL(
    .clk   (clk_i        ),
    .start (1            ),
    .in_1  (g            ),
    .in_2  (din_d        ),
    .out   (gf_out       ),
    .done  (             )
);


//Butterfly
assign bi_out = cnt_in_d[4+ROUND]? bi : fifo_dout;
assign bi     = gf_out ^ fifo_dout;
assign bi_N2  = bi ^ din_d;

//Output
always @(posedge clk_i)
if(dout_en)
  dout     <= bi_out;

assign dout_o = dout;

//------------------------------------------------------------------------------
//Controller
//Input
always @(posedge clk_i)
begin
  start_d     <= start_i;
  din_valid_d <= din_valid_i;
end

always @(posedge clk_i)
if(~rst_ni)
  busy <= 0;
else if(start_i)
  busy <= 1;
else if(cnt_in==254)
  busy <= 0;

assign busy_o = busy;

always @(posedge clk_i)
if(~rst_ni | start_i | last_din)
  cnt_in <= 0;
else if(din_valid_i)
  cnt_in <= cnt_in + 1;

assign last_din = cnt_in==255;

always @(posedge clk_i)
  cnt_in_d <= cnt_in;

//output
assign cnt_out_start = (cnt_in==(16<<ROUND));

always @(posedge clk_i)
if(~rst_ni | cnt_out_start | last_dout)
  cnt_out <= 0;
else if(dout_en)
  cnt_out <= cnt_out + 1;

assign last_dout = cnt_out==255;

always @(posedge clk_i)
if(~rst_ni)
  dout_en <= 0;
else if(cnt_out_start)
  dout_en <= 1;
else if(last_dout)
  dout_en <= 0;

always @(posedge clk_i)
begin
  dout_en_d       <= dout_en;
  cnt_out_start_d <= cnt_out_start;
  last_dout_d1    <= last_dout;
  last_dout_d2    <= last_dout_d1;
end

assign start_o      = cnt_out_start_d;
assign done_o       = last_dout_d2;
assign dout_valid_o = dout_en_d;



//------------------------------------------------------------------------------
//Gamma sums ROM

generate
if(ROUND==0)
begin

always @(posedge clk_i)
  case(cnt_in[3:0])
  0  : g <= 8'h00; 1  : g <= 8'h2d; 2  : g <= 8'h21; 3  : g <= 8'h0c;
  4  : g <= 8'hae; 5  : g <= 8'h83; 6  : g <= 8'h8f; 7  : g <= 8'ha2;
  8  : g <= 8'h0b; 9  : g <= 8'h26; 10 : g <= 8'h2a; 11 : g <= 8'h07;
  12 : g <= 8'ha5; 13 : g <= 8'h88; 14 : g <= 8'h84; 15 : g <= 8'ha9;
  default : g <= 0;
  endcase
end


else if(ROUND==1)
begin
always @(posedge clk_i)
  case(cnt_in[4:0])
  0  : g <= 8'h00; 1  : g <= 8'h0c; 2  : g <= 8'hb7; 3  : g <= 8'hbb;
  4  : g <= 8'h26; 5  : g <= 8'h2a; 6  : g <= 8'h91; 7  : g <= 8'h9d;
  8  : g <= 8'h61; 9  : g <= 8'h6d; 10 : g <= 8'hd6; 11 : g <= 8'hda;
  12 : g <= 8'h47; 13 : g <= 8'h4b; 14 : g <= 8'hf0; 15 : g <= 8'hfc;
  16 : g <= 8'h16; 17 : g <= 8'h1a; 18 : g <= 8'ha1; 19 : g <= 8'had;
  20 : g <= 8'h30; 21 : g <= 8'h3c; 22 : g <= 8'h87; 23 : g <= 8'h8b;
  24 : g <= 8'h77; 25 : g <= 8'h7b; 26 : g <= 8'hc0; 27 : g <= 8'hcc;
  28 : g <= 8'h51; 29 : g <= 8'h5d; 30 : g <= 8'he6; 31 : g <= 8'hea;
  default : g <= 0;
  endcase
end


else if(ROUND==2)
begin
always @(posedge clk_i)
  case(cnt_in[5:0])
  0  : g <= 8'h00; 1  : g <= 8'hb6; 2  : g <= 8'hb3; 3  : g <= 8'h05;
  4  : g <= 8'hed; 5  : g <= 8'h5b; 6  : g <= 8'h5e; 7  : g <= 8'he8;
  8  : g <= 8'h78; 9  : g <= 8'hce; 10 : g <= 8'hcb; 11 : g <= 8'h7d;
  12 : g <= 8'h95; 13 : g <= 8'h23; 14 : g <= 8'h26; 15 : g <= 8'h90;
  16 : g <= 8'h1c; 17 : g <= 8'haa; 18 : g <= 8'haf; 19 : g <= 8'h19;
  20 : g <= 8'hf1; 21 : g <= 8'h47; 22 : g <= 8'h42; 23 : g <= 8'hf4;
  24 : g <= 8'h64; 25 : g <= 8'hd2; 26 : g <= 8'hd7; 27 : g <= 8'h61;
  28 : g <= 8'h89; 29 : g <= 8'h3f; 30 : g <= 8'h3a; 31 : g <= 8'h8c;
  32 : g <= 8'h06; 33 : g <= 8'hb0; 34 : g <= 8'hb5; 35 : g <= 8'h03;
  36 : g <= 8'heb; 37 : g <= 8'h5d; 38 : g <= 8'h58; 39 : g <= 8'hee;
  40 : g <= 8'h7e; 41 : g <= 8'hc8; 42 : g <= 8'hcd; 43 : g <= 8'h7b;
  44 : g <= 8'h93; 45 : g <= 8'h25; 46 : g <= 8'h20; 47 : g <= 8'h96;
  48 : g <= 8'h1a; 49 : g <= 8'hac; 50 : g <= 8'ha9; 51 : g <= 8'h1f;
  52 : g <= 8'hf7; 53 : g <= 8'h41; 54 : g <= 8'h44; 55 : g <= 8'hf2;
  56 : g <= 8'h62; 57 : g <= 8'hd4; 58 : g <= 8'hd1; 59 : g <= 8'h67;
  60 : g <= 8'h8f; 61 : g <= 8'h39; 62 : g <= 8'h3c; 63 : g <= 8'h8a;
  default : g <= 0;
  endcase
end


else if(ROUND==3)
begin
always @(posedge clk_i)
  case(cnt_in[6:0])
  0  : g <= 8'h00; 1  : g <= 8'h80; 2  : g <= 8'h40; 3  : g <= 8'hc0;
  4  : g <= 8'h20; 5  : g <= 8'ha0; 6  : g <= 8'h60; 7  : g <= 8'he0;
  8  : g <= 8'h10; 9  : g <= 8'h90; 10 : g <= 8'h50; 11 : g <= 8'hd0;
  12 : g <= 8'h30; 13 : g <= 8'hb0; 14 : g <= 8'h70; 15 : g <= 8'hf0;
  16 : g <= 8'h08; 17 : g <= 8'h88; 18 : g <= 8'h48; 19 : g <= 8'hc8;
  20 : g <= 8'h28; 21 : g <= 8'ha8; 22 : g <= 8'h68; 23 : g <= 8'he8;
  24 : g <= 8'h18; 25 : g <= 8'h98; 26 : g <= 8'h58; 27 : g <= 8'hd8;
  28 : g <= 8'h38; 29 : g <= 8'hb8; 30 : g <= 8'h78; 31 : g <= 8'hf8;
  32 : g <= 8'h04; 33 : g <= 8'h84; 34 : g <= 8'h44; 35 : g <= 8'hc4;
  36 : g <= 8'h24; 37 : g <= 8'ha4; 38 : g <= 8'h64; 39 : g <= 8'he4;
  40 : g <= 8'h14; 41 : g <= 8'h94; 42 : g <= 8'h54; 43 : g <= 8'hd4;
  44 : g <= 8'h34; 45 : g <= 8'hb4; 46 : g <= 8'h74; 47 : g <= 8'hf4;
  48 : g <= 8'h0c; 49 : g <= 8'h8c; 50 : g <= 8'h4c; 51 : g <= 8'hcc;
  52 : g <= 8'h2c; 53 : g <= 8'hac; 54 : g <= 8'h6c; 55 : g <= 8'hec;
  56 : g <= 8'h1c; 57 : g <= 8'h9c; 58 : g <= 8'h5c; 59 : g <= 8'hdc;
  60 : g <= 8'h3c; 61 : g <= 8'hbc; 62 : g <= 8'h7c; 63 : g <= 8'hfc;
  64 : g <= 8'h02; 65 : g <= 8'h82; 66 : g <= 8'h42; 67 : g <= 8'hc2;
  68 : g <= 8'h22; 69 : g <= 8'ha2; 70 : g <= 8'h62; 71 : g <= 8'he2;
  72 : g <= 8'h12; 73 : g <= 8'h92; 74 : g <= 8'h52; 75 : g <= 8'hd2;
  76 : g <= 8'h32; 77 : g <= 8'hb2; 78 : g <= 8'h72; 79 : g <= 8'hf2;
  80 : g <= 8'h0a; 81 : g <= 8'h8a; 82 : g <= 8'h4a; 83 : g <= 8'hca;
  84 : g <= 8'h2a; 85 : g <= 8'haa; 86 : g <= 8'h6a; 87 : g <= 8'hea;
  88 : g <= 8'h1a; 89 : g <= 8'h9a; 90 : g <= 8'h5a; 91 : g <= 8'hda;
  92 : g <= 8'h3a; 93 : g <= 8'hba; 94 : g <= 8'h7a; 95 : g <= 8'hfa;
  96 : g <= 8'h06; 97 : g <= 8'h86; 98 : g <= 8'h46; 99 : g <= 8'hc6;
  100: g <= 8'h26; 101: g <= 8'ha6; 102: g <= 8'h66; 103: g <= 8'he6;
  104: g <= 8'h16; 105: g <= 8'h96; 106: g <= 8'h56; 107: g <= 8'hd6;
  108: g <= 8'h36; 109: g <= 8'hb6; 110: g <= 8'h76; 111: g <= 8'hf6;
  112: g <= 8'h0e; 113: g <= 8'h8e; 114: g <= 8'h4e; 115: g <= 8'hce;
  116: g <= 8'h2e; 117: g <= 8'hae; 118: g <= 8'h6e; 119: g <= 8'hee;
  120: g <= 8'h1e; 121: g <= 8'h9e; 122: g <= 8'h5e; 123: g <= 8'hde;
  124: g <= 8'h3e; 125: g <= 8'hbe; 126: g <= 8'h7e; 127: g <= 8'hfe;
  default : g <= 0;
  endcase
end

endgenerate



endmodule
