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
			dict set iw_info freq [lindex [split [lindex [split $line "("] 1]] 0]
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


;#Survey data from wlan0
;#        frequency:                      2467 MHz
;#        noise:                          -91 dBm
;#        channel active time:            106 ms
;#        channel busy time:              16 ms
;#        channel receive time:           14 ms
;#        channel transmit time:          0 ms
;#Survey data from wlan0
;#        frequency:                      2472 MHz [in use]
;#        noise:                          -95 dBm
;#        channel active time:            572304 ms
;#        channel busy time:              118588 ms
;#        channel receive time:           25767 ms
;#        channel transmit time:          10 ms

proc iw_get_survey {str} {
	set iw_survey [dict create]
	set lines [split $str "\n\r"]
	set freq 0
	foreach line $lines {
		set line [string trim $line " \t\n\r"]
		set part [string trim [lindex [split $line ":"] 1] " \t\n\r"]
		if {[string match "Survey data from *" $line] == 1} {
			continue
		} elseif {[string match "frequency:*" $line] == 1} {
			set freq [lindex [split $part] 0]
		} elseif {[string match "noise:*" $line] == 1} {
			dict set iw_survey $freq noise [lindex [split $part] 0]
		} elseif {[string match "channel active time:*" $line] == 1} {
			dict set iw_survey $freq activ_time [lindex [split $part] 0]
		} elseif {[string match "channel busy time:*" $line] == 1} {
			dict set iw_survey $freq busy_time [lindex [split $part] 0]
		} elseif {[string match "channel receive time:*" $line] == 1} {
			dict set iw_survey $freq rx_time [lindex [split $part] 0]
		} elseif {[string match "channel transmit time:*" $line] == 1} {
			dict set iw_survey $freq tx_time [lindex [split $part] 0]
		}
	}
	return $iw_survey
}

proc iw_calc_busy {freq survey1 survey2} {
	set sbusy [dict create]
	set busy1 [dict get $survey1 $freq busy_time]
	set activ1 [dict get $survey1 $freq activ_time]
	set tx1 [dict get $survey1 $freq tx_time]

	set busy2 [dict get $survey2 $freq busy_time]
	set activ2 [dict get $survey2 $freq activ_time]
	set tx2 [dict get $survey2 $freq tx_time]
	set tx [expr $tx2 - $tx1]
	set active [expr $activ2 - $activ1]
	set a [expr [expr $busy2 - $busy1] - $tx]
	set b [expr $active - $tx]
	set by [format %#.2f [expr $a/[format "%f" $b] * 100]]
	dict set sbusy busy $by
	dict set sbusy active $active
	return $sbusy
}


