set start_t [clock seconds]
create_project test_decap ./test_decap -part xc7a200tfbg676-1
set_property target_language verilog [current_project]
add_files -norecurse {./build/decap/}


update_compile_order -fileset sources_1

add_files -fileset sim_1 -norecurse ./build/decap/tb/decap_tb.v
add_files -fileset sim_1 -norecurse ./build/decap/tb/h_128.in
add_files -fileset sim_1 -norecurse ./build/decap/tb/h_192.in
add_files -fileset sim_1 -norecurse ./build/decap/tb/h_256.in
add_files -fileset sim_1 -norecurse ./build/decap/tb/x_128.in
add_files -fileset sim_1 -norecurse ./build/decap/tb/x_192.in
add_files -fileset sim_1 -norecurse ./build/decap/tb/x_256.in
add_files -fileset sim_1 -norecurse ./build/decap/tb/y_128.in
add_files -fileset sim_1 -norecurse ./build/decap/tb/y_192.in
add_files -fileset sim_1 -norecurse ./build/decap/tb/y_256.in
add_files -fileset sim_1 -norecurse ./build/decap/tb/s_128.in
add_files -fileset sim_1 -norecurse ./build/decap/tb/s_192.in
add_files -fileset sim_1 -norecurse ./build/decap/tb/s_256.in
add_files -fileset sim_1 -norecurse ./build/decap/barrett_hqc_128.mem
add_files -fileset sim_1 -norecurse ./build/decap/barrett_hqc_192.mem
add_files -fileset sim_1 -norecurse ./build/decap/barrett_hqc_256.mem

add_files -fileset sim_1 -norecurse ./build/decap/tb/d_128.in
add_files -fileset sim_1 -norecurse ./build/decap/tb/d_192.in
add_files -fileset sim_1 -norecurse ./build/decap/tb/d_256.in
add_files -fileset sim_1 -norecurse ./build/decap/tb/u_128.in
add_files -fileset sim_1 -norecurse ./build/decap/tb/u_192.in
add_files -fileset sim_1 -norecurse ./build/decap/tb/u_256.in
add_files -fileset sim_1 -norecurse ./build/decap/tb/v_128.in
add_files -fileset sim_1 -norecurse ./build/decap/tb/v_192.in
add_files -fileset sim_1 -norecurse ./build/decap/tb/v_256.in
add_files -fileset sim_1 -norecurse ./build/decap/tb/s_128.in
add_files -fileset sim_1 -norecurse ./build/decap/tb/s_192.in
add_files -fileset sim_1 -norecurse ./build/decap/tb/s_256.in



# add_files -fileset sim_1 -norecurse ./pk_seed.in
# add_files -fileset sim_1 -norecurse ./sk_seed.in
update_compile_order -fileset sim_1

set_property generic parameter_set="hqc128" [get_filesets sim_1]
launch_simulation
run 2000 us

set_property generic parameter_set="hqc192" [get_filesets sim_1]
relaunch_sim
run 3000 us

set_property generic parameter_set="hqc256" [get_filesets sim_1]
relaunch_sim
run 3000 us


set end_t [clock seconds]
set total_t [expr {$end_t - $start_t}]
set final_t [clock format $total_t -format {%H:%M:%S} -gmt true]
puts "Final time :$final_t"




