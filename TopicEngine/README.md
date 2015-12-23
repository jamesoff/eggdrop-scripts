The TopicEngine script allows advanced topic control in your IRC channel(s). It can be used to allow non-ops to change the topic, as well as offering useful ways for people who could otherwise change the topic directly to modify it.

Consult the settings script for configuration instructions.

This script works fine, but can be quirky for features like prefix and postfix. I’m going to fix it, sometime :)

Full help is available online in the script (`/msg BOTNICK topic help`), but here’s an overview:

`!topic [command] [parameter]`

or for some commands with shortcuts:

`!topic [shortcut][parameter]` (no space between the shortcut character and the parameter)

or via /msg to the bot:

`/msg BOTNICK topic #channel [command] [parameter]` or `/msg BOTNICK topic #channel [shortcut][parameter]`

or via the partyline:

`.topic #channel [command] [parameter]` or `.topic #channel [shortcut][parameter]`

|Command|Shortcut|Description|
|---|:-:|---|
|`add`|+|Add the text to the topic|
|`append`|<<<|Add the text to the topic, deleting earlier stuff if needed|
|`insert`|>>>|Add the text to the start of the topic, deleting later stuff if needed|
|`del`|-|Delete an element. The first element is 1; prefixes and postfixes cannot be removed with this.|
|`set`|=|Set the topic to the text, removing anything else.  `set prefix` (=prefix) will set the prefix. `set postfix` (=postfix) will set the postfix. use "none" to delete the topic/pre-/postfix: `!topic =prefix none`|
|`info`|?|Find out about the topic. No parameters will give into on the topic as a whole. Use with a number to find out about an element: `!topic ?2`. Use "info undo" to find out about the undo buffer|
|`undo`| |Reverse the last command.|
|`regexp`|/|Do a regexp find/replace on the topic. `!topic regexp 3 /hello/goodbye/` or shortcut: `!topic /3/hello/goodbye/`. Options g and i are supported after the last slash.|
|`clear`| |Clears the topic on irc, but remembers it in the bot. use rehash to get it back. `clear content` will clear everything but the pre-/postfix. `clear all` will delete the whole thing.|
|`lock`| |locks the topic (channel owner only) from changes|
|`unlock`| |reverse a lock|
|`rehash`|#|set the topic again (if a server has lost it). Use `rehash force` to force the topic to be set even if the bot doesn’t think it needs doing. ! is a shortcut for force (i.e. `!topic #!`)|

Other shortcuts:

* Prefix the topic with @ to lock it at the same time. (!topic add @this will be locked)
* Prefix the topic with ~ (tilde) to delay the update. The bot will update its internal state but not set the topic on IRC. Use this to do many commands in a row without spamming the channel with topic changes. Omit the tilde from your final change, or use the rehash command when you're done.
