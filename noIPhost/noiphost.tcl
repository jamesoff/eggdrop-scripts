# no ip checker for eggdrop
# (c) James Seward 2003-6
# version 1.1

# http://www.jamesoff.net/site/projects/eggdrop-scripts/noiphost
# james@jamesoff.net

# Released under the GPL

## INSTRUCTIONS
###############################################################################

# This script bans users joining your channel with non-resolving hosts. Bans
# last for a day. (Change the 1440 in the line near the end of the script to
# change this).
#
# Users who are +o, +v, or +f in your bot (local or global) are left alone.
#
# Enable the 'noiphosts' flag for channels you want to protect.
# --> .chanset #somechannel +noiphosts
#
# Enable the debug level on the partyline for some debug output
# --> .console +d (to enable)
# --> .console -d (to disable)


## CODE
###############################################################################

#bind to joins
bind join - *!*@* bancheck_join

#add our channel flag
setudef flag noiphosts

#it all happens in here
proc bancheck_join { nick host handle channel } {
#check we're active
if {![channel get $channel noiphosts]} {
    return 0
}

putloglev d * "noiphosts: join by $host to $channel"

#don't apply to friends, voices, ops
if {[matchattr $handle +fov|+fov $channel]} {
putloglev d * "noiphosts: $nick is a friend"
return 0
  }

  #check host
  if [regexp {@([0-9]{1,3}.[0-9]{1,3}.[0-9]{1,3}.[0-9]{1,3})$} $host matches ip] {
      putlog "noiphosts: $nick has an un-resolved host ($ip), banning"
      set banhost "*@$ip"
      newchanban $channel $banhost "noiphosts" "Non-resolving host" 1440
  }
}

putlog "noiphost 1.1 by JamesOff loaded"
