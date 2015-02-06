-- -----------------------------------------------------------------------------------
-- This example script sets up all database tables needed for the chat system itself, 
-- but without tables for game world environment.
-- If you change table names, you have to modify the config.
-- If you change table structure or similar, you have to modify the database class.
-- -----------------------------------------------------------------------------------
-- MySQL server version: 5.6.12
-- -----------------------------------------------------------------------------------

--
-- Scheme for table `chat - channeljoins`
--

CREATE TABLE IF NOT EXISTS `chat - channeljoins` (
  `ID` int(10) unsigned NOT NULL,
  `UserID` int(10) unsigned NOT NULL,
  `ChannelID` int(10) unsigned NOT NULL,
  PRIMARY KEY (`UserID`,`ChannelID`),
  UNIQUE KEY `ID` (`ID`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COMMENT='Current channel joins of clients/players';

-- --------------------------------------------------------

--
-- Scheme for table `chat - channellogs`
--

CREATE TABLE IF NOT EXISTS `chat - channellogs` (
  `ChannelLogID` bigint(10) unsigned NOT NULL,
  `ChannelBufferID` smallint(5) unsigned NOT NULL,
  `ChannelTextID` varchar(50) NOT NULL,
  `ChannelID` int(10) unsigned NOT NULL,
  `EventTextID` varchar(25) NOT NULL,
  `EventData` text NOT NULL,
  `Timestamp` bigint(20) unsigned NOT NULL,
  PRIMARY KEY (`ChannelBufferID`,`ChannelTextID`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COMMENT='Current chat history of all channels';

-- --------------------------------------------------------

--
-- Scheme for table `chat - channels`
--

CREATE TABLE IF NOT EXISTS `chat - channels` (
  `ID` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `GalaxyID` tinyint(5) unsigned NOT NULL,
  `Title` tinytext NOT NULL,
  `Password` tinytext NOT NULL,
  `IrcChannel` tinytext,
  `IsPublic` tinyint(1) unsigned NOT NULL,
  PRIMARY KEY (`ID`),
  KEY `GalaxyID` (`GalaxyID`)
) ENGINE=MyISAM  DEFAULT CHARSET=utf8 COMMENT='Stored custom/non-default channels';

