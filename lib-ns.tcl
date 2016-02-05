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
	while {[set cmd_out [read $ns_fd]] == ""} {
		after 10
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

proc ns_move_iface {phy ns_pid} {
	return [exec iw phy $phy set netns $ns_pid] 
}

