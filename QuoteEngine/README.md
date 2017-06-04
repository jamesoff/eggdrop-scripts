Quick start, because I can't be arsed writing a full one ;)

SQL setup
---------

1. Create a user and database in your mysql server for the bot to use
2. Populate the database using the .sql script

Note: Give the SQL user minimum permissions, restrict it to just the host the bot runs on, etc.

TCL setup
---------

1. Install mysqltcl package
2. Put the QuoteEngine.tcl file in your eggdrop's scripts/ directory
3. Edit the QuoteEngine-settings.sample.tcl file and save it as
   QuoteEngine-settings.tcl in your scripts/ directory
4. Put `source scripts/QuoteEngine.tcl` in your bot's config file

Webpage setup
-------------

1. Put the files in the www directory in the right place in your webserver
2. Edit settings.sample.inc to have the right details, and rename to settings.inc
3. Profit

3rd Party webpages
------------------

* https://github.com/brandon15811/QuoteEngineWeb
