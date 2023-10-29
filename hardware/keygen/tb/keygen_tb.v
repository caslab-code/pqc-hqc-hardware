
//`include "clog2.v"

module keygen_tb
  #(
    parameter parameter_set = "hqc128",
    
    
    parameter N = (parameter_set == "hqc128")? 17_669:
				  (parameter_set == "hqc192")? 35_851:
			      (parameter_set == "hqc256")? 57_637: 
                                               17_669,
                                           
    parameter M = (parameter_set == "hqc128")? 15:
				  (parameter_set == "hqc192")? 16:
			      (parameter_set == "hqc256")? 16: 
                                               15, 
                                                                                       
    parameter WEIGHT = (parameter_set == "hqc128")? 66:
					   (parameter_set == "hqc192")? 100:
					   (parameter_set == "hqc256")? 131:
                                                    66,
    parameter LOG_WEIGHT = `CLOG2(WEIGHT),
    // common parameters
    parameter SEED_SIZE = 320,
    
    // memory related constants
	parameter MEM_WIDTH = 128,	
	parameter N_MEM = N + (MEM_WIDTH - N%MEM_WIDTH)%MEM_WIDTH, // Memory width adjustment for N
	parameter N_B = N + (8-N%8)%8, // Byte adjustment on N
	parameter N_Bd = N_B - N, // difference between N and byte adjusted N
	parameter N_MEMd = N_MEM - N_B, // difference between byte adjust and Memory adjusted N                                       
    
    parameter OUT_ADDR_WIDTH = (MEM_WIDTH <= 256)? `CLOG2(N_MEM/MEM_WIDTH) : LOG_WEIGHT                                  
  );

//output filenames
parameter sfilename =   (parameter_set == "hqc128") ? "S_output_128.out":
                        (parameter_set == "hqc192") ? "S_output_192.out":
                        (parameter_set == "hqc256") ? "S_output_256.out":
                                                      "S_output.out";
                                                       
parameter xfilename =   (parameter_set == "hqc128") ? "X_output_128.out":
                        (parameter_set == "hqc192") ? "X_output_192.out":
                        (parameter_set == "hqc256") ? "X_output_256.out":
                                                      "X_output.out";
                                                       
parameter yfilename =   (parameter_set == "hqc128") ? "Y_output_128.out":
                        (parameter_set == "hqc192") ? "Y_output_192.out":
                        (parameter_set == "hqc256") ? "Y_output_256.out":
                                                      "Y_output.out";                                                     

parameter randfilename =    (parameter_set == "hqc128") ? "vect_set_rand_output_128.out":
                            (parameter_set == "hqc192") ? "vect_set_rand_output_192.out":
                            (parameter_set == "hqc256") ? "vect_set_rand_output_256.out":
                                                          "vect_set_rand_output.out";

// input  
reg clk = 1'b0;
reg rst = 1'b0;

reg pk_seed_wen = 1'b0;
reg [3:0] pk_seed_addr = 4'b0;
reg [31:0] pk_seed = 32'b0;

reg sk_seed_wen = 1'b0;
reg [3:0] sk_seed_addr = 4'b0;
reg [31:0] sk_seed = 32'b0;

reg start = 1'b0;

// output
wire done;



//ram controls
reg [3:0] addr;
wire [31:0] seed_from_ram;

 //shake signals
wire shake_din_valid;
wire shake_din_ready;
wire [31:0] shake_din;
wire shake_dout_ready;
wire [31:0] shake_dout_scram;
wire shake_force_done;
wire shake_dout_valid;


reg rand_out_rd = 0;	
reg [`CLOG2(N_MEM/MEM_WIDTH) - 1:0]rand_out_addr_0 = 0;
wire [MEM_WIDTH-1:0] rand_out_0;
reg [`CLOG2(N_MEM/MEM_WIDTH) - 1:0]rand_out_addr_1 = 0;
wire [MEM_WIDTH-1:0] rand_out_1;	

reg [1:0] out_type;	
reg out_rd;	
reg [OUT_ADDR_WIDTH - 1:0]out_addr;	
wire [MEM_WIDTH-1:0] out;
wire [MEM_WIDTH-1:0] out_rearrange;
wire [N_MEM%MEM_WIDTH-1:0] out_rearrange_trimmed;
 
  keygen #(.parameter_set(parameter_set), .N(N), .MEM_WIDTH(MEM_WIDTH), .FILE_PKSEED("pk_seed.in"), .FILE_SKSEED("sk_seed.in") )
  DUT  (
    .clk(clk),
    .rst(rst),
    
    .sk_seed_wen(sk_seed_wen),
	.sk_seed_addr(sk_seed_addr),
	.sk_seed(sk_seed),
    
	.pk_seed_wen(pk_seed_wen),
	.pk_seed_addr(pk_seed_addr),
	.pk_seed(pk_seed),
	
	.start(start),
    .done(done),
    
    .keygen_out_en(out_rd),
    .keygen_out_addr(out_addr),
    .keygen_out(out),
    .keygen_out_type(out_type),
    
        //shake signals
    .shake_din_valid(shake_din_valid),
    .shake_din_ready(shake_din_ready),
    .shake_din(shake_din),
    .shake_dout_ready(shake_dout_ready),
    .shake_dout_scram(shake_dout_scram),
    .shake_force_done(shake_force_done),
    .shake_dout_valid(shake_dout_valid)
  );
  
 keccak_top
SHAKE256(
.clk(clk),
.rst(rst),
.din_valid(shake_din_valid),
.din_ready(shake_din_ready),
.din(shake_din),
.dout_valid(shake_dout_valid),
.dout_ready(shake_dout_ready),
.dout(shake_dout_scram),
.force_done(shake_force_done)
);

  integer start_time, end_time;
  //file descriptors
  integer outfile; 
  integer i,j;
  
  
  
  initial
    begin
    outfile = $fopen(sfilename,"w");
	start <= 1'b0;
    rst <= 1'b1;
    addr <= 0;
    out_rd <= 0;
    out_type <= 2'b00;
    # 20;
    rst <= 1'b0;
    #100
    start_time = $time;
    start <= 1'b1;
	
	#10
	
	start <= 1'b0;
      
      #10
      
      
      @(posedge DUT.done);
      end_time = $time -5;
      $display("Total Clock Cycles:", (end_time - start_time)/10);
      
      #40
      out_type <= 2'b11;
      out_rd <= 1;
      for (i = 0; i <N_MEM/MEM_WIDTH; i = i+1) begin
        out_addr <= i;
        #20
        if (i== (N_MEM/MEM_WIDTH) -1) begin
            $fwrite(outfile,"%h",out_rearrange[MEM_WIDTH-1:N_MEMd]);  //write as hexadecimal
        end
        else begin
            $fwrite(outfile,"%h",out_rearrange);
        end
      end
      $fclose(outfile);
      
      #40
      
      outfile = $fopen(randfilename,"w");
      out_type <= 2'b10;
      out_rd <= 1;
      for (i = 0; i <N_MEM/MEM_WIDTH; i = i+1) begin
        out_addr <= i;
        #20
        if (i== (N_MEM/MEM_WIDTH) -1) begin
            $fwrite(outfile,"%h",out_rearrange[MEM_WIDTH-1:N_MEMd]);  //write as hexadecimal
        end
        else begin
            $fwrite(outfile,"%h",out_rearrange);
        end
      end
      $fclose(outfile);
      
      #40
      
      outfile = $fopen(xfilename,"w");
      out_type <= 2'b00;
      out_rd <= 1;
      for (i = 0; i < WEIGHT; i = i+1) begin
        out_addr <= i;
        #20
            $fdisplay(outfile,"%h",out[M-1:0]);  //write as hexadecimal
      end
      $fclose(outfile);
      
      
      #40
      
      outfile = $fopen(yfilename,"w");
      out_type <= 2'b01;
      out_rd <= 1;
      for (i = 0; i < WEIGHT; i = i+1) begin
        out_addr <= i;
        #20
            $fdisplay(outfile,"%h",out[M-1:0]);  //write as hexadecimal
      end
      $fclose(outfile);
      
      # 10000;
      $finish;
    end
  
  genvar k;
  generate
    for (k = 0; k < MEM_WIDTH/8; k=k+1) begin:vector_gen_rearrange
        assign out_rearrange[8*(k+1)-1:8*k] =  out[MEM_WIDTH-8*(k)-1:MEM_WIDTH-8*(k+1)];
    end
  endgenerate
  
   
   
     always 
     begin
       @(posedge DUT.done);
       case (parameter_set)
      
         "hqc128": begin
             $writememb("h_128.in", DUT.VECTSETRAND.rand_mem.mem);
             $writememb("x_128.in", DUT.x_mem.mem);
             $writememb("y_128.in", DUT.genblk1.FIXEDWEIGHT.loca_mem.mem);
             $writememb("s_128.in", DUT.POLY_MULT.INTERLEAVED_RED_MEM.mem);
             $fflush();
            end
        
         "hqc192": begin
             $writememb("h_192.in", DUT.VECTSETRAND.rand_mem.mem);
             $writememb("x_192.in", DUT.x_mem.mem);
             $writememb("y_192.in", DUT.genblk1.FIXEDWEIGHT.loca_mem.mem);
             $writememb("s_192.in", DUT.POLY_MULT.INTERLEAVED_RED_MEM.mem);
             $fflush();
            end

         "hqc256": begin
             $writememb("h_256.in", DUT.VECTSETRAND.rand_mem.mem);
             $writememb("x_256.in", DUT.x_mem.mem);
             $writememb("y_256.in", DUT.genblk1.FIXEDWEIGHT.loca_mem.mem);
             $writememb("s_256.in", DUT.POLY_MULT.INTERLEAVED_RED_MEM.mem);
             $fflush();
            end

           
       default:  begin
                 end
       endcase
      
     end    
     
     
//     always 
//     begin
//       @(posedge DUT.POLY_MULT.REDUCTION.done);
//       #100
//       case (parameter_set)
      
//         "hqc128": begin
//             $writememh("h_128.in", DUT.POLY_MULT.REDUCTION.REDUCED_VALUE.mem);
//             $fflush();
//            end
        
//         "hqc192": begin
//             $writememh("h_192.in", DUT.POLY_MULT.REDUCTION.REDUCED_VALUE.mem);
//             $fflush();
//            end

//         "hqc256": begin
//             $writememh("h_256.in", DUT.POLY_MULT.REDUCTION.REDUCED_VALUE.mem);
//             $fflush();
//            end

           
//       default:  begin
////                 $writememb("mem_vector_fw_def_1.out", DUT.rand_mem.mem);
////                 $fflush();
//                 end
//       endcase
      
//     end 
     
     
//      always 
//      begin
//        @(posedge done);
//        #100
//        case (parameter_set)
      
//          "hqc128": begin
//              $writememb("h_128.in", DUT.VECTSETRAND.rand_mem.mem);
//              $fflush();
//             end
        
//          "hqc192": begin
//              $writememb("h_192.in", DUT.VECTSETRAND.rand_mem.mem);
//              $fflush();
//             end

//          "hqc256": begin
//              $writememb("h_256.in", DUT.VECTSETRAND.rand_mem.mem);
//              $fflush();
//             end

           
//        default:  begin
// //                 $writememb("mem_vector_fw_def_1.out", DUT.rand_mem.mem);
// //                 $fflush();
//                  end
//        endcase
      
//      end 
    
//     always 
//      begin
//        @(posedge done);
//        #100
//        case (parameter_set)
      
//          "hqc128": begin
// //             $writememh("x_128.out", DUT.x_mem.mem);
// //             $writememb("y_128.in", DUT.FIXEDWEIGHT.loca_mem.mem);
// //             $writememh("y_mem_128.out", DUT.FIXEDWEIGHT.onegen_instance.mem_dual_A.mem);
// //             $fflush();
//             end
        
//          "hqc192": begin
// //             $writememh("x_192.out", DUT.x_mem.mem);
// //             $writememb("y_192.in", DUT.FIXEDWEIGHT.loca_mem.mem);
// //             $fflush();
//             end

//          "hqc256": begin
// //             $writememh("x_256.out", DUT.x_mem.mem);
// //             $writememb("y_256.in", DUT.FIXEDWEIGHT.loca_mem.mem);
// //             $fflush();
//             end

           
//        default:  begin
//                  end
//        endcase
      
//      end 
         
  
always 
  # 5 clk = !clk;


// mem_single #(.WIDTH(32), .DEPTH(10), .FILE("mem.out") ) mem_init_seed
 // mem_single #(.WIDTH(32), .DEPTH(10), .FILE("zero.out") ) mem_init_seed
 // (
        // .clock(clk),
        // .data(0),
        // .address(addr),
        // .wr_en(0),
        // .q(seed_from_ram)
 // );  
  
 

endmodule

  
  
  
  
  
  
  