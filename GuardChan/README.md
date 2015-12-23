Guardchan is an eggdrop script which will kick (and optionally ban) anyone who joins a channel who isn’t in the bot’s userfile. If it’s not opped then it’ll /msg a configurable nick to warn them.

To use this script:

* Download it (link below)
* Put the file .TCL file in your eggdrop’s scripts directory
* Edit the script to set your nick as the owner, and to choose if you want bans or not.
* Get the bot to load it by adding this towards the end of your config: `source scripts/guardchan.tcl`
* Rehash your bot
* Activate the script on the required channels: `.chanset #channel +guardchan`

And you’re done.
