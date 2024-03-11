----creating database snapshot----
CREATE DATABASE db_snapshot_ss
ON PRIMARY
(NAME='db file name', FILENAME='location of snapshot file')
AS SNAPSHOT OF [DB name]

----removing database stapshot-----
DROP DATABASE db_snapshot_ss

---restoring database using snapshot----
RESTORE DATABASE Databasename FROM DATABASE_SNAPSHOT = 'ss_Databasename_ss'

---creating database snapshot with multiple files---
CREATE DATABASE db_snapshot_ss
ON
(NAME = [Primary database file name],
 FILENAME ='location of snapshot file\db_snapshot_ss.SS1'),
(NAME = [Secondary database file name],
 FILENAME ='location of snapshot file\db_snapshot_ss.SS2')
AS SNAPSHOT OF [DB Name];
GO
