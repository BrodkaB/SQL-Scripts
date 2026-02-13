---checking what is clustered key for particular table
SELECT 
    i.name AS IndexName,
    i.type_desc,
    i.is_primary_key,
    i.is_unique,
    c.name AS ColumnName,
    ic.key_ordinal
FROM sys.indexes i
JOIN sys.index_columns ic 
    ON i.object_id = ic.object_id 
   AND i.index_id = ic.index_id
JOIN sys.columns c 
    ON ic.object_id = c.object_id 
   AND ic.column_id = c.column_id
WHERE i.object_id = OBJECT_ID('schema.tablename')
  AND i.type = 1  -- 1 = CLUSTERED
ORDER BY ic.key_ordinal;

---checking how many clustered keys it has
SELECT 
    i.type_desc,
    COUNT(*) AS IndexCount
FROM sys.indexes i
WHERE i.object_id = OBJECT_ID('schema.tablename')
  AND i.index_id > 0
GROUP BY i.type_desc;

---full list of all indexes for this table. if filtered, fillfactor, if clustered = PK
SELECT 
    i.name,
    i.type_desc,
    i.is_primary_key,
    i.is_unique,
    i.fill_factor,
    i.has_filter
FROM sys.indexes i
WHERE i.object_id = OBJECT_ID('schema.tablename')
  AND i.index_id > 0
ORDER BY i.type_desc, i.name;

---checking clustered key width
SELECT 
    SUM(c.max_length) AS ClusteredKeyWidthBytes
FROM sys.indexes i
JOIN sys.index_columns ic 
    ON i.object_id = ic.object_id 
   AND i.index_id = ic.index_id
JOIN sys.columns c 
    ON ic.object_id = c.object_id 
   AND ic.column_id = c.column_id
WHERE i.object_id = OBJECT_ID('schema.tablename')
  AND i.type = 1
  AND ic.is_included_column = 0;

---checking type of index
SELECT 
    i.name,
    i.type_desc,
    i.index_id
FROM sys.indexes i
WHERE i.object_id = OBJECT_ID('schema.tablename');

---rows, total pages and sizes of clustered index and NCI
SELECT
    i.name,
    i.type_desc,
    p.rows,
    au.total_pages,
    au.total_pages * 8 / 1024.0 AS SizeMB
FROM sys.indexes i
JOIN sys.partitions p 
    ON i.object_id = p.object_id 
    AND i.index_id = p.index_id
JOIN sys.allocation_units au 
    ON p.partition_id = au.container_id
WHERE i.object_id = OBJECT_ID('schema.tablename')
ORDER BY SizeMB DESC;

---checking fragmentation percent
SELECT
    i.name,
    ps.avg_fragmentation_in_percent,
    ps.page_count
FROM sys.dm_db_index_physical_stats
    (DB_ID(), OBJECT_ID('dbo.schema.tablename'), NULL, NULL, 'LIMITED') ps
JOIN sys.indexes i
    ON ps.object_id = i.object_id
    AND ps.index_id = i.index_id
ORDER BY ps.avg_fragmentation_in_percent DESC;

---seeks, scans and lookups
SELECT 
    i.name,
    us.user_seeks,
    us.user_scans,
    us.user_lookups,
    us.user_updates
FROM sys.indexes i
LEFT JOIN sys.dm_db_index_usage_stats us
    ON us.object_id = i.object_id
    AND us.index_id = i.index_id
    AND us.database_id = DB_ID()
WHERE i.object_id = OBJECT_ID('schema.tablename');

---top selects and seeks on index
SELECT TOP 20
    qs.execution_count,
    qs.total_elapsed_time / qs.execution_count AS avg_time,
    SUBSTRING(qt.text, (qs.statement_start_offset/2)+1,
        ((CASE qs.statement_end_offset
            WHEN -1 THEN DATALENGTH(qt.text)
            ELSE qs.statement_end_offset
        END - qs.statement_start_offset)/2)+1) AS query_text
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) qt
WHERE qt.text LIKE 'schema.tablename'
ORDER BY avg_time DESC;
