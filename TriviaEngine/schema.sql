CREATE TABLE "categories" (
  "cat_id" INTEGER NOT NULL primary key autoincrement,
  "cat_name" varchar(255) NOT NULL default '',
  "cat_enabled" tinyint(4) NOT NULL default '0'
);
CREATE TABLE "games" (
  "game_id" integer NOT NULL primary key,
  "game_start" bigint(20) NOT NULL default '0',
  "game_end" bigint(20) NOT NULL default '0',
  "game_winner" bigint(20) NOT NULL default '0'
);
CREATE TABLE "questions" (
  "question_id" integer NOT NULL primary key autoincrement,
  "cat_id" bigint(20) NOT NULL default '0',
  "question" varchar(255) NOT NULL default '',
  "answer" varchar(255) NOT NULL default '',
  "count" bigint(20) NOT NULL default '0'
);
CREATE TABLE "reports" (
  "report_id" integer NOT NULL primary key autoincrement,
  "when" bigint(20) NOT NULL default '0',
  "who" varchar(15) NOT NULL default '',
  "question_id" bigint(20) NOT NULL default '0',
  "message" varchar(200) NOT NULL default '',
  "resolved" char(1) NOT NULL default 'N'
);
CREATE TABLE "scores" (
  "user_id" bigint(20) NOT NULL default '0',
  "dt" bigint(20) NOT NULL default '0'
);
CREATE TABLE "users" (
  "user_id" integer NOT NULL primary key autoincrement,
  "user_name" varchar(20) NOT NULL default '',
  "user_pass" varchar(255) NOT NULL default '',
  "user_score" bigint(20) NOT NULL default '0',
  "user_reg" bigint(20) default NULL,
  "user_last" bigint(20) default NULL
, user_points bigint not null default 0);
CREATE TABLE "winners" (
user_id bigint(20) not null default '0',
dt bigint(2) not null default '0',
score int not null default '0'
);

