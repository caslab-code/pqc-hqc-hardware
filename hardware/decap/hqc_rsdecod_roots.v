// =============================================================================
// ==                     Technology Innovation Institute                     ==
// =============================================================================
//
// hqc_rsdecod_roots.v
// Compute error values module of RS Decoding for HQC
//
//
//
// 202207xx TII Hardware Team
//
// =============================================================================

module hqc_rsdecod_roots #(

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
    parameter ERR_W          = 8*PARAM_N1,
    parameter SIG_W          = 8*(PARAM_DELTA+1)
    )(
    input                   clk_i,
    input                   rst_ni,
    input   [SIG_W-1:0]     sigma_i,
    input                   start_i,
    output                  busy_o,
    output  [ERR_W-1:0]     error_o,
    output                  dout_valid_o
    );


//
wire            fft_start_out;
wire            fft_busy, fft_done;
wire    [32*8-1:0]  fft_din;

wire            fft_done;
wire    [7:0]   ram_din;
wire            ram_wr;
wire    [7:0]   ram_wr_addr;

reg     [7:0]   ram_dout;
wire            ram_rd;
wire    [7:0]   ram_rd_addr;
wire    [7:0]   ram_addr;
wire            ret_busy;
reg     [7:0]   mem[0:255];


assign fft_din = {{32*8-SIG_W{1'b0}}, sigma_i};

add_fft #(
    .DIN_W      (32*8),
    .AW         (8   ),
    .DW         (8   ))
ADD_FFT(
    .clk_i      (clk_i  ),
    .rst_ni     (rst_ni ),
    .start_i    (start_i),
    .start_o    (fft_start_out),
    // .busy_o     (fft_busy),
    .done_o     (fft_done),
    .din_i      (fft_din ),
    .ram_din_o  (ram_din ),
    .ram_addr_o (ram_wr_addr),
    .ram_wr     (ram_wr  )
    );


//RAM
assign ram_addr = ret_busy? ram_rd_addr : ram_wr_addr;

always @(posedge clk_i)
begin
  if (ram_wr)
    begin
      mem[ram_addr] <= ram_din;
      ram_dout <= ram_din;
    end
  ram_dout <= mem[ram_addr];
end


//Retrieve Error Poly
fft_retrieve_error_poly #(
    .PARAM_SECURITY (PARAM_SECURITY)
    )
FFT_RETRIEVE_ERROR  (
    .clk_i          (clk_i        ),
    .rst_ni         (rst_ni & ~start_i),
    .start_i        (fft_done     ),
    .busy_o         (ret_busy     ),
    .ram_din_i      (ram_dout     ),
    .ram_din_rd_o   (ram_rd       ),
    .ram_din_addr_o (ram_rd_addr  ),
    .dout_o         (error_o      ),
    .dout_valid_o   (dout_valid_o )
    );



endmodule
