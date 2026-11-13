# Dedicated non-project, no-bitstream QEC implementation/report flow.
set root [file normalize [file join [file dirname [info script]] ..]]
cd $root
set mode [lindex $argv 0]
if {$mode eq ""} {set mode uart}
if {$mode ni {core uart}} {error "usage: qec_build.tcl -tclargs core|uart"}
if {![file exists qec/lut.mem]} {error "Generate real qec/lut.mem first"}
set part xc7z010clg400-1
set out build/qec_$mode
file mkdir $out
set_param general.maxThreads 4
# Missing/ignored ROM initialization must fail rather than synthesize a constant.
set_msg_config -id {Synth 8-2898} -new_severity ERROR
read_verilog -sv rtl/common/qec_decoder.sv
if {$mode eq "core"} {
    synth_design -top qec_decoder -part $part -mode out_of_context
    create_clock -name core_clk -period 8.000 [get_ports clk]
    # Explicit virtual synchronous boundary budget, not board interface timing.
    set_input_delay -clock core_clk 0.5 [get_ports {rst in_valid syndrome[*] out_ready}]
    set_output_delay -clock core_clk 0.5 [get_ports {in_ready out_valid prediction cycles[*]}]
} else {
    read_verilog -sv [list rtl/common/sync.sv rtl/common/uart_rx.sv rtl/common/uart_tx.sv rtl/top/top_qec_uart.sv]
    synth_design -top top_qec_uart -part $part
    read_xdc constraints/zybo_z7_10.xdc
    # External asynchronous UART/buttons have no phase relation to board clock.
    # Internal synchronizer-to-synchronizer and all functional clock paths remain timed.
    set_false_path -from [get_ports {btn[*] sw[*] uart_rx}]
    # LEDs and asynchronous UART TX have no external synchronous capture device.
    set_false_path -to [get_ports {led[*] rgb_led[*] uart_tx}]
}
report_utilization -file $out/post_synth_utilization.rpt
report_timing_summary -report_unconstrained -file $out/post_synth_timing.rpt
write_checkpoint -force $out/post_synth.dcp
write_verilog -force -mode funcsim $out/post_synth.v
opt_design
place_design
route_design
report_utilization -file $out/post_route_utilization.rpt
report_timing_summary -report_unconstrained -file $out/post_route_timing.rpt
report_drc -file $out/post_route_drc.rpt
write_checkpoint -force $out/post_route.dcp
set paths [get_timing_paths -max_paths 1 -setup]
if {[llength $paths]==0} {error "No setup timing path reported"}
set slack [get_property SLACK [lindex $paths 0]]
set hold_paths [get_timing_paths -max_paths 1 -hold]
if {[llength $hold_paths]==0} {error "No hold timing path reported"}
set hold_slack [get_property SLACK [lindex $hold_paths 0]]
puts "QEC_IMPLEMENTATION_COMPLETE mode=$mode WNS_NS=$slack WHS_NS=$hold_slack reports=$out"
if {$slack<0 || $hold_slack<0} {error "QEC setup/hold timing failed"}
# Intentionally no write_bitstream, hardware server, programming or board access.
