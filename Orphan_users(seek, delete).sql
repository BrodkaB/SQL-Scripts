---Checking if there are any oprhan users existing in database---

USE [DatabaseName]
GO
SELECT dp.type_desc, dp.sid, dp.name AS user_name  
FROM sys.database_principals AS dp  
LEFT JOIN sys.server_principals AS sp  
    ON dp.sid = sp.sid  
WHERE sp.sid IS NULL  
    AND dp.authentication_type_desc = 'INSTANCE'; 

---Generating drop command for all oprhans that are not needed

SELECT 
    'DROP USER [' + dp.name + '];' AS DropStatement
FROM sys.database_principals dp
LEFT JOIN sys.server_principals sp 
    ON dp.sid = sp.sid
WHERE 
    sp.sid IS NULL
    AND dp.type IN ('S', 'U')
    AND dp.name NOT IN ('dbo', 'guest', 'INFORMATION_SCHEMA', 'sys');

---Drop statement for all orphans on the instance for particular database

DECLARE @sql NVARCHAR(MAX) = N'';

SELECT @sql += N'DROP USER [' + dp.name + N'];' + CHAR(10)
FROM sys.database_principals dp
LEFT JOIN sys.server_principals sp 
    ON dp.sid = sp.sid
WHERE 
    sp.sid IS NULL
    AND dp.type IN ('S', 'U')
    AND dp.name NOT IN ('dbo', 'guest', 'INFORMATION_SCHEMA', 'sys');

PRINT @sql;   -- Najpierw zobacz co poleci
-- EXEC sp_executesql @sql;  -- Odkomentuj dopiero jak potwierdzisz

