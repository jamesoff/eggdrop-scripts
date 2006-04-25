## TopicEngine settings file

#####
# Settings you can change
#
# Channels the script applies to:
#set topicChannels [list "#molsoft" "#ags" "#exeter"]

#
# Maximum topic length for the network
#
# 80 is the safest setting for IRCNet, 120 and 160 are common (watch out for
#   truncation though)
# 120 is typical on EFNet
set topicLengthLimit 120

#
# Announce a topic being reset after a split? (0/1)
set topicAnnounceReset 1

#
# This is the char (or several chars) that separate a topic. A space will go each side of this string.
set topicSeparator "|"

#
# Respond to "!topic info" in the chan or in notice (just to the user to did it)
# 1 = channel, 0 = notice
set topicInfoBroadcast 1

#DO NOT REMOVE THIS LINE:
if {$topicEngineLoad == 1} {
# HOW TO USE:
# (please also read the readme file)
#
# set values for channels in here, like this:
#
# set topicInfo(#channel,setting) <value>
#
# setting               value(s)                              Default
# -------               --------                              -------
#
# leadIn                Default prefix for topic              (blank)
# leadOut               Default postfix                       (blank)
# NO! needOChan             1 = user needs |+o to use             1
# needVChan             1 = user needs |+v to use             1
# needOGlobal           1 = user needs +o to use              0
# needVGlobal           1 = user needs +v to use              0
# needOMode             1 = user must be @ in chan            0
# needVMode             1 = user must be + in chan            0
# Tflag                 1 = any +T user can use (and U can't) 1
# topicBits             [list "topicBit1" "topicBit2" ...]    (empty list)
# learnOnChange         1 = learn topic on change (and join)  1
#
# Do not set other settings in the topicInfo array.
#
# e.g to set the default topic for #lamest to be "www.lamest.net | pop | frogs"
# where the URL is a prefix, do this:
#
# set topicInfo(#lamest,leadIn) "www.lamest.net"
# set topicInfo(#lamest,topicBits) [list "pop" "frogs"]
#

#set topicInfo(#startrek,needVChan) 1
set topicInfo(#startrek,leadIn) "http://utopia.planitia.net"

set topicInfo(#startrek,canFlags) "o|o"

#set topicInfo(#namcoarcade,needVChan) 0
#set topicInfo(#exeter,needVChan) 1

set topicInfo(#exeter,canFlags) "ov|ov"
set topicInfo(#exeter,canModes) "ov"
set topicInfo(#exeter,leadIn) "www.hashexeter.net"

#set topicInfo(#ags,needVChan) 1
set topicInfo(#exeter,canFlags) "ov|ov"
set topicInfo(#exeter,canModes) "ov"

set topicInfo(#molsoft,canFlags) "ov|ov"

set topicInfo(#molsoft,canFlags) "o|o"
set topicInfo(#molsoft,canModes) "o"

#DO NOT REMOVE THIS BRACKET
}
