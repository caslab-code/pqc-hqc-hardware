// =============================================================================
// ==                     Technology Innovation Institute                     ==
// =============================================================================
//
// hqc_rsdecod_elp.v
// Compute Error Locator Polynomial module of RS Decoding for HQC
//
//
//
// 202207xx TII Hardware Team
//
// =============================================================================

module hqc_rsdecod_elp #(

    parameter PARAM_SECURITY = 128,
    parameter PARAM_DELTA    = (PARAM_SECURITY == 128)? 15:
                               (PARAM_SECURITY == 192)? 16:
                               (PARAM_SECURITY == 256)? 29 : 15,
    parameter DIN_W          = 8*2*PARAM_DELTA,
    parameter DOUT_W         = 8*(PARAM_DELTA+1)
    )(
    input                   clk_i,
    input                   rst_ni,
    input   [DIN_W-1:0]     din_i, //syndrome
    input                   din_valid_i,
    output                  busy_o,
    output  [DOUT_W-1:0]    dout_o, //sigma
    output                  dout_valid_o,
    output  [7:0]           deg_sigma_o //degree of sigma
    );

genvar i;

reg     [DIN_W-1:0]            syndrome_buf;
reg     [DOUT_W-1:0]            sigma;
wire    [8*PARAM_DELTA-1:0]     syndrome_swap;

reg     [7:0]   d, dd, deg_X_sigma_p;
wire    [7:0]   dd_mul_out;
reg     [7:0]   pp, dp, inv_dp;
reg     [7:0]   deg_sigma, deg_sigma_p;
reg     [DOUT_W-1:0]    X_sigma_p;

wire            mask1, mask2, mask12;

wire    [8*PARAM_DELTA-1:0]     gf_mul_in1, gf_mul_in2, gf_mul_out;

reg     [5:0]   cnt;
wire    [5:0]   mu;
reg     [2:0]   cnt_en_buf;
reg             busy, dout_valid;


//syndrome = {m[2D-1],m[2D-2],...,m[1],m[0]} with m[i] in byte
always @(posedge clk_i)
if(din_valid_i)
  syndrome_buf <= din_i;
else if(cnt_en_buf[0])
  syndrome_buf <= {syndrome_buf[7:0], syndrome_buf[2*8*PARAM_DELTA-1:8]};

//Swapped first DELTA syndrome for d calculation
generate
  for (i=0; i < PARAM_DELTA; i=i+1)
  begin: swap
    assign syndrome_swap[8*i +:8] = syndrome_buf[2*8*PARAM_DELTA-1 -8*i -:8];
  end
endgenerate

//Calculate d
always @(posedge clk_i)
if(din_valid_i)
  d <= din_i[7:0];
else if(cnt_en_buf[2])
  d <= syndrome_buf[7:0] ^ xor_byte(gf_mul_out);


//Calculate inverse dp
always @(posedge clk_i)
if(din_valid_i)
  inv_dp <= 1;
else if(cnt_en_buf[2])
  inv_dp <= I(dp);


//Calculate dd
//dd = gf_mul(d,inv_dp)
gfmul #(.REG_IN  (0),
        .REG_OUT (0))
DD_MUL(
    .clk   (clk_i        ),
    .start (1            ),
    .in_1  (d            ),
    .in_2  (inv_dp       ),
    .out   (dd_mul_out   ),
    .done  (             )
);

always @(posedge clk_i)
if(cnt_en_buf[0])
  dd <= dd_mul_out;

//Calculate deg_X_sigma_p
always @(posedge clk_i)
if(cnt_en_buf[0])
  deg_X_sigma_p <= mu - pp + deg_sigma_p;


//Calculate pp, deg_sigma, deg_sigma_p, dp
assign mask1 = d!=0;
assign mask2 = (deg_X_sigma_p > deg_sigma);
assign mask12 = mask1 & mask2;

always @(posedge clk_i)
if(din_valid_i)
begin
  pp          <= 8'hff; //-1
  dp          <= 1;
  deg_sigma   <= 0;
  deg_sigma_p <= 0;
end
else if(cnt_en_buf[1] & mask12)
begin
  pp          <= mu;
  dp          <= d;
  deg_sigma   <= deg_X_sigma_p;
  deg_sigma_p <= deg_sigma;
end

//Calculate previous X_sigma
always @(posedge clk_i)
if(din_valid_i)
  X_sigma_p   <= 1<<8; //X_sigma_p[1] = 1
else if(cnt_en_buf[1])
  X_sigma_p   <= mask12? {sigma[8*PARAM_DELTA-1:0], 8'd0} : {X_sigma_p[8*PARAM_DELTA-1:0], 8'd0};

//Calculate sigma
always @(posedge clk_i)
if(din_valid_i)
  sigma <= 1;
else if(cnt_en_buf[1])
  sigma <= {gf_mul_out, 8'd1};

assign deg_sigma_o = deg_sigma;
assign dout_o      = sigma;


//DELTA gf_mul instances
generate
  for (i=0; i < PARAM_DELTA; i=i+1)
  begin: gf_mul
    gfmul #(.REG_IN  (0),
            .REG_OUT (0))
    DD_MUL(
        .clk   (clk_i               ),
        .start (1                   ),
        .in_1  (gf_mul_in1[8*i +: 8]),
        .in_2  (gf_mul_in2[8*i +: 8]),
        .out   (gf_mul_out[8*i +: 8]),
        .done  (                    )
    );
  end
endgenerate

assign gf_mul_in1 = cnt_en_buf[1]? {PARAM_DELTA{dd}} : sigma[8*PARAM_DELTA+8-1:8];
assign gf_mul_in2 = cnt_en_buf[1]? X_sigma_p[8*PARAM_DELTA+8-1:8] : syndrome_swap;

//------------------------------------------------------------------------------
//Controller
//Input Counter
always @(posedge clk_i)
if(~rst_ni | last_cnt & cnt_en_buf[1])
  busy <= 0;
else if(din_valid_i)
  busy <= 1;

assign busy_o = busy;

always @(posedge clk_i)
if(~rst_ni | din_valid_i | last_cnt & cnt_en_buf[1])
  cnt <= 0;
else if(cnt_en_buf[2])
  cnt <= cnt + 1;

assign mu = cnt;
assign last_cnt = (cnt==(2*PARAM_DELTA-1));

always @(posedge clk_i)
if(~rst_ni | last_cnt & cnt_en_buf[1])
  cnt_en_buf <= 3'b000;
else if(din_valid_i)
  cnt_en_buf <= 3'b001;
else if(busy)
  cnt_en_buf <= {cnt_en_buf[1:0], cnt_en_buf[2]};


always @(posedge clk_i)
  dout_valid <= last_cnt & cnt_en_buf[1];

assign dout_valid_o = dout_valid;


//------------------------------------------------------------------------------
//Functions
//XOR byte
function [7:0] xor_byte(input [8*PARAM_DELTA-1:0] x);
integer j;
begin
    xor_byte = 0;
    for (j=0; j<PARAM_DELTA; j=j+1)
        xor_byte = xor_byte ^ x[8*j +: 8];
end
endfunction

//inverse_gf
function [7:0] I(input [7:0] x);
begin
  case(x)
  0  :I=0  ;1  :I=1  ;2  :I=142;3  :I=244;4  :I=71 ;5  :I=167;6  :I=122;7  :I=186;
  8  :I=173;9  :I=157;10 :I=221;11 :I=152;12 :I=61 ;13 :I=170;14 :I=93 ;15 :I=150;
  16 :I=216;17 :I=114;18 :I=192;19 :I=88 ;20 :I=224;21 :I=62 ;22 :I=76 ;23 :I=102;
  24 :I=144;25 :I=222;26 :I=85 ;27 :I=128;28 :I=160;29 :I=131;30 :I=75 ;31 :I=42 ;
  32 :I=108;33 :I=237;34 :I=57 ;35 :I=81 ;36 :I=96 ;37 :I=86 ;38 :I=44 ;39 :I=138;
  40 :I=112;41 :I=208;42 :I=31 ;43 :I=74 ;44 :I=38 ;45 :I=139;46 :I=51 ;47 :I=110;
  48 :I=72 ;49 :I=137;50 :I=111;51 :I=46 ;52 :I=164;53 :I=195;54 :I=64 ;55 :I=94 ;
  56 :I=80 ;57 :I=34 ;58 :I=207;59 :I=169;60 :I=171;61 :I=12 ;62 :I=21 ;63 :I=225;
  64 :I=54 ;65 :I=95 ;66 :I=248;67 :I=213;68 :I=146;69 :I=78 ;70 :I=166;71 :I=4  ;
  72 :I=48 ;73 :I=136;74 :I=43 ;75 :I=30 ;76 :I=22 ;77 :I=103;78 :I=69 ;79 :I=147;
  80 :I=56 ;81 :I=35 ;82 :I=104;83 :I=140;84 :I=129;85 :I=26 ;86 :I=37 ;87 :I=97 ;
  88 :I=19 ;89 :I=193;90 :I=203;91 :I=99 ;92 :I=151;93 :I=14 ;94 :I=55 ;95 :I=65 ;
  96 :I=36 ;97 :I=87 ;98 :I=202;99 :I=91 ;100:I=185;101:I=196;102:I=23 ;103:I=77 ;
  104:I=82 ;105:I=141;106:I=239;107:I=179;108:I=32 ;109:I=236;110:I=47 ;111:I=50 ;
  112:I=40 ;113:I=209;114:I=17 ;115:I=217;116:I=233;117:I=251;118:I=218;119:I=121;
  120:I=219;121:I=119;122:I=6  ;123:I=187;124:I=132;125:I=205;126:I=254;127:I=252;
  128:I=27 ;129:I=84 ;130:I=161;131:I=29 ;132:I=124;133:I=204;134:I=228;135:I=176;
  136:I=73 ;137:I=49 ;138:I=39 ;139:I=45 ;140:I=83 ;141:I=105;142:I=2  ;143:I=245;
  144:I=24 ;145:I=223;146:I=68 ;147:I=79 ;148:I=155;149:I=188;150:I=15 ;151:I=92 ;
  152:I=11 ;153:I=220;154:I=189;155:I=148;156:I=172;157:I=9  ;158:I=199;159:I=162;
  160:I=28 ;161:I=130;162:I=159;163:I=198;164:I=52 ;165:I=194;166:I=70 ;167:I=5  ;
  168:I=206;169:I=59 ;170:I=13 ;171:I=60 ;172:I=156;173:I=8  ;174:I=190;175:I=183;
  176:I=135;177:I=229;178:I=238;179:I=107;180:I=235;181:I=242;182:I=191;183:I=175;
  184:I=197;185:I=100;186:I=7  ;187:I=123;188:I=149;189:I=154;190:I=174;191:I=182;
  192:I=18 ;193:I=89 ;194:I=165;195:I=53 ;196:I=101;197:I=184;198:I=163;199:I=158;
  200:I=210;201:I=247;202:I=98 ;203:I=90 ;204:I=133;205:I=125;206:I=168;207:I=58 ;
  208:I=41 ;209:I=113;210:I=200;211:I=246;212:I=249;213:I=67 ;214:I=215;215:I=214;
  216:I=16 ;217:I=115;218:I=118;219:I=120;220:I=153;221:I=10 ;222:I=25 ;223:I=145;
  224:I=20 ;225:I=63 ;226:I=230;227:I=240;228:I=134;229:I=177;230:I=226;231:I=241;
  232:I=250;233:I=116;234:I=243;235:I=180;236:I=109;237:I=33 ;238:I=178;239:I=106;
  240:I=227;241:I=231;242:I=181;243:I=234;244:I=3  ;245:I=143;246:I=211;247:I=201;
  248:I=66 ;249:I=212;250:I=232;251:I=117;252:I=127;253:I=255;254:I=126;255:I=253;
  endcase
end
endfunction



endmodule
