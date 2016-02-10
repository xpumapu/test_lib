;#Tcl function library

;################################################
;# constant definitions
;################################################



;################################################
;# general
;################################################


;#iw_info Interface wlan2
;#        ifindex 6
;#        wdev 0x2
;#        addr 00:03:7f:aa:00:15
;#        type managed
;#        wiphy 0
;#        channel 44 (5220 MHz), width: 80 MHz, center1: 5210 MHz
proc iw_get_info {str} {
	set iw_info [dict create]
	set lines [split $str "\n"]
	foreach line $lines {
		set line [string trim $line " \t\n\r"]
		if {[string match "Interface*" $line] == 1} {
			dict set iw_info iface [lindex [split $line] 1]
		}
		if {[string match "*addr*" $line] == 1} {
			dict set iw_info addr [lindex [split $line] 1]
		}
		if {[string match "*channel*" $line] == 1} {
			dict set iw_info chan [lindex [split $line] 1]
			set idx [expr [string first "width: " $line] + [string length "width: "]]
			set chanwidth [string range $line $idx [expr $idx + 1]]
			dict set iw_info chanwidth $chanwidth
		}
	}
	return $iw_info
}
