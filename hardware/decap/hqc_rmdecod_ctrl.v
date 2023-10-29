// =============================================================================
// ==                     Technology Innovation Institute                     ==
// =============================================================================
//
// hqc_rmdecod_ctrl.v
// Controller module of RM Decoding for HQC
//
//
//
// 202207xx TII Hardware Team
//
// =============================================================================

module hqc_rmdecod_ctrl #(
    parameter PARAM_SECURITY = 128,
    parameter MULTIPLICITY   = (PARAM_SECURITY == 128)? 3 : 5,
    parameter N1             = (PARAM_SECURITY == 128)? 46 :
                               (PARAM_SECURITY == 192)? 56 :
                               (PARAM_SECURITY == 256)? 90 : 46,
    parameter IN_AW          = (PARAM_SECURITY == 128)? 8 :
                               (PARAM_SECURITY == 192)? 9 :
                               (PARAM_SECURITY == 256)? 9 : 8,
    parameter OUT_AW         = (PARAM_SECURITY == 128)? 6 :
                               (PARAM_SECURITY == 192)? 6 :
                               (PARAM_SECURITY == 256)? 7 : 6
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

    //Expand and Sum
    output  [127:0]         eas_din_o,
    input                   eas_start_ready_i,
    output                  eas_start_o,
    output                  eas_din_valid_o,
    input                   eas_din_ready_i,

    //Find Peaks
    input                   peak_valid_i,
    input   [7:0]           peak_dout_i,

    //Output RAM
    output                  ram_dout_wr_o,
    output  [7:0]           ram_dout_o,
    output  [OUT_AW-1:0]    ram_dout_addr_o

    );


reg                     start_d;
reg                     eas_start_ready_d;
reg                     ram_din_en;
reg                     ram_din_ack;

reg     [IN_AW-1:0]     cnt_in;
reg     [OUT_AW-1:0]    cnt_out;
reg                     busy;
reg                     done;
wire                    last_din;
wire                    last_dout;

//Input Counter
always @(posedge clk_i)
if(~rst_ni | start_i | last_din)
  cnt_in <= 0;
else if(ram_din_rd_o)
  cnt_in <= cnt_in + 1;

assign last_din = cnt_in==(N1*MULTIPLICITY*128/128-1) & ram_din_rd_o;

//Input RAM
always @(posedge clk_i)
if(~rst_ni | last_din)
  ram_din_en <= 0;
else if(start_i)
  ram_din_en <= 1;

always @(posedge clk_i)
  ram_din_ack <= ram_din_rd_o;

assign ram_din_rd_o   = ram_din_en & eas_start_ready_i;
assign ram_din_addr_o = cnt_in;

//Expand and Sum

assign eas_din_o = ram_din_i;
assign eas_start_o = (start_d | ~eas_start_ready_d & eas_start_ready_i) & ram_din_en;
assign eas_din_valid_o = ram_din_ack;

always @(posedge clk_i)
begin
  start_d           <= start_i;
  eas_start_ready_d <= eas_start_ready_i;
end


//Output Counter
always @(posedge clk_i)
if(~rst_ni | start_i)
  cnt_out <= 0;
else if(peak_valid_i)
  cnt_out <= cnt_out + 1;

assign ram_dout_o      = peak_dout_i;
assign ram_dout_wr_o   = peak_valid_i;
assign ram_dout_addr_o = cnt_out;


//Busy and done
always @(posedge clk_i)
if(~rst_ni | last_dout)
  busy <= 0;
else if(start_i)
  busy <= 1;

always @(posedge clk_i)
  done <= last_dout;

assign last_dout = peak_valid_i & cnt_out==(N1-1);
assign busy_o    = busy;
assign done_o    = done;

endmodule