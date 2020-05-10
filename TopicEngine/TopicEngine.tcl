#         Script : TopicEngine v1
#                  Copyright 2001-3 James Seward
#                   $Id: TopicEngine.tcl,v 1.11 2003/02/05 23:24:37 jamesoff Exp $
#
#       Testing
#      Platforms : Linux 2.4
#                  Eggdrop v1.6.4-13
#
#    Description : Advanced script to change/set/lock topics
#                  See readme for full info
#
#
# Author Contact :     Email - james@jamesoff.net
#                  Home Page - http://www.jamesoff.net
#                        IRC - Nick: JamesOff (EFNet)
#                        ICQ - 1094325 (mention this script in your auth req, else you'll get ignored :)
#
#      Credit to : Dan Durrans, for coming up with the idea and feature list
#                  #exeter and #ags people for testing it
#
#

###############################################################################
# TopicEngine - a topic management TCL script for eggdrops
# Copyright (C) James Michael Seward 2000-2003
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
###############################################################################

#Don't change this unless you want to RUIN the script and destroy the world :)
set topicEngineLoad 0

# register the topicEngine channel flag
setudef flag topicengine

#
# This is the path to the config file's directory
# If you use a relative path, it starts from the directory your eggdrop runs in
# No trailing slash!
set topicConfigPath "scripts"

catch {
    source "${topicConfigPath}/TopicEngineSettings.tcl"
    if {[info exists botnet-nick]} {
    #load a bot-specific file
        source "${topicConfigPath}/TopicEngineSettings_${botnet-nick}.tcl"
    }
}

#####
# Shouldn't need to change stuff below here (but you can if you need to and know
# what you're doing)
###################################################################################################

set revision "20060108.1"

#init some info
set topicInfo(pop,version) $revision
set backupInfo(pop,version) $revision
set topicChannels [list]

#split tracking
set topicSplitChans [list]
set topicLastSplit [clock seconds]
set topicSplitDirty 0

if {![info exists topicEngineOnline]} {
    set topicEngineOnline 0
}

# init
set loops 0
set bufferDirty 0

#####
# topicInitArray
#
# Builds the topicInfo array with the default values
# Won't rebuild if topicEngineOnline is 1 (to stop it overwriting
# data that's in use
#
proc topicInitArray { {loaded 0} } {
    global topicInfo topicEngineOnline

    set onChannels [channels]
    set hasError 0

    #change the channels list to all lowercase
    set newChannels [list]
    foreach chan $onChannels {
    #check if this channel is +topicengine
        if [channel get $chan topicengine] {
            lappend newChannels [string tolower $chan]
        }
    }
    set topicChannels $newChannels

    foreach chan $topicChannels {
        set test ""
        catch {
            set test $topicInfo($chan,initialised)
        }
        if {$test == ""} {
        #loading for the first time
            putlog "topicengine: init topicInfo for $chan"
            # These are the defaults, you may change them
            # override them with values in TopicEngineSettings.tcl
            # explainations of these settings are also in that file
            set topicInfo($chan,leadIn) ""
            set topicInfo($chan,leadOut) ""
            #set topicInfo($chan,needOChan) 1
            #set topicInfo($chan,needVChan) 0
            #set topicInfo($chan,needOGlobal) 0
            #set topicInfo($chan,needVGlobal) 0
            #set topicInfo($chan,needOMode) 1
            #set topicInfo($chan,needVMode) 0
            #set topicInfo($chan,Tflag) 1
            set topicInfo($chan,canFlags) "o|ov"
            set topicInfo($chan,canModes) "ov"
            set topicInfo($chan,cantFlags) "T"
            set topicInfo($chan,topicBits) [list]
            set topicInfo($chan,learnOnChange) 1
            set topicInfo($chan,initialised) "1"

            #DO NOT CHANGE THESE
            set topicInfo($chan,topic) ""
            set topicInfo($chan,whoSet) [list]
            set topicInfo($chan,whenSet) [list]
            set topicInfo($chan,whenLastSet) 0
            set topicInfo($chan,whoLastSet) 0
            set topicInfo($chan,lock) [list 0 "" ""]
        } else {
            if {$loaded == 0} {
            #sync the topics if we're online
                catch {
                    if {[lsearch $onChannels $chan] >= 0} {
                    #putlog "Updating topic in $chan"
                        setTopic $chan
                    }
                    set blah 0
                } err
                if {$err != 0} {
                    putlog "topicengine: $chan not initialised! (is it new?)"
                    set topicInfo($chan,leadOut) ""
                    #set topicInfo($chan,needOChan) 1
                    #set topicInfo($chan,needVChan) 0
                    #set topicInfo($chan,needOGlobal) 0
                    #set topicInfo($chan,needVGlobal) 0
                    #set topicInfo($chan,needOMode) 1
                    #set topicInfo($chan,needVMode) 0
                    #set topicInfo($chan,Tflag) 1
                    set topicInfo($chan,canFlags) "o|ov"
                    set topicInfo($chan,canModes) "ov"
                    set topicInfo($chan,cantFlags) "T"
                    set topicInfo($chan,topicBits) [list]
                    set topicInfo($chan,learnOnChange) 1
                    set topicInfo($chan,initialised) "1"

                    #DO NOT CHANGE THESE
                    set topicInfo($chan,topic) ""
                    set topicInfo($chan,whoSet) [list]
                    set topicInfo($chan,whenSet) [list]
                    set topicInfo($chan,whenLastSet) 0
                    set topicInfo($chan,whoLastSet) 0
                    set topicInfo($chan,lock) [list 0 "" ""]
                    set hasError 1
                }
            }
        }
    }
    if {($topicEngineOnline == 0) || ($hasError == 1)} {
    # now load the user defaults
    # you should edit this file to give each channel the settings you want
        global topicConfigPath botnet-nick
        catch {
            set topicEngineLoad 1
            source "${topicConfigPath}/TopicEngineSettings.tcl"
            if {[info exists botnet-nick]} {
            #load a bot-specific file
                source "${topicConfigPath}/TopicEngineSettings_${botnet-nick}.tcl"
            }
        }
    }
}

#### You won't need to change anything below this point ###

#####
# checkTopic
#
# Tries out a new topic (=current topic | newbit)
# returns 0 if it'll fit in the network topic length limit
# else returns the number of characters over the limit
# allows for the " | " between topic elements
#
proc checkTopic {channel newbit {noOldTopic 0}} {
    global topicLengthLimit topicInfo topicSeparator

    #append the new bit onto the topic list
    if {$noOldTopic == 0} {
        set thisTopic $topicInfo($channel,topicBits)
    } else {
    #don't count the old topic, so initalise the 'old' one
        set thisTopic [list]
    }

    if {$newbit != ""} { lappend thisTopic $newbit }

    if {$topicInfo($channel,leadIn) != ""} {
        set thisTopic [linsert $thisTopic 0 $topicInfo($channel,leadIn)]
    }

    if {$topicInfo($channel,leadOut) != ""} {
        set thisTopic [linsert $thisTopic end $topicInfo($channel,leadOut)]
    }

    set topicString ""

    foreach bit $thisTopic {
        append topicString $bit
        append topicString " $topicSeparator "
    }

    set topicString [string range $topicString 0 [expr [string length $topicString] - 4 ]]

    set topicLength [string length $topicString]

    if {$topicLength > $topicLengthLimit} { return [expr $topicLength - $topicLengthLimit] }
    return 0
}

#####
# backupTopic {channel}
#
# saves the topic to another array so it can be recovered if needed
#
proc backupTopic { channel } {
    global topicInfo backupInfo

    set backupInfo($channel,topicBits) $topicInfo($channel,topicBits)
    set backupInfo($channel,topic) $topicInfo($channel,topic)
    set backupInfo($channel,whoSet) $topicInfo($channel,whoSet)
    set backupInfo($channel,whenSet) $topicInfo($channel,whenSet)
    set backupInfo($channel,whoLastSet) $topicInfo($channel,whoLastSet)
    set backupInfo($channel,whenLastSet) $topicInfo($channel,whenLastSet)

    return 0
}

#####
# setTopic {channel, force = 0}
#
# sets the topic based on the topicBits list
# will not change the topic if doesn't need it, unless force is 1
#
proc setTopic {channel {force 0}} {
    global topicInfo loops topicSeparator bufferDirty topicEngineOnline

    putloglev d * "topicengine: updating topic for $channel (force = $force)"

    #debug for recursive stuff
    set loops 0

    #if we're not opped, don't even bother
    if {![botisop $channel]} {
        putlog "topicengine: er, I'm not opped in $channel, so I can't set the topic :("
        return 0
    }

    set thisTopic $topicInfo($channel,topicBits)

    ##leadin and leadout
    if {$topicInfo($channel,leadIn) != ""} {
        putloglev 1 * "topicengine: adding prefix"
        set thisTopic [linsert $thisTopic 0 $topicInfo($channel,leadIn)]
    }

    if {$topicInfo($channel,leadOut) != ""} {
        putloglev 1 * "topicengine: adding postfix"
        set thisTopic [linsert $thisTopic end $topicInfo($channel,leadOut)]
    }

    ##build topic string
    set topicString ""

    foreach bit $thisTopic {
        append topicString $bit
        append topicString " $topicSeparator "
    }

    set topicString [string range $topicString 0 [expr [string length $topicString] - 4 ]]

    #interpolate time stuff
    set loops 0
    while {[regexp "_TIME\{(.+?)\}" $topicString matches timeformat]} {
        incr loops
        if {$loops > 10} {
            set line ""
            putlog "topicengine: TREMENDOUS FAILURE! Topic for $channel couldn't be generated."
            return 1
        }
        set timeString [clock format [clock seconds] -format $timeformat]
        regsub -all "_TIME{$timeformat}" $topicString $timeString topicString
    }

    #putlog "topicengine: final topic for $channel is $topicString"

    set topicInfo($channel,topic) $topicString
    if {([topic $channel] == $topicString) && ($force == 0)} { return 0 }
    if {$force == -1} {
    #just update the topic cache
        return 0
    }

    putserv "TOPIC $channel :$topicString"
    set bufferDirty 0
    return 0
}


#####
# topicChanged
#
# called when the topic is changed on a channel
# checks if the topic is locked and changes it back if it needs to
# if topicInfo(channel,learnOnChange) is 1, will parse this topic and learn it
#
proc topicChanged {nick host handle channel text} {
    global topicInfo topicChannels

    #check the topic script is active in here
    if {![channel get $channel topicengine]} {
        return 0
    }

    #this is because the array isn't initialised when the bot first starts
    topicInitArray 1

    #if it's me, drop
    if [isbotnick $nick] { return 0 }

    #if it's the same topic as before, drop
    if {$text == $topicInfo($channel,topic)} { return 0 }

    #if it's an empty topic, redo it and don't learn it
    if {$text == ""} {
        setTopic $channel
        return 0
    }

    #if it's a bot setting the topic, ignore it
    if [matchattr $handle b] { return 0 }

    if {[lindex $topicInfo($channel,lock) 0] == 0} {
    #learn it?
        if {$topicInfo($channel,learnOnChange) == 1} {
            putlog "Topic in $channel changed, learning it"
            #back it up
            backupTopic $channel
            topicParse $channel $text $nick
        }
        return 0
    }

    #it's locked, put it back and notify
    setTopic $channel 1
    set whoLocked [lindex $topicInfo($channel,lock) 1]
    set whenLocked [clock format [lindex $topicInfo($channel,lock) 2]]
    putserv "NOTICE $nick :Sorry, the topic for $channel was locked by $whoLocked on $whenLocked."
    putlog "Bouncing topic in $channel"
    return 0
}

#####
# topicCommand
#
# interact with the user, accepts the !topic... commands
#
proc topicCommand {nick host handle channel text {silent 0} } {
    global topicInfo topicChannels loops bufferDirty
    set doBuffer 0
    #putlog "topic command: $text ($channel)"

    #check the topic script is active in here
    if {![channel get $channel topicengine]} {
        return 0
    }

    #check I'm opped there
    if {![botisop $channel]} {
        topicNotice "I'm not opped in $channel; I can't manage the topic."
        return 0
    }

    #lowercase the channel (for case insensitivity in the array)
    set channel [string tolower $channel]

    set text [string trim $text]

    incr loops
    if {$loops > 5} {
        set loops 0
        putlog "TopicEngine internal error: recursive looping. Aborting processing of this command."
        return 0
    }

    #this is because the array isn't initialised when the bot first starts
    topicInitArray 1

    #these commands can be used by anyone
    ################# INFO
    if [regexp -nocase "^info ?(.+)?" $text boom param] {
        set loops 0
        if {$param == ""} {
            set updateTime [clock format $topicInfo($channel,whenLastSet)]
            if {[lindex $topicInfo($channel,lock) 0] != 0} {
                set whoLocked [lindex $topicInfo($channel,lock) 1]
                set whenLocked [clock format [lindex $topicInfo($channel,lock) 2]]
                set lockedString " ... locked \002\[\002 $whoLocked | $whenLocked \002\]\002"
            } else {
                set lockedString ""
            }

            set undoString " ... undo \002\[\002 no \002\]\002"

            catch {
                global backupInfo
                if {$backupInfo($channel,topicBits) != ""} {
                    set undoString " ... undo \002\[\002 yes \002\]\002"
                }
            }

            if {$bufferDirty == 1} {
                set bufferString " ... buffer \002\[\002 dirty \002\]\002"
            } else {
                set bufferString ""
            }

            global topicInfoBroadcast topicType
            if {$topicInfoBroadcast == 0} {
                topicNotice "$channel: topic \002\[\002 $topicInfo($channel,topic) \002\]\002 ... changed \002\[\002 $topicInfo($channel,whoLastSet) | $updateTime \002\]\002${lockedString}${bufferString}${undoString}"
            } else {
                if {$topicType == "pub"} {
                    putserv "PRIVMSG $channel :$channel: topic \002\[\002 $topicInfo($channel,topic) \002\]\002 ... changed \002\[\002 $topicInfo($channel,whoLastSet) | $updateTime \002\]\002${lockedString}${bufferString}${undoString}"
                } else {
                #msg and dcc
                    topicNotice "$channel: topic \002\[\002 $topicInfo($channel,topic) \002\]\002 ... changed \002\[\002 $topicInfo($channel,whoLastSet) | $updateTime \002\]\002${lockedString}${bufferString}${undoString}"
                }
            }

            return 1
        }

        if {$param == "undo"} {
            set undoString "\002\[\002 unavailable \002\]\002"

            catch {
                global backupInfo topicType
                if {$backupInfo($channel,topicBits) != ""} {
                    set undoString "\002\[\002 $backupInfo($channel,topic) \002\]\002"
                }
            }

            if {$topicType == "pub"} {
                putserv "PRIVMSG $channel :$channel: topic undo $undoString"
            } else {
            #msg and dcc
                topicNotice "$channel: topic undo $undoString"
            }

            return 1
        }

        set elementCount [llength $topicInfo($channel,topicBits)]

        if {$param < 1} {
            topicNotice "Error: topic index too low!"
            return 1
        }

        if {$param > $elementCount} {
            topicNotice "Error: topic index too high!"
            return 1
        }

        set actparam [expr $param - 1]
        set updateTime [clock format [lindex $topicInfo($channel,whenSet) $actparam]]
        global topicInfoBroadcast topicType
        if {$topicInfoBroadcast == 0} {
            topicNotice "$channel: element \002\[\002 $param = [lindex $topicInfo($channel,topicBits) $actparam] \002\]\002 ... set by \002\[\002 [lindex $topicInfo($channel,whoSet) $actparam] | $updateTime \002\]\002"
        } else {
            if {$topicType == "pub"} {
                putserv "PRIVMSG $channel :$channel: element \002\[\002 $param = [lindex $topicInfo($channel,topicBits) $actparam] \002\]\002 ... set by \002\[\002 [lindex $topicInfo($channel,whoSet) $actparam] | $updateTime \002\]\002"
            } else {
            #msg and dcc
                topicNotice "$channel: element \002\[\002 $param = [lindex $topicInfo($channel,topicBits) $actparam] \002\]\002 ... set by \002\[\002 [lindex $topicInfo($channel,whoSet) $actparam] | $updateTime \002\]\002"
            }
        }

        return 1
    }

    ################# HELP
    if [regexp -nocase "^help" $text] {
        global botnick
        topicNotice "Please use \002/msg $botnick topic help\002 for a command list"
        return 1
    }

    ################# VERSION
    if [string match -nocase "version" $text] {
        topicNotice "I am running JamesOff's TopicEngine version $topicInfo(pop,version)."
        return 1
    }

    #these commands need permissions
    set canTopic 0

    #first we need to check global O and V
    #if {($topicInfo($channel,needOGlobal) == 1) && [matchattr $handle o]} { set canTopic 1 }
    #if {($topicInfo($channel,needVGlobal) == 1) && [matchattr $handle v]} { set canTopic 1 }

    #now local O and V
    #if {($topicInfo($channel,needOChan) == 1) && [matchattr $handle -|o $channel]} { set canTopic 1 }
    #if {($topicInfo($channel,needVChan) == 1) && [matchattr $handle -|v $channel]} { set canTopic 1 }

    #now modes in the channel
    #if {($topicInfo($channel,needOMode) == 1) && [isop $nick $channel]} { set canTopic 1 }
    #if {($topicInfo($channel,needVMode) == 1) && [isvoice $nick $channel]} { set canTopic 1 }

    #now finally the T flag... this is different - if you HAVE it you can't set a topic
    #Hack by Artoo; users with T flag can change topic, users with U flag can not
    #if {($topicInfo($channel,Tflag) == 1) && [matchattr $handle T]} { set canTopic 1 }
    #if {($topicInfo($channel,Tflag) == 1) && [matchattr $handle -|U $channel]} { set canTopic 0 }
    #if {($topicInfo($channel,Tflag) == 1) && [matchattr $handle U]} { set canTopic 0 }
    #if {($topicInfo($channel,Tflag) == 1) && [matchattr $handle -|T $channel]} { set canTopic 1 }

    #New system: using channel settings

    # First we check canFlags, if the user has these eggdrop flags we'll allow use
    if [matchattr $handle $topicInfo($channel,canFlags) $channel] {
        putloglev d * "topicEngine: user $handle matches flags"
        set canTopic 1
    }

    # Now check canModes, if the user has one of these modes we'll allow use
    set modesList [split $topicInfo($channel,canModes) {}]
    foreach modeChar $modesList {
        if {($modeChar == "o") && [isop $nick $channel]} {
            putloglev d * "topicEngine: user $nick is an op, allowed"
            set canTopic 1
            break
        }

        if {($modeChar == "v") && [isvoice $nick $channel]} {
            putloglev d * "topicEngine: user $nick is a voice, allowed"
            set canTopic 1
            break
        }

        if {($modeChar == "h") && [ishalfop $nick $channel]} {
            putloglev d * "topicEngine: user $nick is a halfop, allowed"
            set canTopic 1
            break
        }
    }

    # Finally, if a user matches cantFlags, we'll disable the script for them (regardless of
    # any other match so far

    if [matchattr $handle $topicInfo($channel,cantFlags) $channel] {
        putloglev d * "topicEngine: user $handle matches flags, disallowed"
        set canTopic 0
    }

    if {$canTopic == 0} {
        topicNotice "Sorry, you cannot use the !topic commands"
        return 1
    }

    ################# UNDO
    if [regexp -nocase "^undo(.+)?" $text boom params] {
        if {([lindex $topicInfo($channel,lock) 0] != 0) && (![matchattr $handle |n $channel])} {
            set whoLocked [lindex $topicInfo($channel,lock) 1]
            topicNotice "Sorry, the topic has been locked by $whoLocked."
            return 1
        }
        set loops 0

        set params [string trim $params]

        if {([string first "~" $params] == 0) || [string match -nocase "buffer" $params]} {
        #buffer the topic
            set bufferDirty 1
            set doBuffer 1
        }

        global backupInfo

        if {$backupInfo($channel,topicBits) == ""} {
            topicNotice "Sorry, no undo is available for $channel"
            return 2
        }

        set topicInfo($channel,topicBits) $backupInfo($channel,topicBits)
        set topicInfo($channel,whoSet) $backupInfo($channel,whoSet)
        set topicInfo($channel,whenSet) $backupInfo($channel,whenSet)
        set topicInfo($channel,whoLastSet) "$backupInfo($channel,whoLastSet)/undo:$nick"
        set topicInfo($channel,whenLastSet) [clock seconds]

        set backupInfo($channel,topicBits) ""
        set backupInfo($channel,topic) ""

        if {$doBuffer == 0} {
            setTopic $channel
        } else {
            setTopic $channel -1
        }

        return 1
    }

    ################# ADD
    if [regexp -nocase "^add (.+)" $text boom params] {
        if {([lindex $topicInfo($channel,lock) 0] != 0) && (![matchattr $handle |n $channel])} {
            set whoLocked [lindex $topicInfo($channel,lock) 1]
            topicNotice "Sorry, the topic has been locked by $whoLocked."
            return 1
        }
        set loops 0
        if {[string first "@" $params] == 0} {
        #lock the topic
            topicCommand $nick $host $handle $channel "lock"
            set params [string range $params 1 end]
        }
        if {[string first "~" $params] == 0} {
        #buffer the topic
            set bufferDirty 1
            set doBuffer 1
            set params [string range $params 1 end]
        }

        #remove extra spaces
        set params [string trim $params]
        regsub -all "  +" $params " " params

        #check length
        set tooMany [checkTopic $channel $params]
        if {$tooMany} {
            topicNotice "Sorry, adding that to the topic would make it go over the length limit by $tooMany characters. Please try a shorter topic, or the 'append' (<<<) command instead of 'add' (+)"
            return 1
        }

        backupTopic $channel

        lappend topicInfo($channel,topicBits) $params
        lappend topicInfo($channel,whoSet) $nick
        lappend topicInfo($channel,whenSet) [clock seconds]
        set topicInfo($channel,whoLastSet) $nick
        set topicInfo($channel,whenLastSet) [clock seconds]
        if {$doBuffer == 0} {
            setTopic $channel
        } else {
            setTopic $channel -1
        }
        return 1
    }

    ################# APPEND
    if [regexp -nocase "^append (.+)" $text boom params] {
        if {([lindex $topicInfo($channel,lock) 0] != 0) && (![matchattr $handle |n $channel])} {
            set whoLocked [lindex $topicInfo($channel,lock) 1]
            topicNotice "Sorry, the topic has been locked by $whoLocked."
            return 1
        }
        set loops 0
        if {[string first "@" $params] == 0} {
        #lock the topic
            topicCommand $nick $host $handle $channel "lock"
            set params [string range $params 1 end]
        }
        if {[string first "~" $params] == 0} {
        #buffer the topic
            set bufferDirty 1
            set doBuffer 1
            set params [string range $params 1 end]
        }

        #remove extra spaces
        set params [string trim $params]
        regsub -all "  +" $params " " params

        #check length
        set tooMany [checkTopic $channel $params]
        set originalTopicBits $topicInfo($channel,topicBits)
        set originalTopicWho $topicInfo($channel,whoSet)
        set originalTopicWhen $topicInfo($channel,whenSet)
        set count 0
        while {$tooMany} {

        #delete element 1 (return 2 = failed to delete)
            set result [topicCommand $nick $host $handle $channel "del ~1" 1]

            if {$result == 2} {
            #wahey
                topicNotice "Sorry, couldn't fit that in the topic. Please try something shorter"
                set topicInfo($channel,topicBits) $originalTopicBits
                set topicInfo($channel,topicWho) $originalTopicWho
                set topicInfo($channel,topicWhen) $originalTopicWhen
                return 2
            }

            set tooMany [checkTopic $channel $params]
            incr count
            if {$count == 100} {
                puthelp "ALERT: Looping too much in TopicEngine (append)"
                return 0
            }
        }

        backupTopic $channel

        lappend topicInfo($channel,topicBits) $params
        lappend topicInfo($channel,whoSet) $nick
        lappend topicInfo($channel,whenSet) [clock seconds]
        set topicInfo($channel,whoLastSet) $nick
        set topicInfo($channel,whenLastSet) [clock seconds]
        if {$doBuffer == 0} {
            setTopic $channel
        } else {
            setTopic $channel -1
        }
        return 1
    }

    ################# INSERT
    if [regexp -nocase "^insert (.+)" $text boom params] {
        if {([lindex $topicInfo($channel,lock) 0] != 0) && (![matchattr $handle |n $channel])} {
            set whoLocked [lindex $topicInfo($channel,lock) 1]
            topicNotice "Sorry, the topic has been locked by $whoLocked."
            return 1
        }
        set loops 0
        if {[string first "@" $params] == 0} {
        #lock the topic
            topicCommand $nick $host $handle $channel "lock"
            set params [string range $params 1 end]
        }
        if {[string first "~" $params] == 0} {
        #buffer the topic
            set bufferDirty 1
            set doBuffer 1
            set params [string range $params 1 end]
        }

        #remove extra spaces
        set params [string trim $params]
        regsub -all "  +" $params " " params

        #check length
        set tooMany [checkTopic $channel $params]
        set originalTopicBits $topicInfo($channel,topicBits)
        set originalTopicWho $topicInfo($channel,whoSet)
        set originalTopicWhen $topicInfo($channel,whenSet)
        set count 0
        while {$tooMany} {

        #delete last element (return 2 = failed to delete)
            set lastElement [llength $topicInfo($channel,topicBits)]
            set result [topicCommand $nick $host $handle $channel "del ~$lastElement" 1]

            if {$result == 2} {
            #wahey
                topicNotice "Sorry, couldn't fit that in the topic. Please try something shorter"
                set topicInfo($channel,topicBits) $originalTopicBits
                set topicInfo($channel,topicWho) $originalTopicWho
                set topicInfo($channel,topicWhen) $originalTopicWhen
                return 2
            }

            set tooMany [checkTopic $channel $params]
            incr count
            if {$count == 100} {
                puthelp "ALERT: Looping too much in TopicEngine (insert)"
                return 0
            }
        }

        backupTopic $channel

        set topicInfo($channel,topicBits) [linsert $topicInfo($channel,topicBits) 0 $params]
        set topicInfo($channel,whoSet) [linsert $topicInfo($channel,whoSet) 0 $nick]
        set topicInfo($channel,whenSet) [linsert $topicInfo($channel,whenSet) 0 [clock seconds]]
        set topicInfo($channel,whoLastSet) $nick
        set topicInfo($channel,whenLastSet) [clock seconds]
        if {$doBuffer == 0} {
            setTopic $channel
        } else {
            setTopic $channel -1
        }
        return 1
    }

    ################# SET
    if [regexp -nocase "^set (.+)" $text pop cmdString] {
        if {([lindex $topicInfo($channel,lock) 0] != 0) && (![matchattr $handle |n $channel])} {
            set whoLocked [lindex $topicInfo($channel,lock) 1]
            topicNotice "Sorry, the topic has been locked by $whoLocked."
            return 1
        }
        set loops 0
        if [regexp -nocase "^(pre|post)fix (.+)" $cmdString boom which what] {
            set which [string tolower $which]
            if {$what == "none"} { set what "" }

            if {$which == "pre"} {
                set tooMany [checkTopic $channel $what]
                if {$tooMany} {
                    topicNotice "Sorry, adding that to the topic would make it go over the length limit by $tooMany characters. Please try a shorter topic."
                    return 1
                }
                set topicInfo($channel,leadIn) $what
                setTopic $channel
                return 1
            }

            if {$which == "post"} {
                set tooMany [checkTopic $channel $what]
                if {$tooMany} {
                    topicNotice "Sorry, adding that to the topic would make it go over the length limit by $tooMany characters. Please try a shorter topic."
                    return 1
                }
                set topicInfo($channel,leadOut) $what
                setTopic $channel
                return 1
            }
        }

        #else set the topic as is
        if {$cmdString == "none"} {
            set cmdString ""
        }

        if {[string first "@" $cmdString] == 0} {
        #lock the topic
            topicCommand $nick $host $handle $channel "lock"
            set cmdString [string range $cmdString 1 end]
        }

        if {[string first "~" $cmdString] == 0} {
        #buffer the topic
            set bufferDirty 1
            set doBuffer 1
            set cmdString [string range $cmdString 1 end]
        }


        set tooMany [checkTopic $channel $cmdString 1]
        if {$tooMany} {
            topicNotice "Sorry, adding that to the topic would make it go over the length limit by $tooMany characters. Please try a shorter topic."
            return 1
        }

        #remove extra spaces
        set cmdString [string trim $cmdString]
        regsub -all "  +" $cmdString " " cmdString

        backupTopic $channel

        set topicInfo($channel,whoSet) [list $nick]
        set topicInfo($channel,whenSet) [list [clock seconds]]
        set topicInfo($channel,whoLastSet) $nick
        set topicInfo($channel,whenLastSet) [clock seconds]
        set topicInfo($channel,topicBits) [list $cmdString]
        if {$doBuffer == 0} {
            setTopic $channel
        } else {
            setTopic $channel -1
        }
        return 1
    }

    ################# DEL
    if [regexp -nocase "^del (.+)" $text boom param] {
        if {([lindex $topicInfo($channel,lock) 0] != 0) && (![matchattr $handle |n $channel])} {
            set whoLocked [lindex $topicInfo($channel,lock) 1]
            topicNotice "Sorry, the topic has been locked by $whoLocked."
            return 1
        }
        set loops 0

        #update the cached version
        setTopic $channel -1

        if {[string first "~" $param] == 0} {
        #buffer the topic
            set bufferDirty 1
            set doBuffer 1
            set param [string range $param 1 end]
        }

        set elementCount [llength $topicInfo($channel,topicBits)]

        if {$param < 1} {
            if {$silent == 0} {
                topicNotice "Error: topic index too low!"
            }
            return 1
        }

        if {$param > $elementCount} {
            if {$silent == 0} {
                topicNotice "Error: topic index too high!"
            }
            return 2
        }

        backupTopic $channel

        set param [expr $param - 1]
        set topicInfo($channel,topicBits) [lreplace $topicInfo($channel,topicBits) $param $param]
        set topicInfo($channel,whoSet) [lreplace $topicInfo($channel,whoSet) $param $param]
        set topicInfo($channel,whenSet) [lreplace $topicInfo($channel,whenSet) $param $param]
        set topicInfo($channel,whoLastSet) $nick
        set topicInfo($channel,whenLastSet) [clock seconds]
        if {$doBuffer == 0} {
            setTopic $channel
        } else {
            setTopic $channel -1
        }
        return 1
    }

    ################# REGEXP
    if [regexp -nocase {^regexp ([^ ]+) (.+)} $text matches param re] {
        if {([lindex $topicInfo($channel,lock) 0] != 0) && (![matchattr $handle |n $channel])} {
            set whoLocked [lindex $topicInfo($channel,lock) 1]
            topicNotice "Sorry, the topic has been locked by $whoLocked."
            return 1
        }
        set loops 0

        #update the cached version
        setTopic $channel -1

        if {[string first "~" $re] == 0} {
        #buffer the topic
            set bufferDirty 1
            set doBuffer 1
            set param [string range $param 1 end]
        }

        set elementCount [llength $topicInfo($channel,topicBits)]

        if {$param < 1} {
            if {$silent == 0} {
                topicNotice "Error: topic index too low!"
            }
            return 1
        }

        if {$param > $elementCount} {
            if {$silent == 0} {
                topicNotice "Error: topic index too high!"
            }
            return 2
        }

        if {![regexp {/(.+)/([^/]+)?/(.+)?} $re matches refirst resecond reopts]} {
            topicNotice "Error: not a valid regexp. Use \002/match/replace/options\002."
            return 2
        }

        set param [expr $param - 1]
        set topicElement [lindex $topicInfo($channel,topicBits) $param]

        set options ""
        if [string match "*i*" $reopts] {
            set options "-nocase"
        }
        if [string match "*g*" $reopts] {
            append options "-all"
        }

        if {$options != ""} {
            regsub $options $refirst $topicElement $resecond topicElement
        } else {
            regsub $refirst $topicElement $resecond topicElement
        }

        set oldTopic $topicInfo($channel,topicBits)
        set limit [checkTopic $channel ""]
        if {$limit > 0} {
            topicNotice "Sorry, that would make the topic go over the limit by $limit characters."
            set topicInfo($channel,topicBits) $oldTopic
            return 2
        }

        backupTopic $channel

        set topicInfo($channel,topicBits) [lreplace $topicInfo($channel,topicBits) $param $param $topicElement]
        set topicInfo($channel,whoSet) [lreplace $topicInfo($channel,whoSet) $param $param "$nick/regexp"]
        set topicInfo($channel,whenSet) [lreplace $topicInfo($channel,whenSet) $param $param [clock seconds]]
        set topicInfo($channel,whoLastSet) $nick
        set topicInfo($channel,whenLastSet) [clock seconds]
        if {$doBuffer == 0} {
            setTopic $channel
        } else {
            setTopic $channel -1
        }
        return 1
    }



    ################# REHASH
    if [regexp -nocase "^(rehash|redo)( force)?" $text pop whee force] {
        set mustRedo 0
        if [string match -nocase " force" $force] {
            set mustRedo 1
        }
        setTopic $channel $mustRedo
        return 1
    }

    ################# RESET/CLEAR
    if [regexp -nocase "^(clear|reset)( (content|all))?" $text pop blblbl whee opt] {
        if {([lindex $topicInfo($channel,lock) 0] != 0) && (![matchattr $handle |n $channel])} {
            set whoLocked [lindex $topicInfo($channel,lock) 1]
            topicNotice "Sorry, the topic has been locked by $whoLocked."
            return 1
        }
        set loops 0
        if {$opt == "all"} {
            set topicInfo($channel,leadIn) ""
            set topicInfo($channel,leadOut) ""
            set topicInfo($channel,topicBits) [list]
            set topicInfo($channel,whoSet) [list]
            set topicInfo($channel,whenSet) [list]
            setTopic $channel
            set topicInfo($channel,whoLastSet) $nick
            set topicInfo($channel,whenLastSet) [clock seconds]
            return 1
        }

        if {$opt == "content"} {
            set topicInfo($channel,topicBits) [list]
            set topicInfo($channel,whoSet) [list]
            set topicInfo($channel,whenSet) [list]
            setTopic $channel
            set topicInfo($channel,whoLastSet) $nick
            set topicInfo($channel,whenLastSet) [clock seconds]
            return 1
        }

        set topicInfo($channel,topic) ""
        if { [topic $channel] != ""} {
            putserv "TOPIC $channel :"
        }

        return 1
    }

    ################# LOCK
    if [string match -nocase "lock" $text] {
        if {![matchattr $handle |n $channel]} {
            topicNotice "Sorry, you cannot lock the topic."
            return 1
        }
        set loops 0
        if {[lindex $topicInfo($channel,lock) 0] == 1} {
            topicNotice "The topic is already locked."
            return 1
        }

        set topicInfo($channel,lock) [list 1 $nick [clock seconds]]
        topicNotice "Locking topic for $channel."
        #check the topic is the cached one
        if {$topicInfo($channel,topic) != [topic $channel]} {
            setTopic $channel
        }
        # get any other bots that are locking this channel to unlock it
        putallbots "topicengine unlock $channel"
        return 1
    }

    ################# UNLOCK
    if [string match -nocase "unlock" $text] {
        if {![matchattr $handle |n $channel]} {
            topicNotice "Sorry, you cannot unlock the topic."
            return 1
        }
        set loops 0
        if {[lindex $topicInfo($channel,lock) 0] == 0} {
            topicNotice "The topic is already unlocked."
            return 1
        }

        set topicInfo($channel,lock) [list 0 "" ""]
        topicNotice "Unlocking topic in $channel."
        return 1
    }

    ################# shortcuts
    if [regexp -nocase "^>>>(.+)" $text pop extra] {
    #append
        topicCommand $nick $host $handle $channel "insert $extra"
        return 1
    }
    if [regexp -nocase "^<<<(.+)" $text pop extra] {
    #append
        topicCommand $nick $host $handle $channel "append $extra"
        return 1
    }
    if [regexp -nocase "^\\\+(.+)" $text pop actual] {
    #add
        topicCommand $nick $host $handle $channel "add $actual"
        return 1
    }
    if [regexp -nocase "^\\\-(.+)" $text pop actual] {
    #del
        topicCommand $nick $host $handle $channel "del $actual"
        return 1
    }
    if [regexp -nocase "^\\\=(.+)" $text pop actual] {
    #set
        topicCommand $nick $host $handle $channel "set $actual"
        return 1
    }
    if [regexp -nocase "^\\\?(.+)?" $text pop actual] {
    #info
        topicCommand $nick $host $handle $channel "info $actual"
        return 1
    }
    if [regexp -nocase "^#(!)?" $text pop extra] {
    #rehash
        if {$extra == "!"} { set extra "force" }
        topicCommand $nick $host $handle $channel "rehash $extra"
        return 1
    }
    if [regexp -nocase {^/([0-9]+)(.+)} $text matches index exp] {
    #regexp
        topicCommand $nick $host $handle $channel "regexp $index $exp"
        return 1
    }


    ##If we got here, they used the command wrong
    # assume they meant set, and tell them how to get help

    ##Just double-check it's not that they left off all the text entirely, in which case we'll tell them the topic, and how to get help.
    if {$text == ""} {
        topicCommand $nick $host $handle $channel "info"
        global botnick
        topicNotice "\[FYI\] For help on the !topic commands, please do \002/msg $botnick topic help\002."
        return 1
    }

    #topicCommand $nick $host $handle $channel "set $text"

    global botnick
    topicNotice "\[FYI\] Incorrect use of !topic command. You probably meant !topic set <topic>. Do \002/msg $botnick topic help\002 for more information."
    return 0
}

#####
# topicHelp
#
# respond to /msg botnick topic help ... requests
#
proc topicHelp {nick host handle arg} {
    if [regexp -nocase "^help( .+)?" $arg boom helpon] {
        global botnick topicInfo

        set helpon [string tolower $helpon]
        if {$helpon == ""} {
        #command list
            puthelp "PRIVMSG $nick :\002TopicEngine Script v$topicInfo(pop,version)\002 by JamesOff (james@jamesoff.net) http://www.jamesoff.net/go/topicengine";
            puthelp "PRIVMSG $nick :\037Commands available\037: (all from channel as !topic ..., or in query as /msg $botnick topic ..., or on partyline as .topic ..."
            puthelp "PRIVMSG $nick :Use \037/msg $botnick topic help <command>\037 for more info)";
            puthelp "PRIVMSG $nick :  info    set     add"
            puthelp "PRIVMSG $nick :  del     rehash  clear"
            puthelp "PRIVMSG $nick :  lock    unlock  append"
            puthelp "PRIVMSG $nick :  insert  undo    regexp"
            return 0
        }

        set helpon [string range $helpon 1 [string length $helpon]]

        if {$helpon == "info"} {
            puthelp "PRIVMSG $nick :\002!topic info\002"
            puthelp "PRIVMSG $nick :  This gives you summary information about what the topic is, and when it was last changed by whom"
            puthelp "PRIVMSG $nick :\002!topic info <n>\002"
            puthelp "PRIVMSG $nick :  This tells you about component n of the topic. The first component is 1. Be careful, the pre- and postfixes are not included in this."
            puthelp "PRIVMSG $nick :\002!topic info undo\002"
            puthelp "PRIVMSG $nick :  This tells you the status of the undo buffer for the channel. (See !topic undo)"
            puthelp "PRIVMSG $nick :\002!topic ?\002 and \002!topic ?<n>\002 are shortcuts for this command"
            return 0
        }

        if {$helpon == "set"} {
            puthelp "PRIVMSG $nick :\002!topic set <string>"
            puthelp "PRIVMSG $nick :  This will remove all components of the topic (except the pre- and postfixes) and replace them with your string."
            puthelp "PRIVMSG $nick :  <string> can also be 'none' to clear the topic"
            puthelp "PRIVMSG $nick :\002!topic set prefix|postfix <string>"
            puthelp "PRIVMSG $nick :  This sets the prefix or the postfix to the string you give"
            puthelp "PRIVMSG $nick :  Use 'none' to clear them"
            puthelp "PRIVMSG $nick :\002!topic =<string>\002 and \002!topic =prefix|postfix <string>\002 are shortcuts for this command"
            puthelp "PRIVMSG $nick :You can prefix <string> with @ to make the bot lock the topic at the same time. (Not for pre/postfix)"
            return 0
        }

        if {$helpon == "add"} {
            puthelp "PRIVMSG $nick :\002!topic add <string>"
            puthelp "PRIVMSG $nick :  Adds your string to the topic. Will fail if your string would make the topic go over the topic length limit."
            puthelp "PRIVMSG $nick :\002!topic +<string>\002 is a shortcut for this command"
            puthelp "PRIVMSG $nick :You can prefix <string> with @ to make the bot lock the topic at the same time."
            return 0
        }

        if {$helpon == "append"} {
            puthelp "PRIVMSG $nick :\002!topic append <string>"
            puthelp "PRIVMSG $nick :  Adds your string to the topic. Will automatically drop elements from the start of the topic to try to fit your text in."
            puthelp "PRIVMSG $nick :\002!topic <<<<string>\002 is a shortcut for this command (e.g. !topic <<<hello)."
            puthelp "PRIVMSG $nick :You can prefix <string> with @ to make the bot lock the topic at the same time."
            return 0
        }

        if {$helpon == "append"} {
            puthelp "PRIVMSG $nick :\002!topic insert <string>"
            puthelp "PRIVMSG $nick :  Adds your string to the front of the topic. Will automatically drop elements from the end of the topic to try to fit your text in."
            puthelp "PRIVMSG $nick :\002!topic >>><string>\002 is a shortcut for this command (e.g. !topic >>>hello)."
            puthelp "PRIVMSG $nick :You can prefix <string> with @ to make the bot lock the topic at the same time."
            return 0
        }

        if {$helpon == "regexp"} {
            puthelp "PRIVMSG $nick :\002!topic regexp <index> <regular expression>"
            puthelp "PRIVMSG $nick :  Uses a regexp replace on the topic element at <index>."
            puthelp "PRIVMSG $nick :  The correct form for the regexp is: /match/replace/options"
            puthelp "PRIVMSG $nick :  Options is nothing, or a combination of \002i\002 for case-insensitive matching, and \002g\002 for global matching (match all occurances in string)."
            puthelp "PRIVMSG $nick :\002!topic /<index>/<regexp>/\002 is a shortcut for this command (e.g. !topic /2/hello/goodbye/)."
            puthelp "PRIVMSG $nick :Collected terms can be used in the replacement with \\1, \\2, etc (if you don't understand, this command may not be for you :) See \002man regexp\002 for more information."
            return 0
        }

        if {$helpon == "del"} {
            puthelp "PRIVMSG $nick :\002!topic del <n>"
            puthelp "PRIVMSG $nick :  Deletes topic component n from the topic, first is 1. You cannot use this on the pre- or postfixes (see \037!topic set\037 for info)"
            puthelp "PRIVMSG $nick :\002!topic -<n>\002 is a shortcut for this command"
            return 0
        }

        if {$helpon == "rehash"} {
            puthelp "PRIVMSG $nick :\002!topic rehash\002"
            puthelp "PRIVMSG $nick :  Forces the bot to reset the topic to what it thinks it should be. Will do nothing if the actual topic matches"
            puthelp "PRIVMSG $nick :  what the bot thinks it should be."
            puthelp "PRIVMSG $nick :\002!topic rehash force\002"
            puthelp "PRIVMSG $nick :  Forces the bot to reset to the topic, whether it thinks it should or not."
            puthelp "PRIVMSG $nick :  Note: redo is a synonym for rehash"
            return 0
        }

        if {$helpon == "clear"} {
            puthelp "PRIVMSG $nick :\002!topic clear\002"
            puthelp "PRIVMSG $nick :  Sets the channel topic to nothing, but keeps the settings in the bot. Use \037!topic rehash\037 to get it back."
            puthelp "PRIVMSG $nick :\002!topic clear content"
            puthelp "PRIVMSG $nick :  Sets the content of the topic (not the pre- or postfix) to nothing"
            puthelp "PRIVMSG $nick :\002!topic clear all"
            puthelp "PRIVMSG $nick :  Sets all of the topic, include the pre- and postfixes, to nothing"
            puthelp "PRIVMSG $nick :Note: reset is a synonym for clear"
            return 0
        }

        if {$helpon == "lock"} {
            puthelp "PRIVMSG $nick :\002!topic lock\002"
            puthelp "PRIVMSG $nick :  Locks the topic. The topic can still be changed using the !topic commands, but if anyone"
            puthelp "PRIVMSG $nick :  changes the topic manually (/topic) the bot will set it back. See also \037!topic unlock\037"
            puthelp "PRIVMSG $nick :You can prefix a topic with @ when using !topic set or !topic add to make the bot lock the topic at the same time."
        }

        if {$helpon == "unlock"} {
            puthelp "PRIVMSG $nick :\002!topic unlock\002"
            puthelp "PRIVMSG $nick :  Unlocks the topic after it has been locked with \037!topic lock\037"
            return 0
        }

        if {$helpon == "undo"} {
            puthelp "PRIVMSG $nick :\002!topic undo\002"
            puthelp "PRIVMSG $nick :  Restores the topic to its state before the last command. Currently only one level of undo is supported. Use \002!topic info undo\002 to see what the undo topic will be."
            return 0
        }

    }
}


#####
# topicUnsplit
#
# called on a net-rejoin
# forces the topic to be set to what it should be, in case some servers around the network have lost it
#
proc topicUnsplit {nick host handle channel} {
    global topicInfo topicChannels topicLastSplit topicSplitChans topicSplitDirty

    #check the topic script is active in here
    if {![channel get $channel topicengine]} {
        return 0
    }

    set topicSplitDirty 1

    set topicLastSplit [clock seconds]
    lappend $topicSplitChans $channel
    set topicSplitChans [lsort -unique $topicSplitChans]

    putloglev d * "topicengine: last split time updated to $topicLastSplit ([clock format $topicLastSplit])"
    putloglev d * "topicengine: dirty chans due to split: $topicSplitChans"

    return 0
}

#####
# topicJoin
#
# (a misnomer) called when the bot is opped
# similar to the rejoin one above, checks the topic and resets it if needs to be
# if opped by a server, assume we've come back from a split, force the reset
#
proc topicJoin {nick host handle channel mode victim} {
    global topicInfo topicChannels

    #only do this if I've joined a channel
    if [isbotnick $victim] {

    #check the topic script is active in here
        if {![channel get $channel topicengine]} {
            return 0
        }

        #check i got opped
        if {$mode != "+o"} { return 0 }
        #first check i haven't reset the topic in here myself in the last 120 seconds (stop multiple rejoins fucking up)
        set thirtySecAgo [expr [clock seconds] - 120]
        if {($thirtySecAgo <= $topicInfo($channel,whenSet)) && ($topicInfo($channel,whoSet) == "me")} { return 0 }
        putlog "Opped in $channel, auto-setting topic"
        #if it's a server-mode change, assume we just got un-netsplitted, force the topic
        if {$nick == ""} {
            setTopic $channel 1
        } else {
            setTopic $channel
        }
        set topicInfo($channel,whoLastSet) "me"
        set topicInfo($channel,whenLastSet) [clock seconds]
    }
    return 0
}

#####
# topicParse
#
# turns a string into a new set of topicBits
# used when learning a topic
#
proc topicParse {channel topic nick} {
    global topicInfo topicSeparator

    #if we don't have a |, it's one topic
    if {[string first $topicSeparator $topic] == -1} {
        set topicInfo($channel,topicBits) [list $topic]
        putlog "Learned new topic $topic in $channel ... updating to check it has pre/postfixes for this channel"
        set topicInfo($channel,whoSet) [list $nick]
        set topicInfo($channel,whenSet) [list [clock seconds]]
        set topicInfo($channel,whoLastSet) $nick
        set topicInfo($channel,whenLastSet) [clock seconds]
        set topicInfo($channel,topic) $topic
        set willFit [checkTopic $channel ""]
        if {$willFit > 0} {
            putlog "Oops, I can't fit the new topic in with my pre/postfixes, not setting"
            return 0
        }
        setTopic $channel 0
        return 0
    }

    #it's a multipart topic
    set topic "${topic}${topicSeparator}"
    set blah 0
    set loopCount 0
    set topicInfo($channel,topic) $topic

    while {[string match "*$topicSeparator*" $topic]} {
        set sentence [string range $topic 0 [expr [string first $topicSeparator $topic] -1]]
        if {$sentence != ""} {
            if {$blah == 0} {
                set topicInfo($channel,topicBits) [list [string trim $sentence]]
                set topicInfo($channel,whoSet) [list $nick]
                set topicInfo($channel,whenSet) [list [clock seconds]]
                set blah 1
            } else {
                lappend topicInfo($channel,topicBits) [string trim $sentence]
                lappend topicInfo($channel,whoSet) $nick
                lappend topicInfo($channel,whenSet) [clock seconds]
            }
        }
        set topic [string range $topic [expr [string first $topicSeparator $topic] +1] end]
        incr loopCount
        if {$loopCount > 10} {
            putlog "Couldn't get all of the topic"
            return 0
        }
    }
    if {[lindex $topicInfo($channel,topicBits) 0] == $topicInfo($channel,leadIn)} {
    #the prefix is already on this topic, drop it
        putlog "Prefix on this topic is the same as the one I have on record, dropping it"
        set topicInfo($channel,topicBits) [lreplace $topicInfo($channel,topicBits) 0 0]
        set topicInfo($channel,whoSet) [lreplace $topicInfo($channel,whoSet) 0 0]
        set topicInfo($channel,whenSet) [lreplace $topicInfo($channel,whenSet) 0 0]
        incr loopCount -1
    }

    set lastElement [expr $loopCount - 1]
    if {[lindex $topicInfo($channel,topicBits) $lastElement] == $topicInfo($channel,leadOut)} {
    #the prefix is already on this topic, drop it
        putlog "Postfix on this topic is the same as the one I have on record, dropping it"
        set topicInfo($channel,topicBits) [lreplace $topicInfo($channel,topicBits) $lastElement $lastElement]
        set topicInfo($channel,whoSet) [lreplace $topicInfo($channel,whoSet) $lastElement $lastElement]
        set topicInfo($channel,whenSet) [lreplace $topicInfo($channel,whenSet) $lastElement $lastElement]
    }

    set topicInfo($channel,whoLastSet) $nick
    set topicInfo($channel,whenLastSet) [clock seconds]
    putlog "Learned topic with $loopCount elements in $channel ... updating to check it has pre/postfixes for this channel"
    set willFit [checkTopic $channel ""]
    if {$willFit > 0} {
        putlog "Oops, I can't fit the new topic in with my pre/postfixes, not setting"
        return 0
    }
    setTopic $channel 0
    return 0
}

#####
# topicBotCommand
#
# handle a 'topicengine' command from another bot
#
proc topicBotCommand {fromBot cmd arg} {
    global topicInfo
    if {$cmd == "unlock"} {
    #need to unlock a channel
        if {[lindex $topicInfo($channel,lock) 0] == 1} {
            set topicInfo($arg,lock) [list 0 "" ""]
            putlog "Unlocked topic in $arg at request of $fromBot"
            putbot $fromBot "unlockok $arg"
        }
        return 0
    }

    if {$cmd == "unlockok"} {
    #bot unlocked channel ok
        putlog "$fromBot unlocked channel in $arg for me"
        return 0
    }
}


#####
# topicUpdate
#
# update the topic automagically at 00:01 every day
#
proc topicUpdate { min hour day month year } {
    global topicChannels
    putlog "topicEngine: auto-refreshing topics..."

    foreach chan $topicChannels {
        setTopic $chan
    }

    return 0
}

#####
# topicNotice
#
# Puts text back to the current executing user (puthelp or putidx as needed)
#
proc topicNotice { text } {
    global topicType topicParameter

    #putlog "topicNotice: $text ($topicType = $topicParameter)"

    if {$topicType == ""} {
        putlog "topicengine: CRITIAL ALERT: couldn't work out where to send $text"
        return 1
    }

    if {$topicParameter == ""} {
        putlog "topicengine: CRITICAL ALERT: couldn't work out to whom I should send $text"
        return 1
    }

    if {$topicType == "dcc"} {
        putidx $topicParameter $text
    } else {
        puthelp "NOTICE $topicParameter :$text"
    }
}

#####
# topicCommandPub
#
# Wrapper for topicCommand from !topic in a channel
#
proc topicCommandPub {nick host handle channel text } {
    global topicType topicParameter

    set topicType "pub"
    set topicParameter $nick

    set result [topicCommand $nick $host $handle $channel $text]

    set topicType ""
    set topicParameter ""

    return $result
}

#####
# topicCommandMsg
#
# Wrapper for topicCommand from topic in a msg
#
proc topicCommandMsg {nick host handle text} {
    global topicType topicParameter botnick

    if [string match -nocase "help*" $text] {
        topicHelp $nick $host $handle $text
        return 0
    }

    if [regexp -nocase {(#[^ ]+) (.+)} $text matches channel text2] {

        set topicType "msg"
        set topicParameter $nick

        set result [topicCommand "${nick}/msg" $host $handle $channel $text2]

        set topicType ""
        set topicParameter ""
        return $result
    } else {
        puthelp "NOTICE $nick :use: /msg $botnick topic #channel ..."
    }
}

#####
# topicCommandDCC
#
# Wrapper for topicCommand from .topic in DCC
#
proc topicCommandDCC {handle idx args} {
    global topicType topicParameter

    if [regexp -nocase "(#.+) (.+)\}" $args matches channel text] {

        set topicType "dcc"
        set topicParameter $idx

        #putlog "calling topicCommand $channel $text"

        set result [topicCommand "${handle}/dcc" "" $handle $channel $text]

        set topicType ""
        set topicParameter ""
        return $result
    } else {
        putidx $idx "use: .topic #channel ..."
    }
}

#####
# topicSplitCheck
# handle splits intelligently
#
proc topicSplitCheck {hr min day month year} {
    global topicLastSplit topicSplitChans topicSplitDirty

    if {$topicSplitDirty == 0} {
        return
    }

    set splitDiff [expr [clock seconds] - $topicLastSplit]
    putloglev 1 * "topicengine: checking for splits: diff between now and last split is $splitDiff sec"

    if {$splitDiff > 120} {
    # redo topic in every chan
    #don't do this is the setting is off
        putlog "topicengine: re-setting topics for channels involved in splits..."
        global topicAnnounceReset
        foreach channel $topicSplitChans {
            if {$topicAnnounceReset == 1} {
                puthelp "PRIVMSG $channel :Don't mind me, just resetting the topic in case a netsplit lost it :)"
            }
            setTopic $channel 1
        }
        set topicSplitChans [list]
        set topicSplitDirty 0
    }
}

#####
# Start up stuff
#
# Initialise the variables at start
topicInitArray
#
# set up the binds
bind pub - !topic topicCommandPub
bind dcc - topic topicCommandDCC
bind topc - * topicChanged
bind msg - topic topicCommandMsg
#try to detect a net-unsplit and check the topic
bind rejn - * topicUnsplit
#set the topic to the cached one when I get opped
bind mode - * topicJoin
#auto unlock a channel if another bot locks it
bind bot - "topicengine" topicBotCommand
# update (change or comment out as needed) (syntax: min hour day month year)
bind time - "01 00 * * *" topicUpdate

#check for topics needing resettings after a split
bind time - "* * * * *" topicSplitCheck
#
# log our existence
putlog "TopicEngine v$topicInfo(pop,version) online.";
# set the loaded variable so we don't overwrite topics on a .rehash
set topicEngineOnline 1

# done :)
