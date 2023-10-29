
module fixed_weight_cww_tb
  #(
    parameter parameter_set = "hqc256",
    
    
    parameter N = (parameter_set == "hqc128")? 17_669:
				  (parameter_set == "hqc192")? 35_851:
			      (parameter_set == "hqc256")? 57_637: 
                                               17_669,
                                         
    parameter M = (parameter_set == "hqc128")? 15:
				  (parameter_set == "hqc192")? 16:
			      (parameter_set == "hqc256")? 16: 
                                               15,    
    
   parameter WEIGHT = (parameter_set == "hqc128")? 75:
					   (parameter_set == "hqc192")? 114:
					   (parameter_set == "hqc256")? 149:
                                                    75,
                                        
    // common parameters
    parameter LOG_WEIGHT = `CLOG2(WEIGHT),
    parameter E0_WIDTH = 32,
    parameter E1_WIDTH = 32,
    parameter SEED_SIZE = 320                                       
                                      
  );

// input  
reg clk = 1'b0;
reg rst = 1'b0;
reg seed_valid = 1'b0;
reg [31:0] seed = 32'b0;
reg [31:0] seed_test = 32'b0;
reg start = 1'b0;

// output
wire done;
wire valid_vector;
wire [31:0] vector;

wire [E0_WIDTH-1:0] error_0;
wire rd_e_0 =0;
wire [`CLOG2((N+(E0_WIDTH - N%E0_WIDTH)%E0_WIDTH)/E0_WIDTH) - 1 : 0]rd_addr_e_0=0;

wire rd_e_1=0;
wire [`CLOG2((N+(E1_WIDTH - N%E1_WIDTH)%E1_WIDTH)/E1_WIDTH) - 1 : 0]rd_addr_e_1=0;
wire [E1_WIDTH-1:0] error_1;


//ram controls
reg [3:0] addr;
wire [31:0] seed_from_ram;

 //shake signals
wire seed_valid_internal;
wire seed_ready_internal;
wire [31:0] din_shake;
wire shake_out_capture_ready;
wire [31:0] dout_shake_scrambled;
wire force_done_shake;
wire dout_valid_sh_internal;
reg [1:0]request_another_vector = 0;

wire [M-1:0] error_loc; 
reg  rd_error_loc = 0;
reg [LOG_WEIGHT - 1 : 0]rd_addr_error_loc = 0;

reg [31:0] sk_seed =0;
reg [3:0]sk_seed_addr = 0;
reg sk_seed_wen =0;
  fixed_weight_cww #(.parameter_set(parameter_set), .N(N), .M(M), .WEIGHT(WEIGHT), .FILE_SKSEED("hqc_pk_seed_from_spec.mem") )
  DUT  (
    .clk(clk),
    .rst(rst),
    .start(start),
    .sk_seed_addr(sk_seed_addr),
    .sk_seed(sk_seed),
    .sk_seed_wen(sk_seed_wen),
    .done(done),
    .request_another_vector(request_another_vector),
    .valid_vector(valid_vector),
    
    .error_loc(error_loc), 
    .rd_error_loc(rd_error_loc), 
    .rd_addr_error_loc(rd_addr_error_loc),
    
//    .error_0(error_0), 
//    .rd_e_0(rd_e_0), 
//    .rd_addr_e_0(rd_addr_e_0),
    
//    .rd_e_1(rd_e_1), 
//    .rd_addr_e_1(rd_addr_e_1),
//    .error_1(error_1),
    
        //shake signals
    .seed_valid_internal(seed_valid_internal),
    .seed_ready_internal(seed_ready_internal),
    .din_shake(din_shake),
    .shake_out_capture_ready(shake_out_capture_ready),
    .dout_shake_scrambled(dout_shake_scrambled),
    .force_done_shake(force_done_shake),
    .dout_valid_sh_internal(dout_valid_sh_internal)
  );
  
 keccak_top
SHAKE256(
.clk(clk),
.rst(rst),
.din_valid(seed_valid_internal),
.din_ready(seed_ready_internal),
.din(din_shake),
.dout_valid(dout_valid_sh_internal),
.dout_ready(shake_out_capture_ready),
.dout(dout_shake_scrambled),
.force_done(force_done_shake)
);

  integer start_time;
  
  initial
    begin
    rst <= 1'b1;
    addr <= 0;
    # 20;
    rst <= 1'b0;
    #100
    start_time = $time;
    
    start <= 1'b1; 
    
    #10
    start <= 1'b0;

    
    seed_valid <= 1'b0;

      @(posedge done);
      $display("Total Clock Cycles for 1st:",($time-start_time)/10);
      #100
      
      request_another_vector <= 2'b11;
      
      #10
      
      request_another_vector <= 2'b00;
      
      @(posedge done);
      $display("Total Clock Cycles for 2nd:",($time-start_time)/10);
      #100
      
      request_another_vector <= 2'b11;
      
      #10
      
      request_another_vector <= 2'b00;
      
      @(posedge done);
      $display("Total Clock Cycles for 3rd:",($time-start_time)/10);
      
      # 10000;
      $finish;
    end
  
  always 
    begin
      @(posedge DUT.start_onegen);
      $writememb("loc.out", DUT.loca_mem.mem);
      $fflush();
    end

   // output file to see the final fixed weight vector output
    always 
    begin
      @(posedge DUT.done);
      case (parameter_set)
      
        "hqc128": begin
//            $writememb("mem_vector_128_1.out", DUT.onegen_instance.mem_dual_A.mem);
            $writememh("locations_128_1.out", DUT.loca_mem.mem);
            $fflush();
           end
        
        "hqc192": begin
//            $writememb("mem_vector_192_1.out", DUT.onegen_instance.mem_dual_A.mem);
            $writememh("locations_192_1.out", DUT.loca_mem.mem);
            $fflush();
           end

        "hqc256": begin
//            $writememb("mem_vector_256_1.out", DUT.onegen_instance.mem_dual_A.mem);
            $writememh("locations_256_1.out", DUT.loca_mem.mem);
            $fflush();
           end

           
      default:  begin
//                $writememb("mem_vector_fw_def_1.out", DUT.onegen_instance.mem_dual_A.mem);
                $fflush();
                end
      endcase
      
      #1000
      
      @(posedge DUT.done);
      case (parameter_set)
      
        "hqc128": begin
//            $writememb("mem_vector_128_2.out", DUT.onegen_instance.mem_dual_A.mem);
            $writememh("locations_128_2.out", DUT.loca_mem.mem);
            $fflush();
           end
        
        "hqc192": begin
//            $writememb("mem_vector_192_2.out", DUT.onegen_instance.mem_dual_A.mem);
            $writememh("locations_192_2.out", DUT.loca_mem.mem);
            $fflush();
           end

        "hqc256": begin
//            $writememb("mem_vector_256_2.out", DUT.onegen_instance.mem_dual_A.mem);
            $writememh("locations_256_2.out", DUT.loca_mem.mem);
            $fflush();
           end

           
      default:  begin
//                $writememb("mem_vector_fw_def_2.out", DUT.onegen_instance.mem_dual_A.mem);
                $fflush();
                end
      endcase
      
    end    
    

         
  
always 
  # 5 clk = !clk;


// mem_single #(.WIDTH(32), .DEPTH(10), .FILE("mem.out") ) mem_init_seed
// mem_single #(.WIDTH(32), .DEPTH(10), .FILE("pk_seed.in") ) mem_init_seed
 mem_single #(.WIDTH(32), .DEPTH(10), .FILE("hqc_pk_seed_from_spec.mem") ) mem_init_seed
 (
        .clock(clk),
        .data(0),
        .address(addr),
        .wr_en(0),
        .q(seed_from_ram)
 );  
  
 
wire [31:0] a;
wire [31:0] in = 24'hf6c62f;
parameter mod = 15'h4505;
assign a = in%mod;// - mod*(in / mod);

endmodule


//  set_property generic parameter_set=1 [get_filesets sim_1]
//  relaunch_sim
//  run 1000 us
  
//  set_property generic parameter_set=2 [get_filesets sim_1]
//  relaunch_sim
//  run 1000 us
  
//  set_property generic parameter_set=3 [get_filesets sim_1]
//  relaunch_sim
//  run 1000 us
  
//  set_property generic parameter_set=4 [get_filesets sim_1]
//  relaunch_sim
//  run 1000 us
  
//  set_property generic parameter_set=5 [get_filesets sim_1]
//  relaunch_sim
//  run 1000 us


//diff mem_vector_fw_1.out ev_p1.out -w
//diff mem_vector_fw_2.out ev_p2.out -w
//diff mem_vector_fw_3.out ev_p3.out -w
//diff mem_vector_fw_4.out ev_p4.out -w
//diff mem_vector_fw_5.out ev_p5.out -w
  
  
  
  
  
  
  