;#Tcl function library

;################################################
;# constant definitions
;################################################



;################################################
;# general
;################################################a



;# get list of network local system interfaces
;# return list of network interfaces
proc ls_get_ifaces {} {
	return [glob -tails -directory /sys/class/net/ -nocomplain *]
}


proc ls_get_mac {iface} {
	set fd [open "/sys/class/net/$iface/address" "r"]
	set mac [read $fd]
	close $fd
	return [string trim $mac " \n\r"]
}

proc ls_get_phy {iface} {
	set fd [open "/sys/class/net/$iface/phy80211/index" "r"]
	set index [string trim [read $fd] " \n\r"]
	close $fd
	return "phy$index"
}


;# check whether iface exist in ls (local system)
;# iface - iface name
;# return 0 - does not exist, 1 - iface exist
proc ls_check_iface_exist {iface} {
	set list_iface [ls_get_ifaces]
	foreach ifc $list_iface {
		if {[string match "$iface" $ifc]} {
			return 1
		}
	}
	return 0
}


