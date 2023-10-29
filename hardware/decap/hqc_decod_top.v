// =============================================================================
// ==                     Technology Innovation Institute                     ==
// =============================================================================
//
// hqc_rsdecod_top.v
// Top module of Decoding for HQC
//
//
//
// 202207xx TII Hardware Team
//
// =============================================================================

module hqc_decod_top #(
    parameter PARAM_SECURITY = 128,
    parameter MULTIPLICITY   = (PARAM_SECURITY == 128)? 3 : 5,
    parameter IN_AW          = (PARAM_SECURITY == 128)? 8 :
                               (PARAM_SECURITY == 192)? 9 :
                               (PARAM_SECURITY == 256)? 9 : 8,
    parameter PARAM_K        = (PARAM_SECURITY == 128)? 16:
                               (PARAM_SECURITY == 192)? 24:
                               (PARAM_SECURITY == 256)? 32 : 31,
    parameter DIN_W          = 128,
    parameter DOUT_W         = 8*PARAM_K
    )(
    input                   clk_i,
    input                   rst_ni,
    input                   start_i,//1 pulse start signal
    output                  busy_o, //decoding is busy signal

    //Input RAM, read
    input   [DIN_W-1:0]     ram_din_i,
    output                  ram_din_rd_o,
    output  [IN_AW-1:0]     ram_din_addr_o,

    //Output data
    output  [DOUT_W-1:0]    dout_o,      //msg = {m[K-1],m[K-2],...,m[1],m[0]} with m[i] in byte
    output                  dout_valid_o //output valid

    );


wire                    rm_busy;
wire                    rm_dout_done;
wire                    rm_dout_valid;
wire    [7:0]           rm_dout;

wire                    rs_busy;
wire                    rs_done;
wire    [DOUT_W-1:0]    rs_dout;
wire                    last_busy;



hqc_rmdecod_top #(
    .PARAM_SECURITY (PARAM_SECURITY)
    )
RM_DECOD(
    .clk_i             (clk_i            ),
    .rst_ni            (rst_ni           ),
    .start_i           (start_i          ),
    .busy_o            (rm_busy          ),
    .done_o            (rm_dout_done     ),
    .ram_din_i         (ram_din_i        ),
    .ram_din_rd_o      (ram_din_rd_o     ),
    .ram_din_addr_o    (ram_din_addr_o   ),
    .ram_dout_wr_o     (rm_dout_valid    ),
    .ram_dout_o        (rm_dout          ),
    .ram_dout_addr_o   (                 )
    );

hqc_rsdecod_top #(
    .PARAM_SECURITY (PARAM_SECURITY)
    )
RS_DECOD(
    .clk_i        (clk_i        ),
    .rst_ni       (rst_ni       ),
    .start_i      (start_i      ),
    .din_i        (rm_dout      ),
    .din_valid_i  (rm_dout_valid),
    .din_done_i   (rm_dout_done ),
    .busy_o       (rs_busy      ),
    .last_busy_o  (last_busy    ),
    .done_o       (rs_done      ),
    .dout_o       (rs_dout      )
    );

assign dout_o       = rs_dout;
assign busy_o       = rs_busy;
assign dout_valid_o = rs_done;

endmodule
