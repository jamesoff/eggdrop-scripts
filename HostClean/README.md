HostClean
---------

HostClean helps tidy up old entries in your bot for users hostmasks.

First, run log files (e.g. from your client) through parse.py - expects lines to have something matching "joins (user@hostname)" (or quits). Outputs user@host entries, one per line, for the TCL script. Run it many times and concatenate the output, then use sort and uniq to sanitise.

Then load the TCL script into your bot, and run `.hostload <path to file you made above>`, and then do `.hostclean <handle>` for each user.

The script outputs a bunch of .-host lines, which you should double check, and then you can copy/paste them back into the partyline.

