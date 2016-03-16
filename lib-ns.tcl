;#Tcl function library

;################################################
;# constant definitions
;################################################



;################################################
;# general
;################################################a

;# creates network namespace
;# name - name of ns
proc ns_create {name} {
	return [exec ip netns add $name]
}

;# deletes ns
;# name - ns name
proc ns_del {name} {
	return [exec ip netns del $name]
}

;# lists all ns
;# return list with ns names
proc ns_list {} {
	return [exec ip netns]
}


;# check whether ns exist
;# name - ns name
;# return 0 - does not exist, 1 - ns exist
proc ns_check_exist {name} {
	set list_ns [ns_list]
	foreach ns $list_ns {
		if {[string match "$name" $ns]} {
			return 1
		}
	}
	return 0
}


proc ns_open_shell {name} {
	set ns_fd [open "| ip netns exec $name bash" r+]
	fconfigure $ns_fd -blocking 0
	return $ns_fd
}


proc ns_exec {ns_fd cmd} {
	puts $ns_fd "$cmd; echo ^^^$?^\n"
	flush $ns_fd

	while {true} {
		set cmd_out_part [read $ns_fd]
		if {$cmd_out_part == ""} {
			after 10
			continue
		}
		if {[string match "*^^^*" $cmd_out_part] == 1} {
			append cmd_out $cmd_out_part
			break
		}
		append cmd_out $cmd_out_part
	}
	set start_idx 0
	while {[set idx [string first "^" $cmd_out $start_idx]] >= 0} {
		if { "^^^" == [string range $cmd_out $idx [expr $idx + 2]]} {
			return [string range $cmd_out 0 [expr $idx - 2]]
		}
		set start_idx [expr $idx + 1]
	}
	return $cmd_out
}

proc ns_exec_nw {ns_fd cmd} {
	puts $ns_fd "$cmd\n"
	flush $ns_fd
}

;# gets netns process list
;# ns name
;# return list of processes
proc ns_get_pids {name} {
	return [exec ip netns pids $name]
}

proc ns_get_shell_pid {ns_fd} {
	return [pid $ns_fd]
}

proc ns_get_ifaces {ns_fd} {
	return [concat {*}[ns_exec $ns_fd "ls /sys/class/net"]]
}


;# check whether iface exist in ns (net namespace)
;# ns_fd - descriptor to ns shell pipe
;# iface - iface name
;# return 0 - does not exist, 1 - iface exist
proc ns_check_iface_exist {ns_fd iface} {
	set list_iface [ns_get_ifaces $ns_fd]
	foreach ifc $list_iface {
		if {[string match "$iface" $ifc]} {
			return 1
		}
	}
	return 0
}

;# move phy interface from root ns to netns
;# phy - phynumber of interface
;# ns_pid - ID of process running in netns
proc ns_move_iface {phy ns_pid} {
	return [exec iw phy $phy set netns $ns_pid] 
}

;# move phy interface back to root net ns
;# ns_fd - descriptor to ns shell pipe
;# phy - phynumber of interface
proc ns_remove_iface {ns_fd phy} {
	set cmd "iw phy $phy set netns 1"
	return [ns_exec $ns_fd $cmd]
}

;# get phy number of iface in net ns
;# ns_fd - descriptor to ns shell pipe
;# iface - iface name
proc ns_get_phy {ns_fd iface} {
	set index [ns_exec $ns_fd "cat /sys/class/net/$iface/phy80211/index"]
	return "phy$index"
}

proc ns_get_iface_opstate {ns_fd iface} {
	set opstate [ns_exec $ns_fd "cat /sys/class/net/$iface/operstate"]
	return $opstate
}

proc ns_get_ip {ns_fd iface} {
	set cmd_out [ns_exec $ns_fd "ip addr show dev $iface scope global"]
	foreach line [split $cmd_out "\n"] {
		set line [string trim $line]
		if {[string match "inet *" $line] == 1} {
			set ip_addr [lindex [split $line] 1]
			set ip_addr [string range $ip_addr 0 [expr [string first "/" $ip_addr] - 1]]
			return $ip_addr
		}
	}
	return -1
}

;# configure ns iface
;# ns_fd - descriptor to ns shell pipe
;# iface - iface name
;# op - operation: up/down
proc ns_ifconfig {ns_fd iface op} {
	return [ns_exec $ns_fd "ip link set $iface $op"]
}

proc ns_find_pid {ns_fd cmd} {
	set proc_id 0
	set output [ns_exec $ns_fd "ps -eo pid,args"]
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

;# get net ns pointer
;# returns netns_p type
;# (name, ns_fd)

proc ns_get_netns_p {} {
	set netns_p [dict create]
	set l_ns [split [ns_list] "\n"]
	foreach ns $l_ns {
		set ns_fd [ns_open_shell $ns]
		dict set netns_p $ns $ns_fd
	}
	return $netns_p
}





