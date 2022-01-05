-----------------------------------------------------------------
--Last backup check, localization--
-----------------------------------------------------------------

USE msdb
GO
SELECT  database_name as DB_Name, type as Type, CAST(round(backup_size/1024/1024,1) AS NUMERIC(10,2)) as BackupSize_MB, CAST(round(compressed_backup_size/1024/1024,1) AS NUMERIC(10,2)) as CompressedBackupSize_MB, backup_start_date as Backup_start, backup_finish_date as Backup_Finish, user_name as Who_Performed, server_name as Server_Name, machine_name as Machine_Name, physical_device_name as Direction, is_copy_only as Is_Copy_only
FROM backupset BS join backupmediafamily BMF on BS.media_set_id=BMF.media_set_id
WHERE backup_finish_date > getdate()-1 and type = 'D'
ORDER BY backup_start_date DESC

-----------------------------------------------------------------
--Checking if any backup runs--
-----------------------------------------------------------------

SELECT percent_complete as Percent_Complete, command as Action_Name,  DB_NAME(database_id) DB_Name, wait_resource as Wait_Resource, estimated_completion_time/1000/60/60 as Time_To_Finish,dateadd(second,estimated_completion_time/1000, getdate()) as Estimated_Completion_Time , session_id as Session_ID from sys.dm_exec_requests
WHERE session_id >50 AND (command like '%backup%' or command like '%restore%')

-----------------------------------------------------------------
--Backups in specified timeframe--
-----------------------------------------------------------------
USE msdb
GO
SELECT  database_name as DB_Name, type as Type, CAST(round(backup_size/1024/1024,1) AS NUMERIC(10,2)) as BackupSize_MB, CAST(round(compressed_backup_size/1024/1024,1) AS NUMERIC(10,2)) as CompressedBackupSize_MB, backup_start_date as Backup_start, backup_finish_date as Backup_Finish, user_name as Who_Performed, server_name as Server_Name, machine_name as Machine_Name, physical_device_name as Direction, is_copy_only as Is_Copy_only
FROM backupset BS join backupmediafamily BMF on BS.media_set_id=BMF.media_set_id
WHERE backup_finish_date > '2021-11-01 06:00:00.000' AND backup_finish_date <'2022-01-05 06:00:00.00' AND TYPE= 'D'
ORDER BY backup_start_date DESC

-----------------------------------------------------------------
--Most recent backup for each database--
-----------------------------------------------------------------
SELECT  
   CONVERT(CHAR(100), SERVERPROPERTY('Servername')) AS Server, 
   msdb.dbo.backupset.database_name,  
   MAX(msdb.dbo.backupset.backup_finish_date) AS last_db_backup_date 
FROM   msdb.dbo.backupmediafamily  
   INNER JOIN msdb.dbo.backupset ON msdb.dbo.backupmediafamily.media_set_id = msdb.dbo.backupset.media_set_id  
WHERE  msdb..backupset.type = 'D' 
GROUP BY 
   msdb.dbo.backupset.database_name  
ORDER BY  
   msdb.dbo.backupset.database_name 
