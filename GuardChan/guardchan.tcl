# GuardChan by JamesOff
# Kickbans people if they're not in the bot's userfile
# No other filtering options, sorry
#
# Released under the BSD licence
# http://jamesoff.net/site/projects/eggdrop-scripts/guardchan

# Instructions:
#  - edit the owner setting below to your nick
#  - choose if you want just kicks or bans too
#  - load script
#  - for channels you want to protect: .chanset #channel +guardchan

# (default has invalid char in to make sure you set it)
set guardchan_owner "YOUR_NICK_HERE%"

# set to 1 to ban users rather than just kick them
set guardchan_ban 0

# Stop editing here unless you like TCL
#
#
#
#
#
#
# No really, TCL is a world of pain ;)

bind join - *!*@* guardchan_join

setudef flag guardchan

proc guardchan_join { nick host handle channel } {
    global guardchan_owner guardchan_ban

    if {![channel get $channel guardchan]} {
        return 0
    }

    if {$handle == "*"} {
        if [botisop $channel] {
            if {!$guardchan_ban} {
                putkick $channel $nick "You are not permitted to be in here"
                puthelp "PRIVMSG $guardchan_owner :Kicked $nick from $channel"
            } else {
                set ban [maskhost "$nick!$host"]
                newchanban $channel $ban "guardchan" "Banned for not being in userfile"
                puthelp "PRIVMSG $guardchan_owner :Banned $nick from $channel"
            }
            return 0
        } else {
            puthelp "PRIVMSG $guardchan_owner :HELP! $nick has joined $channel and I can't do anything about it :("
            return 0
        }
    }
}
