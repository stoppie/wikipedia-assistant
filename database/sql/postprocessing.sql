USE wiki_assistant;

-- BASE TABLES CREATION

CREATE TABLE IF NOT EXISTS `page` (
  `page_id` int NOT NULL,
  `page_namespace` int NOT NULL DEFAULT '0',
  `page_title` varbinary(255) NOT NULL DEFAULT '',
  `page_touched` timestamp NOT NULL,
  PRIMARY KEY (`page_id`),
  UNIQUE KEY `page_name_title` (`page_namespace`,`page_title`)
);

CREATE TABLE IF NOT EXISTS `categorylinks` (
  `cl_from` int NOT NULL DEFAULT '0',
  `cl_to` varbinary(255) NOT NULL DEFAULT '',
  PRIMARY KEY (`cl_from`,`cl_to`),
  CONSTRAINT `categorylinks_ibfk_1` FOREIGN KEY (`cl_from`) REFERENCES `page` (`page_id`)
);

CREATE TABLE IF NOT EXISTS `pagelinks` (
  `pl_from` int NOT NULL DEFAULT '0',
  `pl_namespace` int NOT NULL DEFAULT '0',
  `pl_title` varbinary(255) NOT NULL DEFAULT '',
  PRIMARY KEY (`pl_from`,`pl_namespace`,`pl_title`),
  KEY `pl_namespace` (`pl_namespace`,`pl_title`),
  CONSTRAINT `pagelinks_ibfk_1` FOREIGN KEY (`pl_from`) REFERENCES `page` (`page_id`)
);

-- DATA LOADS

INSERT INTO `page` (`page_id`, `page_namespace`, `page_title`, `page_touched`)
SELECT
    page_id,
    page_namespace,
    page_title,
    STR_TO_DATE(CONVERT(page_touched USING utf8), '%Y%m%d%H%i%s')
FROM `wiki_staging`.`page`;

INSERT INTO `categorylinks` (`cl_from`, `cl_to`)
SELECT
    cl_from,
    cl_to
FROM `wiki_staging`.`categorylinks`
WHERE
    cl_from != 1039753; -- MISSING IN THE PAGE TABLE

INSERT INTO `pagelinks` (`pl_from`, `pl_namespace`, `pl_title`)
SELECT
    pl_from,
    pl_namespace,
    pl_title
FROM `wiki_staging`.`pagelinks`
WHERE
    pl_from != 1039753; -- MISSING IN THE PAGE TABLE

-- ADDITIONAL TABLES FOR THE API ENDPOINT

DROP TABLE IF EXISTS `pageoutdatedness`;

CREATE TABLE `pageoutdatedness` (
  `page_id` int NOT NULL DEFAULT '0',
  `page_behind` int NOT NULL,
  PRIMARY KEY (`page_id`)
);

INSERT INTO `pageoutdatedness` (`page_id`, `page_behind`)
SELECT
    p_source.page_id,
    MAX(TIMESTAMPDIFF(SECOND, p_target.page_touched, p_source.page_touched))
FROM `page` p_source
JOIN `pagelinks` pl ON
    p_source.page_id = pl.pl_from
JOIN `page` p_target ON
    pl.pl_namespace = p_target.page_namespace
    AND pl.pl_title = p_target.page_title
GROUP BY
    p_source.page_id
HAVING
    MAX(TIMESTAMPDIFF(SECOND, p_target.page_touched, p_source.page_touched)) > 0;

DROP TABLE IF EXISTS `categoryoutdated`;

CREATE TABLE `categoryoutdated` (
  `category` varbinary(255) NOT NULL DEFAULT '',
  `page_id` int NOT NULL,
  `page_namespace` int NOT NULL DEFAULT '0',
  `page_title` varbinary(255) NOT NULL DEFAULT '',
  `page_outdatedness` int NOT NULL,
  PRIMARY KEY (`category`)
);

INSERT INTO `categoryoutdated` (`category`, `page_id`, `page_namespace`, `page_title`, `page_outdatedness`)
WITH categorycounts AS (
    SELECT
        cl.cl_to category,
        COUNT(*) cnt
    FROM `categorylinks` cl
    GROUP BY cl.cl_to
), rankedpages AS (
    SELECT
        cl.cl_to category,
        cl.cl_from page_id,
        po.page_behind page_outdatedness,
        p.page_namespace,
        p.page_title,
        DENSE_RANK() OVER (PARTITION BY cl.cl_to ORDER BY po.page_behind DESC) rnk
    FROM `categorylinks` cl
    JOIN `pageoutdatedness` po ON
        cl.cl_from = po.page_id
    JOIN `page` p ON
        cl.cl_from = p.page_id
)
SELECT
    rp.category,
    rp.page_id,
    rp.page_namespace,
    rp.page_title,
    rp.page_outdatedness
FROM rankedpages rp
JOIN categorycounts cc ON
    rp.category = cc.category
WHERE
    rp.rnk = 1
ORDER BY
    cc.cnt DESC
LIMIT 10;