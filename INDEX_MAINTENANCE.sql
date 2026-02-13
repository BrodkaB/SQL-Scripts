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
