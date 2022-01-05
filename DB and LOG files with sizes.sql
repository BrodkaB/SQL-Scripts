
-----------------DB files
SELECT name, CAST(ROUND(size*8*1024/1024/1024,1) AS numeric (10,2)) FROM sys.mASter_files
WHERE type_desc= 'ROWS'

--------------------LOG files
SELECT name, CAST(ROUND(size*8*1024/1024/1024,1) AS numeric (10,2)) FROM sys.mASter_files
WHERE type_desc= 'LOG'
