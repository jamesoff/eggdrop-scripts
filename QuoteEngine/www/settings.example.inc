<?php
	// Settings file for QuoteEngine

	// Copy this file to settings.inc and edit the below
	// There's a setting at the end you MUST change before the script will run

	define("MYSQL_HOST", "localhost");
	define("MYSQL_USER", "username");
	define("MYSQL_PASS", "password");
	define("MYSQL_DB",   "quotes");

	// The channel you want to show by default
	// Use "__all" to not filter
	// Omit the leading # for the channel name!
	define("DEFAULT_CHAN", "__all");

	// The person to say is hosting the page
	// Your name or your bot's name probably
	define("QUOTES_HOST", "YourName");

	// The stylesheet to use
	// styles.css or ocean.css
	// Or your own, if you're super-clever
	define("QUOTES_CSS", "styles.css");

	// Change 'false' to 'true' below!
	define("SETTINGS_EDITED", false);
?>
