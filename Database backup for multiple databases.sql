DECLARE @BackupPath NVARCHAR(4000) = N'backup_path';
DECLARE @SQL NVARCHAR(MAX) = N'';

SELECT @SQL += '
BACKUP DATABASE [' + name + ']
TO DISK = N''' + @BackupPath + name + '_' 
    + CONVERT(NVARCHAR(20), GETDATE(), 112) 
    + '_' 
    + REPLACE(CONVERT(NVARCHAR(20), GETDATE(), 108), ':', '') 
    + '.bak''
WITH INIT, COMPRESSION, STATS = 5;'
FROM sys.databases
WHERE name LIKE 'Databases names'
  AND state_desc = 'ONLINE';

--PRINT @SQL;
 EXEC sp_executesql @SQL;
