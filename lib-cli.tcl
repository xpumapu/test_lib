;#Tcl function library

;################################################
;# constant definitions
;################################################

;# CLI prompt
set prompt "# "

;################################################
;# general
;################################################


proc parse_line {line} {
	set parcmd [dict create]

	if {[string length $line] == 0} {
		dict set parcmd cmd "none"
		return $parcmd
	}
	
	set param_list [concat {*}[split [string trimright [string tolower $line]] " \r\n"]]
	set cmd [lindex $param_list 0]
	set args [lrange $param_list 1 end]
	dict set parcmd cmd $cmd
	dict set parcmd args $args
	return $parcmd
}
