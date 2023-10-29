set start_t [clock seconds]
create_project test_keygen ./test_keygen -part xc7a200tfbg676-1
set_property target_language verilog [current_project]
add_files -norecurse {./build/keygen/}

# set_property is_global_include true [get_files  {{clog2.v}}]
# set_property is_global_include true [get_files  {{C:/Users/sd982/OneDrive - Yale University/Desktop/repos/pqc-hqc-hardware/build/keygen/clog2.v}}]
# set_property is_global_include true [get_files  {{./build/keygen/clog2.v}}]


update_compile_order -fileset sources_1

add_files -fileset sim_1 -norecurse ./build/keygen/tb/keygen_tb.v
add_files -fileset sim_1 -norecurse ./build/keygen/tb/pk_seed.in
add_files -fileset sim_1 -norecurse ./build/keygen/tb/sk_seed.in
# add_files -fileset sim_1 -norecurse ./build/keygen/barrett_hqc_128.mem
# add_files -fileset sim_1 -norecurse ./build/keygen/barrett_hqc_192.mem
# add_files -fileset sim_1 -norecurse ./build/keygen/barrett_hqc_256.mem
update_compile_order -fileset sim_1

set_property generic parameter_set="hqc128" [get_filesets sim_1]
launch_simulation
run 2000 us

set_property generic parameter_set="hqc192" [get_filesets sim_1]
relaunch_sim
run 2000 us

set_property generic parameter_set="hqc256" [get_filesets sim_1]
relaunch_sim
run 2000 us


set end_t [clock seconds]
set total_t [expr {$end_t - $start_t}]
set final_t [clock format $total_t -format {%H:%M:%S} -gmt true]
puts "Final time :$final_t"




