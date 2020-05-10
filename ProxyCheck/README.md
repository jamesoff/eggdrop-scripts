proxycheck
==========

proxycheck performs RBL lookups on people joining your channel and bans people who are listed. Per-channel toggle, configurable ban duration, configurable RBL usage.

To use the script:

* Download it
* Put the TCL file in your eggdrop scripts directory
* Add `source scripts/proxycheck.tcl` to the end of your eggdrop config
* If you want to change the list of RBLs the script checks or how long users are banned for, edit it (it's clearly commented)
* Rehash the bot
* Enable on channels with `.chanset #channel +proxycheck`
