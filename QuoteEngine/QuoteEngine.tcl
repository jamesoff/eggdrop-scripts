# $Id: QuoteEngine.tcl,v 1.20 2004/03/30 21:52:12 James Exp $

###############################################################################
# QuoteEngine for eggdrop bots
# Copyright (C) James Michael Seward 2003
#
# This program is covered by the GPL, please refer the to LICENCE file in the
# distribution.
###############################################################################

# load the extension
package require sqlite3

# Make sure you edit the sample settings file and save it as "QuoteEngine-settings.tcl"
# in the eggdrop scripts directory!
source "scripts/QuoteEngine-settings.tcl"

# bind commands CHANGE as needed to set who can use
# use ".chanset #channel [+/-]quoteengine" to enable/disable individual
# channels
bind pub "m|fov" !addquote quote_add
bind pub "m|fov" !randquote quote_rand
bind pub "m|fov" !fetchquote quote_fetch
bind pub "m|fov" !getquote quote_fetch
bind pub "m|fov" !findquote quote_search
bind pub "m|fov" !searchquote quote_search
bind pub "m|fov" !urlquote quote_url
bind pub "-|-" !quoteurl quote_url
bind pub "m|ov" !delquote quote_delete
bind pub "m|ov" !deletequote quote_delete
bind pub "m|ov" !quotestats quote_stats
bind pub "-|-" !quoteversion quote_version
bind pub "-|-" !quotehelp quote_help
bind pubm "-|ov" * quote_auto

################################################################################
#No need to edit beyond this point
################################################################################

set quote_version "2.0"
set quote_auto_last(blah) 0

#add setting to channel
setudef flag quoteengine

# connect to database
proc quote_connect { } {
	global quote_db_handle quote_db_file

	sqlite3 quote_db_handle $quote_db_file
}

proc quote_escape { text } {
    return [string map {' ''} $text]
}

################################################################################
# quote_add
# !addquote <text>
#   Adds a quote to the database
################################################################################
proc quote_add { nick host handle channel text } {
  global quote_noflags

  if {![channel get $channel quoteengine]} {
    return 0
  }

  if [matchattr $handle $quote_noflags] { return 0 }

  if {($handle == "") || ($handle == "*")} {
    set handle $nick
  }

	set text [string trim $text]
	if {$text == ""} {
		putserv "PRIVMSG $nick :You forgot the quote text :("
		return 0
	}

  set nickhost "$nick!$host"
  set when [clock seconds]

  set sql {INSERT INTO quotes VALUES(null, :handle, :nickhost, :text, :channel, :when)}
  putloglev d * "QuoteEngine: executing $sql"

  set result [quote_db_handle eval $sql]
  set id [quote_db_handle last_insert_rowid]
  puthelp "PRIVMSG $channel :Quote \002$id\002 added"
  if [regexp {[^]> ]\|[[<0-9(]} $text] {
      puthelp "PRIVMSG $nick :It's possible you didn't split the lines quite right on the quote you just added. For best results, split lines in quotes using '|' with a space each side. To delete the quote you just added and fix it, do '!delquote $id' in the channel."
  }
}


################################################################################
# quote_rand
# !randquote [--all|--channel #channel]
#   Gets a random quote from the database for the current channel
#     --all: Choose from entire database
#     --channel: Choose from given channel
#     -c: Shortcut for --channel
################################################################################
proc quote_rand { nick host handle channel text } {
  global quote_noflags quote_shrinkspaces

  if {![channel get $channel quoteengine]} {
    return 0
  }

  if [matchattr $handle $quote_noflags] { return 0 }

  set where_clause "WHERE channel='$channel'"
  if [regexp -- "--?all" $text] {
    set where_clause ""
  }

  if [regexp -- "--?c(hannel)?( |=)(.+)" $text matches skip1 skip2 newchan] {
    set where_clause "WHERE channel='[quote_escape $newchan]'"
  }

  set sql "SELECT * FROM quotes $where_clause ORDER BY RANDOM() LIMIT 1"
  putloglev d * "QuoteEngine: executing $sql"

  quote_db_handle eval $sql result {
    set id $result(id)
    set quote $result(quote)
    set by $result(nick)
    set when [clock format $result(timestamp) -format "%Y/%m/%d %H:%M"]
		catch {
			if {$quote_shrinkspaces == 1} {
				regsub -all "  +" $quote " " quote
			}
			set quote [stripcodes bcruag $quote]
		}

    puthelp "PRIVMSG $channel :\[\002$id\002\] $quote"
  }
}


################################################################################
# quote_fetch
# !getquote <id>
#   Fetches the given quote from the database
################################################################################
proc quote_fetch { nick host handle channel text } {
  global quote_db_handle quote_noflags quote_shrinkspaces

  if {![channel get $channel quoteengine]} {
    return 0
  }

  if [matchattr $handle $quote_noflags] { return 0 }

	set verbose ""

  if {![regexp {(-v )?([0-9]+)} $text matches verbose quote_id]} {
    puthelp "PRIVMSG $channel: Use: !getquote \[-v\] <id>"
    return 0
  }


  set sql "SELECT * FROM quotes WHERE id=:quote_id"
  putloglev d * "QuoteEngine: executing $sql"
  set found 0

  quote_db_handle eval $sql result {
    set id $result(id)
		set quote $result(quote)
		catch {
			if {$quote_shrinkspaces == 1} {
				regsub -all "  +" $quote " " quote
			}
			set quote [stripcodes bcruag $quote]
		}
    set by $result(nick)
    set when [clock format $result(timestamp) -format "%Y/%m/%d %H:%M"]
    set chan $result(channel)
    if {$chan != $channel} {
      puthelp "PRIVMSG $channel :\[\002$id\002\] $quote"
      if {$verbose != ""} {
				puthelp "PRIVMSG $channel :\[\002$id\002\] From $chan, by added $by at $when."
			}
    } else {
      puthelp "PRIVMSG $channel :\[\002$id\002\] $quote"
			if {$verbose != ""} {
				puthelp "PRIVMSG $channel :\[\002$id\002\] Added by $by at $when."
			}
    }
    set found 1
  }

  if {!$found} {
    puthelp "PRIVMSG $channel :Couldn't find quote $text"
  }
}


################################################################################
# quote_search
# !findquote [--all] [--channel #channel] [--count <int>] <text>
#   Find all quotes with "text" in them. (in random order)
#   The first 5 (by default) are listed in the channel. The rest are /msg'd to
#   you up to the maximum (default 5).
#     --all: Search all channels, not just current one
#     --channel: Search given channel
#     --count <int>: Find this many total quotes
#     -c: Shortcut for --channel
#     -n: Shortcut for --count
#   Note this is a SQL search, so use % as the wildcard (instead of *)
#   The script automatically puts %s around your text when searching.
################################################################################
proc quote_search { nick host handle channel text } {
  global quote_webpage quote_noflags quote_chanmax

  if {![channel get $channel quoteengine]} {
    return 0
  }

  if [matchattr $handle $quote_noflags] { return 0 }

  if {$text == ""} {
    puthelp "PRIVMSG $channel :Use: !findquote <text>"
    return 0
  }

  set where_clause "AND channel=:channel"
  if [regexp -- "--?all " $text matches skip1] {
    set where_clause ""
    regsub -- $matches $text "" text
  }

  if [regexp -- {--?c(hannel)?( |=)([^ ]+)} $text matches skip1 skip2 newchan] {
    set where_clause "AND channel=:newchan"
    regsub -- $matches $text "" text
  }

  set limit 5
  if [regexp -- {--?count( |=)([^ ]+)} $text matches skip1 count] {
    set limit [quote_escape $count]
    regsub -- $matches $text "" text
  }

  if [regexp -- {-n( )?([^ ]+)} $text matches skip1 count] {
    set limit [quote_escape $count]
    regsub -- $matches $text "" text
  }

  set sql "SELECT * FROM quotes WHERE quote LIKE '%[quote_escape $text]%' $where_clause ORDER BY RANDOM()"

  putloglev d * "QuoteEngine: executing $sql"

  set overflow 0
  set count 0
  quote_db_handle eval $sql result {
      set id $result(id)
      set qnick $result(nick)
      set qhost $result(host)
      set quote $result(quote)
      set qchannel $result(channel)
      set qts $result(timestamp)

      if {$count >= $limit} {
        incr overflow 1
        continue
      }

      if {$count == $quote_chanmax} {
        puthelp "PRIVMSG $nick :Rest of matches for your search '$text' follow in private:"
      }

      if {$count < $quote_chanmax} {
        puthelp "PRIVMSG $channel :\[\002$id\002\] $quote"
      } else {
        puthelp "PRIVMSG $nick :\[\002$id\002\] $quote"
      }
      incr count
    }

    if {$overflow > 0} {
        if {$count < $quote_chanmax} {
            set command "PRIVMSG $channel :"
        } else {
            set command "PRIVMSG $nick :"
        }

        regsub "#" $channel "" chan
        puthelp "${command}Plus $overflow other matches"
    } else {
        if {$count < $quote_chanmax} {
            set command "PRIVMSG $channel :"
        } else {
            set command "PRIVMSG $nick :"
        }
        if {$count == 1} {
            puthelp "${command}(All of 1 match)"
        } else {
            puthelp "${command}(All of $count matches)"
        }
    }
    if {$count == 0} {
        puthelp "PRIVMSG $channel :No matches"
    }
}


################################################################################
# quote_url
# !quoteurl
#   Gives the web of the web interface
#   Removed in 2.0 with switch to sqlite; i'm not supporting the web interface
#   now
################################################################################
proc quote_url { nick host handle channel text } {
  global quote_webpage quote_noflags

  if {![channel get $channel quoteengine]} {
    return 0
  }

  if [matchattr $handle $quote_noflags] { return 0 }

  puthelp "PRIVMSG $channel :Not available."
}


################################################################################
# quote_stats
# !quotestats
#   Give some simple statistics about the db, channel, and user
################################################################################
proc quote_stats { nick host handle channel text } {
  global quote_db_handle quote_noflags

  if {![channel get $channel quoteengine]} {
    return 0
  }

  if [matchattr $handle $quote_noflags] { return 0 }

  set sql "SELECT COUNT(*) AS total FROM quotes WHERE channel='$channel'"
  putloglev d * "QuoteEngine: executing $sql"

  set total 0
  set chan 0
  set by_handle 0
  set total [quote_db_handle onecolumn $sql]

  set sql "SELECT COUNT(*) AS total FROM quotes"
  putloglev d * "QuoteEngine: executing $sql"

  set chan [quote_db_handle onecolumn $sql]

  set sql "SELECT COUNT(*) AS total FROM quotes WHERE nick='$handle' AND channel='$channel'"
  putloglev d * "QuoteEngine: executing $sql"

  set by_handle [quote_db_handle onecolumn $sql]

  puthelp "PRIVMSG $channel :Quotes for $channel: \002$total\002 (total: $chan). You have added \002$by_handle\002 quotes in this channel."
}


################################################################################
# quote_delete
# !delquote <id>
#   Removes a quote from the database. You can only delete the quote if you
#   are a bot/channel master, or if you're the person who added it.
################################################################################
proc quote_delete  { nick host handle channel text } {
  global quote_db_handle quote_noflags

  if {![channel get $channel quoteengine]} {
    return 0
  }

  if [matchattr $handle $quote_noflags] { return 0 }

  set text [quote_escape $text]
  if {![matchattr $handle m|m $channel]} {
    set sql "SELECT nick FROM quotes WHERE id='$text'"
    putloglev d * "QuoteEngine: executing $sql"

    set owner [quote_db_handle onecolume $sql]
    if {$owner != $handle} {
      puthelp "NOTICE $nick :You cannot delete that quote."
      return 0
    }
  }

  set sql "DELETE FROM quotes WHERE id='$text'"
  putloglev d * "QuoteEngine: executing $sql"

  quote_db_handle eval $sql
  puthelp "PRIVMSG $channel :Deleted quote $text"
}


################################################################################
# quote_version
# !quoteversion
#   Gives the version of the script
################################################################################
proc quote_version { nick host handle channel text } {
  global quote_version quote_noflags

  if [matchattr $handle $quote_noflags] { return 0 }

  puthelp "PRIVMSG $channel :This is the QuoteEngine version $quote_version by JamesOff (https://github.com/jamesoff/eggdrop-scripts)"
  return 0
}


################################################################################
# quote_help
# !quotehelp
#   Handle help requests
################################################################################
 proc quote_help { nick host handle channel text } {
  global quote_noflags

  if [matchattr $handle $quote_noflags] { return 0 }

  puthelp "PRIVMSG $nick :Commands for the QuoteEngine script:"
  puthelp "PRIVMSG $nick :  !addquote <quote text> - adds a quote to the database"
  puthelp "PRIVMSG $nick :  !delquote <id> - deletes a quote. You must be either a bot/channel master or the person who added the quote to delete it."
  puthelp "PRIVMSG $nick :  !randquote \[--all\] \[--channel=#channel\] \[-c #channel\] - fetches a random quote from the current channel. --all chooses from all channels, not just the one the command is executed from. --channel and -c choose only from the given channel."
  puthelp "PRIVMSG $nick :  !getquote \[-v\]<id> - fetches the quote with number <id>. Gives info of who added it if -v is specified."
  puthelp "PRIVMSG $nick :  !findquote \[--all\] \[--channel=#channel\] \[-c #channel\] \[--count <int>\] \[-n <int>\] <text> - finds up to <int> (default 5) quotes containing 'text'. Optional parameters same as !randquote. -n is a shortcut for --count."
  puthelp "PRIVMSG $nick :  !quotestats - get some information"
  puthelp "PRIVMSG $nick :  !quoteversion - get the version of the script"
  puthelp "PRIVMSG $nick :  Some commands have synonyms: !deletequote, !fetchquote, !urlquote, and !searchquote."
  puthelp "PRIVMSG $nick :  (End of help)"
  return 0
}

proc quote_auto { nick host handle channel text } {
	global quote_automatic quote_shrinkspaces
	if {$quote_automatic == 0} {
		return
	}

  if {![channel get $channel quoteengine]} {
		return
	}

	global quote_auto_last quote_db_handle quote_automatic_minimum

	if [info exists quote_auto_last($channel)] {
		set diff [expr [clock seconds] - $quote_auto_last($channel)]
		putloglev 1 * "diff for $channel is $diff"
	} else {
		set diff [expr $quote_automatic_minimum + 1]
		putloglev d * "initialising diff for $channel"
		set quote_auto_last($channel) 0
	}

	if {$diff < $quote_automatic_minimum} {
		return
	}

	set words [split $text]
	set newwords [list]

	foreach word $words {
		if [regexp -nocase {^[a-z0-9']{4,}$} $word] {
			if {[lsearch [list "yeah" "about" "hello" "their" "there" "that's" "can't" "morning" "won't"] $word] > -1} {
				continue
			}

			if [onchan $word] {
				continue
			}

			lappend newwords [quote_escape $word]
		}
	}

	if {[llength $newwords] == 0} {
		return
	}

	putloglev d * "quoteengine: candidate words for random quote in $channel: $newwords"

	set thisword [pickRandom $newwords]
	putloglev d * "quoteengine: using $thisword"

	if {[rand 100] < 95} {
		putloglev d * "quoteengine: not random enough, ignoring"
		return
	}


	set where_clause "WHERE channel='[quote_escape $channel]' AND quote LIKE '%$thisword%' ORDER BY RANDOM() LIMIT 1"
	putloglev d * "quoteengine: $where_clause"
	set sql "SELECT id,quote FROM quotes $where_clause"

	quote_db_handle eval $sql result {
		set id $result(id)
		set quote $result(quote)

		catch {
			if {$quote_shrinkspaces == 1} {
				regsub -all "  +" $quote " " quote
			}
			set quote [stripcodes bcruag $quote]
		}

		putloglev d * "RANDOM QUOTE: $quote ($id)"
		puthelp "PRIVMSG $channel :\[\002$id\002\] $quote"
		set quote_auto_last($channel) [clock seconds]
	}
}

# Define the pickRandom method which is used if bMotion isn't loaded
if {[llength [info procs pickRandom]] == 0} {
	proc pickRandom { list } {
		return [lindex $list [rand [llength $list]]]
	}
}

quote_connect
putlog "QuoteEngine $quote_version loaded"
