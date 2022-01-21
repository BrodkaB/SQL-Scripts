---- To show only tables for the particular database
SELECT Table_Name FROM [Database_name].INFORMATION_SCHEMA.TABLES WHERE Table_Type = 'BASE TABLE'

    	----To list all available tables in DATABASE
  	USE [database name]
	GO
	EXEC sp_tables
	GO
      
          	--- To list all tables with particular keyword
          	SELECT * FROM msdb.INFORMATION_SCHEMA.TABLES WHERE table_name LIKE '%%' AND table_type = 'BASE TABLE'
		ORDER BY table_name
		GO
