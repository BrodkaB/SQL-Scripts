------script for restore database from provided location------

USE [master]

RESTORE DATABASE [Database name] 
FROM  DISK = N'\\provide_the_location_here' 
WITH  FILE = 1,  
MOVE N'ADatabase Logical Name' TO N'F:\Databases\Database name.mdf',  
MOVE N'Database Log Logical Name' TO N'L:\DB log\Database name_log.ldf',  
NOUNLOAD,  STATS = 1

GO


      ------script for checking database logical names------
      RESTORE FILELISTONLY 
       FROM DISK = '\\veeamnas.cho.corp.ryanair.com\BI_DUMP\BART\Test dbs to restore\AdventureWorksLT2014.bak'
