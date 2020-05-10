DROP TABLE IF EXISTS `quotes`;
CREATE TABLE `quotes` (
  `id` INTEGER PRIMARY KEY,
  `nick` varchar(20) NOT NULL default '',
  `host` varchar(100) NOT NULL default '',
  `quote` text NOT NULL,
  `channel` varchar(50) NOT NULL default '',
  `timestamp` bigint(20) default NULL
);
