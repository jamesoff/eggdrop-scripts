# open proxy checker for eggdrop
# (c) James Seward 2003-6
# version 1.12

# http://www.jamesoff.net/site/projects/eggdrop-scripts/proxycheck
# james@jamesoff.net

# Released under the GPL

## INSTRUCTIONS
###############################################################################

# This script will check the hosts of people joining channels against one or
# RBLs. Choose your RBLs wisely, some of them list DIALUP SPACE and that would
# be a bad thing to be matching your IRC users against :P
#
# Enable the 'proxycheck' flag for channels you want the script active on
# --> .chanset #somechannel +proxycheck
#
# Users who are +o, +v, or +f in your bot (local or global) won't be checked.
#
# Turn on console level d on the partyline to see some debug from the script
# --> .console +d (to enable)
# --> .console -d (to disable)

## CONFIG
###############################################################################

# space-separated list of RBLs to look in
set proxycheck_rbls {
    "cbl.abuseat.org"
    "opm.blitzed.org"
}

# time in minutes to ban for
set proxycheck_bantime 15

# stop editing here unless you're TCL-proof



## CODE
###############################################################################

#add our channel flag
setudef flag proxycheck

#bind our events
bind join - *!*@* proxycheck_join

#cache
set proxycheck_lastip ""

#swing your pants

# catch joins
proc proxycheck_join { nick host handle channel } {
#check we're active
if {![channel get $channel proxycheck]} {
    return 0
}

#don't apply to friends, voices, ops
if {[matchattr $handle fov|fov $channel]} {
return 0
  }

  #get the actual host
  regexp ".+@(.+)" $host matches newhost
  if [regexp {[0-9]{1,3}.[0-9]{1,3}.[0-9]{1,3}.[0-9]{1,3}$} $newhost] {
  #it's a numeric host, skip the lookup
      proxycheck_check2 $newhost $newhost 1 $nick $newhost $channel
  } else {
      putloglev d * "proxycheck: doing dns lookup on $newhost to get IP"
      dnslookup $newhost proxycheck_check2 $nick $newhost $channel
  }
}

# first callback (runs RBL checks)
proc proxycheck_check2 { ip host status nick orighost channel } {
    global proxycheck_rbls proxylookup_rbls

    if {$status == 1} {
        putloglev d * "proxycheck: $host resolves to $ip"

        # reverse the IP
        regexp {([0-9]{1,3}).([0-9]{1,3}).([0-9]{1,3}).([0-9]{1,3})} $ip matches a b c d
        set newip "$d.$c.$b.$a"

        # look it up in the rbls
        foreach rbl $proxycheck_rbls {
            putloglev d * "proxycheck: looking up $newip.$rbl"
            dnslookup "$newip.$rbl" proxycheck_check3 $nick $host $channel $rbl
        }
    } else {
        putlog "proxycheck: Couldn't resolve $host. (No further action taken.)"
    }
}

# second callback (catches RBL results)
proc proxycheck_check3 { ip host status nick orighost channel rbl } {
    global proxycheck_bantime proxycheck_lastip

    if {$status} {
        if {$ip == $proxycheck_lastip} {
            putloglev d * "proxycheck: $host = $ip appears in RBL $ip, but I've already seen this one."
            return 0
        }
        set proxycheck_lastip $ip
        putloglev d * "proxycheck: got host $host = ip $ip from RBL $rbl ... banning"
        putlog "proxycheck: $nick ($orighost) is listed in $rbl ... banning from $channel"
        newchanban $channel "*@$orighost" "proxychk" "proxycheck: $rbl" $proxycheck_bantime
    }
    #if we didn't get a host, they're not in RBL
}

putlog "proxycheck 1.11 by JamesOff loaded (checking [llength $proxycheck_rbls] RBLs)"
