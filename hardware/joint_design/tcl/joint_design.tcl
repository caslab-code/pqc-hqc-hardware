set start_t [clock seconds]
create_project test_joint_design ./test_joint_design -part xc7a200tfbg676-1
set_property target_language verilog [current_project]
add_files -norecurse {./build/joint_design/}


update_compile_order -fileset sources_1

set_property verilog_define SHARED=1 [current_fileset]
set_property verilog_define SHARED_ENCAP=1 [current_fileset]

set_property verilog_define SHARED=1 [get_filesets sim_1]
set_property verilog_define SHARED_ENCAP=1 [get_filesets sim_1]

add_files -fileset sim_1 -norecurse ./build/joint_design/tb/hqc_kem_joint_design_keygen_tb.v
add_files -fileset sim_1 -norecurse ./build/joint_design/tb/hqc_kem_joint_design_decap_tb.v
add_files -fileset sim_1 -norecurse ./build/joint_design/tb/hqc_kem_joint_design_encap_tb.v
add_files -fileset sim_1 -norecurse ./build/joint_design/tb/pk_seed.in
add_files -fileset sim_1 -norecurse ./build/joint_design/tb/sk_seed.in
update_compile_order -fileset sim_1

# set_property generic parameter_set="hqc128" [get_filesets sim_1]
# launch_simulation
# run 2000 us

# set_property generic parameter_set="hqc192" [get_filesets sim_1]
# relaunch_sim
# run 2000 us

# set_property generic parameter_set="hqc256" [get_filesets sim_1]
# relaunch_sim
# run 2000 us


set end_t [clock seconds]
set total_t [expr {$end_t - $start_t}]
set final_t [clock format $total_t -format {%H:%M:%S} -gmt true]
puts "Final time :$final_t"




