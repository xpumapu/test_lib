;#Tcl function library

;################################################
;# constant definitions
;################################################


;################################################
;# general
;################################################

proc wpa_cli_get_ifaces {cmd_out} {
	set ifaces_ready 0
	foreach line [split $cmd_out "\n"] {
		if {[string match "Selected interface*" $line] == 1} {
		} elseif {[string match "Available interfaces:*" $line] == 1} {
			set ifaces_ready 1
		} elseif {$ifaces_ready == 1} {
			append ifaces_list $line
		}
	}
	return $ifaces_list
}


;#bssid / frequency / signal level / flags / ssid
;#68:7f:74:04:dd:48       2412    -47     [WPA2-PSK-CCMP][ESS]    Wireshark_not_even_once

proc wpa_cli_get_scan_res {cmd_out} {
	set scan_res [dict create]
	set lines [split $cmd_out "\n"]
	set header [split [lindex $lines 0] "/"]
	set idx 0
	foreach line [lrange $lines 1 end] {
		set split_line [split $line]
		for {set col 0} {$col < [llength $header]} {incr col} {
			dict set scan_res $idx [string trim [lindex $header $col]] [string trim [lindex $split_line $col]]
		}
		incr idx
	}
	return $scan_res
}


