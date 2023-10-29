// =============================================================================
// ==                     Technology Innovation Institute                     ==
// =============================================================================
//
// hqc_rmdecod_top.v
// Top module of RM Decoding for HQC
//
//
//
// 202207xx TII Hardware Team
//
// =============================================================================

module hqc_rmdecod_top #(
    parameter PARAM_SECURITY = 128,
    parameter MULTIPLICITY   = (PARAM_SECURITY == 128)? 3 : 5,
    parameter IN_AW          = (PARAM_SECURITY == 128)? 8 :
                               (PARAM_SECURITY == 192)? 9 :
                               (PARAM_SECURITY == 256)? 9 : 8,
    parameter OUT_AW         = (PARAM_SECURITY == 128)? 6 :
                               (PARAM_SECURITY == 192)? 6 :
                               (PARAM_SECURITY == 256)? 7 : 6,

    parameter EAS_W          = (PARAM_SECURITY == 128)? 2 : 3,
    parameter HAD_W          = 1 + EAS_W + 7
    )(
    input                   clk_i,
    input                   rst_ni,
    input                   start_i,
    output                  busy_o,
    output                  done_o,

    //Input RAM
    input   [127:0]         ram_din_i,
    output                  ram_din_rd_o,
    output  [IN_AW-1:0]     ram_din_addr_o,

    //Output RAM
    output                  ram_dout_wr_o,
    output  [7:0]           ram_dout_o,
    output  [OUT_AW-1:0]    ram_dout_addr_o

    );


wire                eas_start;
wire                eas_start_ready;
wire    [127:0]     eas_din;
wire                eas_din_valid;
wire                eas_din_ready;
wire    [EAS_W-1:0] eas_dout0;
wire    [EAS_W-1:0] eas_dout1;
wire                eas_dout_valid;

wire                had_start;
wire    [HAD_W-1:0] had_dout0;
wire    [HAD_W-1:0] had_dout1;
wire                had_dout_valid;

wire                peak_start;
wire                peak_valid;
wire    [7:0]       peak_dout;



hqc_rmdecod_expnsum #(
    .PARAM_SECURITY (PARAM_SECURITY)
    )
EXPANSE_AND_SUM(
    .clk_i        (clk_i            ),
    .rst_ni       (rst_ni           ),
    .start_i      (eas_start        ),
    .start_ready_o(eas_start_ready  ),
    .din_i        (eas_din          ),
    .din_valid_i  (eas_din_valid    ),
    .din_ready_o  (eas_din_ready    ),
    .dout_start_o (had_start        ),
    .dout0_o      (eas_dout0        ),
    .dout1_o      (eas_dout1        ),
    .dout_valid_o (eas_dout_valid   ),
    .dout_ready_i (1                )
    );


hqc_rmdecod_hadamard #(
    .PARAM_SECURITY (PARAM_SECURITY)
    )
HADAMARD(
    .clk_i        (clk_i         ),
    .rst_ni       (rst_ni        ),
    .start_i      (had_start     ),
    .din0_i       (eas_dout0     ),
    .din1_i       (eas_dout1     ),
    .din_valid_i  (eas_dout_valid),
    .dout_start_o (peak_start    ),
    .dout0_o      (had_dout0     ),
    .dout1_o      (had_dout1     ),
    .dout_valid_o (had_dout_valid)
    );

hqc_rmdecod_findpeaks #(
    .PARAM_SECURITY (PARAM_SECURITY)
    )
FIND_PEAKS(
    .clk_i        (clk_i         ),
    .rst_ni       (rst_ni        ),
    .start_i      (peak_start    ),
    .din0_i       (had_dout0     ),
    .din1_i       (had_dout1     ),
    .din_valid_i  (had_dout_valid),
    .dout_o       (peak_dout     ),
    .dout_valid_o (peak_valid    )
    );



hqc_rmdecod_ctrl #(
    .PARAM_SECURITY (PARAM_SECURITY)
    )
RM_DECOD_CTRL(
    .clk_i             (clk_i            ),
    .rst_ni            (rst_ni           ),
    .start_i           (start_i          ),
    .busy_o            (busy_o           ),
    .done_o            (done_o           ),
    .ram_din_i         (ram_din_i        ),
    .ram_din_rd_o      (ram_din_rd_o     ),
    .ram_din_addr_o    (ram_din_addr_o   ),
    .eas_din_o         (eas_din          ),
    .eas_start_ready_i (eas_start_ready  ),
    .eas_start_o       (eas_start        ),
    .eas_din_valid_o   (eas_din_valid    ),
    .eas_din_ready_i   (eas_din_ready    ),
    .peak_valid_i      (peak_valid       ),
    .peak_dout_i       (peak_dout        ),
    .ram_dout_wr_o     (ram_dout_wr_o    ),
    .ram_dout_o        (ram_dout_o       ),
    .ram_dout_addr_o   (ram_dout_addr_o  )
    );
endmodule
