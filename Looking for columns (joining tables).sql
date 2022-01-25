SELECT
s.name AS 'schema name',
o.name AS 'object name',
c.name AS 'column name',
o.type_desc AS 'object type desc'
FROM sys.columns c
JOIN sys.objects o
ON c.object_id = o.object_id
JOIN sys.schemas s
ON s.schema_id = o.schema_id
WHERE c.name LIKE '%put_desired_column_name_here_bro%'
