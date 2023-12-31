// =============================================================================
// ==                     Technology Innovation Institute                     ==
// =============================================================================
//
// hqc_rsdecod_syndromes.v
// Compute syndromes module of RS Decoding for HQC
//
//
//
// 202207xx TII Hardware Team
//
// =============================================================================

module hqc_rsdecod_syndromes #(

    parameter PARAM_SECURITY = 128,
    parameter PARAM_DELTA    = (PARAM_SECURITY == 128)? 15:
                               (PARAM_SECURITY == 192)? 16:
                               (PARAM_SECURITY == 256)? 29 : 15,
    parameter PARAM_G        = (PARAM_SECURITY == 128)? 31:
                               (PARAM_SECURITY == 192)? 33:
                               (PARAM_SECURITY == 256)? 59 : 31,
    parameter PARAM_K        = (PARAM_SECURITY == 128)? 16:
                               (PARAM_SECURITY == 192)? 24:
                               (PARAM_SECURITY == 256)? 32 : 31,
    parameter PARAM_N1       = (PARAM_SECURITY == 128)? 46:
                               (PARAM_SECURITY == 192)? 56:
                               (PARAM_SECURITY == 256)? 90 : 46,
    parameter ALPHA_DW       = 8*2*PARAM_DELTA,
    parameter ALPHA_AW       = (PARAM_SECURITY == 128)? 6:
                               (PARAM_SECURITY == 192)? 6:
                               (PARAM_SECURITY == 256)? 7 : 6,
    parameter DIN_W          = 8,
    parameter DOUT_W         = 8*2*PARAM_DELTA,
    parameter MSG_W          = 8*PARAM_K
    )(
    input                   clk_i,
    input                   rst_ni,
    input                   start_i,
    input   [DIN_W-1:0]     din_i,
    input                   din_valid_i,
    input                   din_done_i,
    output  [DOUT_W-1:0]    dout_o,
    output                  dout_valid_o,
    output  [MSG_W-1:0]     msg_o
    );


reg     [DOUT_W-1:0]    synd_buf;
reg     [MSG_W-1:0]     msg_buf;

reg                     din_valid_d;
reg                     gf_en;
wire                    synd_en;
wire    [7:0]           cdw_in;
wire    [7:0]           alpha_ij_pow;
wire    [7:0]           gf_mul_out;

reg     [ALPHA_DW-1:0]  alpha_rom, alpha_buf;
reg     [ALPHA_AW-1:0]  din_cnt;

reg     [5:0]   cnt;
reg             cnt_en;
wire            last_cnt;
reg             input_done;
reg             dout_valid;


//Accumulates K bytes messages (last K bytes of input)
//msg = {m[K-1],m[K-2],...,m[1],m[0]} with m[i] in byte
always @(posedge clk_i)
if(din_valid_i)
  msg_buf <= {din_i, msg_buf[MSG_W-1:DIN_W]};

assign msg_o = msg_buf;
assign cdw_in = msg_buf[MSG_W-1 -: 8];


always @(posedge clk_i)
if(~rst_ni | start_i)
  synd_buf <= 0;
else if(synd_en)
begin
  synd_buf[DOUT_W-1 -: 8] <= gf_mul_out ^ synd_buf[7:0];
  synd_buf[DOUT_W-1-8: 0] <= synd_buf[DOUT_W-1:8];
end

assign dout_o = synd_buf;

always @(posedge clk_i)
if(din_valid_d)
  alpha_buf <= alpha_rom;
else if(gf_en)
  alpha_buf <= {alpha_buf[ALPHA_DW-1-8:0], alpha_buf[ALPHA_DW-1 -: 8]};

assign alpha_ij_pow = alpha_buf[ALPHA_DW-1 -: 8];

//GF multiplication
gfmul #(.REG_IN  (0),
        .REG_OUT (1))
GFMUL_SYND (
    .clk   (clk_i       ),
    .start (gf_en       ),
    .in_1  (cdw_in      ),
    .in_2  (alpha_ij_pow),
    .out   (gf_mul_out  ),
    .done  (synd_en     )
);


//------------------------------------------------------------------------------
//Controller
//Input Counter
always @(posedge clk_i)
if(~rst_ni | start_i)
  din_cnt <= 0;
else if(din_valid_i)
  din_cnt <= din_cnt + 1;



always @(posedge clk_i)
if(~rst_ni | din_valid_i | last_cnt)
  cnt <= 0;
else if(cnt_en)
  cnt <= cnt + 1;

assign last_cnt = (cnt==(2*PARAM_DELTA-1));

always @(posedge clk_i)
if(~rst_ni | last_cnt)
  cnt_en <= 0;
else if(din_valid_i)
  cnt_en <= 1;

always @(posedge clk_i)
begin
  gf_en       <= cnt_en;
  din_valid_d <= din_valid_i;
end

always @(posedge clk_i)
if(~rst_ni | start_i)
  input_done <= 0;
else if(din_done_i)
  input_done <= 1;

always @(posedge clk_i)
  dout_valid <= ~gf_en & synd_en & input_done;

assign dout_valid_o = dout_valid;


//------------------------------------------------------------------------------
//Alpha power ROM

generate
if(PARAM_SECURITY == 128)
  always @(posedge clk_i)
  case(din_cnt)
    0  : alpha_rom <= 240'h010101010101010101010101010101010101010101010101010101010101;
    1  : alpha_rom <= 240'h020408102040801D3A74E8CD8713264C982D5AB475EAC98F03060C183060;
    2  : alpha_rom <= 240'h0410401D74CD134C2DB4EA8F0618609D4E25946AB5EE9F460514505D69B9;
    3  : alpha_rom <= 240'h08403ACD262D758F0C60272535B5C1460A50BAB9A1612F650F78E76B7FDF;
    4  : alpha_rom <= 240'h101DCD4CB48F189D256AEE46145DB95F99651EFD6BFE5BD9110DD081F83B;
    5  : alpha_rom <= 240'h207426B403609C6AC105A0B9BE5E0FFDD6DFE2111A677C3B332EA9844D55;
    6  : alpha_rom <= 240'h40CD2D8F6025B54650B96165786BDFD944D03E3B66B821A855E4BFFCF196;
    7  : alpha_rom <= 240'h801375189CB58C5DA15E3C6BA3431A8193666D842939D1FCFF6257C8E059;
    8  : alpha_rom <= 240'h1D4C8F9D6A465D5F65FDFED90D813B854FA849E6FCE395821C51C312F72C;
    9  : alpha_rom <= 240'h3A2D0C25C150A165E7DF86D0ED66A9A892BFB3965707A6C324FB7DAD4026;
    10 : alpha_rom <= 240'h74B4606A05B95EFDDF11673B2E8455E6D796AE1C59ACF42C6C2026039CC1;
    11 : alpha_rom <= 240'hE8EA27EEA0613CFE866776B8543991E3DC07A2ACF5B0473AB4C0B5285F0F;
    12 : alpha_rom <= 240'hCD8F2546B9656BD9D03BB8A8E4FC9682DDC33D2CAD3A7527C1BA2FE7B61A;
    13 : alpha_rom <= 240'h87063514BE78A30DED2E54E4E562645145FB83202DC0EEBA5EBBD9BDECA9;
    14 : alpha_rom <= 240'h1318B55D5E6B4381668439FC62C859120BADE8033528C2E7E2BDC59EAA91;
    15 : alpha_rom <= 240'h2660C1B90FDF1A3BA95591966459242C012660C1B90FDF1A3BA955919664;
    16 : alpha_rom <= 240'h4C9D465FFDD98185A8E6E38251122C0298278CBEE7AF1F174DD1DB19A224;
    17 : alpha_rom <= 240'h984E0A99D644934F92D7DCDD450B01984E0A99D644934F92D7DCDD450B01;
    18 : alpha_rom <= 240'h2D255065DFD066A8BF9607C3FBAD26270A2F7F1AC51573DB64F2F536CD60;
    19 : alpha_rom <= 240'h5A94BA1EE23E6D49B3AEA23D83E8608C997F3433A8636238AC1608EAD4B9;
    20 : alpha_rom <= 240'hB46AB9FD113B84E6961CAC2C2003C1BED61A334D9137A724E97460055EDF;
    21 : alpha_rom <= 240'h75B5A16B1A6629FC5759F5AD2D35B9E744C5A8916EA63D362625BA78863B;
    22 : alpha_rom <= 240'hEAEE61FE67B839E307ACB03AC0280FAF93156337A67AD82D6ADE6B348555;
    23 : alpha_rom <= 240'hC99F2F5B7C21D195A6F44775EEC2DF1F4F7362A73DD85AB5BEFECEDAD596;
    24 : alpha_rom <= 240'h8F4665D93BA8FC82C32C3A27BAE71A1792DB3824362DB561DF3E21BF6E59;
    25 : alpha_rom <= 240'h03050F113355FF1C246CB4C15EE23B4DD764ACE9266ABEDF7C8491AEEF2C;
    26 : alpha_rom <= 240'h0614780D2EE46251FB20C0BABBBDA9D1DCF2167425DEFE3E843F822BFA26;
    27 : alpha_rom <= 240'h0C50E7D0A9BF57C37D26B52FD9C555DBDDF50860BA6BCE21918256CF2DC1;
    28 : alpha_rom <= 240'h185D6B8184FCC812AD0328E7BD9E91194536EA057834DABFAE2BCF5A230F;
    29 : alpha_rom <= 240'h30697FF84DF1E0F7409C5FB6ECAA96A20BCDD45E8685D56EEFFA2D231E1A;
    30 : alpha_rom <= 240'h60B9DF3B5596592C26C10F1AA99164240160B9DF3B5596592C26C10F1AA9;
    31 : alpha_rom <= 240'hC0DEB697726E9B1B8FA0B1ED524B59589846F067157BE0FB74D46588DA91;
    32 : alpha_rom <= 240'h9D5FD985E682120227BEAF17D11924044E61432EBF3248089CC2865C6364;
    33 : alpha_rom <= 240'h276186B89107F53AB50FD015F1A62C2D0A6BED55C4C3360CB9B666738224;
    34 : alpha_rom <= 240'h4E99444FD7DD0B980AD69392DC45014E99444FD7DD0B980AD69392DC4501;
    35 : alpha_rom <= 240'h9C5E1A84FF59E903B9E22E911CEB2605D63B72AE24206A0F674D96EF6C60;
    36 : alpha_rom <= 240'h2565D0A896C3AD272F1A15DBF23660614421F159CF0CA186A9B3A67D8FB9;
    37 : alpha_rom <= 240'h4A89CE52378A10D4787C4957481DC1D393E419F4CD8CB1C5E68DFB4C28DF;
    38 : alpha_rom <= 240'h941E3E49AE3DE88C7F33633816EAB9434FF1796C27BCBD29370940EED33B;
    39 : alpha_rom <= 240'h3578EDE464FB2DBAD9A9F1F2AD250F3E9282F52650B6B8B359362765CE55;
    40 : alpha_rom <= 240'h6AFD3BE61C2C03BE1A4D37247405DF2ED7596C9C0F7C7264EBB4B9118496;
    41 : alpha_rom <= 240'hD4D3C5C6A7CF9DCA3E72C88BC95F1A9ADC3D13A0D99EAB56209F7F85E559;
    42 : alpha_rom <= 240'hB56B66FC59AD35E7C591A63625783BBFDDCF270FED73387D60653EE4072C;
    43 : alpha_rom <= 240'h77B1177BEF089FE1B8FF2B408C5BA9AB453A14E2213112CDA04315959026;
    44 : alpha_rom <= 240'hEEFEB8E3AC3A28AF15377A2DDE3455320B0CBC7C73E08325FD97FC7902C1;
    45 : alpha_rom <= 240'hC1DFA9962426B91A55642C600F3B915901C1DFA9962426B91A55642C600F;
    default : alpha_rom <= 240'h010101010101010101010101010101010101010101010101010101010101;
  endcase

else if(PARAM_SECURITY == 192)
  always @(posedge clk_i)
  case(din_cnt)
    0  : alpha_rom <= 256'h0101010101010101010101010101010101010101010101010101010101010101;
    1  : alpha_rom <= 256'h020408102040801D3A74E8CD8713264C982D5AB475EAC98F03060C183060C09D;
    2  : alpha_rom <= 256'h0410401D74CD134C2DB4EA8F0618609D4E25946AB5EE9F460514505D69B9DE5F;
    3  : alpha_rom <= 256'h08403ACD262D758F0C60272535B5C1460A50BAB9A1612F650F78E76B7FDFB6D9;
    4  : alpha_rom <= 256'h101DCD4CB48F189D256AEE46145DB95F99651EFD6BFE5BD9110DD081F83B9785;
    5  : alpha_rom <= 256'h207426B403609C6AC105A0B9BE5E0FFDD6DFE2111A677C3B332EA9844D5572E6;
    6  : alpha_rom <= 256'h40CD2D8F6025B54650B96165786BDFD944D03E3B66B821A855E4BFFCF1966E82;
    7  : alpha_rom <= 256'h801375189CB58C5DA15E3C6BA3431A8193666D842939D1FCFF6257C8E0599B12;
    8  : alpha_rom <= 256'h1D4C8F9D6A465D5F65FDFED90D813B854FA849E6FCE395821C51C312F72C1B02;
    9  : alpha_rom <= 256'h3A2D0C25C150A165E7DF86D0ED66A9A892BFB3965707A6C324FB7DAD40268F27;
    10 : alpha_rom <= 256'h74B4606A05B95EFDDF11673B2E8455E6D796AE1C59ACF42C6C2026039CC1A0BE;
    11 : alpha_rom <= 256'hE8EA27EEA0613CFE866776B8543991E3DC07A2ACF5B0473AB4C0B5285F0FB1AF;
    12 : alpha_rom <= 256'hCD8F2546B9656BD9D03BB8A8E4FC9682DDC33D2CAD3A7527C1BA2FE7B61AED17;
    13 : alpha_rom <= 256'h87063514BE78A30DED2E54E4E562645145FB83202DC0EEBA5EBBD9BDECA952D1;
    14 : alpha_rom <= 256'h1318B55D5E6B4381668439FC62C859120BADE8033528C2E7E2BDC59EAA914B19;
    15 : alpha_rom <= 256'h2660C1B90FDF1A3BA95591966459242C012660C1B90FDF1A3BA9559196645924;
    16 : alpha_rom <= 256'h4C9D465FFDD98185A8E6E38251122C0298278CBEE7AF1F174DD1DB19A2245804;
    17 : alpha_rom <= 256'h984E0A99D644934F92D7DCDD450B01984E0A99D644934F92D7DCDD450B01984E;
    18 : alpha_rom <= 256'h2D255065DFD066A8BF9607C3FBAD26270A2F7F1AC51573DB64F2F536CD604661;
    19 : alpha_rom <= 256'h5A94BA1EE23E6D49B3AEA23D83E8608C997F3433A8636238AC1608EAD4B9F043;
    20 : alpha_rom <= 256'hB46AB9FD113B84E6961CAC2C2003C1BED61A334D9137A724E97460055EDF672E;
    21 : alpha_rom <= 256'h75B5A16B1A6629FC5759F5AD2D35B9E744C5A8916EA63D362625BA78863B15BF;
    22 : alpha_rom <= 256'hEAEE61FE67B839E307ACB03AC0280FAF93156337A67AD82D6ADE6B3485557B32;
    23 : alpha_rom <= 256'hC99F2F5B7C21D195A6F44775EEC2DF1F4F7362A73DD85AB5BEFECEDAD596E048;
    24 : alpha_rom <= 256'h8F4665D93BA8FC82C32C3A27BAE71A1792DB3824362DB561DF3E21BF6E59FB08;
    25 : alpha_rom <= 256'h03050F113355FF1C246CB4C15EE23B4DD764ACE9266ABEDF7C8491AEEF2C749C;
    26 : alpha_rom <= 256'h0614780D2EE46251FB20C0BABBBDA9D1DCF2167425DEFE3E843F822BFA26D4C2;
    27 : alpha_rom <= 256'h0C50E7D0A9BF57C37D26B52FD9C555DBDDF50860BA6BCE21918256CF2DC16586;
    28 : alpha_rom <= 256'h185D6B8184FCC812AD0328E7BD9E91194536EA057834DABFAE2BCF5A230F885C;
    29 : alpha_rom <= 256'h30697FF84DF1E0F7409C5FB6ECAA96A20BCDD45E8685D56EEFFA2D231E1ADA63;
    30 : alpha_rom <= 256'h60B9DF3B5596592C26C10F1AA99164240160B9DF3B5596592C26C10F1AA99164;
    31 : alpha_rom <= 256'hC0DEB697726E9B1B8FA0B1ED524B59589846F067157BE0FB74D46588DA91C890;
    32 : alpha_rom <= 256'h9D5FD985E682120227BEAF17D11924044E61432EBF3248089CC2865C63649010;
    33 : alpha_rom <= 256'h276186B89107F53AB50FD015F1A62C2D0A6BED55C4C3360CB9B6667382240825;
    34 : alpha_rom <= 256'h4E99444FD7DD0B980AD69392DC45014E99444FD7DD0B980AD69392DC45014E99;
    35 : alpha_rom <= 256'h9C5E1A84FF59E903B9E22E911CEB2605D63B72AE24206A0F674D96EF6C60BE11;
    36 : alpha_rom <= 256'h2565D0A896C3AD272F1A15DBF23660614421F159CF0CA186A9B3A67D8FB9D9B8;
    37 : alpha_rom <= 256'h4A89CE52378A10D4787C4957481DC1D393E419F4CD8CB1C5E68DFB4C28DFCCC6;
    38 : alpha_rom <= 256'h941E3E49AE3DE88C7F33633816EAB9434FF1796C27BCBD29370940EED33BB7C8;
    39 : alpha_rom <= 256'h3578EDE464FB2DBAD9A9F1F2AD250F3E9282F52650B6B8B359362765CE55573D;
    40 : alpha_rom <= 256'h6AFD3BE61C2C03BE1A4D37247405DF2ED7596C9C0F7C7264EBB4B9118496AC20;
    41 : alpha_rom <= 256'hD4D3C5C6A7CF9DCA3E72C88BC95F1A9ADC3D13A0D99EAB56209F7F85E559D84A;
    42 : alpha_rom <= 256'hB56B66FC59AD35E7C591A63625783BBFDDCF270FED73387D60653EE4072C0C2F;
    43 : alpha_rom <= 256'h77B1177BEF089FE1B8FF2B408C5BA9AB453A14E2213112CDA043159590266922;
    44 : alpha_rom <= 256'hEEFEB8E3AC3A28AF15377A2DDE3455320B0CBC7C73E08325FD97FC7902C1E16D;
    45 : alpha_rom <= 256'hC1DFA9962426B91A55642C600F3B915901C1DFA9962426B91A55642C600F3B91;
    46 : alpha_rom <= 256'h9F5B2195F475C21F73A7D8B5FEDA964898A1BD723883946B2EE38A87D21AAA8D;
    47 : alpha_rom <= 256'h237115A5EB0C8976FCEF8050225264B04EE785FF8A136FD0727036D4FEA9627A;
    48 : alpha_rom <= 256'h46D9A8822C27E717DB242D613EBF59080A8629647D256BB8963D752FED91F240;
    49 : alpha_rom <= 256'h8C4329C8E935FE9E6EEB3078CCE3245A99ED3FEF3A6968E4A78E46AF9A64FA94;
    50 : alpha_rom <= 256'h0511551C6CC1E24D64E96ADF84AE2C9CD6A937EB60FD2E96F4030F33FF24B45E;
    51 : alpha_rom <= 256'h0A4492DD010A4492DD010A4492DD010A4492DD010A4492DD010A4492DD010A44;
    52 : alpha_rom <= 256'h140DE45120BABDD1F274DE3E3F2B26C293B309B46597E33D033C1731F360D3DA;
    53 : alpha_rom <= 256'h2834737974A1F8E58AB4CA664BF760BB4F57B06AB69A0EAD0588E4A280B91F3F;
    54 : alpha_rom <= 256'h50D0BFC3262FC5DBF5606B2182CFC18692A640B93EFC8A750F17C48B25DFA807;
    55 : alpha_rom <= 256'hA06791ACB40F2E372C6AE255A720B97CD72403FDA9AEE9C111725974BE3BFFF4;
    default : alpha_rom <= 256'h0101010101010101010101010101010101010101010101010101010101010101;
  endcase


else if(PARAM_SECURITY == 256)
  always @(posedge clk_i)
  case(din_cnt)
    0  : alpha_rom <= 464'h01010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101;
    1  : alpha_rom <= 464'h020408102040801D3A74E8CD8713264C982D5AB475EAC98F03060C183060C09D274E9C254A94356AD4B577EEC19F23468C050A142850A05DBA69;
    2  : alpha_rom <= 464'h0410401D74CD134C2DB4EA8F0618609D4E25946AB5EE9F460514505D69B9DE5F61995E65891E78FDD36BB1FEDF5B71D94311440D34D067813EF8;
    3  : alpha_rom <= 464'h08403ACD262D758F0C60272535B5C1460A50BAB9A1612F650F78E76B7FDFB6D986441AD0CE3EED3BC56617B8A92115A8295592E473BF91FCB3F1;
    4  : alpha_rom <= 464'h101DCD4CB48F189D256AEE46145DB95F99651EFD6BFE5BD9110DD081F83B9785B84F84A85249E4E6C6FC7BE39695A582C81CDD5179C3AC123DF7;
    5  : alpha_rom <= 464'h207426B403609C6AC105A0B9BE5E0FFDD6DFE2111A677C3B332EA9844D5572E691D7FF9637AE641CA759EFAC24F4EB2CE96C01207426B403609C;
    6  : alpha_rom <= 464'h40CD2D8F6025B54650B96165786BDFD944D03E3B66B821A855E4BFFCF1966E8207DD59C38A3DFB2CCFAD083A26750C2735C10ABAA12F0FE77FB6;
    7  : alpha_rom <= 464'h801375189CB58C5DA15E3C6BA3431A8193666D842939D1FCFF6257C8E0599B12F50BE9AD10E82D039D359F28B9C289E7FEE244BDF8C52E9EA8AA;
    8  : alpha_rom <= 464'h1D4C8F9D6A465D5F65FDFED90D813B854FA849E6FCE395821C51C312F72C1B023A980327D48CBABECAE7E1AF1A1F76179E4D92D1E5DB371938A2;
    9  : alpha_rom <= 464'h3A2D0C25C150A165E7DF86D0ED66A9A892BFB3965707A6C324FB7DAD40268F27B50AB92F787FD91A3EC5B8155573FCDB6E64DDF28AF52C3608CD;
    10 : alpha_rom <= 464'h74B4606A05B95EFDDF11673B2E8455E6D796AE1C59ACF42C6C2026039CC1A0BE0FD6E21A7C33A94D7291FF3764A7EF24EBE90174B4606A05B95E;
    11 : alpha_rom <= 464'hE8EA27EEA0613CFE866776B8543991E3DC07A2ACF5B0473AB4C0B5285F0FB1AFD0932E154963F137C8A62B7A2CD8802D306A0ADECA6BE234ED85;
    12 : alpha_rom <= 464'hCD8F2546B9656BD9D03BB8A8E4FC9682DDC33D2CAD3A7527C1BA2FE7B61AED17159291DB5738F2248B36402D60B5506178DF443E662155BFF16E;
    13 : alpha_rom <= 464'h87063514BE78A30DED2E54E4E562645145FB83202DC0EEBA5EBBD9BDECA952D1F1DC1CF24816AD74C9258CDE0FFE223ECC84923F4B82A72BF5FA;
    14 : alpha_rom <= 464'h1318B55D5E6B4381668439FC62C859120BADE8033528C2E7E2BDC59EAA914B19A645EB361DEA25055F785B343BDA52BFE3AEDD2BF7CF205A2723;
    15 : alpha_rom <= 464'h2660C1B90FDF1A3BA95591966459242C012660C1B90FDF1A3BA95591966459242C012660C1B90FDF1A3BA95591966459242C012660C1B90FDF1A;
    16 : alpha_rom <= 464'h4C9D465FFDD98185A8E6E38251122C0298278CBEE7AF1F174DD1DB19A22458042D4E0561D3433E2E9ABFAB325948B0085A9C0AC2BB867C5C2963;
    17 : alpha_rom <= 464'h984E0A99D644934F92D7DCDD450B01984E0A99D644934F92D7DCDD450B01984E0A99D644934F92D7DCDD450B01984E0A99D644934F92D7DCDD45;
    18 : alpha_rom <= 464'h2D255065DFD066A8BF9607C3FBAD26270A2F7F1AC51573DB64F2F536CD6046616B443B21E4F182593DCF3A0CC1A1E786EDA992B357A6247D408F;
    19 : alpha_rom <= 464'h5A94BA1EE23E6D49B3AEA23D83E8608C997F3433A8636238AC1608EAD4B9F043ED4F72F11979F56C132714BCDFBD85293F37DD09B04003EEA1D3;
    20 : alpha_rom <= 464'hB46AB9FD113B84E6961CAC2C2003C1BED61A334D9137A724E97460055EDF672E55D7AE59F46C269CA00FE27CA972FF64EFEB01B46AB9FD113B84;
    21 : alpha_rom <= 464'h75B5A16B1A6629FC5759F5AD2D35B9E744C5A8916EA63D362625BA78863B15BFC4DD24CFCD27500FD9ED217396388A7D3A600A65B63EA9E4DB07;
    22 : alpha_rom <= 464'hEAEE61FE67B839E307ACB03AC0280FAF93156337A67AD82D6ADE6B3485557B32C30B200C8CBCB67C9E7331E02483132569FD44979AFCAE79FB02;
    23 : alpha_rom <= 464'hC99F2F5B7C21D195A6F44775EEC2DF1F4F7362A73DD85AB5BEFECEDAD596E04836986AA1B1BDB872AB38128326946F6B682E92E30E8AE98725D2;
    24 : alpha_rom <= 464'h8F4665D93BA8FC82C32C3A27BAE71A1792DB3824362DB561DF3E21BF6E59FB080C0A0F86C529B364567DCD25B96BD0B8E496DD3DAD75C12FB6ED;
    25 : alpha_rom <= 464'h03050F113355FF1C246CB4C15EE23B4DD764ACE9266ABEDF7C8491AEEF2C749CB9D667A9E63759EB2060A0FD1A2E7296A7F40103050F113355FF;
    26 : alpha_rom <= 464'h0614780D2EE46251FB20C0BABBBDA9D1DCF2167425DEFE3E843F822BFA26D4C2B6934DB38D0936B49F65439755E3703D8E030A3C88177231A6F3;
    27 : alpha_rom <= 464'h0C50E7D0A9BF57C37D26B52FD9C555DBDDF50860BA6BCE21918256CF2DC16586669296A6FB4027B97F3E15FC648A3675460F4417E4C4598B3A25;
    28 : alpha_rom <= 464'h185D6B8184FCC812AD0328E7BD9E91194536EA057834DABFAE2BCF5A230F885C73DCEF7D4CEE651185E495792C87D42FAF339231A28B74946171;
    29 : alpha_rom <= 464'h30697FF84DF1E0F7409C5FB6ECAA96A20BCDD45E8685D56EEFFA2D231E1ADA6382456C8F28D3CE84E507900260D2FEED9AFFDDF38025BE71C549;
    30 : alpha_rom <= 464'h60B9DF3B5596592C26C10F1AA99164240160B9DF3B5596592C26C10F1AA99164240160B9DF3B5596592C26C10F1AA99164240160B9DF3B559659;
    31 : alpha_rom <= 464'hC0DEB697726E9B1B8FA0B1ED524B59589846F067157BE0FB74D46588DA91C890084EBED9CCB757ACD80C69E13BAA62F2FAB40AD31FA8FF538B87;
    32 : alpha_rom <= 464'h9D5FD985E682120227BEAF17D11924044E61432EBF3248089CC2865C63649010259911B8C6C83D204A2F226D918D7A40945E44DA3F07F48035BC;
    33 : alpha_rom <= 464'h276186B89107F53AB50FD015F1A62C2D0A6BED55C4C3360CB9B66673822408252F44A9FC38FBCDC178CEA8DB597D75507F3B926E56AD60A1D917;
    34 : alpha_rom <= 464'h4E99444FD7DD0B980AD69392DC45014E99444FD7DD0B980AD69392DC45014E99444FD7DD0B980AD69392DC45014E99444FD7DD0B980AD69392DC;
    35 : alpha_rom <= 464'h9C5E1A84FF59E903B9E22E911CEB2605D63B72AE24206A0F674D96EF6C60BE11A9D7A72CB4A0DF33E664F474C1FD7C5537AC019C5E1A84FF59E9;
    36 : alpha_rom <= 464'h2565D0A896C3AD272F1A15DBF23660614421F159CF0CA186A9B3A67D8FB9D9B8FCDD2C75BAB61791388B2D50DF66BF07FB260A7FC57364F5CD46;
    37 : alpha_rom <= 464'h4A89CE52378A10D4787C4957481DC1D393E419F4CD8CB1C5E68DFB4C28DFCCC6380BB4BA715CFCA7B08F6F43A97BA2CF18BE4442E3F26C9D2F34;
    38 : alpha_rom <= 464'h941E3E49AE3DE88C7F33633816EAB9434FF1796C27BCBD29370940EED33BB7C8FB98A0B65CE5A6E918610D2A962B02353C7C92417ACD05FE66C6;
    39 : alpha_rom <= 464'h3578EDE464FB2DBAD9A9F1F2AD250F3E9282F52650B6B8B359362765CE55573DCD0ADF17FCA6CF602FD0296E243A467F6691DD7D0C611AA8C48A;
    40 : alpha_rom <= 464'h6AFD3BE61C2C03BE1A4D37247405DF2ED7596C9C0F7C7264EBB4B9118496AC20C1D63391A7E9605E6755AEF426A0E2A9FFEF016AFD3BE61C2C03;
    41 : alpha_rom <= 464'hD4D3C5C6A7CF9DCA3E72C88BC95F1A9ADC3D13A0D99EAB56209F7F85E559D84A7893E638B0182F67AA82F35AB9222AC412740A5B6DF1EF02B5BB;
    42 : alpha_rom <= 464'hB56B66FC59AD35E7C591A63625783BBFDDCF270FED73387D60653EE4072C0C2FCE92648B8F61D05582FB75A11A2957F52DB944A86E3D26BA8615;
    43 : alpha_rom <= 464'h77B1177BEF089FE1B8FF2B408C5BA9AB453A14E2213112CDA043159590266922A8DCF42D6F0D29AEF3755F685519CB8FC26792C8160C5E1FE40E;
    44 : alpha_rom <= 464'hEEFEB8E3AC3A28AF15377A2DDE3455320B0CBC7C73E08325FD97FC7902C1E16DDB457450432A6EF45AA168AA64161865F8E6DD1B4AE733E5F204;
    45 : alpha_rom <= 464'hC1DFA9962426B91A55642C600F3B915901C1DFA9962426B91A55642C600F3B915901C1DFA9962426B91A55642C600F3B915901C1DFA9962426B9;
    46 : alpha_rom <= 464'h9F5B2195F475C21F73A7D8B5FEDA964898A1BD723883946B2EE38A87D21AAA8D7D4EFD667B2B3AA022291916601EECFCF9200AAF5457EB0665C7;
    47 : alpha_rom <= 464'h237115A5EB0C8976FCEF8050225264B04EE785FF8A136FD0727036D4FEA9627A75997CBFA20246E22A57CB180FECE5C31DA044A4C87D9CD317E3;
    48 : alpha_rom <= 464'h46D9A8822C27E717DB242D613EBF59080A8629647D256BB8963D752FED91F24050445507CF357FA9C4F58F653BFCC33ABA1A923836B5DF216EFB;
    49 : alpha_rom <= 464'h8C4329C8E935FE9E6EEB3078CCE3245A99ED3FEF3A6968E4A78E46AF9A64FA947F4F37FB183C66FF122DC2F891F91DBA3472DD4723D94D327D4A;
    50 : alpha_rom <= 464'h0511551C6CC1E24D64E96ADF84AE2C9CD6A937EB60FD2E96F4030F33FF24B45E3BD7AC26BE7C91EF74B967E65920A01A72A7010511551C6CC1E2;
    51 : alpha_rom <= 464'h0A4492DD010A4492DD010A4492DD010A4492DD010A4492DD010A4492DD010A4492DD010A4492DD010A4492DD010A4492DD010A4492DD010A4492;
    52 : alpha_rom <= 464'h140DE45120BABDD1F274DE3E3F2B26C293B309B46597E33D033C1731F360D3DA6E0B9C7F42417D6A5BA8C81BC1AFA438470544395308A06873B2;
    53 : alpha_rom <= 464'h2834737974A1F8E58AB4CA664BF760BB4F57B06AB69A0EAD0588E4A280B91F3F56985EC5E37A0CFD6D6E164ADF54C8362311925310BA6763C313;
    54 : alpha_rom <= 464'h50D0BFC3262FC5DBF5606B2182CFC18692A640B93EFC8A750F17C48B25DFA807AD0A1A73F2CD613BF13D0CE7A9577DB5D955DD08BACE91562D65;
    55 : alpha_rom <= 464'hA06791ACB40F2E372C6AE255A720B97CD72403FDA9AEE9C111725974BE3BFFF460D684646C051AE6EF265E3396EB9CDF4D1C01A06791ACB40F2E;
    56 : alpha_rom <= 464'h5D81FC1203E79E19360534BF2B5A0F5CDC7DEE11E479872F33318B9471555380A193FFF59DFEA81C02BA1FE52406D321326C0A686356B41EB8A5;
    57 : alpha_rom <= 464'hBA3EB33D607FA83808B9EDF1F527DF29DD40A13BDBFB25B655A63A61C5968B35D99259CD2F66C42CB586E4F22665176E7DC14473C32D0FB857CF;
    58 : alpha_rom <= 464'h69F8F1F79CB6AAA2CD5E856EFA231A63458FD3840702D2EDFFF32571495987BC17DCE94634C68A03BB150E04B9C7E3FB4AE292B213652EA5CF8C;
    59 : alpha_rom <= 464'hD2C7DBCB6A86B79B75FD4207046F3B4B0BB522E656C9D3151C10A1EC312CEE88BF45036B547040BE97C4B09F1AC6090CB14DDD1DC26637FA4668;
    60 : alpha_rom <= 464'hB93B962CC11A912460DF5559260FA96401B93B962CC11A912460DF5559260FA96401B93B962CC11A912460DF5559260FA96401B93B962CC11A91;
    61 : alpha_rom <= 464'h6FECC4FA05CE7BF33511D18A18E155B29878421C40C285576C5DEDAB16C1347E3D4EE2E49BC96B4D53CDCADA6402DEC595E90A81F6FB6A22BF09;
    62 : alpha_rom <= 464'hDE976E1BA0ED4B5846677BFBD48891904ED9B7AC0CE1AAF2B4D3A853870F9E0E40992E828E6FC5378350F8AB2C23BDB3F36A44C64827E2D55606;
    63 : alpha_rom <= 464'hA16657ADB9C56E36BA3BC4CF50ED967D0A3EDB2C46CEF18BC1D0B3FBB51AFCF53544913D2586BF2427D9738A60B6E4560CDF92C38F7F55F2756B;
    64 : alpha_rom <= 464'h5F858202BE171904612E3208C25C641099B8C8202F6D8D405EDA0780BCA90E1D654F1C3ACA9E3874892170E80F42E0CD1E84DD873C15A713782A;
    65 : alpha_rom <= 464'hBE2E64205EA91C740F84A726FD4D59B4D655EF03DF72AC60E2E6249C1191F46A1AD7EBC167FF2C057C96E9A03B376CB933AE01BE2E64205EA91C;
    66 : alpha_rom <= 464'h61B8073A0F15A62D6B55C30CB673242544FCFBC1CEDB7D503B6EADA11764406521DD26E729F28FDFE48A278691F5B5D0F12C0AEDC436B9668208;
    67 : alpha_rom <= 464'hC2DA3887FD29F906B6E6903534F62C14936E47BEB80EE8784D798FA3B7244A0DB30B05ED95D8A12E8D3A1E5459EAE1E4099C44E5CB467C62366F;
    68 : alpha_rom <= 464'h994FDD98D692454E44D70B0A93DC01994FDD98D692454E44D70B0A93DC01994FDD98D692454E44D70B0A93DC01994FDD98D692454E44D70B0A93;
    69 : alpha_rom <= 464'h2F21A675DF733DB5CE9636A1B838266B928A251AF17DBA66643A7829C36086FC8B0A3B57086515598FB6BFF5C13EC4AD61A9DD2D7FE42435D0DB;
    70 : alpha_rom <= 464'h5E845903E291EB053BAE200F4DEF6011D72CA0336474FD55AC9C1AFFE9B92E1C26D672246A67966CBEA9A7B4DFE6F4C17C37015E845903E291EB;
    71 : alpha_rom <= 464'hBC2AF23011B3B069171C4C7FB77AC1F8DC08894DC39D88F1E96FB8E05ADFD1F74693AE403C52569C34DB1B5FA953EAB6C6EB0AEC193AFDAA8A94;
    72 : alpha_rom <= 464'h65A8C3271ADB366121590C86B37DB9B8DD75B6918B506607267F73F5463B823AE79224B53E6E080F295625D096AD2F15F26044F1CFA1A9A68FD9;
    73 : alpha_rom <= 464'hCA9A564A67C4028929AC94CE95040F5245358137081EA48A6A1F6E103C5509D43EDC2078AA12B57CA540F0492477F85780FD9248EEEDAE1DE739;
    74 : alpha_rom <= 464'h89528AD47C571DD3E4F48CC58D4CDFC60BBA5CA78F437BCFBE42F29D34968ECA29456A3EA580E7727A46ECC826E1638B5D2EDDC9AFB3E95F2179;
    75 : alpha_rom <= 464'h0F5524C13B6426DF912CB9A959601A96010F5524C13B6426DF912CB9A959601A96010F5524C13B6426DF912CB9A959601A96010F5524C13B6426;
    76 : alpha_rom <= 464'h1E493D8C3338EA43F16CBC2909EE3BC898B6E5E9612A2B357C41CDFEC62C6F9EF24E676E80BB73EB5DB851301A31047839F40ACCE08F11E3ADCA;
    77 : alpha_rom <= 464'h3C39F5282EA63034C420D373CB69A9794ECEA5747FC658A1849B35F819265BE5CF994D8AEE7607B4AFF1D8CA55908C66E003444B027872F7505C;
    78 : alpha_rom <= 464'h78E4FBBAA9F2253E8226B6B33665553D0A17A660D06E3A7F917D61A88AC1C5388F449608E7738BB921C335ED642DD9F1AD0F92F550B85927CE57;
    79 : alpha_rom <= 464'hF0B78B6F845677EC38030DC480B191FA9929480517519DCEAE13B67BD80F39F3BA4FEF35C78D75114B08D3D12C5F548A9F33DD18686E74E1FC83;
    80 : alpha_rom <= 464'hFDE62CBE4D24052E599C7C64B4119620D691E95E55F4A0A9EF6A3B1C031A3774DFD76C0F72EBB984ACC133A76067AE26E2FF01FDE62CBE4D2405;
    81 : alpha_rom <= 464'hE7BF7D2F55F5BA2156C166A6273E647544C43ADFB3AD78732C61293D50A9C3B5C5DD60CE822D8696407FFC360FE48BA1A8240AB8F2353B380CD0;
    82 : alpha_rom <= 464'hD3C6CFCA728B5F9A3DA09E569F85594A93381867825A22C4745BF102BB918389E40BBE297A5D21AC2317B2943B7030CE19B44495E8B6FF046B3F;
    83 : alpha_rom <= 464'hBB3F363CE67DBC398BBE52F5D22A24284F56232EF2D497A69CC738308164C934579811C4E871DB20FEB38ED3911B1E73B05E92CB5F29F4691512;
    84 : alpha_rom <= 464'h6BFCADE7913678BFCF0F737D65E42C2F928B6155FBA129F5B9A83DBA152450218A0AA95646B8C3C117F2B5665935C5A6253BDD27ED38603E070C;
    85 : alpha_rom <= 464'hD6D701D6D701D6D701D6D701D6D701D6D701D6D701D6D701D6D701D6D701D6D701D6D701D6D701D6D701D6D701D6D701D6D701D6D701D6D701D6;
    86 : alpha_rom <= 464'hB17B08E1FF405BAB3AE231CD43952622DC2D0DAE7568198F67C80C1F0E60F8702793A725EC513533B2B585F9C15C9B46DAAC0A9E09508448BA54;
    87 : alpha_rom <= 464'h7FF140B696CD866E2D1A828FCE0760EDDD25C559B517C346A98A50153DB929FB61922C6573CF7891AD6BB308DFDB3AD9C426445775D0640C3E38;
    88 : alpha_rom <= 464'hFEE33AAF372D34320C7CE0259779C16D45502AF4A1AA1665E61BE7E504DFABE886DCB4D0C830EDA79466F923A9095DA8F7BE925889BF6CBBB310;
    89 : alpha_rom <= 464'hE1ABCD22AE8F1F702533F9469E48B9A40B65D16C6BF680D9375AD08DC03BA277B845A0A8F3C2E4E9F0FC04A396138882067CDD94CCC305423DDE;
    default : alpha_rom <= 464'h01010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101;
  endcase

endgenerate



endmodule
