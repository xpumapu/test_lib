;#Tcl function library

;################################################
;# constant definitions
;################################################
set prompt {# }
set capture_dir "/tmp"
set src_dir "/usr/local/src"
set result_dir "/tmp"
set cores 3

;################################################
;# general
;################################################
proc exec_cmd_ex {spawnid cmd} {
	set tmp_timeout $::timeout
	set ::timeout 2
	set spawn_id $spawnid
	send "$cmd\r"
	expect $::prompt {}
	set ::timeout $tmp_timeout
	return 0
}

proc exec_cmd {dev cmd} {
	if {[catch {exec ssh $dev $cmd}]} {
		;# failed
		return 1
	} else {
		;# exec successuful
		return 0
	}
}

proc exec_shell_cmd {cmd} {
	return [exec $::env(SHELL) -c $cmd]
}

proc check_dir_exist {dev dir_path} {
	if {[catch {exec ssh $dev "test -d $dir_path && echo 0"}]} {
		;# dir does not exist
		return 0
	} else {
		;# dir exist
		return 1
	}	
}

proc check_file_exist {dev file_path} {
	if {[catch {exec ssh $dev "test -f $file_path"}]} {
		;# dir does not exist
		return 0
	} else {
		;# dir exist
		return 1
	}	
}

;# push file to remote machine
;# dst_dev - destination machine
;# src_path - source path on local machine
;# dst_path - destination path on destination machine
proc push_file {dst_dev src_path dst_path} {
	return [exec scp $src_path $dst_dev:$dst_path]
}

;# pull file from remote machine
;# src_dev - source machine
;# src_path - source path on remote machine
;# dst_path - destination path on local machine
proc pull_file {src_dev src_path dst_path} {
	return [exec scp $src_dev:$src_path $dst_path]
}
 
proc find_pid {dev cmd} {
	set proc_id 0
	set output [exec ssh $dev ps -eo pid,args]
	set record [split $output "\n"]
	for {set idx 0} { $idx < [llength $record]} {incr idx} {
		set line [lindex $record $idx]
		if {[string match "*$cmd" $line] == 1} {
			set elem [split [string trim $line]]
			set proc_id [lindex $elem 0]
			return $proc_id
		}
	}
	return $proc_id
}

proc find_pid_ex {dev cmd} {
	set proc_id 0
	set output [exec ssh $dev ps -eo pid,args]
	set record [split $output "\n"]
	for {set idx 0} { $idx < [llength $record]} {incr idx} {
		set line [lindex $record $idx]
		if {[string match "*$cmd" $line] == 1} {
			set elem [split [string trim $line]]
			set proc_id [lindex $elem 0]
			return $proc_id
		}
	}
	return $proc_id
}

proc kill_pid {dev proc_id} {
	exec ssh $dev kill $proc_id
}

proc kill_pid_ex {spawnid proc_id} {
	exec_cmd_ex $spawnid "kill $proc_id"
}

proc get_mac_ex {spawnid iface} {
	set tmp_timeout $::timeout
	set ::timeout 2
	set spawn_id $spawnid
	set r_cmd "cat /sys/class/net/$iface/address\r"
	send $r_cmd
	;# cmd echo
	expect {
		"$r_cmd\n" {}
		default {}
	}

	;# get output
	set outbuf {}
	expect {
		"\r" {
			set line [string trim $expect_out(buffer)]
			lappend outbuf $line
			exp_continue
		}
		default {}
	}
	expect $::prompt {}
	set ::timeout $tmp_timeout
	return $outbuf
}

proc get_mac {dev iface} {
	return [exec ssh $dev cat /sys/class/net/$iface/address]
}

proc get_iface_opstate {dev iface} {
	return [exec ssh $dev cat /sys/class/net/$iface/operstate]
}

proc get_ifaces {dev} {
	return [exec_cmd $dev "ls /sys/class/net/"]
}

;# Checks whether interface exist
;# dev - remote machine,
;# iface - interface name on dev
;# return 1 exist, 0 not exist
proc check_iface_exist {dev iface} {
	set ifaces [get_ifaces $dev]
	foreach iter $ifaces {
		if {[string match $iface $iter] == 1} {
			return 1
		} 
	}
	return 0
}

;# Create monitor interface
;# dev - remote machine to execute command,
;# miface - master interface to create monitor from,
;# siface - sniffer interface name,
proc create_monitor_iface {dev miface siface } {
	puts [exec_cmd $dev "iw $miface interface add $siface type monitor"]
}

proc is_iface_lo {dev iface} {
	set str [exec_cmd $dev "ip link show $iface"]
	if {[string match "*link/loopback*" $str] == 1} {
		return 1
	}
	return 0
}

proc is_iface_tuntap {dev iface} {
	if {[check_file_exist $dev /sys/class/net/$iface/tun_flags] == 1} {
		return 1
	}
	return 0
}

proc get_iface_type {dev iface} {
	if {[check_dir_exist $dev /sys/class/net/$iface/bridge] == 1} {
		set type bridge
	} elseif {[check_dir_exist $dev /sys/class/net/$iface/phy80211] == 1} {
		set type wlan
	} elseif {[is_iface_lo $dev $iface] == 1} {
		set type loopback
	} elseif {[is_iface_tuntap $dev $iface] == 1} {
		set type tuntap
	} else {
		set type ethernet
	}
}

proc get_upper_bridge {dev iface} {
	set file_list [exec_cmd $dev "ls /sys/class/net/$iface"]
	foreach entry $file_list {
		if {[string match "upper_*" $entry] == 1} {
			return [string range $entry [string first "_" $entry]+1 end] 
		}
	}
	return none
}

proc get_ifaces_info {dev} {
	set iface_list [get_ifaces $dev]
	set ifaces_info [dict create]
	foreach iface $iface_list {
		puts "Iface >$iface<"
		set type [get_iface_type $dev $iface]
		dict set ifaces_info $iface type $type
		dict set ifaces_info $iface mac [get_mac $dev $iface]
		dict set ifaces_info $iface opstate [get_iface_opstate $dev $iface]
		dict set ifaces_info $iface bifaces none
		dict set ifaces_info $iface bridge none
		if {$type == "bridge"} {
			dict set ifaces_info $iface bridge master
			dict set ifaces_info $iface bifaces [exec_cmd $dev "ls /sys/class/net/$iface/brif"]
		} else {
			dict set ifaces_info $iface bridge [get_upper_bridge $dev $iface]		
		}
	}
	return $ifaces_info
}

proc get_ether_ifaces {dev} {
	return [get_ifaces $dev]
}

proc is_test_env_dev {dev_ipv6 iface} {
	set result [catch {exec ssh -q -o BatchMode=yes -o ConnectTimeout=2 -l root $dev_ipv6%$iface exit} ] 
	if {$result == 1} {
		return 0 ;# is not a test device
	} elseif {$result == 0} {
		return 1 ;# test device
	}
}

proc get_ipv6_ex {spawnid iface} {
	set tmp_timeout $::timeout
	set ::timeout 2
	set spawn_id $spawnid
	set r_cmd "ip addr show $iface\r"
	send $r_cmd
	;# cmd echo
	expect {
		"$r_cmd\n" {}
		default {}
	}

	;# get output
	set outbuf {}
	expect {
		"\r" {
			set line [string trim $expect_out(buffer)]
			if {[string match "*scope link*" $line]} {
				lappend outbuf $line
			} else {
				exp_continue
			}
		}
		default {}
	}
	set fields [split $outbuf]
	for {set idx 0} {$idx < [llength $fields]} {incr idx} {
		set field [lindex $fields $idx]
		if {[string match "*:*" $field]} {
			set outbuf [string range $field 0 [string first "\/" $field]-1]
			break
		}
	}
	expect $::prompt {}
	set ::timeout $tmp_timeout
	return $outbuf
}

proc verify_connection_by_ping {src_dev dst_ip v6}  {
	global fifo pkt_loss
	set sta_connected 1
	if {$v6 ==0} {
		set ping "ping"
	} else {
		set ping "ping6"
	}

	set ping_cmd "ssh $src_dev $ping -i 0.1 -w 1 $dst_ip"
	puts $ping_cmd

	;# start pinging
	set fifo [open "| $ping_cmd" r]
	set pkt_loss ""
	fconfigure $fifo -blocking 0
	proc read_fifo {} {
		global fifo pkt_loss
		if {[gets $fifo x] < 0} {
			if {[eof $fifo]} {
				close $fifo
				unset fifo
			}
		}
		puts $x
		if {[string match "*packet loss,*" $x]} {
			set fields [split $x ","]
			for {set idx 0} {$idx < [llength $fields]} {incr idx} {
				set field [lindex $fields $idx]
				if {[string match "*packet loss*" $field]} {
					set pkt_loss [string range $field 0 [string first "%" $field]-1]
				}
			}

		}
	}
	fileevent $fifo readable read_fifo
	vwait fifo
		if {$pkt_loss == 100} {
			puts "No connection available yet"
			set sta_connected 0
		}
	return $sta_connected
}

proc wait_for_sta {src_dev dst_ip n_times v6} {
	set n 0
	set sta 1
	while { [verify_connection_by_ping $src_dev $dst_ip $v6] == 0 } {
		incr n
		if {$n == $n_times} {
			set sta 0
			break
		}
	}
	return $sta
}

proc wait_for_ipv6 {dev iface} {
	set wait_ipv6 1
	while {$wait_ipv6} {
		set wait_ipv6 0
		set output [exec ssh $dev "ip address show dev $iface tentative"]
		set lines [split $output "\n"]
		for {set idx 0} {$idx < [llength $lines]} {incr idx} {
			set line [lindex $lines $idx]
			if {[string match "*tentative*" $line]} {
				puts "IPv6 $iface tentative waiting..."
				set wait_ipv6 1
				break
			}
		}
		after 100
	}
	puts [exec_cmd $dev "ip address show dev $iface"]
}

proc multicast_pingv6 {dev iface n_times} {
	set output [exec_cmd $dev "ping6 -i0.5 -c$n_times ff02::1%$iface"]
	set lines [split $output "\n"]
	for {set idx 0} {$idx < [llength $lines]} {incr idx} {
		set line [lindex $lines $idx]
		if {[string match "*DUP*" $line]} {
			puts $line
		}
	}
}

proc get_ipv6_from_neighbour {dev iface mac} {
	set count 0
	while {1} {
		set output [exec_cmd $dev "ip neighbour show dev $iface"]
		set lines [split $output "\n"]
		for {set idx 0} {$idx < [llength $lines]} {incr idx} {
			set line [lindex $lines $idx]
			if {[string match "*$mac*" $line]} {
				set record [split $line]
				return [lindex $record 0]
			}
		}
		if {$count == 20} {
			puts "mac address not found in neighbour table"
			return 0
		}
		incr count
		after 500
	}
}

proc list_ipv6_from_neighbour {dev iface} {
	set count 0
	while {1} {
		set output [exec_cmd $dev "ip neighbour show dev $iface"]
		set lines [split $output "\n"]
		for {set idx 0} {$idx < [llength $lines]} {incr idx} {
			set record [split [lindex $lines $idx]]
			if {[lindex $record 2] == "FAILED"} {continue}
			dict set dev_list [lindex $record 2] [lindex $record 0]
		}
		if {$count == 20} {
			if {[dict size $dev_list] == 0} {
				puts "none entry found in neighbour table"
				return 0
			}
			return $dev_list
		}
		incr count
		after 500
	}
}

proc clean_up_iface {dev iface} {
	exec_cmd $dev "ifconfig $iface 0.0.0.0"
	exec_cmd $dev "ifconfig $iface down"
}

proc logtime_ex {text} {
	puts "[timestamp -format %X]-$text"
}

proc add_sta {dev iface base_name index} {
	set base_mac [get_mac $dev $iface]
	set new_mac [string replace $base_mac 13 13 1]
	if {$index > 9} {
		set new_mac [string replace $new_mac 15 16 $index]
	} else {
		set new_mac [string replace $new_mac 15 16 "0$index"]
	}
	set new_iface "$base_name$index"
	exec ssh $dev "iw $iface interface add $new_iface type managed"

	set cur_mac [get_mac $dev $new_iface]
	if {$cur_mac == $base_mac} {
		exec ssh $dev "ip link set $new_iface address $new_mac"
		return $new_mac
	} else {
		return cur_mac
	}
}

proc del_iface {dev iface} {
	set cmd "iw $iface del"
	puts $cmd
	puts [exec_cmd $dev "iw $iface del"]
}

;################################################
;# wpa_supplicant related
;################################################
set hapd "/tmp/hostapd"
set supp "/tmp/wpa_supplicant"
set cli "/tmp/wpa_cli"
set hapd_entr_file "/tmp/entr"
set supp_entr_file "/tmp/entr"

set hapd_conf_file "/tmp/hapd[pid].conf"
set supp_conf_file "/tmp/supp[pid].conf"

set cmd_base "$cli -p /var/run/wpa_supplicant"

proc cli_cmd_OK {spawnid iface cmd} {
	set tmp_timeout $::timeout
	set ::timeout 2
	set spawn_id $spawnid
	send "$::cmd_base -i $iface $cmd\r"
	expect {
		"OK" {}
		default { exit 2}
	}
	expect $::prompt {}
	set ::timeout $tmp_timeout
}

proc cli_cmd_output {spawnid iface cmd} {
	set tmp_timeout $::timeout
	set ::timeout 2
	set spawn_id $spawnid
	set out_cmd "$::cmd_base -i $iface $cmd\r"
	send $out_cmd
	;# cmd echo
	expect {
		"$out_cmd\n" {}
		default {}
	}

	;# get output
	set outbuf {}
	expect {
		"\r" {
			set line [string trim $expect_out(buffer)]
			lappend outbuf $line
			exp_continue
		}
		default {}
	}
	expect $::prompt {}
	set ::timeout $tmp_timeout
	return $outbuf
}

proc parse_status {status param} {
	set ret {}
	for {set idx 0} {$idx < [llength $status]} {incr idx} {
		set line [lindex $status $idx]

		if {[string match "$param=*" $line]} {
			return [string range $line [expr [string first "=" $line] +1] end] 
		}
	}
	return "null"
}

proc get_hostap_conf {ssid iface country chan mode chan_wd offset security} {
	set cmd1 "./hapd_gen_base $ssid $iface $country"
	set cmd2 "./hapd_gen_chan_sec_basic $chan $mode $chan_wd $offset $security"
	set output "[exec_shell_cmd $cmd1]\n[exec_shell_cmd $cmd2]\n"
	return $output
}

proc get_supp_conf {ssid security passwd} {
	set cmd "./wpa_supp_gen $ssid $security $passwd"
	set output "[exec_shell_cmd $cmd]\n"
	return $output
}

proc change_hapd_conf {hapd_conf param value} {
	set lines [split $hapd_conf "\n"]
	set n_lines [llength $lines]
	set new_conf ""
	for {set idx 0} {$idx < $n_lines} {incr idx} {
		set line [lindex $lines $idx]
		if {[string match "$param=*" $line] == 1} {
			
			set line "$param=$value"
		}
		append new_conf "$line\n"
	}
	return $new_conf
}

proc change_supp_conf {supp_conf param value} {
	set lines [split $supp_conf "\n"]
	set n_lines [llength $lines]
	set new_conf ""
	for {set idx 0} {$idx < $n_lines} {incr idx} {
		set line [lindex $lines $idx]
		if {[string match "*$param=*" $line] == 1} {
			set pref ""
			set idy 0
			while {[string is space -strict [string index $line $idy]] == 1} {
				append pref [string index $line $idy]
				if {$idy == [string length $line]} {
					break
				}
				incr idy
			}
			set quo ""
			if {[string match "*\"*" $line] == 1} {
				set quo "\""
			}
			set line "$pref$param=$quo$value$quo"
		}
		append new_conf "$line\n"
	}
	return $new_conf
}

;# Starts hostapd
;# dev - ssh machine
;# sh_id - spawnid for particular machine
;# hapd_conf - content of hostapd conf file
proc start_hapd {dev sh_id hapd_conf} {
	global hapd hapd_entr_file hapd_conf_file

	set fp [open $hapd_conf_file w]
	puts $fp $hapd_conf
	close $fp

	exec_shell_cmd "scp $hapd_conf_file $dev:$hapd_conf_file"

	set cmd "$hapd -e $hapd_entr_file $hapd_conf_file"
	exec_cmd_ex $sh_id "$cmd &"
	set spawn_id $sh_id
	expect {
		"AP-ENABLED" {}
		default {exit 1}
	}

	set proc_id [find_pid $dev $cmd]

	return $proc_id
}

;# Starts wpa_supplicant

proc start_supp {dev sh_id supp_conf iface} {
	global supp supp_entr_file supp_conf_file

	set fp [open $supp_conf_file w]
	puts $fp $supp_conf
	close $fp

	exec_shell_cmd "scp $supp_conf_file $dev:$supp_conf_file"

	set cmd "$supp -i $iface -c $supp_conf_file -e $supp_entr_file"

	exec_cmd_ex $sh_id "$cmd &"
	set spawn_id $sh_id
	puts "timeout $::timeout"
	expect {
		"CTRL-EVENT-CONNECTED" {}
		timeout {set ::timeout 40} 
		default {exit 1}
	}

	set proc_id [find_pid $dev $cmd]
	return $proc_id
}

;# Updates build time configuration file with listed options
;# local_config - original configuration file stored locally
;# option_list - list of options to enable
proc update_build_config {local_config option_list} {
	;# open local config file
	set fd [open $local_config r]
	;# read whole file
	set fd_data [read $fd]
	close $fd

	;# separate by line
	set data [split $fd_data "\n"]
	foreach line $option_list {
		set line_no [lsearch $data "#$line"]
		if {$line_no == -1} {
			puts "Config options $line not found in $local_config"
		} else {
			set data [lreplace $data $line_no $line_no $line]
		}
	}
	;# join all line and write to file
	set fd_data [join $data "\n"]

	set fd [open $local_config w]
	puts $fd $fd_data
	close $fd
}

;################################################
;# sniffer
;################################################

proc is_monitor_iface {dev iface} {
	
}

proc configure_sniffer {} {
	
} 

proc start_sniffer {spawnid capture_file} {
	set tmp_timeout $::timeout
	set ::timeout 10
	set spawn_id $spawnid
	set sniff_cmd "tshark -i $::env(sniff_iface) -w $capture_file\r"
	send $sniff_cmd
	expect {
		"Capturing on" {}
		default {
			puts "Capturing not started"
			exit 1
		}
	}
	set ::timeout $tmp_timeout
}

proc stop_sniffer {spawnid time} {
	set tmp_timeout $::timeout
	set spawn_id $spawnid
	set ::timeout $time
	expect {
		timeout {
			;#stop tshark Ctrl+C
			send \003
		}
	}
	expect $::prompt {}
	set ::timeout $tmp_timeout
}

proc filtered_frame_list {spawnid capture_file filter} {
	set tmp_timeout $::timeout
	set ::timeout 2
	set spawn_id $spawnid
	set frame_list {}
	set sniff_cmd "tshark -r $capture_file -Y \"$filter\" -T fields -E header=y -e frame.number\r"

	send $sniff_cmd

	expect {
		"$sniff_cmd" { exp_continue}
		"frame.number\r" {}
		default {}
	}
	;# frame numbers
	expect {
		"\r" {
			set line [string trim $expect_out(buffer)]
			lappend frame_list $line
			exp_continue
		}
		default {}
	}
	expect $::prompt {}

	if {[llength $frame_list] == 0} {
		puts ">$filter< filtered frame not found"
	}
	set ::timeout $tmp_timeout

	return $frame_list
}

proc get_frame {spawnid capture_file filter fields} {
	set tmp_timeout $::timeout
	set ::timeout 2
	set spawn_id $spawnid
	set tfields ""
	for {set idx 0} {$idx < [llength $fields]} {incr idx} {
		set tfields "$tfields -e [lindex $fields $idx]"
	}
	set sniff_cmd "tshark -r $capture_file -Y \"$filter\" -T fields -E header=y -E separator=\"|\" $tfields -e frame.number\r"

	send $sniff_cmd

	expect {
		"$sniff_cmd" { exp_continue}
		"frame.number\r" {}
		default {}
	}

	;# one frame
	set frame_content ""
	expect {
		"\r" {
			set line [string trim $expect_out(buffer)]
			set line [split $line "|"]
			set frame_content "$frame_content $line"
			exp_continue
		}
		default {}
	}
	expect $::prompt {}

	if {[llength $frame_content] == 0} {
		puts ">$filter< filtered frame not found"
	}
	set ::timeout $tmp_timeout
	return $frame_content
}

proc get_ap_info {spawnid capture_file} {
	set filter "wlan.fc.type_subtype == 0x0008"
	set fields "wlan_mgt.ssid wlan.bssid wlan_mgt.tim.dtim_period" 
	set beacons [get_frame $spawnid $capture_file $filter $fields]

	;# ap selection first run
	set ap_list [dict create]
	foreach {ssid bssid dtim fn} $beacons {
		dict set ap_list $ssid bssid $bssid
		dict set ap_list $ssid dtim $dtim
		dict set ap_list $ssid fn $fn
	}
	dict for {ssid info} $ap_list {
		set filter "frame.number==[dict get $ap_list $ssid fn]"
		set fields "radiotap.datarate radiotap.channel.freq radiotap.dbm_antsignal wlan.sa "
		append fields "wlan_mgt.fixed.beacon wlan_mgt.supported_rates wlan_mgt.extended_supported_rates "
		append fields "wlan_mgt.ht.capabilities wlan_mgt.wfa.ie.wme.version wlan_mgt.wfa.ie.wme.qos_info.ap.u_apsd "
		set beacon_more [get_frame $spawnid $capture_file $filter $fields]

		dict set ap_list $ssid datarate [lindex $beacon_more 0]
		dict set ap_list $ssid freq [lindex $beacon_more 1]
		dict set ap_list $ssid ant_sig [lindex $beacon_more 2]
		dict set ap_list $ssid sa [lindex $beacon_more 3]
		dict set ap_list $ssid beacon_int [lindex $beacon_more 4]
		dict set ap_list $ssid supp_rates [lindex $beacon_more 5]
		dict set ap_list $ssid ext_supp_rates [lindex $beacon_more 6]
		dict set ap_list $ssid ht_capa [lindex $beacon_more 7]
		dict set ap_list $ssid wme_ver [lindex $beacon_more 8]
		dict set ap_list $ssid uapsd [lindex $beacon_more 9]
	}
	return $ap_list
}

proc get_sta_info {spawnid capture_file} {
	;# filter probe requests
	set filter "wlan.fc.type_subtype == 0x0004"
	set fields "wlan.sa" 
	set prob_req [get_frame $spawnid $capture_file $filter $fields]

	set sta_list [dict create]
	foreach {sa fn} $prob_req {
		dict set sta_list $sa fn $fn
	}
	
	dict for {sa info} $sta_list {
		set filter "frame.number==[dict get $sta_list $sa fn]"
		set fields "radiotap.datarate radiotap.channel.freq radiotap.dbm_antsignal "
		append fields "wlan_mgt.supported_rates wlan_mgt.extended_supported_rates "
		append fields "wlan_mgt.ht.capabilities wlan_mgt.ssid "
		set prob_req_more [get_frame $spawnid $capture_file $filter $fields]
		dict set sta_list $sa datarate [lindex $prob_req_more 0]
		dict set sta_list $sa freq [lindex $prob_req_more 1]
		dict set sta_list $sa ant_sig [lindex $prob_req_more 2]
		dict set sta_list $sa supp_rates [lindex $prob_req_more 3]
		dict set sta_list $sa ext_supp_rates [lindex $prob_req_more 4]
		dict set sta_list $sa ht_capa [lindex $prob_req_more 5]
		dict set sta_list $sa ssid [lindex $prob_req_more 6]
	}
	return $sta_list
}

;################################################
;# LOGS
;################################################

;# Get date and time from target machine
;# return - date and time in string format
proc get_date_time {dev} {
	return [exec_cmd $dev "date +%Y-%m-%d_%H-%M"]
}

;# Get kernel logs and store them in result directory
;# dev - machine to execute that command
;# result_path - path to result directory
;# return - path to kernel logs
proc get_kernel_logs {dev result_path} {
	set postfix [get_date_time $dev]
	puts [exec_cmd $dev "cat /var/log/messages > $result_path/file$postfix"]
	return "$result_path/file$postfix"
}

;# Get kernel logs between markers
;# dev - machine to execute that commend
;# mark1 - string representing start marker
;# mark2 - string representing stop marker
;# log_path - path and file name to store from logs between markers
proc get_marked_kernel_logs {dev mark1 mark2 log_path} {
	set target_tmp "/tmp/stmp.log"
	set host_tmp "/tmp/dtmp.log"
	set host_tmp_cut "/tmp/cut.log"

	exec_cmd $dev "cat /var/log/messages > $target_tmp"
	pull_file $dev $target_tmp $host_tmp

	set srcd [open $host_tmp r]
	;# read whole file
	set src_data [read $srcd]
	close $srcd

	set dstd [open $host_tmp_cut w]

	;# separate by line
	set data [split $src_data "\n"]

	set aline [lsearch $data "*$mark1"]
	set bline [lsearch $data "*$mark2"]
	if {$aline > $bline} {
		;# swap points
		set cline $aline
		set aline $bline
		set bline $cline
	}

	set log_range [lrange $data $aline $bline]
	foreach line $log_range {
		puts $dstd $line
	}
	;# join all line and write to file
	;#set fd_data [join $data "\n"]

	close $dstd

	push_file $dev $host_tmp_cut $log_path
	return "$log_path"
}

;# Set marker to kernel log
;# dev - machine to execute that command
;# marker - string to place in kernel logs
proc set_kernel_log_marker {dev marker} {
	return [exec_cmd $dev "logger $marker"]
}

;################################################
;# TDLS
;################################################

proc verify_tdls_connection {sniff_id file sta1_mac sta2_mac} {
	;# filter data frames from sta1 to sta2
	set filter "wlan.sa==$sta1_mac and wlan.da==$sta2_mac and wlan.ra==$sta2_mac and wlan.fc.type_subtype==0x28 and wlan.fc.ds==0"
	set data_frame_list [filtered_frame_list $sniff_id $file $filter]

	if {[llength $data_frame_list] == 0} {
		puts "Tdls data from $sta2_mac to $sta2_mac not found"
		return 0;
	}
	return 1;
}

;################################################
;# GIT
;################################################

proc checkout_latest {dev path remote_branch } {
	;# checkout the latest code
	if {[catch {exec ssh  $dev "cd $path && git checkout $remote_branch"} result]} {
		if {[string match "*checking out *" $result] == 1} {
			puts "Checking out latest code..."
		} elseif { [string match "*HEAD is now at*" $result] == 1} {
			puts "Already latest code"
		} else {
			puts "Checkout failed"
			return -1
		}
	}
	return 1
}




