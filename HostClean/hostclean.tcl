
set seen_hostnames [list]

proc load_hostnames { handle idx filename } {
	global seen_hostnames

	set filehandle [open $filename "r"]
	set line [gets $filehandle]

	set count 0

	while {![eof $filehandle]} {
		set line [string trim $line]
		set line "somenick!$line"
		lappend seen_hostnames $line
		incr count
		set line [gets $filehandle]
	}

	putidx $idx "hostclean: loaded [llength $seen_hostnames] hostnames from cache"
}


proc hostclean { handle idx user } {
	global seen_hostnames
	set hostnames [getuser $user HOSTS]
	putlog "hostclean: found [llength $hostnames] hosts for $user"
	if {[llength $hostnames] > 0} {
		foreach host $hostnames {
			if [string match "-telnet*" $host] {
				set seen 1
				continue
			}
			set regexp_hostname [string map { . \\. * .+ ? . } $host]
			regsub {\.\+!([a-zA-Z0-9_])} $regexp_hostname {.+!~?\1} regexp_hostname
			regsub {\.\+!\.\+([a-zA-Z0-9_])} $regexp_hostname {.+!.*\1} regexp_hostname
			set seen 0
			foreach seen_host $seen_hostnames {
				if [regexp -nocase $regexp_hostname $seen_host] {
					set seen 1
					break
				}
			}
			if {!$seen} {
			# XXX delete this host
				putidx $idx ".-host $user $host"
			}
		}
	}
}

bind dcc n hostload load_hostnames
bind dcc n hostclean hostclean

putlog "HostClean loaded; user .hostload <filename> and .hostclean <handle>"
