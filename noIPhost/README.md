noIPhost
========

This script automatically bans people joining a channel with non-resolving hosts. Per-channel toggle. Bans last a day by default. (To adjust, edit the script.)

To use this script:

* Download it
* Put the TCL file in your eggdrop's `scripts` directory
* Add `source scripts/noiphost.tcl` to your eggdrop config file
* Rehash the bot
* Enable it on desired channels with `.chanset #channel +noiphosts`
