CREATE TABLE `bar` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `foo_id` int(11) NOT NULL,
  `name` varchar(10) NOT NULL DEFAULT '',
  PRIMARY KEY (`id`),
  KEY `index_bar_on_foo_id` (`foo_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `entries` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `word_id` int(11) NOT NULL,
  `rowidx` bigint(20) NOT NULL,
  `modelid` int(11) NOT NULL,
  `modelrowid` int(11) NOT NULL,
  `rank` int(11) NOT NULL,
  `row_priority` float NOT NULL DEFAULT '0.5',
  PRIMARY KEY (`id`),
  KEY `index_entries_on_rowidx` (`rowidx`),
  KEY `index_entries_on_modelid` (`modelid`),
  KEY `index_entries_on_modelrowid` (`modelrowid`),
  KEY `index_entries_on_word_id_and_rank` (`word_id`,`rank`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

CREATE TABLE `foo` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(10) NOT NULL DEFAULT '',
  `description` varchar(20) NOT NULL DEFAULT '',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `schema_migrations` (
  `version` varchar(255) COLLATE utf8_unicode_ci NOT NULL,
  UNIQUE KEY `unique_schema_migrations` (`version`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

CREATE TABLE `words` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `word` varchar(64) CHARACTER SET utf8 COLLATE utf8_bin NOT NULL,
  `entries_count` int(11) NOT NULL DEFAULT '0',
  `rank_limit` int(11) NOT NULL DEFAULT '0',
  `stem` varchar(64) NOT NULL DEFAULT '',
  `metaphone` varchar(64) DEFAULT NULL,
  `soundex` varchar(4) DEFAULT NULL,
  `primary_metaphone` varchar(4) DEFAULT NULL,
  `secondary_metaphone` varchar(4) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_words_on_word` (`word`),
  KEY `index_words_on_entries_count` (`entries_count`),
  KEY `index_words_on_stem` (`stem`),
  KEY `index_words_on_metaphone` (`metaphone`),
  KEY `index_words_on_soundex` (`soundex`),
  KEY `index_words_on_primary_metaphone` (`primary_metaphone`),
  KEY `index_words_on_secondary_metaphone` (`secondary_metaphone`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

INSERT INTO schema_migrations (version) VALUES ('20120712194526');

INSERT INTO schema_migrations (version) VALUES ('20120712194650');