---- To show only tables for the particular database
SELECT TABLE_NAME FROM <DATABASE_NAME>.INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE = 'BASE TABLE'

    ----To list all available tables in DATABASE
    USE [database name]
			GO
			EXEC sp_tables
			GO
      
          --- To list all tables with particular keyword
          SELECT * FROM msdb.INFORMATION_SCHEMA.TABLES WHERE table_name LIKE '%%' AND table_type = 'BASE TABLE'
					ORDER BY table_name
					GO
