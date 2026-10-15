-----------------------------------------------------------------
--DB files--
-----------------------------------------------------------------
SELECT name as 'Database file Name', CAST(ROUND(CAST(size AS BIGINT)*8*1024/1024/1024,1) AS numeric (10,2)) as 'Size'
FROM sys.master_files
WHERE type_desc= 'ROWS'

-----------------------------------------------------------------
--LOG files--
-----------------------------------------------------------------
SELECT name as 'Log file Name', CAST(ROUND(CAST(size AS BIGINT)*8*1024/1024/1024,1) AS numeric (10,2)) as 'Size'
FROM sys.master_files
WHERE type_desc= 'LOG'

-----------------------------------------------------------------
--All files together--
-----------------------------------------------------------------
SELECT name as 'File names', CAST(ROUND(CAST(size AS BIGINT)*8*1024/1024/1024,1) AS numeric (10,2)) as 'Size'
FROM sys.master_files

SELECT
    DB_NAME(database_id) AS [Database],
    name AS [File name],
    type_desc AS [File type],
    CAST(ROUND(size * 8.0 / 1024 / 1024, 2) AS NUMERIC(10,2)) AS [Size (GB)]
FROM sys.master_files
ORDER BY database_id, type_desc, name;
