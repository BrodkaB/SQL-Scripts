----To see what are the highest modification_counters for stats inside exact database 
WITH StatsCTE AS (
    SELECT
        OBJECT_SCHEMA_NAME(s.object_id) AS schema_name,
        OBJECT_NAME(s.object_id) AS table_name,
        s.name AS stats_name,
        STATS_DATE(s.object_id, s.stats_id) AS last_updated,
        sp.rows,
        sp.modification_counter,
        ROW_NUMBER() OVER (ORDER BY sp.modification_counter DESC) AS rn
    FROM sys.stats s
    CROSS APPLY sys.dm_db_stats_properties(s.object_id, s.stats_id) sp
    WHERE OBJECTPROPERTY(s.object_id, 'IsUserTable') = 1
      AND sp.modification_counter > 0
)
SELECT
    schema_name,
    table_name,
    stats_name,
    last_updated,
    rows,
    modification_counter
FROM StatsCTE
WHERE rn <= 10---here you can use whatever value 
ORDER BY modification_counter DESC;

WITH StatsCTE AS (
    SELECT
        OBJECT_SCHEMA_NAME(s.object_id) AS schema_name,
        OBJECT_NAME(s.object_id) AS table_name,
        s.name AS stats_name,
        sp.modification_counter,
        ROW_NUMBER() OVER (ORDER BY sp.modification_counter DESC) AS rn
    FROM sys.stats s
    CROSS APPLY sys.dm_db_stats_properties(s.object_id, s.stats_id) sp
    WHERE OBJECTPROPERTY(s.object_id, 'IsUserTable') = 1
      AND sp.modification_counter > 0
)
SELECT
    'UPDATE STATISTICS '
    + QUOTENAME(schema_name) + '.'
    + QUOTENAME(table_name) + ' '
    + QUOTENAME(stats_name)
    + ' WITH SAMPLE 10 PERCENT;'
    AS update_statement
FROM StatsCTE
WHERE rn <= 5
ORDER BY rn;

----reading current CPU usage 
select scheduler_id, runnable_tasks_count from sys.dm_os_schedulers where status = 'VISIBLE ONLINE';

----checking which stat is currently being updated 
select r.session_id, r.status, r.wait_type, r.cpu_time, r.total_elapsed_time, t.text from sys.dm_exec_requests r cross apply sys.dm_exec_sql_text(r.sql_handle) t where r.command like 'UPDATE STATISTICS'


WITH StatsCTE AS (
    SELECT
        OBJECT_SCHEMA_NAME(s.object_id) AS schema_name,
        OBJECT_NAME(s.object_id) AS table_name,
        s.name AS stats_name,
        sp.last_updated,
        ROW_NUMBER() OVER (ORDER BY sp.last_updated ASC) AS rn
    FROM sys.stats s
    CROSS APPLY sys.dm_db_stats_properties(s.object_id, s.stats_id) sp
    WHERE OBJECTPROPERTY(s.object_id, 'IsUserTable') = 1
      AND sp.last_updated IS NOT NULL
)
SELECT
    'UPDATE STATISTICS '
    + QUOTENAME(schema_name) + '.'
    + QUOTENAME(table_name) + ' '
    + QUOTENAME(stats_name)
    + ' WITH SAMPLE 5 PERCENT;'
    AS update_statement,
    last_updated
FROM StatsCTE
WHERE rn <= 5
ORDER BY rn;

