# The trivia engine YAY
# vim: foldmethod=marker:foldcolumn=2:foldmarker=<<<,>>>:sw=2:ts=2

### INIT <<<
# load mysqltcl
package require mysqltcl

# the channel to play in
set trivia_channel "#triviacow"

# the time between hints (sec)
set trivia_speed 20

# the time between rounds (sec)
set trivia_delay 30

# hold the current question info <<<
set trivia_q_id ""
set trivia_q_cat ""
set trivia_q_question ""
set trivia_q_answer ""
set trivia_q_hint ""
set trivia_q_attempts 0
set trivia_unanswered 0
set trivia_run_last 0
set trivia_run_qty 0
set trivia_run_nick ""
set trivia_guesser ""
set trivia_guesser_count 0
set trivia_last_qid 0

if [info exists trivia_must_rehash] {
  if {$trivia_must_rehash == 1} {
    set trivia_must_rehash 2
  } else {
    set trivia_must_rehash 0
  }
} else {
  set trivia_must_rehash 0
}
#>>>

# 0 = off
# 1 = on
# -1 = disabled
set trivia_status 0

set trivia_timer ""
set trivia_watchdog_timer ""
set trivia_last_ts 0

#colours <<<
set trivia_c(off) "\003"
set trivia_c(red) "\0034"
set trivia_c(blue) "\0033"
set trivia_c(purple) "\0036"
set trivia_c(bold) "\002"
#>>>

bind pubm - * trivia_input
bind msg - trivia trivia_msg

# connect mysql <<<
proc trivia_connect { } {
  global trivia_db_handle
  set trivia_db_handle [mysqlconnect -host localhost -user root -password 7MKh3ako -db trivialive]
}
#>>>

#>>>

### SETTINGS <<<
set trivia_flag T
set trivia_admin S
# >>>


# Handle a /msg
proc trivia_msg { nick host handle cmd } {
#<<<
  global trivia_db_handle trivia_last_qid
  global trivia_q_cat trivia_c

  regsub "(trivia )" $cmd "" cmd
  putlog "trivia: msg command $cmd from $nick"

  if {($nick == "Greeneyez") || ($nick == "JamesOff")} {
    if [regexp -nocase "^setcat (.+)" $cmd matches category] {

      if {$trivia_last_qid == 0} {
        puthelp "PRIVMSG $nick :Can't fathom last question, unable to update category"
        return
      }

      set orig_cat $category
      set category [mysqlescape $category]
      set sql "SELECT cat_id FROM categories WHERE cat_name='$category'"
      set result [mysqlquery $trivia_db_handle $sql]

      if {[set row [mysqlnext $result]] != ""} {
        set cat_id [lindex $row 0]
        mysqlendquery $result
        puthelp "PRIVMSG $nick :Moving question $trivia_last_qid to category$trivia_c(purple) $category$trivia_c(off) ($cat_id)"
        set sql "UPDATE questions SET cat_id='$cat_id' WHERE question_id='$trivia_last_qid'"
        mysqlexec $trivia_db_handle $sql
        set trivia_q_cat $orig_cat
        return
      } else {
        puthelp "PRIVMSG $nick :Creating new category$trivia_c(purple) $category"
        set sql "INSERT INTO categories VALUES (null, '$category', 1)"
        mysqlexec $trivia_db_handle $sql
        set cat_id [mysqlinsertid $trivia_db_handle]
        puthelp "PRIVMSG $nick :Moving question $trivia_last_qid to category$trivia_c(purple) $category$trivia_c(off) ($cat_id)"
        set sql "UPDATE questions SET cat_id='$cat_id' WHERE question_id='$trivia_last_qid'"
        mysqlexec $trivia_db_handle $sql
        set trivia_q_cat $orig_cat
        return
      }
    }
  }
}
#>>>

# Handle input coming from a channel
proc trivia_input { nick host handle channel arg } {
#<<<
  global trivia_channel trivia_status trivia_q_answer
  global trivia_guesser_count trivia_guesser trivia_c

  if {[string tolower $trivia_channel] != [string tolower $channel]} {
    return 0
  }

  if [regexp -nocase "^!t(rivia)? (.+)" $arg matches cmd param] {
    trivia_command $nick $host $handle $channel $param
    return 0
  }

  if [regexp -nocase "^!t(rivia)?$" $arg] {
    if {$trivia_status == 1} {
      puthelp "PRIVMSG $trivia_channel :!trivia ... ?"
      return 0
    } else {
      puthelp "PRIGMSG $trivia_channel :Perhaps you want $trivia_c(purple)!trivia start"
      return 0
    }
  }

  # need to be running below here
  if {$trivia_status == -1} {
    return 0
  }

  if {$trivia_q_answer == ""} {
    return 0
  }

  #see if someone else is playing
  if {($nick == $trivia_guesser) && ($nick != "NoTopic")} {
    incr trivia_guesser_count
    putloglev d * "$nick has talked $trivia_guesser_count times in a row..."
  } else {
    set trivia_guesser_count 0
    set trivia_guesser $nick
  }

  #tidy the string up
  set arg [string tolower $arg]
  set arg [string trim $arg]
  if {$arg == [string tolower $trivia_q_answer]} {
    trivia_correct $nick
    return 0
  }

  #if they didn't get it right, and it's been more than 20 lines, taunt!
  if {($trivia_guesser_count > 0) && (($trivia_guesser_count % 20)) == 0} {
    putserv "PRIVMSG $trivia_channel :Playing with yourself, $nick? ;)"
    putlog "Is $nick playing with themselves?"
  }
}
#>>>

# Someone got it right!
proc trivia_correct { nick } {
#<<<
  global trivia_q_id trivia_q_cat trivia_q_question trivia_q_answer trivia_q_hint trivia_q_attempts trivia_channel trivia_status
  global trivia_timer trivia_delay trivia_db_handle trivia_unanswered trivia_run_qty trivia_run_last trivia_run_nick trivia_c

  if {$trivia_status != 1} {
  #something strange going on
    return 0
  }

  trivia_killtimer
  set answer $trivia_q_answer
  set trivia_q_answer ""
  set newuser 0

  set uid [trivia_get_uid $nick]
  if {$uid == 0} {
    putlog "$nick does not have entry in database... creating"
    set uid [trivia_create_user $nick]
    set newuser 1
  }

  putlog "$nick has uid $uid"

  trivia_incr_score $uid

  putquick "PRIVMSG $trivia_channel :Congratulations $trivia_c(purple)$nick$trivia_c(off)! The answer was$trivia_c(purple) $answer$trivia_c(off)."
  if {$newuser == 1} {
    putquick "PRIVMSG $trivia_channel :Welcome to our newest player,  $trivia_c(purple)$nick$trivia_c(off) :)"
  }
  putquick "PRIVMSG $trivia_channel :rank0rs: [trivia_near_five2 $uid]"

  #set score [trivia_get_score $uid]
  #putserv "PRIVMSG $trivia_channel :$nick now has $score points."

  set trivia_timer [utimer $trivia_delay trivia_start_round]
  set trivia_unanswered 0
  if {$trivia_run_last == $uid} {
    incr trivia_run_qty
    if {$trivia_run_qty > 2} {
      putquick "PRIVMSG $trivia_channel :$nick [trivia_get_run $trivia_run_qty] $trivia_run_qty in a row!"
    }
  } else {
  #end of streak
    if {$trivia_run_qty > 2} {
      putquick "PRIVMSG $trivia_channel :$nick ended $trivia_run_nick's winning spree."
    }
    set trivia_run_qty 1
    set trivia_run_last $uid
    set trivia_run_nick $nick
  }

  if {[rand 100] > 95} {
    putserv "PRIVMSG $trivia_channel :Remember, to report a problem with a question or answer, type $trivia_c(purple)!trivia report <description of problem>"
  }


  trivia_check_rehash
}
#>>>

#See if we need to rehash
proc trivia_check_rehash { } {
#<<<
  global trivia_must_rehash trivia_channel trivia_c
  if {$trivia_must_rehash == 1} {
    putquick "PRIVMSG $trivia_channel :$trivia_c(red)### Please wait, reloading trivia script ###"
    trivia_killtimer
    rehash
  }
}
#>>>

# Turn a winning spree into text
proc trivia_get_run { row } {
#<<<
  switch $row {
    3 {
      return "is on a winning spree!"
    }
    5 {
      return "is on a rampage!"
    }
    6 {
      return "is unstoppable!"
    }
    8 {
      return "is on a Google spree!"
    }
    10 {
      return "is GODLIKE!"
    }
    12 {
      return "needs to get out more."
    }
  }
  return "is on a roll ..."
}
#>>>

# Get someone's user ID from their nick
proc trivia_get_uid { nick } {
#<<<
  global trivia_db_handle

  putloglev 4 * "trivia_get_uid ($nick)"

  set nick [mysqlescape $nick]
  set sql "SELECT user_id FROM users WHERE user_name = '$nick'"
  set result [mysqlquery $trivia_db_handle $sql]
  #putlog $sql

  if {[set row [mysqlnext $result]] != ""} {
    set user_id [lindex $row 0]
    mysqlendquery $result
    return $user_id
  } else {
    return 0
  }
}
#>>>

# Get a period
proc trivia_get_period { } {
#<<<
  return [expr [clock scan "last friday 23:59" -gmt true] + 60]
}
#>>>

# Get a score from a UID
proc trivia_get_score { user_id } {
#<<<
  global trivia_db_handle

  putloglev 4 * "trivia_get_score ($user_id)"

  set dt [trivia_get_period]

  set sql "SELECT COUNT(*) AS yarr FROM scores WHERE dt > '$dt' AND user_id='$user_id'"

  set result [mysqlquery $trivia_db_handle $sql]

  if {[set row [mysqlnext $result]] != ""} {
    set score [lindex $row 0]
    mysqlendquery $result
    return $score
  } else {
    return 0
  }
}
#>>>

# Turn a timestamp into a date
proc trivia_ts_to_date { ts } {
#<<<
  return [clock format $ts -format "%Y/%m/%d %H:%M"]
}
#>>>

# Get someone's userinfo from their UID
proc trivia_get_userinfo { user_id } {
#<<<
  global trivia_db_handle

  putloglev 4 * "trivia_get_userinfo ($user_id)"

  set sql "SELECT user_score, user_last, user_reg FROM users WHERE user_id = '$user_id'"
  set result [mysqlquery $trivia_db_handle $sql]

  if {[set row [mysqlnext $result]] != ""} {
    set last [lindex $row 1]
    set score [trivia_get_score $user_id]
    if {$last == ""} {
      set last "Unknown"
    } else {
      set last [trivia_ts_to_date $last]
    }

    set reg [lindex $row 2]
    if {$reg == ""} {
      set reg "Unkown"
    } else {
      set reg [trivia_ts_to_date $reg]
    }

    return "$score|$last|$reg"
    mysqlendquery $result
  } else {
    return "No stats"
  }
}
#>>>

# Get someone's stats from their username
proc trivia_user_stats { user_name } {
#<<<
  global trivia_channel

  set uid [trivia_get_uid $user_name]
  if {$uid == 0} {
    putserv "PRIVMSG $trivia_channel :Unknown user '$user_name'"
    return
  }
  set stats [trivia_get_userinfo $uid]
  if {$stats == "No stats"} {
    putserv "PRIVMSG $trivia_channel :No stats available."
    return
  }

  set stats2 [split $stats "|"]
  putserv "PRIVMSG $trivia_channel :Trivia stats for $user_name:"
  putserv "PRIVMSG $trivia_channel :  Current score: [lindex $stats2 0]"
  putserv "PRIVMSG $trivia_channel :        Ranking: [trivia_get_rank $uid]"
  putserv "PRIVMSG $trivia_channel :     First seen: [lindex $stats2 2]"
  putserv "PRIVMSG $trivia_channel :    Last scored: [lindex $stats2 1]"
}
#>>>

# Increase a UID's score
proc trivia_incr_score { id { howmuch 1 } } {
#<<<
  global trivia_db_handle

  putloglev 4 * "trivia_incr_score ($id, $howmuch)"

  #set sql "UPDATE users SET user_score = user_score + $howmuch WHERE user_id = '$id'"
  #mysqlexec $trivia_db_handle $sql
  set sql "UPDATE users SET user_last = UNIX_TIMESTAMP() WHERE user_id = '$id'"
  mysqlexec $trivia_db_handle $sql
  set sql "INSERT INTO scores VALUES ('$id', '[clock seconds]')"
  mysqlexec $trivia_db_handle $sql
}
#>>>

# Create a new user
proc trivia_create_user { nick } {
#<<<
  global trivia_db_handle

  putloglev 4 * "trivia_create_user ($nick)"

  set nick [mysqlescape $nick]
  set sql "INSERT INTO users VALUES (null, '$nick', '', 0, UNIX_TIMESTAMP(), UNIX_TIMESTAMP())"
  mysqlexec $trivia_db_handle $sql

  set uid [mysqlinsertid $trivia_db_handle]

  return $uid
}
#>>>

# Handle a !trivia command
proc trivia_command { nick host handle channel param } {
#<<<
  global trivia_channel trivia_status trivia_flag trivia_admin trivia_c

  set arg ""
  regexp {^([^ ]+)( .+)?$} $param matches cmd arg
  set param [string tolower $cmd]
  set arg [string trim $arg]


  putloglev d *  "trivia command: $param from: $nick ($arg)"

  if {[matchattr $handle |$trivia_admin $trivia_channel] && ($param != "enable") && ($trivia_status == -1)} {
    return 0
  }

  if [regexp -nocase "^(score|place)( .+)?" $param] {
    putserv "PRIVMSG $trivia_channel :[trivia_score $arg $nick]"
    if [string match -nocase $nick $arg] {
      putserv "PRIVMSG $trivia_channel :(You know putting your own nick is optional, right? :)"
    }
    return 0
  }

  if {$param == "top10"} {
    putserv "PRIVMSG $trivia_channel :[trivia_get_top10]"
    return 0
  }

  if {$param == "info"} {
    trivia_user_stats $arg
    return 0
  }

  if {$param == "start"} {
    trivia_start
    return 0
  }

  if {$param == "report"} {
    trivia_report $nick $arg
    return 0
  }

  if {![matchattr $handle |$trivia_flag $channel]} {
    putserv "PRIVMSG $nick :use: !trivia \[score|top10|start\]"
    return 0
  }

  if {$param == "stop"} {
    trivia_stop
    return 0
  }


  if {$param == "skip"} {
    trivia_skip $nick
    return 0
  }

  if {$param == "stats"} {
    trivia_stats
    return 0
  }

  if {![matchattr $handle |$trivia_admin $channel]} {
    putserv "PRIVMSG $nick :use: !trivia \[score|top10|start|stop|skip|stats\]"
    return 0
  }

  if {$param == "disable"} {
    trivia_disable
    return 0
  }

  if {$param == "enable"} {
    trivia_enable
    return 0
  }

  if {$param == "merge"} {
    trivia_merge $nick $arg
    #puthelp "PRIGMSG $trivia_channel :Score merging is disabled"
    return 0
  }

  if {$param == "rehash"} {
    trivia_rehash
    return 0
  }

  putserv "PRIVMSG $nick :use: !trivia \[start|stop|score|top10|skip|stats|enable|disable|merge\]"
  return 0
}
#>>>

# Rehash
proc trivia_rehash { } {
#<<<
  global trivia_status trivia_channel trivia_must_rehash
  if {$trivia_must_rehash == 1} {
    putserv "PRIVMSG $trivia_channel :! Reloading trivia now..."
    rehash
    return 0
  }

  if {$trivia_status != 1} {
    putserv "PRIVMSG $trivia_channel :! Reloading trivia now..."
    rehash
    return 0
  }
  set trivia_must_rehash 1
  putserv "PRIVMSG $trivia_channel :Trivia will reload after current round"
}
#>>>

# Disable the script
proc trivia_disable { } {
#<<<
  global trivia_status trivia_channel

  if {$trivia_status == 1} {
  #stop the current game
    trivia_stop
  }

  set trivia_status -1
  putserv "PRIVMSG $trivia_channel :Trivia disabled."
  return 0
}
#>>>

# Enable the script1
proc trivia_enable {} {
#<<<
  global trivia_status trivia_channel

  set trivia_status 0
  putserv "PRIVMSG $trivia_channel :Trivia enabled."

  set alive [::mysql::ping $trivia_db_handle]
  if {$alive == false} {
    putlog "ERROR: mysql has gone away :("
    putquick "PRIVMSG $trivia_channel :Warning: Unable to reach database!"
  }
  return 0
}
#>>>

#Make a hint
proc trivia_make_hint { hint answer } {
#<<<
  set hint [string toupper $hint]
  set answer [string toupper $answer]

  set answer_words [split $answer { }]
  set final_hint ""

  #are we making the very first hint?
  if {$hint == ""} {
    foreach word $answer_words {
      append final_hint [string repeat "_" [string length $word]]
      append final_hint " "
    }

    set final_hint [string trim $final_hint]

    #now put the punctuation in
    set letters [split $answer {}]
    set i 0
    foreach letter $letters {
      if {![regexp -nocase {[A-Z0-9 ]} $letter]} {
        set final_hint [string replace $final_hint $i $i $letter]
      }
      incr i
    }
    return [string trim $final_hint]
  }

  # explode the into words
  set hint_words [split $hint { }]


  set i 0

  foreach word $hint_words {
    set answer_word [lindex $answer_words $i]
    putloglev 1 * "considering $answer_word ($word)"

    #are we on the first iteration?
    if [regexp "^_+$" $word] {
    #use the first letter
      set letters [string length $word]

      #don't hint for single-letter words
      if {$letters > 1} {
        set word [string index $answer_word 0]
        append word [string repeat "_" [expr $letters - 1]]
      } else {
        set word "_"
      }
      append final_hint "$word "
    } else {
    #not the first iteration so figure out where the gaps are
      set gaps [list]
      set letters [split $word {}]
      set j 0
      foreach letter $letters {
        if {$letter == "_"} {
          lappend gaps $j
        }
        incr j
      }
      if {[llength $gaps] <= 1} {
      #eek no letters to replace, or only one gap
        putloglev 1 * "  insufficient gaps, using $word"
        append final_hint "$word "
      } else {
      #now we pick a random letter position
        set pos [trivia_random_element $gaps]
        putloglev 1 * "  filling in $pos"
        set word [string replace $word $pos $pos [string index $answer_word $pos]]
        putloglev 1 * "  --> $word"
        append final_hint "$word "
      }
    }
    incr i
  }
  set final_hint [string trim $final_hint]
  return $final_hint
}
#>>>

# Fetch a question
proc trivia_get_question { } {
#<<<
  global trivia_db_handle trivia_q_id trivia_q_cat trivia_q_question trivia_q_answer trivia_q_hint trivia_channel

  # make sure we're connected
  set alive [::mysql::ping $trivia_db_handle]
  if {$alive == false} {
    putlog "ERROR: mysql has gone away :("
    putquick "PRIVMSG $trivia_channel :Couldn't reach database to load next question :("
    return 0
  }

  set sql "SELECT q.question, q.question_id, q.answer, c.cat_name FROM questions q LEFT JOIN categories c USING (cat_id) WHERE c.cat_enabled=1 ORDER BY count ASC, rand() LIMIT 1"
  set result [mysqlquery $trivia_db_handle $sql]

  if {[set row [mysqlnext $result]] != ""} {
    set trivia_q_id [lindex $row 1]
    set trivia_q_cat [lindex $row 3]
    set trivia_q_question [lindex $row 0]
    set trivia_q_answer [string toupper [lindex $row 2]]
    set trivia_q_hint ""
    mysqlendquery $result
  } else {
    putlog "ERROR: Couldn't fetch a question from the database."
  }

  #update the times used
  set trivia_q_id [mysqlescape $trivia_q_id]
  set sql "UPDATE questions SET count = count + 1 WHERE question_id = '$trivia_q_id'"
  mysqlexec $trivia_db_handle $sql
}
#>>>

# Start a round
proc trivia_start_round { } {
#<<<
  global trivia_q_id trivia_q_cat trivia_q_question trivia_q_answer trivia_q_hint trivia_q_attempts trivia_channel trivia_status trivia_last_qid

  if {$trivia_status != 1} {
  #we're switched off, abort
    return 0
  }

  #init variables
  set trivia_q_id ""
  set trivia_q_cat ""
  set trivia_q_question ""
  set trivia_q_answer ""
  set trivia_q_hint ""

  putlog "Fetching next question..."

  trivia_get_question

  if {$trivia_q_id == ""} {
    putlog "Couldn't init trivia round, aborting."
    return
  }

  putlog "Successfully fetched question $trivia_q_id from database"
  putloglev 4 * "question = $trivia_q_question"
  putloglev 4 * "answer   = $trivia_q_answer"

  set trivia_q_attempts 1

  set trivia_last_qid $trivia_q_id

  trivia_round
}
#>>>

# Run a round
proc trivia_round { } {
#<<<
  global trivia_q_id trivia_q_cat trivia_q_question trivia_q_answer trivia_q_hint trivia_q_attempts trivia_channel trivia_status
  global trivia_timer trivia_speed trivia_c trivia_last_ts

  if {$trivia_status != 1} {
  #we're switched off, abort
    return 0
  }

  if {$trivia_q_attempts == 5} {
    trivia_end_round
    return 0
  }

  if {$trivia_q_answer == ""} {
    return 0
  }

  #update the hint
  set trivia_q_hint [trivia_make_hint $trivia_q_hint $trivia_q_answer]

  #say our stuff
  if {$trivia_q_attempts > 1} {
    set hint " \[[expr $trivia_q_attempts - 1] of 3\]"
  } else {
    set hint ""
  }

  putserv "PRIVMSG $trivia_channel :$trivia_c(red)--== Trivia ==--$trivia_c(off) \[category: \002$trivia_q_cat\002\]"
  #\[question id: \002$trivia_q_id\002\]"
  set split_question [trivia_question_split $trivia_q_question]
  foreach q $split_question {
    if {$q != ""} {
      putserv "PRIVMSG $trivia_channel :$trivia_c(blue) [trivia_question_inject $q]"
    }
  }
  #set new_question [trivia_question_inject $trivia_q_question]
  #putserv "PRIVMSG $trivia_channel :$trivia_c(blue) $new_question"
  putserv "PRIVMSG $trivia_channel :Hint$hint: [trivia_explode $trivia_q_hint]"

  incr trivia_q_attempts

  set trivia_last_ts [clock seconds]

  global trivia_must_rehash
  if {$trivia_must_rehash != 2} {
    set trivia_timer [utimer $trivia_speed trivia_round]
  }
}
#>>>

# Make it harder for things to break questions (inject bold codes)
proc trivia_question_inject { question } {
#<<<
  putlog "trivia_question_inject $question"
  #inject random bold/underline/colour codes into question
  global trivia_c

  set l [string length $question]
  putlog "length: $l"
  if {$l < 1} {
    return $question
  }
  set pos [rand $l]
  set first [string range $question 0 $pos]
  incr pos
  set second [string range $question $pos end]
  switch [rand 1] {
    0 {
      putlog "question_inject: using bold at pos $pos"
      return $first$trivia_c(bold)$trivia_c(bold)$second
    }
    1 {
      putlog "question_inject: using purple at pos $pos"
      return $first$trivia_c(purple)$trivia_c(off)$second
    }
  }
  return $question
}
#>>>

# Make it harder for things to break questions (inject line breaks)
proc trivia_question_split { question } {
#<<<
  putlog "trivia_question_split $question"
  #explodes a question into two lines at word boundaries, if it's long enough
  #don't split unscrambles incorrectly
  if [regexp -nocase "(unscramble .+:) (\[A-Z \]+)" $question matches first second] {
    return [list $first $second]
  }
  set words [split $question " "]
  set wordcount [llength $words]
  if {$wordcount < 4} {
    putlog "aborting, too short"
    return [list $question]
  }

  #enough words to split
  #we want at least two on the first line
  putlog "wordcount: $wordcount"
  incr wordcount -2
  if {$wordcount < 0} {
    return [list $question]
  }
  set pos [rand $wordcount]
  incr pos 2
  putlog "picked pos $pos"
  set wordlist [list]
  set i 0
  set line ""
  foreach word $words {
  #putlog "word = $word, i = $i"
    append line "$word "
    if {$i == $pos} {
    #putlog "splitting here, line = $line"
      lappend wordlist [string trim $line]
      set line ""
    }
    incr i
  }
  #putlog "done, appending $line to list"
  if {$line != ""} {
    lappend wordlist [string trim $line]
  }
  #putlog "split question list is: $wordlist"
  return $wordlist
}
#>>>

# Finish a round (without a winner)
proc trivia_end_round { } {
#<<<
  global trivia_q_id trivia_q_cat trivia_q_question trivia_q_answer trivia_q_hint trivia_q_attempts trivia_channel trivia_status
  global trivia_timer trivia_delay trivia_db_handle trivia_unanswered
  global trivia_run_last trivia_run_nick trivia_run_qty trivia_c

  if {$trivia_status != 1} {
  #we're switched off, abort
    return 0
  }

  set trivia_q_answer [string toupper $trivia_q_answer]
  putquick "PRIVMSG $trivia_channel :Time's up! Nobody got it right. The answer was$trivia_c(purple) $trivia_q_answer"
  set trivia_q_answer ""

  incr trivia_unanswered
  if {$trivia_run_qty > 2} {
    putserv "PRIVMSG $trivia_channel :So much for $trivia_run_nick's winning spree."
  }
  set trivia_run_last 0
  set trivia_run_qty 0
  set trivia_run_nick ""

  if {[rand 100] > 90} {
    putserv "PRIVMSG $trivia_channel :Remember, to report a problem with a question or answer, type $trivia_c(purple)!trivia report <description of problem>"
  }

  if {$trivia_unanswered > 3} {
    putserv "PRIVMSG $trivia_channel :Three unanswered in a row, stopping the game."
    set trivia_status 0
  } else {
    set trivia_timer [utimer $trivia_delay trivia_start_round]
    trivia_check_rehash
  }
}
#>>>

# Skip the rest of this question
proc trivia_skip { nick } {
#<<<
  global trivia_q_id trivia_q_cat trivia_q_question trivia_q_answer trivia_q_hint trivia_q_attempts trivia_channel trivia_status
  global trivia_timer trivia_delay trivia_db_handle trivia_unanswered

  if {$trivia_status != 1} {
  #we're switched off, abort
    return 0
  }

  if {$trivia_q_answer == ""} {
  #no round in progress
    return 0
  }

  set trivia_q_question ""
  set trivia_q_answer ""

  trivia_killtimer

  putserv "PRIVMSG $trivia_channel :Skipping this question by $nick's request."
  set trivia_timer [utimer $trivia_delay trivia_start_round]
}
#>>>

# Utility function to fetch a random item from a list
proc trivia_random_element { l } {
#<<<
  return [lindex $l [rand [llength $l]]]
}
#>>>

# Start the game
proc trivia_start { } {
#<<<
  global trivia_status trivia_channel trivia_unanswered trivia_run_last trivia_run_qty trivia_c trivia_must_rehash trivia_db_handle

  if {$trivia_status == 1} {
    putserv "PRIVMSG $trivia_channel :Trivia is already running."
    return 0
  }

  if {$trivia_status == -1} {
    putserv "PRIVMSG $trivia_channel :Trivia is currently disabled."
    return 0
  }

  set alive [::mysql::ping $trivia_db_handle]
  if {$alive == false} {
    putlog "ERROR: mysql has gone away :("
    putquick "PRIVMSG $trivia_channel :Unable to start game; can't reach database :("
  }

  # go go go
  set trivia_status 1
  if {$trivia_must_rehash == 2 } {
    putquick "PRIVMSG $trivia_channel :$trivia_c(blue)### Resuming trivia game ###" -next
  } else {
    putquick  "PRIVMSG $trivia_channel :Trivia game started!" -next
  }

  #trivia_stats

  set trivia_unanswered 0
  set trivia_run_last 0
  set trivia_run_qty 0

  trivia_start_round
  return 0
}
#>>>

# Stop the game
proc trivia_stop { } {
#<<<
  global trivia_channel trivia_status

  if {$trivia_status == 1} {
    putserv "PRIVMSG $trivia_channel :Trivia game stopped."
    set trivia_status 0
    trivia_killtimer
  }
  return 0
}
#>>>

# Kill our timer
proc trivia_killtimer { } {
#<<<
  global trivia_timer

  if {$trivia_timer != ""} {
    killutimer $trivia_timer
  }
}
#>>>

# Utility function to explode line into letters
proc trivia_explode { line } {
#<<<
  set letters [split $line {}]
  set newline ""
  foreach letter $letters {
    append newline "$letter "
  }
  return [string trim $newline]
}
#>>>

# Get a UID's ranking
proc trivia_get_rank { uid } {
#<<<
  global trivia_db_handle

  putloglev 4 * "trivia_get_rank ($uid)"

  set sql "SELECT user_id FROM users ORDER by user_score DESC"
  set dt [trivia_get_period]
  set sql "select user_id, count(dt) as d from scores where dt > $dt group by user_id order by d desc"
  set result [mysqlsel $trivia_db_handle $sql -flatlist]

  set pos [lsearch -exact $result $uid]
  return [expr $pos + 1]
}
#>>>

# Get the top 10 users
proc trivia_get_top10 { } {
#<<<
  global trivia_db_handle

  set sql "SELECT user_name, user_score FROM users ORDER BY user_score DESC LIMIT 10"
  set dt [trivia_get_period]
  set sql "select users.user_name, count(dt) as d from scores left join users using (user_id) where dt > $dt group by scores.user_id order by d desc limit 10"

  set result [mysqlsel $trivia_db_handle $sql -list]
  set output ""
  set index 0

  foreach place $result {
    incr index
    append output "\002$index:\002 "
    append output [lindex $place 0]
    append output " ("
    append output [lindex $place 1]
    append output ")  "
  }

  set output "The top $index players are... $output"
  return $output
}
#>>>

# Fix a number into text
proc trivia_ordinal { number } {
#<<<
  if [regexp {1[0-9]$} $number] {
    return "th"
  }

  set last [string range $number end end]

  if {$last == "1"} {
    return "st"
  }

  if {$last == "2"} {
    return "nd"
  }

  if {$last == "3"} {
    return "rd"
  }

  return "th"
}
#>>>

# Get a score
proc trivia_score { n { nick "" } } {
#<<<
  set n [string trim $n]
  putloglev 4 * "trivia_score($n, $nick)"

  if {$n == ""} {
    set ni $nick
    set o "You are"
  } else {
    set ni $n
    set o "$n is"
  }

  set uid [trivia_get_uid $ni]
  set score [trivia_get_score $uid]
  set pos [trivia_get_rank $uid]
  if {$score == 0} {
    return "No score found for $n."
  }
  return "$o ranked $pos[trivia_ordinal $pos] with $score points."
}
#>>>

# Get the scores around a UID
proc trivia_near_five { uid } {
#<<<
  global trivia_db_handle trivia_c

  set sql "SELECT user_id, user_name, user_score FROM users ORDER BY user_score DESC"
  set dt [trivia_get_period]
  set sql "select users.user_id, users.user_name, count(dt) as user_score from scores left join users using (user_id) where dt > $dt group by scores.user_id order by user_score desc"

  set result [mysqlsel $trivia_db_handle $sql -flatlist]

  set pos [lsearch -exact $result $uid]

  #we use +- 6 here because it's a flat list, and we want 2 nodes either side
  putlog $result
  set near_five [lrange $result [expr $pos - 6] [expr $pos + 8]]

  putlog $near_five
  set low_pos [expr round(($pos-1) / 3)]
  if {$low_pos < 1} {
    set low_pos 1
  }
  putlog $low_pos
  set i 0
  set output ""
  while {$i < [llength $near_five]} {
    set user_id [lindex $near_five $i]
    incr i
    set nick [lindex $near_five $i]
    incr i
    set score [lindex $near_five $i]
    incr i

    if {$uid == $user_id} {
      append output "$trivia_c(purple)$trivia_c(bold)"
    }

    append output "$low_pos[trivia_ordinal $low_pos]:"
    append output "$nick"
    append output " ($score)  "

    if {$uid == $user_id} {
      append output "$trivia_c(off)$trivia_c(bold)"
    }

    incr low_pos
  }
  return $output
}
#>>>

# Turn a list into a stats list
proc trivia_list_to_stats { pos user_id l } {
#<<<
  putloglev 4 * "trivia_list_to_stats ($pos, $user_id, $l)"
  global trivia_c
  set uid [lindex $l 0]
  set nick [lindex $l 1]
  set score [lindex $l 2]
  incr pos

  set result ""
  if {$user_id == $uid} {
    set result "$trivia_c(purple)$trivia_c(bold)"
  }
  append result "$pos[trivia_ordinal $pos]: $nick ($score)  "
  if {$user_id == $uid} {
    append result "$trivia_c(off)$trivia_c(bold)"
  }
  return $result
}
#>>>

# Another function to get the nearest users to your score
proc trivia_near_five2 { uid } {
#<<<
  global trivia_db_handle trivia_c

  set sql "SELECT user_id, user_name, user_score FROM users ORDER BY user_score DESC"
  set dt [trivia_get_period]
  set sql "select users.user_id, users.user_name, count(dt) as user_score from scores left join users using (user_id) where dt > $dt group by scores.user_id order by user_score desc"

  set result [mysqlsel $trivia_db_handle $sql -list]

  putloglev d * "current score list: $result"

  set position 0
  foreach item $result {
    if {[lindex $item 0] == $uid} {
      putloglev d * "found at position $position"
      break
    }
    incr position
  }

  set line ""

  if {$position > 2} {
    append line [trivia_list_to_stats [expr $position - 2] $uid [lindex $result [expr $position - 2]]]
  }

  if {$position > 1} {
    append line [trivia_list_to_stats [expr $position - 1] $uid [lindex $result [expr $position - 1]]]
  }

  append line [trivia_list_to_stats $position $uid [lindex $result $position]]

  if {$position < [expr [llength $result] - 1]} {
    append line [trivia_list_to_stats [expr $position + 1] $uid [lindex $result [expr $position + 1]]]
  }

  if {$position < [expr [llength $result] - 2]} {
    append line [trivia_list_to_stats [expr $position + 2] $uid [lindex $result [expr $position + 2]]]
  }

  return $line
}
#>>>

# Get some stats from the DB
proc trivia_stats { } {
#<<<
  global trivia_db_handle trivia_channel

  set sql "SELECT COUNT(*) AS total FROM questions LEFT JOIN categories USING (cat_id) WHERE categories.cat_enabled = 1;"
  set result [mysqlsel $trivia_db_handle $sql -flatlist]
  set stat_total_questions [lindex $result 0]

  set sql "SELECT COUNT(*) AS total FROM categories WHERE cat_enabled = 1"
  set result [mysqlsel $trivia_db_handle $sql -flatlist]
  set stat_total_cats [lindex $result 0]

  putserv "PRIVMSG $trivia_channel :Using\002 $stat_total_questions\002 questions in\002 $stat_total_cats\002 categories."
}
#>>>

# Merge two users
proc trivia_merge { nick param } {
#<<<
  global trivia_db_handle

  putloglev 4 * "trivia_merge ($nick, $param)"

  if [regexp {^([^ ]+) (.+)$} $param matches nick1 nick2] {
    set olduid [trivia_get_uid [mysqlescape $nick1]]
    set newuid [trivia_get_uid [mysqlescape $nick2]]

    if {$olduid == 0} {
      puthelp "PRIVMSG $nick :Can't find user '$nick1'"
      return 0
    }

    if {$newuid == 0} {
      puthelp "PRIVMSG $nick :Can't find user '$nick2'"
      return 0
    }

    puthelp "PRIVMSG $nick :Meging score for $nick1 into score for $nick2"
    set sql "UPDATE scores SET user_id=$newuid WHERE user_id=$olduid"
    mysqlexec $trivia_db_handle $sql

    set newscore [trivia_get_score $newuid]
    puthelp "PRIVMSG $nick :$nick2 now has $newscore points."

    set sql "DELETE FROM users WHERE user_id = $olduid"
    mysqlexec $trivia_db_handle $sql
    puthelp "PRIVMSG $nick :User $nick1 has been deleted."
    return 0
  } else {
    puthelp "PRIVMSG $nick :Use: !trivia merge <olduser> <newuser>"
    puthelp "PRIVMSG $nick :  olduser's score is merged with newuser's and olduser is deleted."
  }
}
#>>>

# Find people who can start the script
# TODO: is this still used?
proc trivia_find_starters { } {
#<<<
  global trivia_channel trivia_flag
  set nicks [chanlist #triviacow &$trivia_flag]

  if {[llength $nicks] > 0} {
    return "One of the following users may be able to help: $nicks"
  } else {
    return "Sorry, noone who can start trivia is present."
  }
}
#>>>

# Report a broken question
proc trivia_report { nick msg } {
#<<<
  global trivia_channel trivia_db_handle trivia_last_qid trivia_c

  if {$trivia_last_qid == 0} {
    puthelp "PRIVMSG $trivia_channel :Sorry, unable to work out which question to report on :("
    return 0
  }

  set nick [mysqlescape $nick]
  set msg [mysqlescape $msg]

  set sql "INSERT INTO reports VALUES (null, UNIX_TIMESTAMP(), '$nick', '$trivia_last_qid', '$msg', 'N')"
  mysqlexec $trivia_db_handle $sql
  puthelp "PRIVMSG $trivia_channel :Added a report against question ID$trivia_c(purple) $trivia_last_qid$trivia_c(off) from $trivia_c(purple)$nick$trivia_c(off)."
  set trivia_last_qid 0
}
#>>>

### WATCHDOG STUFF <<<
# Watchdog timer to make sure we're not ruined
proc trivia_watchdog { } {
#<<<
  global trivia_last_ts trivia_watchdog_timer trivia_status trivia_channel

  putloglev d * "trivia watchdog: tick"

  if {$trivia_last_ts == 0} {
  #never asked a question
    set trivia_watchdog_timer [utimer 45 trivia_watchdog]
    return 0
  }

  set current_ts [clock seconds]
  set difference [expr $current_ts - $trivia_last_ts]

  if {$difference > 60} {
    if {$trivia_status == 1} {
      putlog "watchdog: trivia is broken"
      #putserv "PRIVMSG $trivia_channel :Oops, I think I'm broken. Attempting to recover..."
      #set trivia_status 0
      #trivia_start
      putlog "trivia watchdog: current: $current_ts, last: $trivia_last_ts, difference: $difference"
    }
  }

  set trivia_watchdog_timer [utimer 10 trivia_watchdog]
  return 0
}
#>>>

# Kill the watchdog timeer
proc trivia_killwatchdog { } {
#<<<
  global trivia_watchdog_timer

  if {$trivia_watchdog_timer != ""} {
    killutimer $trivia_watchdog_timer
  }
}
#>>>

trivia_killwatchdog
set trivia_watchdog_timer [utimer 45 trivia_watchdog]
#>>>

trivia_connect

putlog {TriviaEngine ENGAGED(*$£&($}

if {$trivia_must_rehash == 2} {
  putlog "Auto-restarting trivia..."
  trivia_start
  set trivia_must_rehash 0
}
