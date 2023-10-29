// =============================================================================
// ==                     Technology Innovation Institute                     ==
// =============================================================================
//
// hqc_rsdecod_top.v
// Top module of RS Decoding for HQC
//
//
//
// 202207xx TII Hardware Team
//
// =============================================================================

module hqc_rsdecod_top #(
    parameter PARAM_SECURITY = 128,
    parameter PARAM_K        = (PARAM_SECURITY == 128)? 16:
                               (PARAM_SECURITY == 192)? 24:
                               (PARAM_SECURITY == 256)? 32 : 31,
    parameter DIN_W          = 8,
    parameter DOUT_W         = 8*PARAM_K
    )(
    input                   clk_i,
    input                   rst_ni,
    input                   start_i,
    output                  busy_o,
    output                  last_busy_o, //1 clock before NOT busy
    output                  done_o,

    //Input data
    input   [DIN_W-1:0]     din_i,
    input                   din_valid_i,
    input                   din_done_i,

    //Output data
    output  [DOUT_W-1:0]    dout_o //msg = {m[K-1],m[K-2],...,m[1],m[0]} with m[i] in byte

    );

localparam PARAM_DELTA	= (PARAM_SECURITY == 128)? 15:
						  (PARAM_SECURITY == 192)? 16:
						  (PARAM_SECURITY == 256)? 29 : 15;
localparam PARAM_G      = (PARAM_SECURITY == 128)? 31:
						  (PARAM_SECURITY == 192)? 33:
						  (PARAM_SECURITY == 256)? 59 : 31;
localparam PARAM_N1     = (PARAM_SECURITY == 128)? 46:
						  (PARAM_SECURITY == 192)? 56:
						  (PARAM_SECURITY == 256)? 90 : 46;


wire	[8*2*PARAM_DELTA-1:0]	syndromes;
wire							syn_valid;
wire	[DOUT_W-1:0]			msg_temp;
reg		[DOUT_W-1:0]			corrected_msg;


wire	[8*(PARAM_DELTA+1)-1:0]	sigma;
wire							sigma_valid;
wire							elp_busy;
wire	[7:0]					deg_sigma;

wire	[8*(PARAM_DELTA+1)-1:0]	z;
wire							z_valid;
wire							zpoly_busy;


wire	[8*PARAM_N1-1:0]		rs_error;
wire							root_busy;
wire							root_valid;
wire	[DOUT_W-1:0]			err_val;
wire							err_busy;


reg                     busy;
reg                     done;

hqc_rsdecod_syndromes #(
    .PARAM_SECURITY (PARAM_SECURITY)
    )
COMPUTE_SYNDROMES(
    .clk_i        (clk_i      ),
    .rst_ni       (rst_ni     ),
    .start_i      (start_i    ),
    .din_i        (din_i      ),
    .din_valid_i  (din_valid_i),
    .din_done_i   (din_done_i ),
    .dout_o       (syndromes  ),
    .dout_valid_o (syn_valid  ),
    .msg_o        (msg_temp   )
    );
	

hqc_rsdecod_elp #(
    .PARAM_SECURITY (PARAM_SECURITY)
    )
COMPUTE_ELP(
    .clk_i        (clk_i      ),
    .rst_ni       (rst_ni     ),
    .din_i        (syndromes  ),
    .din_valid_i  (syn_valid  ),
    .busy_o       (elp_busy   ),
    .dout_o       (sigma      ),
    .dout_valid_o (sigma_valid),
    .deg_sigma_o  (deg_sigma  )
    );
	
	
hqc_rsdecod_zpoly #(
    .PARAM_SECURITY (PARAM_SECURITY)
    )
COMPUTE_ZPOLY(
    .clk_i        (clk_i      ),
    .rst_ni       (rst_ni     ),
    .synd_i       (syndromes[8*PARAM_DELTA-1:0]), //first PARAM_DELTA syndromes
    .sigma_i      (sigma      ),
    .deg_sigma_i  (deg_sigma  ),
    .start_i      (sigma_valid),
    .busy_o       (zpoly_busy ),
    .dout_o       (z          ),
    .dout_valid_o (z_valid    )
    );
	
	
hqc_rsdecod_roots #(
    .PARAM_SECURITY (PARAM_SECURITY)
    )
COMPUTE_ROOTS(
    .clk_i        (clk_i        ),
    .rst_ni       (rst_ni       ),
    .sigma_i      (sigma        ),
    .start_i      (sigma_valid  ),
    .busy_o       (root_busy    ),
    .error_o      (rs_error     ),
    .dout_valid_o (root_valid   )
    );
	
hqc_rsdecod_err_val #(
    .PARAM_SECURITY (PARAM_SECURITY)
    )
COMPUTE_ERRVALS(
    .clk_i        (clk_i        ),
    .rst_ni       (rst_ni & ~start_i),
    .error_i      (rs_error     ),
    .z_i          (z            ),
    .start_i      (root_valid   ),
    .busy_o       (err_busy     ),
    .error_o      (err_val      ),
    .dout_valid_o (err_val_valid)
    );
	
	
//Busy and done
always @(posedge clk_i)
if(~rst_ni | err_val_valid)
  busy <= 0;
else if(start_i)
  busy <= 1;

always @(posedge clk_i)
  done <= err_val_valid;
  
always @(posedge clk_i)
if(err_val_valid)
  corrected_msg <= msg_temp ^ err_val;

assign last_busy_o = err_val_valid;
assign busy_o      = busy;
assign done_o      = done;
assign dout_o      = corrected_msg;

endmodule
