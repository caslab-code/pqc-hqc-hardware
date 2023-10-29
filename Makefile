SHELL := /bin/bash

#keygen
pk_seed = 0 #random seed in hex (The maximum seed length should not exceed 320-bits)
sk_seed = 0 #random seed in hex (The maximum seed length should not exceed 320-bits)
pk_seed_filename = "pk_seed.in"
sk_seed_filename = "sk_seed.in"
# seed = $(shell python -c 'from random import randint; print(randint(1023, 65535));') #random seed in hex (The maximum seed length should not exceed 256-bits)

#encap
msg_128 = 000102030405060708090a0b0c0d0e0f #message input hex (The maximum message length depends on the security level)
msg_192 = 000102030405060708090a0b0c0d0e0f1011121314151617 #message input hex (The maximum message length depends on the security level)
msg_256 = 000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f #message input hex (The maximum message length depends on the security level)
msg128_file_name = "msg_128.in"
msg192_file_name = "msg_192.in"
msg256_file_name = "msg_256.in"


default: run

run:./build_all


build_all:./build_keygen ./build_encap ./build_decap

run_xilinx_sim_decap:./run_xilinx_sim_keygen ./run_xilinx_sim_encap ./build_decap
	#copy keygen and encap output files required for decap
	cp ./test_keygen/test_keygen.sim/sim_1/behav/xsim/s_128.in ./build/decap/tb/
	cp ./test_keygen/test_keygen.sim/sim_1/behav/xsim/s_192.in ./build/decap/tb/
	cp ./test_keygen/test_keygen.sim/sim_1/behav/xsim/s_256.in ./build/decap/tb/
	cp ./test_keygen/test_keygen.sim/sim_1/behav/xsim/h_128.in ./build/decap/tb/
	cp ./test_keygen/test_keygen.sim/sim_1/behav/xsim/h_192.in ./build/decap/tb/
	cp ./test_keygen/test_keygen.sim/sim_1/behav/xsim/h_256.in ./build/decap/tb/
	cp ./test_keygen/test_keygen.sim/sim_1/behav/xsim/x_128.in ./build/decap/tb/
	cp ./test_keygen/test_keygen.sim/sim_1/behav/xsim/x_192.in ./build/decap/tb/
	cp ./test_keygen/test_keygen.sim/sim_1/behav/xsim/x_256.in ./build/decap/tb/
	cp ./test_keygen/test_keygen.sim/sim_1/behav/xsim/y_128.in ./build/decap/tb/
	cp ./test_keygen/test_keygen.sim/sim_1/behav/xsim/y_192.in ./build/decap/tb/
	cp ./test_keygen/test_keygen.sim/sim_1/behav/xsim/y_256.in ./build/decap/tb/

	cp ./test_encap/test_encap.sim/sim_1/behav/xsim/d_128.in ./build/decap/tb/
	cp ./test_encap/test_encap.sim/sim_1/behav/xsim/d_192.in ./build/decap/tb/
	cp ./test_encap/test_encap.sim/sim_1/behav/xsim/d_256.in ./build/decap/tb/
	cp ./test_encap/test_encap.sim/sim_1/behav/xsim/u_128.in ./build/decap/tb/
	cp ./test_encap/test_encap.sim/sim_1/behav/xsim/u_192.in ./build/decap/tb/
	cp ./test_encap/test_encap.sim/sim_1/behav/xsim/u_256.in ./build/decap/tb/
	cp ./test_encap/test_encap.sim/sim_1/behav/xsim/v_128.in ./build/decap/tb/
	cp ./test_encap/test_encap.sim/sim_1/behav/xsim/v_192.in ./build/decap/tb/
	cp ./test_encap/test_encap.sim/sim_1/behav/xsim/v_256.in ./build/decap/tb/
	cp ./test_encap/test_encap.sim/sim_1/behav/xsim/s_128.in ./build/decap/tb/
	cp ./test_encap/test_encap.sim/sim_1/behav/xsim/s_192.in ./build/decap/tb/
	cp ./test_encap/test_encap.sim/sim_1/behav/xsim/s_256.in ./build/decap/tb/

	vivado -mode batch -nojournal -nolog -notrace -source ./build/decap/tb/decap.tcl	# running

	#copy output files
	mkdir ./build/decap/output
	cp ./test_decap/test_decap.sim/sim_1/behav/xsim/ss_output_128.out ./build/decap/output/
	cp ./test_decap/test_decap.sim/sim_1/behav/xsim/ss_output_192.out ./build/decap/output/
	cp ./test_decap/test_decap.sim/sim_1/behav/xsim/ss_output_256.out ./build/decap/output/

run_xilinx_sim_encap:./run_xilinx_sim_keygen ./build_encap

	#copy keygen output files required for encap
	cp ./test_keygen/test_keygen.sim/sim_1/behav/xsim/s_128.in ./build/encap/tb/
	cp ./test_keygen/test_keygen.sim/sim_1/behav/xsim/s_192.in ./build/encap/tb/
	cp ./test_keygen/test_keygen.sim/sim_1/behav/xsim/s_256.in ./build/encap/tb/
	cp ./test_keygen/test_keygen.sim/sim_1/behav/xsim/h_128.in ./build/encap/tb/
	cp ./test_keygen/test_keygen.sim/sim_1/behav/xsim/h_192.in ./build/encap/tb/
	cp ./test_keygen/test_keygen.sim/sim_1/behav/xsim/h_256.in ./build/encap/tb/
	cp ./test_keygen/test_keygen.sim/sim_1/behav/xsim/x_128.in ./build/encap/tb/
	cp ./test_keygen/test_keygen.sim/sim_1/behav/xsim/x_192.in ./build/encap/tb/
	cp ./test_keygen/test_keygen.sim/sim_1/behav/xsim/x_256.in ./build/encap/tb/
	cp ./test_keygen/test_keygen.sim/sim_1/behav/xsim/y_128.in ./build/encap/tb/
	cp ./test_keygen/test_keygen.sim/sim_1/behav/xsim/y_192.in ./build/encap/tb/
	cp ./test_keygen/test_keygen.sim/sim_1/behav/xsim/y_256.in ./build/encap/tb/
	
	vivado -mode batch -nojournal -nolog -notrace -source ./build/encap/tb/encap.tcl	# running 
	
	#copy output files
	mkdir ./build/encap/output
	cp ./test_encap/test_encap.sim/sim_1/behav/xsim/d_output_128.out ./build/encap/output/
	cp ./test_encap/test_encap.sim/sim_1/behav/xsim/d_output_192.out ./build/encap/output/
	cp ./test_encap/test_encap.sim/sim_1/behav/xsim/d_output_256.out ./build/encap/output/
	cp ./test_encap/test_encap.sim/sim_1/behav/xsim/u_output_128.out ./build/encap/output/
	cp ./test_encap/test_encap.sim/sim_1/behav/xsim/u_output_192.out ./build/encap/output/
	cp ./test_encap/test_encap.sim/sim_1/behav/xsim/u_output_256.out ./build/encap/output/
	cp ./test_encap/test_encap.sim/sim_1/behav/xsim/v_output_128.out ./build/encap/output/
	cp ./test_encap/test_encap.sim/sim_1/behav/xsim/v_output_192.out ./build/encap/output/
	cp ./test_encap/test_encap.sim/sim_1/behav/xsim/v_output_256.out ./build/encap/output/
	cp ./test_encap/test_encap.sim/sim_1/behav/xsim/ss_output_128.out ./build/encap/output/
	cp ./test_encap/test_encap.sim/sim_1/behav/xsim/ss_output_192.out ./build/encap/output/
	cp ./test_encap/test_encap.sim/sim_1/behav/xsim/ss_output_256.out ./build/encap/output/

run_xilinx_sim_keygen:./build_keygen
	mkdir ./build/keygen/output
	vivado -mode batch -nojournal -nolog -notrace -source ./build/keygen/tb/keygen.tcl	# running 
	cp ./test_keygen/test_keygen.sim/sim_1/behav/xsim/s_128.in ./build/keygen/output/
	cp ./test_keygen/test_keygen.sim/sim_1/behav/xsim/s_192.in ./build/keygen/output/
	cp ./test_keygen/test_keygen.sim/sim_1/behav/xsim/s_256.in ./build/keygen/output/
	cp ./test_keygen/test_keygen.sim/sim_1/behav/xsim/h_128.in ./build/keygen/output/
	cp ./test_keygen/test_keygen.sim/sim_1/behav/xsim/h_192.in ./build/keygen/output/
	cp ./test_keygen/test_keygen.sim/sim_1/behav/xsim/h_256.in ./build/keygen/output/
	cp ./test_keygen/test_keygen.sim/sim_1/behav/xsim/x_128.in ./build/keygen/output/
	cp ./test_keygen/test_keygen.sim/sim_1/behav/xsim/x_192.in ./build/keygen/output/
	cp ./test_keygen/test_keygen.sim/sim_1/behav/xsim/x_256.in ./build/keygen/output/
	cp ./test_keygen/test_keygen.sim/sim_1/behav/xsim/y_128.in ./build/keygen/output/
	cp ./test_keygen/test_keygen.sim/sim_1/behav/xsim/y_192.in ./build/keygen/output/
	cp ./test_keygen/test_keygen.sim/sim_1/behav/xsim/y_256.in ./build/keygen/output/



build_keygen: 
	mkdir ./build/keygen
	mkdir ./build/keygen/tb

	cp ./hardware/keygen/keygen.v ./build/keygen/
	cp ./hardware/keygen/vect_set_random.v ./build/keygen/
	
	cp ./hardware/common/fixed_weight/fixed_weight.v ./build/keygen/
	cp ./hardware/common/fixed_weight/onegen.v ./build/keygen/
	cp ./hardware/common/fixed_weight/fixed_weight_ct.v ./build/keygen/
	cp ./hardware/common/fixed_weight/onegen_ct.v ./build/keygen/
	cp ./hardware/common/fixed_weight/hqc_barrett_red.v ./build/keygen/

	cp ./hardware/common/memory/* ./build/keygen/
	
	
	
	cp ./hardware/common/clog2.v ./build/keygen/
	cp ./hardware/common/poly_mult/poly_mult.v	./build/keygen/
	cp ./hardware/common/shake256/rtl/* ./build/keygen/
	
	cp ./hardware/common/adders/* ./build/keygen/
	# cp -r ./hardware/common/barrett_reduction/* ./build/keygen/
	
	cp ./hardware/keygen/tcl/keygen.tcl ./build/keygen/tb/

	cp ./hardware/keygen/memory_files/seed_align.py ./build/keygen/
	
	cp ./hardware/keygen/tb/keygen_tb.v ./build/keygen/tb/

	python ./build/keygen/seed_align.py seed_align $(pk_seed) $(pk_seed_filename) 	# aligning seed for the hardware input
	python ./build/keygen/seed_align.py seed_align $(sk_seed) $(sk_seed_filename)	# aligning seed for the hardware input

	mv pk_seed.in ./build/keygen/tb/
	mv sk_seed.in ./build/keygen/tb/

	# vivado -mode batch -nojournal -nolog -notrace -source ./build/keygen/tb/keygen.tcl	# running 



build_encap: 
	mkdir ./build/encap
	mkdir ./build/encap/tb

	cp ./hardware/encap/encap.v ./build/encap/
	cp ./hardware/encap/*.v ./build/encap/
	
	cp ./hardware/common/fixed_weight/fixed_weight.v ./build/encap/
	# cp ./hardware/common/fixed_weight/onegen.v ./build/encap/
	cp ./hardware/common/memory/* ./build/encap/
	
	# cp ./hardware/common/fixed_weight/fixed_weight_ct.v ./build/encap/
	# cp ./hardware/common/fixed_weight/hqc_barrett_red.v ./build/encap/
	# cp ./hardware/common/fixed_weight/fixed_weight_cww.v ./build/encap/
	cp -r ./hardware/common/fixed_weight/* ./build/encap/
	
	cp ./hardware/common/clog2.v ./build/encap/
	cp ./hardware/common/poly_mult/poly_mult.v	./build/encap/
	cp ./hardware/common/shake256/rtl/* ./build/encap/
	
	cp ./hardware/common/adders/* ./build/encap/
	cp -r ./hardware/common/barrett_reduction/* ./build/encap/

	cp ./hardware/encap/tb/encap_tb.v ./build/encap/tb/
	
	cp ./hardware/encap/memory_files/seed_align.py ./build/encap/

	cp ./hardware/encap/tcl/encap.tcl ./build/encap/tb/


	python ./build/encap/seed_align.py seed_align $(msg_128) 16 $(msg128_file_name) "no"	# aligning seed for the hardware input
	python ./build/encap/seed_align.py seed_align $(msg_192) 24 $(msg192_file_name) "no"	# aligning seed for the hardware input
	python ./build/encap/seed_align.py seed_align $(msg_256) 32 $(msg256_file_name) "no"	# aligning seed for the hardware input
	
	mv $(msg128_file_name) ./build/encap/tb/
	mv $(msg192_file_name) ./build/encap/tb/
	mv $(msg256_file_name) ./build/encap/tb/

	# vivado -mode batch -nojournal -nolog -notrace -source ./build/encap/encap.tcl
	
	
build_decap: 
	mkdir ./build/decap
	mkdir ./build/decap/tb

	cp ./hardware/decap/*.v ./build/decap/
	
	cp ./hardware/encap/*.v ./build/decap/
	
	# cp ./hardware/common/fixed_weight/fixed_weight.v ./build/decap/
	# cp ./hardware/common/fixed_weight/onegen.v ./build/decap/
	cp -r ./hardware/common/fixed_weight/* ./build/decap/
	cp ./hardware/common/memory/* ./build/decap/
	
	# cp ./hardware/common/fixed_weight/fixed_weight_ct.v ./build/decap/
	# cp ./hardware/common/fixed_weight/fixed_weight_cww.v ./build/decap/
	
	cp ./hardware/common/clog2.v ./build/decap/
	cp ./hardware/common/poly_mult/poly_mult.v	./build/decap/
	cp ./hardware/common/shake256/rtl/* ./build/decap/
	
	cp ./hardware/common/adders/* ./build/decap/
	cp -r ./hardware/common/barrett_reduction/* ./build/decap/
	
	cp ./hardware/decap/tb/decap_tb.v ./build/decap/tb/
	cp ./hardware/decap/tcl/decap.tcl ./build/decap/tb/
	

	# cp ./test_encap/test_encap.sim/sim_1/behav/xsim/d_128.in ./build/encap/output/
	# cp ./test_encap/test_encap.sim/sim_1/behav/xsim/d_192.in ./build/encap/output/
	# cp ./test_encap/test_encap.sim/sim_1/behav/xsim/d_256.in ./build/encap/output/
	# cp ./test_encap/test_encap.sim/sim_1/behav/xsim/u_128.in ./build/encap/output/
	# cp ./test_encap/test_encap.sim/sim_1/behav/xsim/u_192.in ./build/encap/output/
	# cp ./test_encap/test_encap.sim/sim_1/behav/xsim/u_256.in ./build/encap/output/
	# cp ./test_encap/test_encap.sim/sim_1/behav/xsim/v_128.in ./build/encap/output/
	# cp ./test_encap/test_encap.sim/sim_1/behav/xsim/v_192.in ./build/encap/output/
	# cp ./test_encap/test_encap.sim/sim_1/behav/xsim/v_256.in ./build/encap/output/
	# cp ./test_encap/test_encap.sim/sim_1/behav/xsim/y_128.in ./build/encap/output/
	# cp ./test_encap/test_encap.sim/sim_1/behav/xsim/y_192.in ./build/encap/output/
	# cp ./test_encap/test_encap.sim/sim_1/behav/xsim/y_256.in ./build/encap/output/

	# vivado -mode batch -nojournal -nolog -notrace -source ./build/decap/decap.tcl

	
	
	
build_joint_design:
	mkdir ./build/joint_design
	mkdir ./build/joint_design/tb
	
	cp ./hardware/joint_design/*.v ./build/joint_design/
	
	cp ./hardware/keygen/*.v ./build/joint_design/
	
	cp ./hardware/decap/*.v ./build/joint_design/
	
	cp ./hardware/encap/*.v ./build/joint_design/
	
	cp ./hardware/common/fixed_weight/* ./build/joint_design/
	cp ./hardware/common/memory/* ./build/joint_design/
		
	cp ./hardware/common/clog2.v ./build/joint_design/
	cp ./hardware/common/poly_mult/poly_mult.v	./build/joint_design/
	cp ./hardware/common/shake256/rtl/* ./build/joint_design/
	
	cp ./hardware/common/adders/* ./build/joint_design/
	cp ./hardware/common/barrett_reduction/* ./build/joint_design/
	
	cp ./hardware/joint_design/tcl/joint_design.tcl ./build/joint_design/tb/
	cp ./hardware/joint_design/tb/* ./build/joint_design/tb/

	cp ./hardware/encap/memory_files/seed_align.py ./build/joint_design/

	python ./build/joint_design/seed_align.py seed_align $(pk_seed) 40 $(pk_seed_filename) "yes"	# aligning seed for the hardware input
	python ./build/joint_design/seed_align.py seed_align $(sk_seed) 40 $(sk_seed_filename) "yes"	# aligning seed for the hardware input


	python ./build/joint_design/seed_align.py seed_align $(msg_128) 16 $(msg128_file_name) "no"	# aligning seed for the hardware input
	python ./build/joint_design/seed_align.py seed_align $(msg_192) 24 $(msg192_file_name) "no"	# aligning seed for the hardware input
	python ./build/joint_design/seed_align.py seed_align $(msg_256) 32 $(msg256_file_name) "no"	# aligning seed for the hardware input
	
	mv pk_seed.in ./build/joint_design/tb/
	mv sk_seed.in ./build/joint_design/tb/
	mv msg_128.in ./build/joint_design/tb/
	mv msg_192.in ./build/joint_design/tb/
	mv msg_256.in ./build/joint_design/tb/

	vivado -mode batch -nojournal -nolog -notrace -source ./build/joint_design/tb/joint_design.tcl


clean:
	rm -rf ./build/*
	rm -rf .Xil
	rm -rf test_*

