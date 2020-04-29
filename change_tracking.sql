--
-- CHANGE TRACKING USING THE "AUDIT LOG" ;)
-- 

DROP DATABASE IF EXISTS tracking;
CREATE DATABASE tracking;
use tracking;

DROP TABLE IF EXISTS CHANGE_TRACKING;

CREATE TABLE CHANGE_TRACKING (
   DB_NAME VARCHAR(64),
   TABLE_NAME VARCHAR(64),
   START_TIME TIMESTAMP NULL,
   PRIMARY KEY (DB_NAME,TABLE_NAME)
);

DELIMITER $$

DROP PROCEDURE IF EXISTS START_TRACKING
$$
DROP PROCEDURE IF EXISTS STOP_TRACKING;
$$
DROP PROCEDURE IF EXISTS LIST_TRACKING;
$$

--
-- SET_FILTER
--
CREATE PROCEDURE SET_FILTER()
BEGIN
    DECLARE _filtername VARCHAR(64);
    DECLARE _tracking_data TEXT;
    SET _filtername='tracking_filter';

    SELECT GROUP_CONCAT('{ "and": [ { "field": { "name": "table_database.str", "value":"', DB_NAME , '"} }, { "field": { "name": "table_name.str", "value":"', TABLE_NAME , '"} } ] }') INTO _tracking_data FROM CHANGE_TRACKING;

    
    SET @s = CONCAT(' ',
    ' { ',
    '   "filter": ',
    '   { ',
    '     "id": "main", ',
    '     "class": ',
    '     { ',
    '       "name": "table_access", ',
    '       "event": ',
    '       { ',
    '         "name": [ "delete", "insert", "update" ], ',
    '         "log": false, ',
    '         "filter": ',
    '         { ',
    '           "activate": ',
    '           {  ',
    '              "or": [ ', _tracking_data , ' ] ',
    '           }, ',
    '           "class": ',
    '           { ', 
    '             "name": "general", ',
    '             "event": ',
    '             { ',
    '                       "name": "status", ',
    '                       "log": { "field": { "name": "general_error_code", "value": 0 } }, ',
    '                       "filter": { "ref": "main" } ',
    '             } ',
    '           } ',
    '         } ',
    '       } ',
    '     } ',
    '   } ',
    ' } ');

    IF (_tracking_data IS NULL) THEN
       SET @s = '{ "filter": { "log": false } }';
    END IF;

    SELECT audit_log_filter_set_filter(_filtername, @s);
    SELECT audit_log_filter_set_user('%',_filtername);
END
$$


--
-- START_TRACKING
--
CREATE PROCEDURE START_TRACKING(IN track_db VARCHAR(64), IN track_table VARCHAR(64))
BEGIN
    INSERT INTO CHANGE_TRACKING (DB_NAME,TABLE_NAME,START_TIME) VALUES (track_db,track_table,NOW());
    CALL SET_FILTER();
END
$$

--
-- STOP_TRACKING
--
CREATE PROCEDURE STOP_TRACKING(IN track_db VARCHAR(64), IN track_table VARCHAR(64))
BEGIN
    DELETE FROM CHANGE_TRACKING WHERE DB_NAME=track_db and TABLE_NAME=track_table;
    CALL SET_FILTER();
END
$$

CREATE PROCEDURE LIST_TRACKING()
BEGIN
    SELECT * FROM CHANGE_TRACKING;
END
$$
DELIMITER ;

