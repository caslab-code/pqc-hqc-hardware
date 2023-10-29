// =============================================================================
// ==                     Technology Innovation Institute                     ==
// =============================================================================
//
// hqc_rmdecod_findpeaks.v
// Find Peaks module of RM Decoding for HQC
//
//
//
// 202207xx TII Hardware Team
//
// =============================================================================

module hqc_rmdecod_findpeaks #(

    parameter PARAM_SECURITY = 128,
    parameter MULTIPLICITY   = (PARAM_SECURITY == 128)? 3 : 5,
    parameter SUM_W          = (PARAM_SECURITY == 128)? 2 : 3,
    parameter DIN_W          = 1 + SUM_W + 7,
    parameter DOUT_W         = 8
    )(
    input                   clk_i,
    input                   rst_ni,
    input                   start_i,
    input   [DIN_W-1:0]     din0_i,
    input   [DIN_W-1:0]     din1_i,
    input                   din_valid_i,
    output  [DOUT_W-1:0]    dout_o,
    output                  dout_valid_o
    );

reg                     dout_valid;
reg     [DOUT_W-1:0]    dout;

wire    [DIN_W-1:0]     peak_value0, peak_value1, next_value;
wire    [DIN_W-2:0]     peak_abs0, peak_abs1;
wire    [6:0]           peak_pos0, peak_pos1, next_pos;
wire					dout_valid0, dout_valid1;
wire					check_abs, check_equ, check_pos;




//Compare absolute value
assign check_abs = (peak_abs1>peak_abs0);
assign check_equ = (peak_abs1==peak_abs0);
assign check_pos = (peak_pos1>peak_pos0);

//Next values
assign next_pos   = (check_equ & check_pos | check_abs)? peak_pos1   : peak_pos0;
assign next_value = (check_equ & check_pos | check_abs)? peak_value1 : peak_value0;


//Outputs
always @(posedge clk_i)
begin
  dout_valid <= dout_valid0;
  dout       <= {~(next_value[DIN_W-1] | next_value[DIN_W-2:0]==0), next_pos}; 
  // dout       <= {(next_value>0), next_pos}; 
end

assign dout_o       = dout;
assign dout_valid_o = dout_valid;


findpeaks_core #(
    .PARAM_SECURITY(PARAM_SECURITY),
    .DIN_W         (DIN_W         ),
    .DOUT_W        (7             ),
    .STARTPOS      (0             ))
FIND_PEAKS_0(
    .clk_i         (clk_i       ),
    .rst_ni        (rst_ni      ),
    .start_i       (start_i     ),
    .din_i         (din0_i      ),
    .din_valid_i   (din_valid_i ),
    .peak_abs_o    (peak_abs0   ),
    .peak_pos_o    (peak_pos0   ),
    .peak_value_o  (peak_value0 ),
    .dout_valid_o  (dout_valid0 ));


findpeaks_core #(
    .PARAM_SECURITY(PARAM_SECURITY),
    .DIN_W         (DIN_W         ),
    .DOUT_W        (7             ),
    .STARTPOS      (1             ))
FIND_PEAKS_1(
    .clk_i         (clk_i       ),
    .rst_ni        (rst_ni      ),
    .start_i       (start_i     ),
    .din_i         (din1_i      ),
    .din_valid_i   (din_valid_i ),
    .peak_abs_o    (peak_abs1  ),
    .peak_pos_o    (peak_pos1  ),
    .peak_value_o  (peak_value1),
    .dout_valid_o  (dout_valid1));

endmodule


module findpeaks_core #(

    parameter PARAM_SECURITY = 128,
    parameter DIN_W          = 10,
    parameter DOUT_W         = 8,
    parameter STARTPOS       = 0 //0 for even, 1 for odd
    )(
    input                   clk_i,
    input                   rst_ni,
    input                   start_i,
    input   [DIN_W-1:0]     din_i,
    input                   din_valid_i,
    output  [DIN_W-2:0]     peak_abs_o,
    output  [DOUT_W-1:0]    peak_pos_o,
    output  [DIN_W-1:0]     peak_value_o,
    output                  dout_valid_o
    );

reg                     start_d;
reg     [6:0]   		cnt_in;
reg						dout_valid;

reg     [DIN_W-1:0]     peak_value;
reg     [DIN_W-1:0]     peak_abs;
reg     [DOUT_W-1:0]    peak_pos;

wire    [DIN_W-1:0]     prev_value, next_value, din_value;
wire    [DIN_W-2:0]     prev_abs, next_abs, din_abs;
wire    [DOUT_W-1:0]    prev_pos, next_pos, din_pos;
wire					check_abs;

//Input values
assign din_value = din_i;
assign din_abs   = din_i[DIN_W-1]? ~din_i + 1 : din_i;
assign din_pos   = cnt_in;

//Previous values
assign prev_abs   = start_d? 0 : peak_abs;
assign prev_pos   = start_d? STARTPOS : peak_pos;
assign prev_value = start_d? 0 : peak_value;

//Compare absolute value
assign check_abs = (din_abs>prev_abs);

//Next values
assign next_abs   = check_abs? din_abs   : prev_abs;
assign next_pos   = check_abs? din_pos   : prev_pos;
assign next_value = check_abs? din_value : prev_value;

//Delayed input start
always @(posedge clk_i)
  start_d <= start_i;


always @(posedge clk_i)
if(din_valid_i)
begin
  peak_abs   <= next_abs;
  peak_pos   <= next_pos;
  peak_value <= next_value;
end

assign peak_abs_o   = peak_abs;
assign peak_pos_o   = peak_pos;
assign peak_value_o = peak_value;

//Controller
//Input Counter
always @(posedge clk_i)
if(~rst_ni | start_i | last_din)
  cnt_in <= STARTPOS;
else if(din_valid_i)
  cnt_in <= cnt_in + 2;

assign last_din = cnt_in[6:1]==63 & din_valid_i;

//Output valid
always @(posedge clk_i)
  dout_valid <= last_din;

assign dout_valid_o = dout_valid;



endmodule
