# The trivia engine YAY
# vim: foldmethod=marker:foldcolumn=2:foldmarker=<<<,>>>:sw=2:ts=2

### INIT <<<
package require sqlite

# the channel to play in
set trivia_channel "#triviacow"

# the time between hints (sec)
set trivia_speed 20

# the time between rounds (sec)
set trivia_delay 30

# allow new categories to be created?
set trivia_allow_new_cats 0

# time before end of round to start counting down
set trivia_time_left_warning 86400

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
set trivia_q_timestamp 0
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
set trivia_score_time 0
set trivia_debug_mode 0
set trivia_warned 0
set trivia_asking_question 0
set trivia_current_leader -1

#colours <<<
set trivia_c(off) "\003"
set trivia_c(red) "\0034"
set trivia_c(blue) "\0033"
set trivia_c(purple) "\0036"
set trivia_c(bold) "\002"
set trivia_c(realblue) "\0032"
#>>>

bind pubm - * trivia_input
bind msg - trivia trivia_msg

# connect database <<<
proc trivia_connect { } {
  global trivia_db_handle
  sqlite3 trivia_db_handle trivia.db
}
#>>>

#>>>

### SETTINGS <<<
set trivia_flag T
set trivia_admin S

#botnet handle of the bmotion bot we're going to play with (set blank to disable)
set trivia_bmotion_bot "NoTopic"
# >>>

# Send a botnet command to the bmotion bot
proc trivia_bmotion_send { command params } {
  global trivia_bmotion_bot

  if {$trivia_bmotion_bot == ""} {
    return 0
  }

  if [islinked $trivia_bmotion_bot] {
    putbot $trivia_bmotion_bot "trivia $command :$params"
    putloglev d * "triviaengine: send $command to $trivia_bmotion_bot with params $params"
  } else {
    putlog "triviaengine: trying to communicate with bmotion bot $trivia_bmotion_bot but it's not linked"
  }
}



# Handle a /msg
proc trivia_msg { nick host handle cmd } {
#<<<
  global trivia_db_handle trivia_last_qid
  global trivia_q_cat trivia_c trivia_allow_new_cats

  regsub "(trivia )" $cmd "" cmd
  putlog "trivia: msg command $cmd from $nick"

  if {($nick == "Greeneyez") || ($nick == "JamesOff")} {
  #<<< set a question's category
    if [regexp -nocase "^setcat (.+)" $cmd matches category] {

      if {$trivia_last_qid == 0} {
        puthelp "PRIVMSG $nick :Can't fathom last question, unable to update category"
        return
      }

      set orig_cat $category
      set category [trivia_sqlite_escape $category]
      set sql "SELECT cat_id FROM categories WHERE cat_name='$category'"
      set cat_id 0

      set cat_id [trivia_db_handle eval $sql]
      if {$cat_id != ""} {
        puthelp "PRIVMSG $nick :Moving question $trivia_last_qid to category$trivia_c(purple) $category$trivia_c(off) ($cat_id)"
        set sql "UPDATE questions SET cat_id='$cat_id' WHERE question_id='$trivia_last_qid'"
        trivia_db_handle eval $sql
        set trivia_q_cat $orig_cat
        return
      } else {
        if {$trivia_allow_new_cats == 1} {
          puthelp "PRIVMSG $nick :Creating new category$trivia_c(purple) $category"
          set sql "INSERT INTO categories VALUES (null, '$category', 1)"
          putloglev d * $sql
          trivia_db_handle eval $sql
          set cat_id [trivia_db_handle last_insert_rowid]
          puthelp "PRIVMSG $nick :Moving question $trivia_last_qid to category$trivia_c(purple) $category$trivia_c(off) ($cat_id)"
          set sql "UPDATE questions SET cat_id='$cat_id' WHERE question_id='$trivia_last_qid'"
          putloglev d * $sql
          trivia_db_handle eval $sql
          set trivia_q_cat $orig_cat
        } else {
          puthelp "PRIVMSG $nick :Creating new categories is $trivia_c(purple)DISABLED$trivia_c(off). ('trivia newcat enable' to enable.)"
        }
        return
      }
    }
    #>>>

    #<<< enable or disable new category creation
    if [regexp -nocase "^newcat (enable|disable)" $cmd matches toggle] {
      if {$toggle == "enable"} {
        puthelp "PRIVMSG $nick :$trivia_c(purple)ENABLING$trivia_c(off) new category creation"
        set trivia_allow_new_cats 1
        return
      }

      if {$toggle == "disable"} {
        puthelp "PRIVMSG $nick :$trivia_c(purple)DISABLING$trivia_c(off) new category creation"
        set trivia_allow_new_cats 0
        return
      }

      puthelp "PRIVMSG $nick :Use: trivia newcat enable|disable"
      return
    }
    #>>>

    #<<< debug
    if [regexp -nocase {^debug (.+)} $cmd matches func] {
      global trivia_debug_mode

      if {$trivia_debug_mode == 0} {
        putquick "PRIVMSG $nick :Debug mode is disabled. Cannot use debug commands."
        return 0
      }

      if {$func == "endweek"} {
        putquick "PRIVMSG $nick :Ending this week in 10 seconds..."
        global trivia_score_time
        set trivia_score_time [expr [clock seconds] + 10]
        return 0
      }
    }
    #>>>


    #<<< handle reports
    if [regexp -nocase {^report (help|list|fix|view|done|delete)?( .+)?} $cmd matches func arg] {
      if {($func == "") || ($func == "help")} {
        puthelp "PRIVMSG $nick :Use: report (list|view|fix|done|delete)"
        puthelp "PRIVMSG $nick :report list: see 10 reports"
        puthelp "PRIVMSG $nick :report view <id>: see the question and answer associated with a report"
        puthelp "PRIVMSG $nick :report fix <id> (question|answer) <new text>: update a question or answer"
        puthelp "PRIVMSG $nick :report done <id>: mark a report as done"
        return 0
      }

      if {$func == "list"} {
        putserv "PRIVMSG $nick :Gathering 10 trivia reports..."
        set sql "SELECT * FROM reports WHERE resolved = 'N' LIMIT 10"
        trivia_db_handle eval $sql result {
          putserv "PRIVMSG $nick :$result(report_id): [format %10s $result(who)] $result(message)"
        }
        return 0
      }

      if {$func == "view"} {
        if {$arg == ""} {
          puthelp "PRIVMSG $nick :Use: report view <id>"
          return 0
        }

        set arg [string trim $arg]
        set arg [trivia_sqlite_escape $arg]
        set sql "SELECT * FROM reports, questions WHERE report_id = '$arg' AND reports.question_id = questions.question_id"
        trivia_db_handle eval $sql result {
          putserv "PRIVMSG $nick :Report$trivia_c(purple) $result(report_id) $trivia_c(off)by$trivia_c(purple) $result(who) $trivia_c(off)on$trivia_c(blue) [clock format $result(when) -gmt 1]"
          putserv "PRIVMSG $nick :Question: $result(question)"
          putserv "PRIVMSG $nick :  Answer: $result(answer)"
          putserv "PRIVMSG $nick :  Report: $result(message)"
        }
        return 0
      }

      if {$func == "fix"} {
        set arg [string trim $arg]
        if [regexp -nocase {([0-9]+) (question|answer) (.+)} $arg matches report_id thing fix] {
          putserv "PRIVMSG $nick :Attempting to fix $trivia_c(purple)$thing$trivia_c(off) from report$trivia_c(purple) $report_id"
          #get question ID for this report
          set sql "SELECT question_id FROM reports WHERE report_id = '$report_id'"
          putloglev d * $sql
          set question_id 0
          trivia_db_handle eval $sql result {
            set question_id $result(question_id)
          }

          if {$question_id == 0} {
            putserv "PRIVMSG $nick :I can't seem to find that report, sorry :("
            return 0
          }

          set fix [trivia_sqlite_escape $fix]
          set sql "UPDATE questions SET $thing = '$fix' WHERE question_id = '$question_id'"
          putloglev d * $sql
          trivia_db_handle eval $sql

          putserv "PRIVMSG $nick :Updated!"
          return 0
        } else {
          puthelp "PRIVMSG $nick :Use: report fix <id> (question|answer) <new text>"
          return 0
        }
      }

      if {$func == "done"} {
        set arg [string trim $arg]
        set arg [trivia_sqlite_escape $arg]
        putserv "PRIVMSG $nick :Marking report$trivia_c(purple) $arg $trivia_c(off)as done."
        set sql "UPDATE reports SET resolved = 'Y' WHERE report_id = '$arg'"
        putloglev d * $sql
        trivia_db_handle eval $sql
        return 0
      }

      if {$func == "delete"} {
        set arg [string trim $arg]
        set arg [trivia_sqlite_escape $arg]
        putserv "PRIVMSG $nick :Deleting question from report$trivia_c(purple) $arg $trivia_c(off) and marking report as done."
        set sql "DELETE FROM questions WHERE question_id IN (SELECT question_id FROM reports WHERE report_id = '$arg')"
        putloglev d * $sql
        trivia_db_handle eval $sql
        set sql "UPDATE reports SET resolved = 'Y' WHERE report_id = '$arg'"
        putloglev d * $sql
        trivia_db_handle eval $sql
        return 0
      }
    }
    #>>>
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

  if [string match -nocase "!start" $arg] {
    if {$trivia_status > 0} {
      return
    }
    puthelp "PRIVMSG $trivia_channel :YOU'RE DOING IT WRONG"
  }

  if [regexp -nocase "^!t(rivia)?$" $arg] {
    if {$trivia_status == 1} {
      puthelp "PRIVMSG $trivia_channel :!trivia ... ?"
      return 0
    } else {
      puthelp "PRIVMSG $trivia_channel :Perhaps you want $trivia_c(purple)!trivia start"
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
  # try to stop any other output
    clearqueue server
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
  global trivia_score_time trivia_time_left_warning trivia_asking_question trivia_current_leader trivia_q_timestamp

  if {$trivia_status != 1} {
  #something strange going on
    return 0
  }

  trivia_killtimer
  set answer $trivia_q_answer
  set trivia_q_answer ""
  set newuser 0
  set trivia_asking_question 0

  set speed [expr [clock seconds] - $trivia_q_timestamp]

  set speedword ""
  if {$speed <= 1} {
    set speedword [trivia_random_element [list "POW! 0 to correct in under a second!" "Faster than a speeding fast thing!" "Even I didn't get it that quick, and I've just got to do a database lookup!"]]
  } elseif {$speed < 7} {
    set speedword [trivia_random_element [list "WHOOSH! 0 to correct in $speed seconds!" "%% shows their unassailable knowledge of whatever that question was about by getting it in $speed seconds" "Set course for correctsville, Commander %%. Ahead warp [expr 10 - $speed]!" "Caffeine abuse pays off for %% with a speedy time of $speed seconds" "Faster than a speeding triviabullet!"]]
  }

  set uid [trivia_get_uid $nick]
  if {$uid == 0} {
    putlog "$nick does not have entry in database... creating"
    set uid [trivia_create_user $nick]
    set newuser 1
  }

  putlog "$nick has uid $uid"

  set old_leader [trivia_leader]

  trivia_incr_score $uid

  regsub -all -nocase "%%" $speedword "$trivia_c(purple)$nick$trivia_c(off)" speedword

  putquick "PRIVMSG $trivia_channel :Congratulations $trivia_c(purple)$nick$trivia_c(off)! The answer was$trivia_c(purple) $answer$trivia_c(off)."
  if {$speedword != ""} {
    putquick "PRIVMSG $trivia_channel :$speedword"
  }

  trivia_bmotion_send "winner" "$nick $answer"
  if {$newuser == 1} {
    putquick "PRIVMSG $trivia_channel :Welcome to our newest player,  $trivia_c(purple)$nick$trivia_c(off) :)"
  }
  putquick "PRIVMSG $trivia_channel :Rankings: [trivia_near_five3 $uid]"

  set leader [trivia_leader]

  if {($leader != $old_leader) && ($leader != -1) && ($old_leader != -1)} {
    putquick "PRIVMSG $trivia_channel :$trivia_c(purple) $nick $trivia_c(off) has taken the lead!"
  }

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

  if {$trivia_score_time <= [clock seconds]} {
    trivia_end_week
  } else {
    if {[expr $trivia_score_time - [clock seconds]] < $trivia_time_left_warning} {
      set diff [expr $trivia_score_time - [clock seconds]]
      set diff $diff.0
      set nearness [expr $diff / $trivia_time_left_warning * 100]
      set chance [rand 100]
      putlog "diff = $diff, nearness = $nearness, chance = $chance"
      if {$chance < $nearness} {
        putserv "PRIVMSG $trivia_channel :[trivia_score_time_left] until the end of this game!"
      }
    }
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
  global trivia_channel trivia_c
  switch $row {
    3 {
      return "is on a winning spree!"
    }
    4 {
      putquick "PRIVMSG $trivia_channel :$trivia_c(realblue)QUAD DAMAGE!"
      return "is on a roll ..."
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

# Escape stuff for SQL
proc trivia_sqlite_escape { text } {
#<<<
  return [string map {' ''} $text]
}
#>>>

# Get someone's user ID from their nick
proc trivia_get_uid { nick } {
#<<<
  global trivia_db_handle

  putloglev 4 * "trivia_get_uid ($nick)"

  set nick [trivia_sqlite_escape $nick]
  set sql "SELECT user_id FROM users WHERE user_name = '$nick'"
  trivia_db_handle eval $sql {
    return $user_id
  }
  return 0
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
  trivia_db_handle eval $sql {
    return $yarr
  }
  return 0
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
  global trivia_db_handle trivia_channel

  putloglev 4 * "trivia_get_userinfo ($user_id)"
  set donestats 0

  set sql "SELECT user_name, user_score, user_last, user_reg FROM users WHERE user_id = '$user_id'"

  trivia_db_handle eval $sql {
    if {$user_last == ""} {
      set last "Unknown"
    } else {
      set last [trivia_ts_to_date $user_last]
    }

    if {$user_reg == ""} {
      set reg "Unkown"
    } else {
      set reg [trivia_ts_to_date $user_reg]
    }

    putserv "PRIVMSG $trivia_channel :Trivia stats for $user_name:"
    putserv "PRIVMSG $trivia_channel :   Current score: $user_score"
    putserv "PRIVMSG $trivia_channel :      First seen: $reg"
    putserv "PRIVMSG $trivia_channel :     Last scored: $last"
    set donestats 1
  }

  set sql "SELECT COUNT(dt) AS score FROM scores WHERE dt > [trivia_get_period] AND user_id = '$user_id'"
  if {$donestats} {
    trivia_db_handle eval $sql {
      putserv "PRIVMSG $trivia_channel :Points this week: $score"
      putserv "PRIVMSG $trivia_channel :  Weekly Ranking: [trivia_get_rank $user_id]"
    }
  } else {
    putserv "PRIVMSG $trivia_channel :No stats found"
  }
}
#>>>

# Get someone's stats from their username
proc trivia_user_stats { user_name } {
#<<<
  global trivia_channel

  set uid [trivia_get_uid $user_name]
  if {$uid == 0} {
    putserv "PRIVMSG $trivia_channel :Unknown user '$user_name' (is the case right?)"
    return
  }

  trivia_get_userinfo $uid
}
#>>>

# Increase a UID's score
proc trivia_incr_score { id { howmuch 1 } } {
#<<<
  global trivia_db_handle

  putloglev 4 * "trivia_incr_score ($id, $howmuch)"

  set sql "UPDATE users SET user_last = [clock seconds], user_points = user_points + 1 WHERE user_id = '$id'"
  trivia_db_handle eval $sql

  set sql "INSERT INTO scores VALUES ('$id', '[clock seconds]')"
  trivia_db_handle eval $sql
}
#>>>

# Create a new user
proc trivia_create_user { nick } {
#<<<
  global trivia_db_handle

  putloglev 4 * "trivia_create_user ($nick)"

  set nick [trivia_sqlite_escape $nick]
  set sql "INSERT INTO users VALUES (null, '$nick', '', 0, [clock seconds], [clock seconds], 0)"
  trivia_db_handle eval $sql

  set uid [trivia_db_handle last_insert_rowid]

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

  if {$param == "countdown"} {
    trivia_countdown
    return 0
  }

  if {![matchattr $handle |$trivia_flag $channel]} {
    putserv "PRIVMSG $nick :use: !trivia \[score|top10|start|report\]"
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
    #puthelp "PRIVMSG $trivia_channel :Score merging is disabled"
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

proc trivia_ping { } {
  return
}

# Enable the script
proc trivia_enable {} {
#<<<
  global trivia_status trivia_channel trivia_db_handle

  set trivia_status 0
  putserv "PRIVMSG $trivia_channel :Trivia enabled."

  trivia_ping

  return 0
}
#>>>

#Make a hint
proc trivia_make_hint { hint answer } {
#<<<
  global trivia_debug_mode

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
  if {$trivia_debug_mode == 1} {
    return $answer
  }

  return $final_hint
}
#>>>

# Fetch a question
proc trivia_get_question { } {
#<<<
  global trivia_db_handle trivia_q_id trivia_q_cat trivia_q_question trivia_q_answer trivia_q_hint trivia_channel

  set trivia_q_id ""

  set sql "SELECT q.question, q.question_id, q.answer, c.cat_name FROM questions q LEFT JOIN categories c USING (cat_id) WHERE c.cat_enabled=1 ORDER BY count ASC, random() LIMIT 1"
  trivia_db_handle eval $sql {
    set trivia_q_id $question_id
    set trivia_q_cat $cat_name
    set trivia_q_question $question
    set trivia_q_answer [string toupper $answer]
    set trivia_q_hint ""

    #tidy up question and answer
    regsub -all "  +" $trivia_q_question " " trivia_q_question
    regsub -all "  +" $trivia_q_answer " " trivia_q_answer

    set trivia_q_question [string trim $trivia_q_question]
    set trivia_q_answer [string trim $trivia_q_answer]
  }

  if {$trivia_q_id == ""} {
    return
  }

  #update the times used
  set sql "UPDATE questions SET count = count + 1 WHERE question_id = '$trivia_q_id'"
  trivia_db_handle eval $sql
}
#>>>

# Start a round
proc trivia_start_round { } {
#<<<
  global trivia_q_id trivia_q_cat trivia_q_question trivia_q_answer trivia_q_hint trivia_q_attempts trivia_channel trivia_status trivia_last_qid
  global trivia_asking_question trivia_delay botnick trivia_q_timestamp

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

  set trivia_asking_question 1

  trivia_bmotion_send "start" "$trivia_channel $trivia_delay $botnick"
  set trivia_q_timestamp [clock seconds]

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
  putlog "hint is $trivia_q_hint"

  #say our stuff
  if {$trivia_q_attempts > 1} {
    set hint " \[[expr $trivia_q_attempts - 1] of 3\]"
  } else {
    set hint ""
  }

  set split_question [trivia_question_split $trivia_q_question]

  putquick "PRIVMSG $trivia_channel :$trivia_c(red)--== Trivia ==--$trivia_c(off) \[category: \002$trivia_q_cat\002\]"
  foreach q $split_question {
    if {$q != ""} {
      putquick "PRIVMSG $trivia_channel :$trivia_c(blue) [trivia_question_inject $q]"
    }
  }
  #set new_question [trivia_question_inject $trivia_q_question]
  #putquick "PRIVMSG $trivia_channel :$trivia_c(blue) $new_question"
  putquick "PRIVMSG $trivia_channel :Hint$hint: [trivia_explode $trivia_q_hint]"

  incr trivia_q_attempts

  trivia_bmotion_send "hint" [string map {_ .} $trivia_q_hint]

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
  global trivia_run_last trivia_run_nick trivia_run_qty trivia_c trivia_score_time trivia_asking_question trivia_time_left_warning

  if {$trivia_status != 1} {
  #we're switched off, abort
    return 0
  }

  set trivia_asking_question 0

  trivia_bmotion_send "winner" "* $trivia_q_answer"
  trivia_bmotion_send "stop" ""

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
    putserv "PRIVMSG $trivia_channel :Four unanswered in a row, stopping the game."
    putserv "PRIVMSG $trivia_channel :You can restart it with $trivia_c(purple)!t start"
    set trivia_status 0
  } else {
    set trivia_timer [utimer $trivia_delay trivia_start_round]
    if {$trivia_score_time <= [clock seconds]} {
      trivia_end_week
    } else {
      if {[expr $trivia_score_time - [clock seconds]] < $trivia_time_left_warning} {
        set diff [expr $trivia_score_time - [clock seconds]]
        set diff $diff.0
        set nearness [expr $diff / $trivia_time_left_warning * 100]
        set chance [rand 100]
        putlog "diff = $diff, nearness = $nearness, chance = $chance"
        if {$chance < $nearness} {
          putserv "PRIVMSG $trivia_channel :[trivia_score_time_left] until the end of this game!"
        }
      }
    }
    trivia_check_rehash
  }
}
#>>>

# Skip the rest of this question
proc trivia_skip { nick } {
#<<<
  global trivia_q_id trivia_q_cat trivia_q_question trivia_q_answer trivia_q_hint trivia_q_attempts trivia_channel trivia_status
  global trivia_timer trivia_delay trivia_db_handle trivia_unanswered trivia_score_time

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

  trivia_bmotion_send "stop" ""

  putserv "PRIVMSG $trivia_channel :Skipping this question by $nick's request."
  set trivia_timer [utimer $trivia_delay trivia_start_round]
  if {$trivia_score_time <= [clock seconds]} {
    trivia_end_week
  }
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

  trivia_ping

  # go go go
  set trivia_status 1
  if {$trivia_must_rehash == 2 } {
    putquick "PRIVMSG $trivia_channel :$trivia_c(blue)### Resuming trivia game ###" -next
  } else {
    putquick  "PRIVMSG $trivia_channel :Trivia game started!" -next
  }

  #trivia_stats

  putquick "PRIVMSG $trivia_channel :[trivia_score_time_left] left until end of this game!"

  #try to find last week's winner
  set sql "SELECT winners.user_id, users.user_name FROM winners LEFT JOIN users USING(user_id) ORDER BY dt DESC, score DESC LIMIT 1"
  putloglev d * $sql
  trivia_db_handle eval $sql {
    putquick "PRIVMSG $trivia_channel :Last week's winner was$trivia_c(purple) [string toupper $user_name]$trivia_c(off)!"
  }

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
    clearqueue server
    putserv "PRIVMSG $trivia_channel :Trivia game stopped."
    set trivia_status 0
    trivia_bmotion_send "stop" ""
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

  set pos 0
  trivia_db_handle eval $sql {
    incr pos
    putloglev d * "considering user_id $user_id, score $d"
    if {$user_id == $uid} {
      return $pos
    }
  }
  return 0
}
#>>>

# Get the top 10 users
proc trivia_get_top10 { } {
#<<<
  global trivia_db_handle

  set dt [trivia_get_period]
  set sql "select users.user_name as u, count(dt) as d from scores left join users using (user_id) where dt > $dt group by scores.user_id order by d desc limit 10"

  set output ""
  set index 0

  trivia_db_handle eval $sql {
    incr index
    append output "\002$index:\002 "
    append output $u
    append output " ("
    append output $d
    append output ")  "
  }

  if {$index == 0} {
    set output "No scores so far, everyone is equal first! \\o/"
  } else {
    set output "The top $index players are... $output"
  }
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
  set sql "select users.user_id as user_id, users.user_name as user_name, count(dt) as user_score from scores left join users using (user_id) where dt > $dt group by scores.user_id order by count(dt) desc"
  putlog $sql

  set result [list]
  trivia_db_handle eval $sql {
    set line [list]
    lappend line $user_id
    lappend line [trivia_question_inject $user_name]
    lappend line $user_score
    putlog "adding line $line"
    lappend result $line
  }

  putlog "results list: $result"

  set position 0
  foreach item $result {
    if {[lindex $item 0] == $uid} {
      putlog "found at position $position"
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

# Third function to get the nearest users to your score
proc trivia_near_five3 { uid } {
  global trivia_db_handle trivia_c

  set sql "DROP TABLE IF EXISTS _score"
  putlog $sql
  trivia_db_handle eval $sql

  set sql "CREATE TEMPORARY TABLE _score (user_id int, user_score int, last_score int)"
  putlog $sql
  trivia_db_handle eval $sql

  set sql "INSERT INTO _score SELECT user_id, COUNT(dt), MAX(dt) AS user_score FROM scores GROUP BY scores.user_id"
  putlog $sql
  trivia_db_handle eval $sql

  set outputlist ""


  # get our score
  set sql "SELECT user_score, last_score FROM _score WHERE user_id = $uid"
  set our_score ""
  set our_last ""
  trivia_db_handle eval $sql {
    set our_score $user_score
    set our_last $last_score
  }

  if {$our_score == ""} {
    return ""
  }

  if {$last_score == ""} {
    return ""
  }

  #find our position
  #don't need to use last_score here because we must've just scored - making use the most recent point for this score
  set sql "SELECT user_id FROM _score WHERE user_score >= $our_score ORDER BY user_score DESC, last_score DESC"
  putlog $sql
  set position 1
  trivia_db_handle eval $sql {
    if {$user_id != $uid} {
      incr position
    } else {
      break
    }
  }

  putlog "our position is $position"


  if {$position == 1} {
    putlog "oh we're first"
    #set output "$trivia_c(purple) $trivia_c(bold)"
    #append output "1st: [trivia_get_username $uid] ($our_score)  $trivia_c(off)$trivia_c(bold)"
    lappend outputlist [list $uid $our_score]
  } else {
  #find some users higher than us
    set sql "SELECT * FROM _score WHERE user_score > $user_score ORDER BY user_score ASC, last_score ASC LIMIT 4"
    putlog $sql

    set prelist [list]

    trivia_db_handle eval $sql {
      set outputlist [concat [list [list $user_id $user_score] ] $outputlist]
      putlog "outputlist is now $outputlist"
    }

    # finally, us
    lappend outputlist [list $uid $our_score]
  }

  putlog "so far, output list is $outputlist"

  # find two people below us
  set sql "SELECT * FROM _score WHERE (user_score < $our_score) OR ((user_score = $our_score) AND (last_score < $our_last)) ORDER BY user_score DESC, last_score DESC LIMIT 5"
  putlog $sql
  set postlist [list]
  trivia_db_handle eval $sql {
    lappend postlist [list $user_id $user_score]
  }

  putlog "postlist is $postlist"

  set pre_size 3
  set post_size 2

  if {$position == 1} {
    putlog "we're in first"
    set pre_size 1
    set post_size 4
  }

  if {$position == 2} {
    putlog "we're in 2nd"
    set pre_size 2
    set post_size 3
  }

  if {[llength $postlist] == 0} {
    putlog "no postlist, using only prelist"
    set pre_size 5
  }

  if {[llength $postlist] == 1} {
    putlog "one postlist, using most prelist"
    set pre_size 4
  }

  if {$pre_size < [llength $outputlist]} {
    putlog "pre_size $pre_size < length of prelist, trimming"
    set startpos [expr [llength $outputlist] - $pre_size]
    set outputlist [lrange $outputlist $startpos end]
  }

  putlog "outputlist length is [llength $outputlist]"

  set post_size [expr 5 - [llength $outputlist]]

  if {$post_size < [llength $postlist]} {
    putlog "post_size calculated as $post_size and is less than list length"
    set postlist [lrange $postlist 0 [expr $post_size - 1]]
  }

  putlog "---"
  putlog "pre: $outputlist"
  putlog "post: $postlist"

  if {$position > 2} {
    set initpos [expr $position - 2]
  } else {
    set initpos 1
  }

  putlog "first position on list is $initpos"

  foreach place $postlist {
    lappend outputlist $place
  }

  set output ""

  foreach place $outputlist {
    set entry ""
    append entry "$initpos"
    append entry [trivia_ordinal $initpos]
    append entry ": "
    append entry [trivia_question_inject [trivia_get_username [lindex $place 0]]]
    append entry " ("
    append entry [lindex $place 1]
    append entry ")"
    incr initpos
    if {[lindex $place 0] == $uid} {
      append output "$trivia_c(purple)$trivia_c(bold) $entry$trivia_c(off)$trivia_c(bold) "
    } else {
      append output " $entry "
    }
  }

  putlog $output
  return $output

}

proc trivia_get_username { uid } {
  global trivia_db_handle

  set sql "SELECT user_name FROM users WHERE user_id = $uid"
  putlog $sql
  return [trivia_db_handle onecolumn $sql]
}


# Get the current leader's UID
proc trivia_leader { } {
  global trivia_db_handle

  set dt [trivia_get_period]
  set sql "SELECT user_id, count(dt) AS user_score FROM scores WHERE dt > $dt GROUP BY user_id ORDER BY COUNT(dt) DESC LIMIT 1"
  set uid -1
  trivia_db_handle eval $sql {
    set uid $user_id
  }

  return $uid
}

# Get some stats from the DB
proc trivia_stats { } {
#<<<
  global trivia_db_handle trivia_channel

  set sql "SELECT COUNT(*) AS total FROM questions LEFT JOIN categories USING (cat_id) WHERE categories.cat_enabled = 1;"
  set stat_total_questions [trivia_db_handle eval $sql]

  set sql "SELECT COUNT(*) AS total FROM categories WHERE cat_enabled = 1"
  set stat_total_cats [trivia_db_handle eval $sql]

  putserv "PRIVMSG $trivia_channel :Using\002 $stat_total_questions\002 questions in\002 $stat_total_cats\002 categories."
}
#>>>

# Merge two users
proc trivia_merge { nick param } {
#<<<
  global trivia_db_handle

  putloglev 4 * "trivia_merge ($nick, $param)"

  if [regexp {^([^ ]+) (.+)$} $param matches nick1 nick2] {
    set olduid [trivia_get_uid [trivia_sqlite_escape $nick1]]
    set newuid [trivia_get_uid [trivia_sqlite_escape $nick2]]

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
    trivia_db_handle eval $sql

    set newscore [trivia_get_score $newuid]
    puthelp "PRIVMSG $nick :$nick2 now has $newscore points."

    set sql "DELETE FROM users WHERE user_id = $olduid"
    trivia_db_handle eval $sql
    puthelp "PRIVMSG $nick :User $nick1 has been deleted."
    return 0
  } else {
    puthelp "PRIVMSG $nick :Use: !trivia merge <olduser> <newuser>"
    puthelp "PRIVMSG $nick :  olduser's score is merged with newuser's and olduser is deleted."
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

  set nick [trivia_sqlite_escape $nick]
  set msg [trivia_sqlite_escape $msg]

  set sql "INSERT INTO reports VALUES (null, [clock seconds], '$nick', '$trivia_last_qid', '$msg', 'N')"
  trivia_db_handle eval $sql
  puthelp "PRIVMSG $trivia_channel :Added a report against question ID$trivia_c(purple) $trivia_last_qid$trivia_c(off) from $trivia_c(purple)$nick$trivia_c(off)."
  set trivia_last_qid 0
}
#>>>

### WATCHDOG STUFF <<<
# Watchdog timer to make sure we're not ruined
proc trivia_watchdog { } {
#<<<
  global trivia_last_ts trivia_watchdog_timer trivia_status trivia_channel trivia_delay trivia_speed

  putloglev d * "trivia watchdog: tick"

  # slow down if we've never asked a question or we're stopped
  if {($trivia_last_ts == 0) || ($trivia_status == 0)} {
    putloglev 1 * "trivia is not running, slowing down watchdog"
    set trivia_watchdog_timer [utimer 45 trivia_watchdog]
    return 0
  }

  set current_ts [clock seconds]
  set difference [expr $current_ts - $trivia_last_ts]

  set trivia_limit [expr $trivia_delay + $trivia_speed + 5]

  putloglev 1 * "trivia watchdog: current: $current_ts, last: $trivia_last_ts, difference: $difference, max: $trivia_limit"

  if {$difference > $trivia_limit} {
    if {$trivia_status == 1} {
      putlog "watchdog: trivia is broken"
      putquick "PRIVMSG $trivia_channel :Oops, I think I'm broken. Attempting to recover..."
      set trivia_status 0
      trivia_start
    }
  }

  set timer_interval [expr $trivia_delay * 2]

  set trivia_watchdog_timer [utimer 10 trivia_watchdog]
  return 0
}
#>>>

# Kill the watchdog timeer
proc trivia_killwatchdog { } {
#<<<
  global trivia_watchdog_timer

  set alltimers [utimers]
  foreach t $alltimers {
    putloglev 1 * "checking timer $t"
    set t_function [lindex $t 1]
    set t_name [lindex $t 2]
    set t_function [string tolower $t_function]
    if {$t_function == "trivia_watchdog"} {
      putloglev d * "killing timer $t_name"
      killutimer $t_name
    }

    if {$t_function == "trivia_score_rot_timer"} {
      putloglev d * "killing timer $t_name"
      killutimer $t_name
    }
  }

  unset trivia_watchdog_timer
}
#>>>

trivia_killwatchdog
set trivia_watchdog_timer [utimer 45 trivia_watchdog]
#>>>

#<<< SCORE ROTATION STUFF

#take this week's scores and figure out this week's winners
proc trivia_score_winners { } {
#<<<
  global trivia_db_handle trivia_channel

  set winners [list]

  set now [clock seconds]

  set updates [list]

  #knock off a week
  set cutoff [expr $now - 604800]

  set sql "SELECT user_id, COUNT(*) AS score FROM scores WHERE dt > $cutoff GROUP BY user_id ORDER BY score DESC LIMIT 5"
  putloglev d * $sql

  trivia_db_handle eval $sql {
    lappend winners [list $user_id $score]
  }

  set winner_name [list]

  foreach winner $winners {
    set sql "SELECT user_name FROM users WHERE user_id = '[trivia_sqlite_escape [lindex $winner 0]]'"
    putloglev d * $sql
    trivia_db_handle eval $sql {
      lappend winner_name [list $user_name [lindex $winner 0] [lindex $winner 1]]
    }
  }

  putlog $winners
  putlog $winner_name

  putserv "PRIVMSG $trivia_channel :This week's winners are:"
  set position 1
  foreach winner $winner_name {
  #smudge woz ere
    putserv "PRIVMSG $trivia_channel :$position[trivia_ordinal $position] place: [lindex $winner 0] with [lindex $winner 2] points"
    set sql "INSERT INTO winners VALUES ([lindex $winner 1], $now, [expr 6 - $position])"
    putloglev d * $sql
    trivia_db_handle eval $sql

    set sql "UPDATE users SET user_score = user_score + [expr 6 - $position]"
    putloglev d * $sql
    trivia_db_handle eval $sql

    incr position
  }

  set sql "DELETE FROM scores"
  putloglev d * $sql
  trivia_db_handle eval $sql
}

#>>>

#get the timestamp for next cutoff
proc trivia_score_get_time { } {
#<<<
  global trivia_score_time

  set trivia_score_time [clock scan "friday 19:00"]
  if {$trivia_score_time < [clock seconds]} {
    set trivia_score_time [clock scan "next friday 19:00"]
  }
  set trivia_score_time [expr $trivia_score_time]
  putloglev d * "setting next score rotation to [clock format $trivia_score_time]"
}
#>>>

#figure out how long is left until the score rotation
proc trivia_score_time_left { } {
#<<<
  global trivia_score_time

  set now [clock seconds]
  if {$now > $trivia_score_time} {
  #erk
    putloglev d * "trivia_score_time_left: oops!"
    putloglev d * "now: $now, time: $trivia_score_time"
    putloglev d * [clock format $now]
    putloglev d * [clock format $trivia_score_time]
    return
  }

  set diff [expr $trivia_score_time - $now]
  putloglev d * "trivia_score_time_left: difference is $diff seconds"

  if {$diff > 60} {
    return [trivia_time_to_words $diff]
  } else {
    return "less than a minute"
  }
}
#>>>

proc trivia_time_to_words { time } {
#<<<
  putloglev 2 * "trivia_time_to_words $time"
  set output ""

  if {$time > 86400} {
    set days [expr $time / 86400]
    append output $days
    append output " day"
    if {$days > 1} {
      append output "s"
    }
    set time [expr $time - [expr $days * 86400]]
    append output " "
  }

  if {$time > 3600} {
    set hours [expr $time / 3600]
    append output $hours
    append output " hour"
    if {$hours > 1} {
      append output "s"
    }
    set time [expr $time - [expr $hours * 3600]]
    append output " "
  }

  if {$time > 60} {
    set mins [expr $time / 60]
    append output $mins
    append output " minute"
    if {$mins > 1} {
      append output "s"
    }
  }

  set output [string trim $output]
  putloglev d * "trivia_time_to_words returing $output"
  return $output
}
#>>>

proc trivia_score_rot_timer { } {
  global trivia_score_time trivia_channel trivia_c trivia_asking_question trivia_warned

  #putloglev 1 * "score_rot tick"
  utimer 10 trivia_score_rot_timer

  if {[clock seconds] > $trivia_score_time} {
  #end of week!

    putlog "trivia: end of week"

    if {$trivia_asking_question == 1} {
      putlog "trivia: game is running"
      if {$trivia_warned == 0} {
        putlog "trivia: need to warn"
        putquick "PRIVMSG $trivia_channel :$trivia_c(red)### BING BONG ###"
        putquick "PRIVMSG $trivia_channel :I've started so I'll finish."
        set trivia_warned 1
      }
      return 0
    } else {
      putlog "trivia: not running game, ending week now"
      trivia_end_week
      return 0
    }
  }
  set trivia_warned 0
}
#>>>

# handle end of week
proc trivia_end_week { } {
#<<<
  global trivia_channel trivia_score_time

  # set next week end
  trivia_score_get_time

  # move scores around
  trivia_score_winners
  #>>>
}

# Announce the time remaining
proc trivia_countdown { } {
#<<<
  global trivia_channel

  putserv "PRIVMSG $trivia_channel :[trivia_score_time_left] left until end of this game."
}
#>>>

trivia_connect
trivia_score_get_time
utimer 10 trivia_score_rot_timer

putlog {TriviaEngine ENGAGED(*$£&($}

if {$trivia_must_rehash == 2} {
  putlog "Auto-restarting trivia..."
  trivia_start
  set trivia_must_rehash 0
}
