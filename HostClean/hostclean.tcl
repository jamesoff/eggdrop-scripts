
set seen_hostnames [list]

proc load_hostnames { filename } {
	global seen_hostnames

	set filehandle [open $filename "r"]
	set line [gets $filehandle]

	set count 0

	while {![eof $filehandle]} {
		set line [string trim $line]
		lappend seen_hostnames $line
		incr count
		set line [gets $filehandle]
	}

	putlog "hostclean: loaded [llength $seen_hostnames] hostnames from cache"
}


proc hostclean { user } {
  	global seen_hostnames
	set hostnames [getuser $user HOSTS]
	putlog "hostclean: found [llength $hostnames] hosts for $user"
	if {[llength $hostnames] > 0} {
		foreach $hostnames $host {
			set regexp_hostname [string map { . \\. * .+ ? . } $host]
			set seen 0
			foreach $seen_hostnames $seen_host {
			  if [regexp $regexp_hostname $seen_host] {
				set seen 1
				break
			  }
			}
			if {!$seen} {
			  # XXX delete this host
			  putlog "$host is a candidate for deletion from user $user"
			}
		}
	}
}
