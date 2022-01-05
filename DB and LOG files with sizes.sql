-----------------DB files
SELECT name as 'Database file Name', CAST(ROUND(size*8*1024/1024/1024,1) AS numeric (10,2)) as 'Size'
FROM sys.master_files
WHERE type_desc= 'ROWS'

--------------------LOG files
SELECT name as 'Log file Name', CAST(ROUND(size*8*1024/1024/1024,1) AS numeric (10,2)) as 'Size'
FROM sys.master_files
WHERE type_desc= 'LOG'
