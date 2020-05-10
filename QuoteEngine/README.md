QuoteEngine
===========

A quote database for Eggdrop bots.

Prerequisites
-------------

1. Install all necessary packages for eggdrop to make use of mysql (also packages which you need to have are included).

   For example for ubuntu 18.04 these would be the packages `tcl, tcl-dev, tcllib, tcl-tls, zlibc, zlib1g, tcl-trf, mysqltcl`

2. Install `mysql-server`. You may also want to install `phpmyadmin` and phpmyadmin (phpmyadmin is not really needed, but it helps to manage databases).
   <br>
   For example for ubuntu 18.04 these would be the packages: mysql-server, mysql-client, phpmyadmin
      <br>
      For phpmyadmin you need the following packages: apache2, php <- install those first. :)
      <br>
      Note: after finishing the things which you wanted to do in the database with phpmyadmin,
      <br>
      don't forget to disable it with command:
      <br>
      ```a2disconf phpmyadmin.conf```
      <br>
      so it won't be available until you need it again. In case you need it once more, you can enable phpmyadmin with command:
      <br>
      ```a2enconf phpmyadmin.conf```
      <br>
      Note: After module/conf enable/disable, you need to reload/restart apache2!
      <br>
3. Install eggdrop. Check out here: https://www.eggheads.org/downloads

In case you have a running bot, you can continue.


Database setup, first steps
---------------------------------------------

<br>
!! Keep in mind, to give the minimum ammount of rights only, to database users!
<br>

1. Create admin user for mysql if you don't have it yet.

   // In case you have an admin user for your mysql server other than the "root" user, you can skip this. //

   With root user enter the following command in your shell:
   <br>
   ```# mysql -u root```
      <br>
      This will let you to login to mysql, so you can make changes on/in it.

   Create a new admin user (so you can login to phpmyadmin later on):
   <br>
   ```mysql> CREATE USER '<user>'@'%' IDENTIFIED BY '<pwhere>';```
      <br>
      This will create the <user> with the given password.

   Grant all right to the user:
   <br>
   ```mysql> GRANT ALL PRIVILEGES ON *.* TO '<user>'@'%' WITH GRANT OPTION;```
      <br>
      This command allows you to login from any host/ip and gives you unlimited control over all databases.

   Check if you did everything well, so the user exists:
   <br>
   ```mysql> SHOW GRANTS FOR '<user>'@'%';```
   <br>
   ```mysql> exit```
   <br>
      This will exit you out from the mysql console.

2. Create a user and database in your mysql server for the bot to use.

   You have two options now:
   <br>
   <br>
   a, Use phpmyadmin, where you can log in with the user which you created in point one and there
      create a new database and a new user, then grant that user rights over the database ..

   OR

   b, Use the following commands:

   With your shell user, login to mysql with the previously created user:
   <br>
   ```$ mysql -u <user> -p```
   <br>
      Here you will need to enter the password which you have given previous (`<pwhere>`).
   <br>

   ```mysql> CREATE DATABASE quotesdb;```
   <br>
      This will create a database, named "quotesdb".

   Now we need to create an other user for the bot.
   <br>
   ```mysql> CREATE USER '<botnick>'@'localhost' IDENTIFIED BY '<botpwhere>';```
   <br>
      This will create a user named "botnick". We will use this user,
      <br>
      to connect to mysql and make changes in database named "quotesdb".
      <br>
      For that, we need to set rights.

   ```mysql> GRANT SELECT, INSERT, UPDATE, DELETE ON quotesdb.* TO '<botnick>'@'localhost';```
   <br>
      This will grant all right on db "quotesdb" to "botnick" user, connecting from localhost.


   Now we are ready to move on to the next step. :)


2. Now, you have to create the tables into the database which you made.
   <br>
   For this, you can download the pre-made script - you can find it in the sql folder, named "quotes.sql".
   Download it (example: wget) and run the following command with your shell user:
   <br>
      ```$ mysql -u <user> -p quotesdb < quotes.sql```
      <br>
         The <user> is what you have created at point 1. :)


   At this point you are ready with the preparations and you can move to the next chapter. :)


Setting up the tcl script, edit the config(s)
---------------------------------------------

1. Download the script (QuoteEngine.tcl) and put that into the eggdrop's  scripts directory.
2. Download the settings file (QuoteEngine-settings.sample.tcl) rename it to "QuoteEngine-settings.tcl" and edit it!
   <br>
   The settings file needs to be edited. If you followed the guide, you won't have any problems to fill it out. :)
3. Open your bot's configuraton file and put the following like to the end of the file:
     <br>
      ```source "scripts/QuoteEngine.tcl"```
      <br>
4. Telnet to your bot (or use dcc chat), or however you go to your bot's console and rehash your bot.
   You need to see this line in the console:
   <br>
      `"QuoteEngine 1.3 loaded"`
    <br>
   In case you cannot see it, you did something wrong. Check again the guide. :)


Usage
---------------------------------------------

1. You have to set "+quoteengine" flag to the channel where you want to enable to use the commands provided by the script.
   <br>
   You can do this via the bot's console with command:
      ```.chanset <#channelname_here> +quoteengine```
      <br>
2. If you did everything right, now you will be able to use commands as:

```
!addquote <text>        -- add a quote
!getquote <#number>     -- get the quote of #
!randquote              -- get a random quote
!delquote <#number>     -- delete a quote
!quotehelp              -- list of all available command
```


Note: some of the commands are limited bot owners, masters, etc..
<br>
Check QuoteEngine.tcl for further details.
   (
    You need to check the "bind pub" lines. :)
    m,f,o,v are flags (rights) which you can have in the bot
   )


Webpage setup
---------------------------------------------

!! The php part - so the webiste - won't work, because the code is for php5, so on php7 it wont work.
<br>
!! I don't recommend anyone to install php5 anymore.
<br>
!! In case you are into coding and have free time, feel free to contribute to this project,
<br>
!! rewrite the code and open a pull request!
<br>
!! Help is much appreciated! :)
<br>
!! Thanks in advance!


For php5 the instructions are:
1. Put the files in the www directory in the right place in your webserver
2. Edit settings.sample.inc to have the right details, and rename to settings.inc
3. Profit


3rd Party webpages
---------------------------------------------

* https://github.com/brandon15811/QuoteEngineWeb
