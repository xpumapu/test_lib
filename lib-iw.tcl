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


;# iw wlan1 link
;#Connected to 08:bd:43:9d:30:10 (on wlan1)
;#        SSID: SH2.5.0
;#        freq: 5180
;#        RX: 980 bytes (10 packets)
;#        TX: 490 bytes (4 packets)
;#        signal: -45 dBm
;#        tx bitrate: 6.0 MBit/s
;#
;#        bss flags:      short-slot-time
;#        dtim period:    1
;#        beacon int:     300
proc iw_get_link {str} {
	set iw_link [dict create]
	set lines [split $str "\n"]
	foreach line $lines {
		set line [string trim $line " \t\n\r"]
		if {[string match "Connected to *" $line] == 1} {
			dict set iw_link apmac [lindex [split $line] 2]
		}
		if {[string match "SSID:*" $line] == 1} {
			dict set iw_link ssid [lindex [split $line] 1]
		}

		if {[string match "freq:*" $line] == 1} {
			dict set iw_link freq [lindex [split $line] 1]
		}

		if {[string match "signal:*" $line] == 1} {
			dict set iw_link signal "[lindex [split $line] 1] [lindex [split $line] 2]"
		}

		if {[string match "tx bitrate:*" $line] == 1} {
			dict set iw_link txrate "[lindex [split $line] 2] [lindex [split $line] 3]"
		}
	}
	return $iw_link
}

