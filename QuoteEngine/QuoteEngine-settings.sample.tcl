# Settings file for QuoteEngine
#
# Edit this file and save it as QuoteEngine-settings.tcl in
# your eggdrop's scripts/ directory


#### MYSQL ONLY SETTINGS

# The mysql hostname to connect to
set quote_db(host) "127.0.0.1"

# The mysql account to connect as
set quote_db(user) "<botnick>"
set quote_db(password) "<botpwhere>"

# The name of the database to use
set quote_db(database) "quotesdb"

# The URL of the webpage
# If you're not using it, set this to ""
set quote_webpage "http://servername/~bot/quotes/"

#### END MYSQL ONLY SETTINGS


#### SQLITE ONLY SETTINGS

# The filename to store quotes in
# Note: relative to the working dir of your bot (probably the eggdrop/
# directory)
set quote_db_file "quotes.db"

#### END SQLITE ONLY SETTINGS


# automatically spew "relevant" quotes?
# Done by looking for quotes containing a word someone said in the channel
# 1 to enable, 0 to disable
set quote_automatic 1

# minimum number of seconds between automatic quotes
# default is 10800 (3 hours)
set quote_automatic_minimum 10800

# a user with this flag(s) can't use the script at all
set quote_noflags "Q|Q"

# maximum number of quotes to show in channel when searching before switching
# to /msg'ing the user
set quote_chanmax 5

# shrink multiple spaces to single spaces when fetching a quote?
# 0 to disable, 1 to enable
set quote_shrinkspaces 1
