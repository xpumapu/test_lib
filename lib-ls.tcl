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

;# check whether iface is loopback
;# iface - iface name
;# return 0 - no lo iface, 1 - lo iface

proc ls_is_iface_lo {iface} {
	set str [exec ip link show $iface]
	if {[string match "*link/loopback*" $str] == 1} {
		return 1
	}
	return 0
}

;# check whether iface is tuntap
;# iface - iface name
;# return 0 - no tuntap iface, 1 - tuntap iface
proc ls_is_iface_tuntap {iface} {
	if {[file exists /sys/class/net/$iface/tun_flags] == 1} {
		return 1
	}
	return 0
}

;# gets iface type
;# iface - iface name
;# return iface type: bridge, wlan, loopback, tuntap, ethernet
proc ls_get_iface_type {iface} {
	if {[file exist /sys/class/net/$iface/bridge] == 1} {
		set type bridge
	} elseif {[file exist /sys/class/net/$iface/phy80211] == 1} {
		set type wlan
	} elseif {[ls_is_iface_lo $iface] == 1} {
		set type loopback
	} elseif {[ls_is_iface_tuntap $iface] == 1} {
		set type tuntap
	} else {
		set type ethernet
	}
	return $type
}

