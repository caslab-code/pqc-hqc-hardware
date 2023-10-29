//`include "clog2.v"
module poly_mult_hqc_v1_tb
  #(
    parameter parameter_set = "hqc128",
    
//    parameter MAX_WEIGHT = (parameter_set == "hqc128")? 71: 
    parameter MAX_WEIGHT = (parameter_set == "hqc128")? 75: 
                           (parameter_set == "hqc192")? 114:
			               (parameter_set == "hqc256")? 149:
			               (parameter_set == "bike")? 71:
                                                        4,
                                                        
//    parameter WEIGHT = (parameter_set == "hqc128")? 71: 
    parameter WEIGHT = (parameter_set == "hqc128")? 66: 
//                       (parameter_set == "hqc192")? MAX_WEIGHT: //100:
                       (parameter_set == "hqc192")? 100:
			           (parameter_set == "hqc256")? 131:
			           (parameter_set == "bike")? 71:
                                                    4,
    
//    parameter N = (parameter_set == "hqc128")? 12323:
    parameter N = (parameter_set == "hqc128")? 17_669:
				  (parameter_set == "hqc192")? 35_851:
			      (parameter_set == "hqc256")? 57_637: 
			      (parameter_set == "bike")? 12323: 
                                               31,
        
//    parameter M = (parameter_set == "hqc128")? 14:
    parameter M = (parameter_set == "hqc128")? 15:
				  (parameter_set == "hqc192")? 16:
			      (parameter_set == "hqc256")? 16: 
			      (parameter_set == "bike")? 14: 
                                               4, 
                                               
	
	
	//128
    parameter RAMWIDTH = 64, // Width of each chunk W needs to be divided in to. Best to choose a 2 power
    parameter TWO_N = 2*N,
    parameter W_RAMWIDTH = TWO_N + (RAMWIDTH-TWO_N%RAMWIDTH)%RAMWIDTH, 
//    parameter W_RAMWIDTH = N + (RAMWIDTH-N%RAMWIDTH)%RAMWIDTH, 
    parameter W = W_RAMWIDTH + RAMWIDTH*((W_RAMWIDTH/RAMWIDTH)%2),
    parameter X = W/RAMWIDTH,
    
	


//	parameter W = WIDTH + (2**LOG_WIDTH - WIDTH%(2**LOG_WIDTH))%2**LOG_WIDTH,  
//  parameter X = (W+(RAMWIDTH-W%RAMWIDTH)%RAMWIDTH)/RAMWIDTH, 
    parameter LOGX = `CLOG2(X), 
    parameter Y = X/2,
	parameter LOGW = `CLOG2(W),
	parameter W_BY_X = W/X, 
	parameter W_BY_Y = W/Y, // This number needs to be a power of 2 for optimized synthesis
	parameter RAMSIZE = X + X%2,
	parameter ADDR_WIDTH = `CLOG2(RAMSIZE),
	parameter LOG_WEIGHT = `CLOG2(WEIGHT),
    parameter LOG_MAX_WEIGHT = `CLOG2(MAX_WEIGHT),
    
      // memory related constants
	parameter MEM_WIDTH = RAMWIDTH,	
	parameter N_MEM = N + (MEM_WIDTH - N%MEM_WIDTH)%MEM_WIDTH, // Memory width adjustment for N
	parameter N_B = N + (8-N%8)%8, // Byte adjustment on N
	parameter N_Bd = N_B - N, // difference between N and byte adjusted N
	parameter N_MEMd = N_MEM - N_B // difference between byte adjust and Memory adjusted N                                     
                                      
  );

// input  

//(    );


reg clk =0;
reg rst;
reg start =0;
reg [W_BY_X-1:0]din =0;
reg [LOGW-1:0]shift =0;
reg wr_en =0;
reg [ADDR_WIDTH-1:0]addr = 0;
reg [ADDR_WIDTH-1:0]addr_result = 0;
wire valid;
wire [W_BY_X-1:0]dout, dout_rearrange;
reg rd_dout;
  integer start_time, end_time;

   
  poly_mult_opt_1 #(
  
  .MAX_WEIGHT(MAX_WEIGHT),
  .N(N),
  .M(M),
  .W(W),
  .RAMWIDTH(RAMWIDTH),
  .X(X)
  
  )
  DUT  (
		.clk(clk),
		.rst(rst),
		.start(start),
				
		// Shift Position loading
		.loc_addr(loc_addr),
		.loc_in(loc_in),
		.weight(WEIGHT),
		
		// Random Vector Loading
		.mux_word_0(mux_word_0),
		.mux_word_1(mux_word_1),
		.addr_0(addr_0),
		.addr_1(addr_1),
		
		.valid(valid),
		.addr_result(addr_result),
		.rd_dout(rd_dout),
		.dout(dout),
		
		.add_wr_en(0),
		.add_addr(0),
		.add_in(0)
  );

always@(posedge clk) begin
   addr_0_reg <= addr_0; 
   addr_1_reg <= addr_1; 
end  
  
assign mux_word_0 = (addr_0_reg> RAMSIZE/2 - 1)? 0: dout_0;
assign mux_word_1 = (addr_1_reg> RAMSIZE/2 - 1)? 0: dout_1;  

 
integer red_file,rfile,i;  
always 
  # 5 clk = !clk;
  
  
  initial
    begin
    rfile = $fopen("red_file.out","w");
    rst <= 1'b1;
    start <= 0;
	wr_en <= 0;
	rd_dout <= 0;
	# 20;
    rst <= 1'b0;
    #100
	start <= 1'b1; start_time = $time; #10
	start <= 1'b0;
		
      @(posedge valid);
      end_time = $time;
      $display("Total Clock Cycles:", (end_time - start_time)/10);
      # 1000;
      
      rd_dout = 1;
      for (i = 0; i <N_MEM/MEM_WIDTH; i = i+1) begin
        addr_result <= i;
        #20
            $fdisplay(rfile,"%h",dout_rearrange);  //write as hexadecimal
      end
      $fclose(rfile);
      #40
      $finish;
    end
  
    genvar k;
  generate
    for (k = 0; k < MEM_WIDTH/8; k=k+1) begin:vector_gen_rearrange
        assign dout_rearrange[8*(k+1)-1:8*k] =  dout[MEM_WIDTH-8*(k)-1:MEM_WIDTH-8*(k+1)];
    end
  endgenerate
    
 always 
 begin
   @(posedge valid);
   #100
   case (parameter_set)
  
     "hqc128": begin
//         $writememh("s_128.out", DUT.REDUCTION.REDUCED_VALUE.mem);
//         $writememh("interm_128h.out", DUT.INTERMEDIATE_MEM.mem);
//         $writememb("interm_128b.out", DUT.INTERMEDIATE_MEM.mem);
         $writememh("int_red_128h.out", DUT.INTERLEAVED_RED_MEM.mem);
         $fflush();
        end
    
     "hqc192": begin
//         $writememb("interm.out", DUT.INTERMEDIATE_MEM.mem);
         $fflush();
        end

     "hqc256": begin
//         $writememb("interm.out", DUT.INTERMEDIATE_MEM.mem);
         $fflush();
        end

   default:  begin
             end
   endcase
 end    
    

//parameter random_file = (parameter_set == "hqc128")? "random_vector_128.mem":
parameter random_file = (parameter_set == "hqc128")? "vect_set_random_128.mem":
				        (parameter_set == "hqc192")? "h_192.in":
			            (parameter_set == "hqc256")? "random_vector_256.mem": 
                                                     "smal_para_test.mem";
wire [ADDR_WIDTH-1:0]addr_0;
wire [ADDR_WIDTH-1:0]addr_1;
reg [ADDR_WIDTH-1:0]addr_0_reg;
reg [ADDR_WIDTH-1:0]addr_1_reg;
wire [W_BY_X-1:0] mux_word_0;
wire [W_BY_X-1:0] mux_word_1;
wire [W_BY_X-1:0] dout_0;
wire [W_BY_X-1:0] dout_1;



  mem_dual #(.WIDTH(W_BY_X), .DEPTH(RAMSIZE), .FILE(random_file)) RANDOM_BITS_MEM (
    .clock(clk),
    .data_0(din),
    .data_1(0),
    .address_0(addr_0),
    .address_1(addr_1),
    .wren_0(wr_en),
    .wren_1(0),
    .q_0(dout_0),
    .q_1(dout_1)
  );
  
 
 
wire [LOG_WEIGHT-1:0]loc_addr;
wire [M-1:0] loc_in;


//parameter locations = (parameter_set == "hqc128")? "locations.mem":
parameter locations = (parameter_set == "hqc128")? "y_128.mem":
				      (parameter_set == "hqc192")? "r2_192.in":
			          (parameter_set == "hqc256")? "locations_256.mem": 
                                                   "small_loc.mem";

   mem_single #(.WIDTH(LOGW), .DEPTH(WEIGHT),  .FILE(locations)) POSITION_RAM
 (
        .clock(clk),
        .data(0),
        .address(loc_addr),
        .wr_en(0),
        .q(loc_in)
 );
  
endmodule


  
  
  
  
  
  