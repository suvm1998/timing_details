set enable_prelayout_timing 1
set working_dir [exec pwd]
set array_length [llength [split [lindex $argv 0] .]]
set input [lindex [split [lindex $argv 0] .] $vsd_array_length-1]

if {![regexp {^csv} $input] || $argc!=1 } {
	puts "Error in usage"
	puts "where <.csv> file has below inputs"
	exit
} else {
	set filename [lindex $argv 0]
	package require csv
	package require struct::matrix
	struct::matrix m
	set f [open $filename]
	csv::read2matrix $f m, auto 
	close $f
	set columns [m columns]
	m link my_arr
	set num_of_rows [m rows]
	set i 0
	while {$i < $num_of_rows} {
		puts"\nsetting $my_arr(0,$i) as '$my_arr(1,$i)'"
		if {$i ==0} {
			set [string map {" " ""} $my_arr(0,$i)] $my_arr(1,$i)
		}else{
			set [string map {" " ""} $my_arr(0,$i)] [file normalize $my_arr(1,$i)]
		}
		set $i [expr{ $i + 1 }]
	}
}

puts "\nInfo: Below are the list of initial variables and their values. User can use these variables for further debug. Use 'puts <variable name>' command to query value of below variables"
puts "DesignName = $DesignName"
puts "OutputDirectory = $OutputDirectory"
puts "NetlistDirectory = $NetlistDirectory"
puts "EarlyLibraryPath = $EarlyLibraryPath"
puts "LateLibraryPath = $LateLibraryPath"
puts "ConstraintsFile = $ConstraintsFile"


if {! [file exists $EarlyLibraryPath]} {
	puts"\n Fatal: Library path Not found."
	exit
}
if {! [file isdirectory $NetlistDirectory]} {
	puts"\n Fatal: Netlist directory Not found."
	exit
}
if {! [file exists $LateLibraryPath]} {
	puts"\n Fatal: Library path Not found."
	exit
}
if {! [file exists $ConstraintsFile]} {
	puts"\n Fatal: Constraints file Not found."
	exit
}
if {![file isdirectory $OutputDirectory]} {
	puts "\nInfo: Cannot find output directory $OutputDirectory. Creating $OutputDirectory"
	file mkdir $OutputDirectory
} else {
	puts "\nInfo: Output directory found in path $OutputDirectory"
}

puts"\n Dumping SDC constraints for $DesignName"
::struct::matrix constraints
set chan [open $ConstraintsFile]
csv::read2matrix  $chan constraints, auto
close $chan
set num_of_rows [columns constraints]
set num_of_columns [columns constraints]


set clock_start [lindex[lindex[constraints search all CLOCKS] 0] 1]  #Gives list of {col,row} pairs and 0 picks first pair amd 1 picks the row value#
set clock_start_column [lindex[lindex [constraints search all CLOCKS ] 0] 0]
set input_port_start [lindex[lindex [constraints search all INPUTS] 0] 1]
set output_port_start[lindex [lindex [constraints search all OUTPUTS]0]1]


set clock_early_rise_delay_start [lindex [lindex [constraints search rect $clock_start $clock_start_column [expr {$num_of_rows-1}] [expr {$num_of_columns-1}] early_rise_delay] 0] 0]
set clock_early_fall_delay_start [lindex [lindex [constraints search rect $clock_start $clock_start_column [expr {$num_of_rows-1}] [expr {$num_of_columns-1}] early_fall_delay] 0] 0]
set clock_late_rise_delay_start [lindex [lindex [constraints search rect $clock_start $clock_start_column [expr {$num_of_rows-1}] [expr {$num_of_columns-1}] late_rise_delay] 0] 0]
set clock_late_fall_delay_start [lindex [lindex [constraints search rect $clock_start $clock_start_column [expr {$num_of_rows-1}] [expr {$num_of_columns-1}] late_fall_delay] 0] 0]
set clock_early_rise_slew_start [lindex [lindex [constraints search rect $clock_start_column $clock_start [expr {$number_of_columns-1}] [expr {$input_ports_start-1}]  early_rise_slew] 0 ] 0]
set clock_early_fall_slew_start [lindex [lindex [constraints search rect $clock_start_column $clock_start [expr {$number_of_columns-1}] [expr {$input_ports_start-1}]  early_fall_slew] 0 ] 0]
set clock_late_rise_slew_start [lindex [lindex [constraints search rect $clock_start_column $clock_start [expr {$number_of_columns-1}] [expr {$input_ports_start-1}]  late_rise_slew] 0 ] 0]
set clock_late_fall_slew_start [lindex [lindex [constraints search rect $clock_start_column $clock_start [expr {$number_of_columns-1}] [expr {$input_ports_start-1}]  late_fall_slew] 0 ] 0]

set sdc_file [open $OutputDirectory/$DesignName.sdc "w"]
set i[expr{ $clock_start+1 }]
set end_of_ports[expr{ $input_ports_start-1}]
while { $i<$end_of_ports} {
        puts -nonewline $sdc_file "\ncreate_clock -name [constraints get cell 0 $i] -period [constraints get cell 1 $i] -waveform \{0 [expr {[constraints get cell 1 $i]*[constraints get cell 2 $i]/100}]\} \[get_ports [constraints get cell 0 $i]\]"
		puts -nonewline $sdc_file "\nset_clock_transition -rise -min [constraints get cell $clock_early_rise_slew_start $i] \[get_clocks [constraints get cell 0 $i]\]"
		puts -nonewline $sdc_file "\nset_clock_transition -fall -min [constraints get cell $clock_early_fall_slew_start $i] \[get_clocks [constraints get cell 0 $i]\]"
        puts -nonewline $sdc_file "\nset_clock_transition -rise -max [constraints get cell $clock_late_rise_slew_start $i] \[get_clocks [constraints get cell 0 $i]\]"
        puts -nonewline $sdc_file "\nset_clock_transition -fall -max [constraints get cell $clock_late_fall_slew_start $i] \[get_clocks [constraints get cell 0 $i]\]"
        puts -nonewline $sdc_file "\nset_clock_latency -source -early -rise [constraints get cell $clock_early_rise_delay_start $i] \[get_clocks [constraints get cell 0 $i]\]"
        puts -nonewline $sdc_file "\nset_clock_latency -source -early -fall [constraints get cell $clock_early_fall_delay_start $i] \[get_clocks [constraints get cell 0 $i]\]"
        puts -nonewline $sdc_file "\nset_clock_latency -source -late -rise [constraints get cell $clock_late_rise_delay_start $i] \[get_clocks [constraints get cell 0 $i]\]"
        puts -nonewline $sdc_file "\nset_clock_latency -source -late -fall [constraints get cell $clock_late_fall_delay_start $i] \[get_clocks [constraints get cell 0 $i]\]"
        set i [expr {$i+1}]
}

set input_early_rise_delay_start [lindex [lindex [constraints search rect $clock_start_column $input_ports_start [expr {$number_of_columns-1}] [expr {$output_ports_start-1}]  early_rise_delay] 0 ] 0]
set input_early_fall_delay_start [lindex [lindex [constraints search rect $clock_start_column $input_ports_start [expr {$number_of_columns-1}] [expr {$output_ports_start-1}]  early_fall_delay] 0 ] 0]
set input_late_rise_delay_start [lindex [lindex [constraints search rect $clock_start_column $input_ports_start [expr {$number_of_columns-1}] [expr {$output_ports_start-1}]  late_rise_delay] 0 ] 0]
set input_late_fall_delay_start [lindex [lindex [constraints search rect $clock_start_column $input_ports_start [expr {$number_of_columns-1}] [expr {$output_ports_start-1}]  late_fall_delay] 0 ] 0]

set input_early_rise_slew_start [lindex [lindex [constraints search rect $clock_start_column $input_ports_start [expr {$number_of_columns-1}] [expr {$output_ports_start-1}]  early_rise_slew] 0 ] 0]
set input_early_fall_slew_start [lindex [lindex [constraints search rect $clock_start_column $input_ports_start [expr {$number_of_columns-1}] [expr {$output_ports_start-1}]  early_fall_slew] 0 ] 0]
set input_late_rise_slew_start [lindex [lindex [constraints search rect $clock_start_column $input_ports_start [expr {$number_of_columns-1}] [expr {$output_ports_start-1}]  late_rise_slew] 0 ] 0]
set input_late_fall_slew_start [lindex [lindex [constraints search rect $clock_start_column $input_ports_start [expr {$number_of_columns-1}] [expr {$output_ports_start-1}]  late_fall_slew] 0 ] 0]
set related_clock [lindex [lindex [constraints search rect $clock_start_column $input_ports_start [expr {$number_of_columns-1}] [expr {$output_ports_start-1}]  clocks] 0 ] 0]

set i [expr{ $input_ports_start+1}]
set end_of_ports [expr{ $output_ports_start-1}]
while { $i<$end_of_ports}{
	set netlist [glob -dir $NetlistDirectory *.v]
	set temp_file [open /tmp/1 "w"]
	foreach f $netlist {
		set fd [open $f]
		while { [gets $fd line] != -1} {
			set pattern1 " [constraints get cell 0 $i];"
			#if the pattern1 is found in the line then the regexp gives one else zero 
			if { [regexp -all -- $pattern1 $line]} {   
				set pattern2 [lindex[split $line ";"] 0]
				if { regexp -all {input} [lindex [split pattern2 "\S+"]0]} {
					set s1 "[lindex [split $pattern2 "\S+"] 0] [lindex [split $pattern2 "\S+"] 1] [lindex [split $pattern2 "\S+"] 2]"
					puts -nonewline $temp_file "\n[regsub -all {\s+} $s1 " "]"
				}

			}

		}
		close $fd
	}
	close $temp_file
	set temp_file [open /tmp/1 "r"]
	set temp_file2 [open /tmp/2 "w"]
	puts -nonewline " [join[lsort -unique [ split [read $temp_file] \n]	] \n] "
	close $temp_file
	close $temp_file2
	set temp_file2 [open /tmp/2 "r"]
	set count [llength [read $tmp2_file]]
	if {$count > 2} {
		set inp_ports [concat [constraints get cell 0 $i]*]
		puts "bussed"
	} else {
		set inp_ports [constraints get cell 0 $i]
		puts "not bussed"
	}
		puts -nonewline $sdc_file "\nset_input_delay -clock \[get_clocks [constraints get cell $related_clock $i]\] -min -rise -source_latency_included [constraints get cell $input_early_rise_delay_start $i] \[get_ports $inp_ports\]"
        puts -nonewline $sdc_file "\nset_input_delay -clock \[get_clocks [constraints get cell $related_clock $i]\] -min -fall -source_latency_included [constraints get cell $input_early_fall_delay_start $i] \[get_ports $inp_ports\]"
        puts -nonewline $sdc_file "\nset_input_delay -clock \[get_clocks [constraints get cell $related_clock $i]\] -max -rise -source_latency_included [constraints get cell $input_late_rise_delay_start $i] \[get_ports $inp_ports\]"
        puts -nonewline $sdc_file "\nset_input_delay -clock \[get_clocks [constraints get cell $related_clock $i]\] -max -fall -source_latency_included [constraints get cell $input_late_fall_delay_start $i] \[get_ports $inp_ports\]"

        puts -nonewline $sdc_file "\nset_input_transition -clock \[get_clocks [constraints get cell $related_clock $i]\] -min -rise -source_latency_included [constraints get cell $input_early_rise_slew_start $i] \[get_ports $inp_ports\]"
        puts -nonewline $sdc_file "\nset_input_transition -clock \[get_clocks [constraints get cell $related_clock $i]\] -min -fall -source_latency_included [constraints get cell $input_early_fall_slew_start $i] \[get_ports $inp_ports\]"
        puts -nonewline $sdc_file "\nset_input_transition -clock \[get_clocks [constraints get cell $related_clock $i]\] -max -rise -source_latency_included [constraints get cell $input_late_rise_slew_start $i] \[get_ports $inp_ports\]"
        puts -nonewline $sdc_file "\nset_input_transition -clock \[get_clocks [constraints get cell $related_clock $i]\] -max -fall -source_latency_included [constraints get cell $input_late_fall_slew_start $i] \[get_ports $inp_ports\]"


        set i [expr {$i+1}]
}
close $temp_file2

set output_early_rise_delay_start [lindex [lindex [constraints search rect $clock_start_column $output_ports_start [expr {$number_of_columns-1}] [expr {$number_of_rows-1}]  early_rise_delay] 0 ] 0]
set output_early_fall_delay_start [lindex [lindex [constraints search rect $clock_start_column $output_ports_start [expr {$number_of_columns-1}] [expr {$number_of_rows-1}]  early_fall_delay] 0 ] 0]
set output_late_rise_delay_start [lindex [lindex [constraints search rect $clock_start_column $output_ports_start [expr {$number_of_columns-1}] [expr {$number_of_rows-1}]  late_rise_delay] 0 ] 0]
set output_late_fall_delay_start [lindex [lindex [constraints search rect $clock_start_column $output_ports_start [expr {$number_of_columns-1}] [expr {$number_of_rows-1}]  late_fall_delay] 0 ] 0]
set output_load_start [lindex [lindex [constraints search rect $clock_start_column $output_ports_start [expr {$number_of_columns-1}] [expr {$number_of_rows-1}]  load] 0 ] 0]
set related_clock [lindex [lindex [constraints search rect $clock_start_column $output_ports_start [expr {$number_of_columns-1}] [expr {$number_of_rows-1}]  clocks] 0 ] 0]
set i [expr {$output_ports_start+1}]
set end_of_ports [expr {$number_of_rows}]
puts "\nInfo-SDC: Working on IO constraints....."
puts "\nInfo-SDC: Categorizing output ports as bits and bussed"

while { $i < $end_of_ports } {

set netlist [glob -dir $NetlistDirectory *.v]
set tmp_file [open /tmp/1 w]
foreach f $netlist {
        set fd [open $f]
        while {[gets $fd line] != -1} {
                set pattern1 " [constraints get cell 0 $i];"
                if {[regexp -all -- $pattern1 $line]} {
                        set pattern2 [lindex [split $line ";"] 0]
                        if {[regexp -all {output} [lindex [split $pattern2 "\S+"] 0]]} {
                        set s1 "[lindex [split $pattern2 "\S+"] 0] [lindex [split $pattern2 "\S+"] 1] [lindex [split $pattern2 "\S+"] 2]"
                        puts -nonewline $tmp_file "\n[regsub -all {\s+} $s1 " "]"
                        }
                }
        }
close $fd
}
close $tmp_file
set tmp_file [open /tmp/1 r]
set tmp2_file [open /tmp/2 w]
puts -nonewline $tmp2_file "[join [lsort -unique [split [read $tmp_file] \n]] \n]"
close $tmp_file
close $tmp2_file
set tmp2_file [open /tmp/2 r]
set count [split [llength [read $tmp2_file]] " "]
if {$count > 2} {
        set op_ports [concat [constraints get cell 0 $i]*]
} else {
        set op_ports [constraints get cell 0 $i]
}
        puts -nonewline $sdc_file "\nset_output_delay -clock \[get_clocks [constraints get cell $related_clock $i]\] -min -rise -source_latency_included [constraints get cell $output_early_rise_delay_start $i] \[get_ports $op_ports\]"
        puts -nonewline $sdc_file "\nset_output_delay -clock \[get_clocks [constraints get cell $related_clock $i]\] -min -fall -source_latency_included [constraints get cell $output_early_fall_delay_start $i] \[get_ports $op_ports\]"
        puts -nonewline $sdc_file "\nset_output_delay -clock \[get_clocks [constraints get cell $related_clock $i]\] -max -rise -source_latency_included [constraints get cell $output_late_rise_delay_start $i] \[get_ports $op_ports\]"
        puts -nonewline $sdc_file "\nset_output_delay -clock \[get_clocks [constraints get cell $related_clock $i]\] -max -fall -source_latency_included [constraints get cell $output_late_fall_delay_start $i] \[get_ports $op_ports\]"
	puts -nonewline $sdc_file "\nset_load [constraints get cell $output_load_start $i] \[get_ports $op_ports\]"
	set i [expr {$i+1}]
}
close $tmp2_file
close $sdc_file

puts "\nInfo: SDC created. Please use constraints in path  $OutputDirectory/$DesignName.sdc"

set data "read_liberty -lib -ignore_miss_dir -setattr blackbox  $LateLibraryPath"
set filename "$DesignName.hier.ys"
set fileId [open $OutputDirectory/$filename "w"]
puts -nonewline $fileId $data
set netlist [glob -dir $NetlistDirectory *.v]
foreach f $netlist{
	puts -nonewline $fileId "\nread_verilog $f"
}
puts -nonewline $fileId "\nhierarchy -check"
close $fileId

set my_err [catch {exec yosys -s $OutputDirectory/DesignName.hier.ys >& $OutputDirectory/$DesignName.hierarchy_check.log} msg]
if { $my_err}{ 
	set filename "$OutputDirectory/$DesignName.hierarchy_check.log"
	set pattern {referenced in module}
	set count 0
	set fid [open $filename "r" ]
	while { [gets $fid line] !=-1}{
		incr count [regexp -all -- $pattern $line]
		if{[regexp -all -- $pattern $line]}{
			puts "\nError: module [lindex $line 2] is not part of design $DesignName. Please correct RTL in the path '$NetlistDirectory'" 
			puts "\nInfo: Hierarchy check FAIL"
		}
	}
	close $fid
}else{
	puts "\n Info: Hierarchy check passed"
}
puts "\nInfo: Please find hierarchy check details in [file normalize $OutputDirectory/$DesignName.hierarchy_check.log] for more info"
cd $working_dir

set data "read_liberty -lib -ignore_miss_dir -setattr blackbox ${LateLibraryPath}"
set filename "$OutputDirectory/$DesignName.ys"
set fid [open $filename "w"]
set netlist [glob -dir $NetlistDirectory *.v]
foreach f $netlist{
	set data $f
	puts -nonewline $fid "\nread_verilog $data"
}
puts -nonewline $fileId "\nhierarchy -top $DesignName"
puts -nonewline $fid "\nsynth -top $DesignName\nsplitnets -ports -format ___\ndfflibmap -liberty ${LateLibraryPath}\nopt"
puts -nonewline $fileId "\nabc -liberty ${LateLibraryPath} "
puts -nonewline $fid "\nflatten \nclean -purge\niopadmap -outpad BUFX2 A:Y -bits\nopt\nclean"
puts -nonewline $fid "\nwrite_verilog $DesignName.synth.v"
close $fid

puts "\nInfo: Synthesis script created and can be accessed from path $OutputDirectory/$DesignName.ys"

puts "\nInfo: Running synthesis........"

set my_err [catch {exec yosys -s $OutputDirectory/$DesignName.ys >& $OutputDirectory/$DesignName.main.log} msg]
if { my_err}{
	puts "\nError:Failed synthesis"
}else{
	puts "\n Info: Synthesis Successful"
}
puts "\nInfo: Please refer to log $OutputDirectory/$DesignName.synthesis.log"


set fid [open /tmp/1 "w"]
puts -nonewline $fid [exec grep -v -w "*" $OutputDirectory/$DesignName.synth.v]
close $fid
set filename "/tmp/1"
set output [open $OutputDirectory/$DesignName.final.synth.v "w"]
set fid [open $filename]
while { [gets $fid line != -1]} {
	puts -nonewline $output [string map {"\\" ""} $line]
	puts -nonewline $output "\n"
}
close $fid
close $output

source $working_dir/procs/reopenStdout.proc 
source $working_dir/procs/set_num_threads.proc

reopenStdout $OutputDirectory/DesignName.conf
set_num_threads -localCpu 4

source $working_dir/procs/read_lib.proc
read_lib -early $working_dir/osu018_stdcells.lib 
read_lib -late $working_dir/osu018_stdcells.lib
source $working_dir/procs/read_verilog.proc
read_verilog $OutputDirectory/$DesignName.final.synth.v

source $working_dir/procs/read_sdc.proc
read_sdc $OutputDirectory/$DesignName.sdc
reopenStdout /dev/tty

if {$enable_prelayout_timing == 1} {
	puts "\nInfo: enable_prelayout_timing is $enable_prelayout_timing. Enabling zero-wire load parasitics"
	set spef_file [open $OutputDirectory/$DesignName.spef w]
puts $spef_file "*SPEF \"IEEE 1481-1998\" " 
puts $spef_file "*DESIGN \"$DesignName\" " 
puts $spef_file "*DATE \"Tue Sep 25 11:51:50 2012\" " 
puts $spef_file "*VENDOR \"TAU 2015 Contest\" " 
puts $spef_file "*PROGRAM \"Benchmark Parasitic Generator\" " 
puts $spef_file "*VERSION \"0.0\" " 
puts $spef_file "*DESIGN_FLOW \"NETLIST_TYPE_VERILOG\" " 
puts $spef_file "*DIVIDER / " 
puts $spef_file "*DELIMITER : " 
puts $spef_file "*BUS_DELIMITER [ ] " 
puts $spef_file "*T_UNIT 1 PS " 
puts $spef_file "*C_UNIT 1 FF " 
puts $spef_file "*R_UNIT 1 KOHM " 
puts $spef_file "*L_UNIT 1 UH " 
}
close $spef_file

set conf_file [open $OutputDirectory/$DesignName.conf a]
puts $conf_file "set_spef_fpath $OutputDirectory/$DesignName.spef"
puts $conf_file "init_timer "
puts $conf_file "report_timer "
puts $conf_file "report_wns "
puts $conf_file "report_worst_paths -numPaths 10000 "
close $conf_file

set tcl_precision 3
set time_elapsed_in_us [time {exec /home/kunalg/Desktop/tools/opentimer/OpenTimer-1.0.5/bin/OpenTimer < $OutputDirectory/$DesignName.conf >& $OutputDirectory/$DesignName.results} 1]
puts "time_elapsed_in_us is $time_elapsed_in_us"
set time_elapsed_in_sec "[expr {[lindex $time_elapsed_in_us 0]/100000}]sec"
puts "time_elapsed_in_sec is $time_elapsed_in_sec"
puts "\nInfo: STA finished in $time_elapsed_in_sec seconds"
puts "\nInfo: Refer to $OutputDirectory/$DesignName.results for warnings and errors"

#set tcl_precision 3
puts "tcl_precision is $tcl_precision"

#-----find worst output violation------#
set worst_RAT_slack "-"
set report_file [open $OutputDirectory/$DesignName.results r]
puts "report_file is $OutputDirectory/$DesignName.results"
set pattern {RAT}
puts "pattern is $pattern"
while {[gets $report_file line] != -1} {
        if {[regexp $pattern $line]} {
	puts "pattern \"$pattern\" found in \"$line\""
	puts "old worst_RAT_slack is $worst_RAT_slack"
        set worst_RAT_slack  "[expr {[lindex $line  3]/1000}]ns"
	puts "part1 is [lindex $line 3]"
	puts "new worst_RAT_slack is $worst_RAT_slack"
	puts "breaking"
        break
        } else {
        continue
        }
}
close $report_file

#-----find number of output violation------#
set report_file [open $OutputDirectory/$DesignName.results r]
set count 0
puts "inital count is $count"
puts "being_count"
while {[gets $report_file line] != -1} {
        incr count [regexp -all -- $pattern $line]
}
set Number_output_violations $count
puts "Number_output_violations is $Number_output_violations"
close $report_file

#-----find worst setup violation------#
set worst_negative_setup_slack "-"
set report_file [open $OutputDirectory/$DesignName.results r]
set pattern {Setup}
while {[gets $report_file line] != -1} {
        if {[regexp $pattern $line]} {
        set worst_negative_setup_slack "[expr {[lindex $line  3]/1000}]ns"
        break
        } else {
        continue
        }
}
close $report_file


#-----find number of setup violation------#
set report_file [open $OutputDirectory/$DesignName.results r]
set count 0
while {[gets $report_file line] != -1} {
        incr count [regexp -all -- $pattern $line]
}       
set Number_of_setup_violations $count
close $report_file

#-----find worst hold violation------#
set worst_negative_hold_slack "-"
set report_file [open $OutputDirectory/$DesignName.results r]
set pattern {Hold}
while {[gets $report_file line] != -1} {
        if {[regexp $pattern $line]} {
        set worst_negative_hold_slack "[expr {[lindex $line  3]/1000}]ns"
        break
        } else {
        continue
        }
}
close $report_file


#-----find number of hold violation------#
set report_file [open $OutputDirectory/$DesignName.results r]
set count 0
while {[gets $report_file line] != -1} {
        incr count [regexp -all -- $pattern $line]
}
set Number_of_hold_violations $count
close $report_file

#-----find number of instance------#
set pattern {Num of gates}
set report_file [open $OutputDirectory/$DesignName.results r]
while {[gets $report_file line] != -1} {
        if {[regexp -all -- $pattern $line]} {
        set Instance_count [lindex [join $line " "] 4 ]
	puts "pattern \"$pattern\" found at line \"$line\""
        break
        } else {
        continue
        }
}
close $report_file


puts "DesignName is \{$DesignName\}"
puts "time_elapsed_in_sec is \{$time_elapsed_in_sec\}"
puts "Instance_count is \{$Instance_count\}"
puts "worst_negative_setup_slack is \{$worst_negative_setup_slack\}"
puts "Number_of_setup_violations is \{$Number_of_setup_violations\}"
puts "worst_negative_hold_slack is \{$worst_negative_hold_slack\}"
puts "Number_of_hold_violations is \{$Number_of_hold_violations\}"
puts "worst_RAT_slack is \{$worst_RAT_slack\}"
puts "Number_output_violations is \{$Number_output_violations\}"

puts "\n"
puts "                                         ****PRELAYOUT TIMING RESULTS****                                                  "
set formatStr {%15s%15s%15s%15s%15s%15s%15s%15s%15s}

puts [format $formatStr "-----------" "-------" "--------------" "---------" "---------" "--------" "--------" "-------" "-------"]
puts [format $formatStr "Design Name" "Runtime" "Instance Count" "WNS setup" "FEP Setup" "WNS Hold" "FEP Hold" "WNS RAT" "FEP RAT"]
puts [format $formatStr "-----------" "-------" "--------------" "---------" "---------" "--------" "--------" "-------" "-------"]
foreach design_name $DesignName runtime $time_elapsed_in_sec instance_count $Instance_count wns_setup $worst_negative_setup_slack fep_setup $Number_of_setup_violations wns_hold $worst_negative_hold_slack fep_hold $Number_of_hold_violations wns_rat $worst_RAT_slack fep_rat $Number_output_violations {
        puts [format $formatStr $design_name $runtime $instance_count $wns_setup $fep_setup $wns_hold $fep_hold $wns_rat $fep_rat]
}

puts [format $formatStr "-----------" "-------" "--------------" "---------" "---------" "--------" "--------" "-------" "-------"]
puts "\n"