# GuardChan by JamesOff
# Kickbans people if they're not in the bot's userfile
# No other filtering options, sorry
# 
# Released under the BSD licence
# http://jamesoff.net/site/projects/eggdrop-scripts/guardchan

# Instructions:
#  - edit the owner setting below to your nick
#  - load script
#  - for channels you want to protect: .chanset #channel +guardchan

# Only configurable setting (default has invalid char in to make sure you set it)
set guardchan_owner "YOUR_NICK_HERE%"

# Stop editing here unless you like TCL

bind join - *!*@* guardchan_join

setudef flag guardchan

proc guardchan_join { nick host handle channel } {
  global guardchan_owner
  if {![channel get $channel guardchan]} {
    return 0
  }

  if {$handle == "*"} {
    if [botisop $channel] {
      putkick $channel $nick "You are not permitted to be in here"
      puthelp "PRIVMSG $guardchan_owner :Kicked $nick from $channel"
      return 0
    } else {
      puthelp "PRIVMSG $guardchan_owner :HELP! $nick has joined $channel and I can't do anything about it :("
      return 0
    }
  }
}
