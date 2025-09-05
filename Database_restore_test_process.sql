-----This is step by step instrucion for proces I have created. It requires to create several database objects, you can put them whereever you want. I always create dedicated DBA database that is used for any DBA related stuff later.
-----Note that names of stored procedures, tables, database and job used are just examples that I created for my own use.

---Task1: Database CHECKDB test. For that purpose, use Ola's Hallengren script for DBCC CHECKDB, you can find it here: https://ola.hallengren.com/. This require below sp's and tables to be created, everything is described on Ola's page:
------------dbo.DatabaseIntegrityCheck stored procedure creation (Part of Ola's setup)
------------dbo.CommandExecute stored procedure creation (Part of Ola's setup)
------------dbo.CommandLog table creation (Part of Ola's setup)
------------dbo.BackupValidationCHECKDB table creation (required to successfully execute whole proces)
USE [DBA]
GO

CREATE TABLE [dbo].[BackupValidationCHECKDB]
(
	ValidationID INT IDENTITY PRIMARY KEY,
	DatabaseName [sysname] NOT NULL,
	StepName NVARCHAR(50) NOT NULL,
	StepResult NVARCHAR(10) NOT NULL,
	DurationMs INT NULL,
	OutputMsg NVARCHAR(500) NOT NULL,
	RunDate DATETIME2 NOT NULL DEFAULT SYSDATETIME()
)

---Task2: Database performance check. This step requires stored procedure, which is selecting top 3 biggest tables for each database and running COUNT(*) function on it. It returns PASS/FAIL feedback including time it took to run command on each table
------------dbo.RunPerfTests_AutoTablePick stored procedure to be executed
USE [DBA]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE   PROCEDURE [dbo].[RunPerfTests_AutoTablePick]
    @TopTables INT = 3   --Numer of largest tables to be taken
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @db SYSNAME, @sql NVARCHAR(MAX), @tbl NVARCHAR(300), @testName NVARCHAR(200);
    DECLARE @startTime DATETIME2, @durationMs INT;

    -- Creating temp table for the session
    IF OBJECT_ID('tempdb..#tbls') IS NOT NULL
        DROP TABLE #tbls;

    CREATE TABLE #tbls (
        TableName NVARCHAR(300),
        NumRows BIGINT
    );

    --User databases cursor excliduing system dbs and DBA database
    DECLARE db_cursor CURSOR FOR
    SELECT name
    FROM sys.databases
    WHERE name NOT IN ('master','model','msdb','tempdb','DBA')
      AND state_desc = 'ONLINE';

    OPEN db_cursor;
    FETCH NEXT FROM db_cursor INTO @db;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        --Temporary table cleanup after each database
        TRUNCATE TABLE #tbls;

        --Dynamic sql for each database
        SET @sql = N'
            INSERT INTO #tbls
            SELECT TOP (' + CAST(@TopTables AS NVARCHAR(10)) + N')
                QUOTENAME(s.name) + ''.'' + QUOTENAME(t.name) AS TableName,
                SUM(p.rows) AS NumRows
            FROM ' + QUOTENAME(@db) + N'.sys.tables t
            JOIN ' + QUOTENAME(@db) + N'.sys.schemas s ON t.schema_id = s.schema_id
            JOIN ' + QUOTENAME(@db) + N'.sys.partitions p ON t.object_id = p.object_id
            WHERE p.index_id IN (0,1)
            GROUP BY s.name, t.name
            ORDER BY SUM(p.rows) DESC;';

        EXEC(@sql);

        --Loop running on currently used database
        DECLARE tbl_cursor CURSOR FOR SELECT TableName FROM #tbls;
        OPEN tbl_cursor;
        FETCH NEXT FROM tbl_cursor INTO @tbl;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @testName = 'NumRows_' + @tbl;

            BEGIN TRY
                SET @startTime = SYSDATETIME();

                SET @sql = N'SELECT COUNT(*) FROM ' + QUOTENAME(@db) + N'.' + @tbl + N';';
                EXEC (@sql);

                SET @durationMs = DATEDIFF(MILLISECOND, @startTime, SYSDATETIME());

                INSERT INTO DBA.dbo.BackupValidationPerfTest
                    (DatabaseName, StepName, StepResult, DurationMs, OutputMsg, RunDate)
                VALUES
                    (@db, @testName, 'PASS', @durationMs, 'Executed successfully', SYSDATETIME());
            END TRY
            BEGIN CATCH
                INSERT INTO DBA.dbo.BackupValidationPerfTest
                    (DatabaseName, StepName, StepResult, DurationMs, OutputMsg, RunDate)
                VALUES
                    (@db, @testName, 'FAIL', NULL, ERROR_MESSAGE(), SYSDATETIME());
            END CATCH;

            FETCH NEXT FROM tbl_cursor INTO @tbl;
        END

        CLOSE tbl_cursor;
        DEALLOCATE tbl_cursor;

        FETCH NEXT FROM db_cursor INTO @db;
    END

    CLOSE db_cursor;
    DEALLOCATE db_cursor;

    DROP TABLE #tbls;
END
GO

------------dbo.BackupValidationPerfTest table creation that will store results for each execution
USE [DBA]
GO

CREATE TABLE [dbo].[BackupValidationPerfTest]
(
	ValidationID INT IDENTITY PRIMARY KEY NOT NULL,
	DatabaseName SYSNAME NOT NULL,
	StepName NVARCHAR(200) NOT NULL,
	StepResult NVARCHAR(10) NOT NULL,
	DurationMs INT NULL,
	OutputMsg NVARCHAR(500) NOT NULL,
	RunDate DATETIME2 NOT NULL DEFAULT SYSDATETIME()
)

---Task3: Database last restore check step. This require stored procedure that using msdb.dbo tables to see when last database restore happened and it's putting output into below table
------------dbo.LastRestoreCheck stored procedure
USE [DBA]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE   PROCEDURE [dbo].[LastRestoreCheck]
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH LatestRestoreDate AS (
        SELECT 
            r.destination_database_name AS DatabaseName,
            MAX(r.restore_date) AS LastRestoreDate
        FROM msdb.dbo.restorehistory r
        GROUP BY r.destination_database_name
    ),
    LastChain AS (
        SELECT 
            r.destination_database_name AS DatabaseName,
            CASE r.restore_type
                WHEN 'D' THEN 'FULL'
                WHEN 'I' THEN 'DIFF'
                WHEN 'L' THEN 'LOG'
                ELSE r.restore_type END AS RestoreType,
            r.restore_date AS RestoreStart,
            r.stop_at AS RestoreEnd
        FROM msdb.dbo.restorehistory r
        INNER JOIN LatestRestoreDate l
            ON r.destination_database_name = l.DatabaseName
           AND r.restore_date = l.LastRestoreDate
    )
    INSERT INTO DBA.dbo.BackupValidationRestore
        (DatabaseName, RestoreType, RestoreStart, RestoreEnd, RestoreDurationSec, DatabaseSizeGB, RunDate)
    SELECT 
        l.DatabaseName,
        'FULL+LOG_CHAIN',
        MIN(l.RestoreStart) AS RestoreStart,
        MAX(l.RestoreEnd)   AS RestoreEnd,
        DATEDIFF(SECOND, MIN(l.RestoreStart), MAX(l.RestoreEnd)) AS RestoreDurationSec,
        CAST(SUM(mf.size) * 8.0 / 1024 / 1024 AS DECIMAL(10,2)) AS DatabaseSizeGB,
        SYSDATETIME()
    FROM LastChain l
    JOIN sys.databases d ON d.name = l.DatabaseName
    JOIN sys.master_files mf ON mf.database_id = d.database_id
    GROUP BY l.DatabaseName
    HAVING MAX(l.RestoreEnd) IS NOT NULL;
END
GO

------------dbo.BackupValidationRestore table that stores output from above stored procedure. Please note, that depends on what system you use for restore, some data may be missing, like RestoreEnd column, it may be empty. 
------------For next step (view creation) you have to pick columns that are valid for your system
USE [DBA]
GO

CREATE TABLE [dbo].[BackupValidationRestore](

	ValidationID INT IDENTITY(1,1) NOT NULL,
	DatabaseName SYSNAME NOT NULL,
	RestoreType NVARCHAR(20) NOT NULL,
	RestoreStart DATETIME2(7) NOT NULL,
	RestoreEnd DATETIME2(7) NULL,
	RestoreDurationSec INT NULL,
	DatabaseSizeGB DECIMAL(10, 2) NULL,
	RunDate DATETIME2(7) NOT NULL,
)


---Task2: Database view creation that is selecting and joining all required that for report that are stored inside above tables
------------dbo.vw_BackupValidationResults view creation
USE [DBA]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE OR ALTER  VIEW [dbo].[vw_BackupValidationResults]AS
WITH LatestCHECKDB AS
(
    SELECT *
    FROM
    (
        SELECT *,
               ROW_NUMBER() OVER (PARTITION BY DatabaseName, StepName ORDER BY RunDate DESC) AS rn
        FROM DBA.dbo.BackupValidationCHECKDB
    ) t
    WHERE rn = 1
),
LatestPerfTest AS
(
    SELECT *
    FROM
    (
        SELECT *,
               ROW_NUMBER() OVER (PARTITION BY DatabaseName, StepName ORDER BY RunDate DESC) AS rn
        FROM DBA.dbo.BackupValidationPerfTest
    ) t
    WHERE rn = 1
),
LatestRestore AS
(
    SELECT *
    FROM
    (
        SELECT *,
               ROW_NUMBER() OVER (PARTITION BY DatabaseName ORDER BY RunDate DESC) AS rn
        FROM DBA.dbo.BackupValidationRestore
    ) t
    WHERE rn = 1
)
SELECT
    db.name AS DatabaseName,

    -- CHECKDB columns
    c.StepResult       AS CHECKDB_Result,
    c.DurationMs       AS CHECKDB_DurationMs,
    c.OutputMsg        AS CHECKDB_OutputMsg,
    c.RunDate          AS CHECKDB_RunDate,

    -- PerfTest columns
    p.StepName         AS PerfTest_StepName,
    p.StepResult       AS PerfTest_Result,
    p.DurationMs       AS PerfTest_DurationMs,
    p.OutputMsg        AS PerfTest_OutputMsg,
    p.RunDate          AS PerfTest_RunDate,

    -- Restore metrics
    r.RestoreType        AS Restore_Type,
    r.DatabaseSizeGB     AS Restore_SizeGB,
    r.RestoreStart       AS Restore_StartDate

FROM sys.databases db
LEFT JOIN LatestCHECKDB c
    ON db.name = c.DatabaseName
LEFT JOIN LatestPerfTest p
    ON db.name = p.DatabaseName
LEFT JOIN LatestRestore r
    ON db.name = r.DatabaseName
WHERE db.database_id > 4      -- cutting system databases (master, model, msdb, tempdb)
  AND db.name <> 'DBA';       -- cutting your database (in my example it's DBA)
GO

---Task5: SQL Server job creation that automates whole process. It's build with separated steps. Step1) Database integrity check Step2) Last restore check Step3) Inserting integrity check into dedicated table Step4) Performance Test
---Step 5) CommandLog table cleanup (set for 30 days retention to keep DBA database as small as possible) Step6) Mail sending (to selected recipients. WARNING! To use that step, DatabaseMail service has to be enabled and configured with your company settings)
------------DBA - RestoredDB_Test_and_SummaryMail job creation script
USE [msdb]
GO

/****** Object:  Job [DBA - RestoredDB_Test_and_SummaryMail]    Script Date: 9/5/2025 2:26:49 PM ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [[Uncategorized (Local)]]    Script Date: 9/5/2025 2:26:49 PM ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'[Uncategorized (Local)]' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'[Uncategorized (Local)]'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'DBA - RestoredDB_Test_and_SummaryMail', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'This job has been created to test database integrity and to perform performance test after restore using Rubrik', 
		@category_name=N'[Uncategorized (Local)]', 
		@owner_login_name=N'JACKSONLEWIS\Brodkab', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Database integrity check sp run]    Script Date: 9/5/2025 2:26:50 PM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Database integrity check sp run', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'EXEC dbo.DatabaseIntegrityCheck
	@Databases = ''USER_DATABASES, -DBA'',
	@CheckCommands = ''CHECKDB'',
	@LogToTable = ''Y'';', 
		@database_name=N'DBA', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Last restore check]    Script Date: 9/5/2025 2:26:50 PM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Last restore check', 
		@step_id=2, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'EXEC dbo.LastRestoreCheck', 
		@database_name=N'DBA', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Inserting integrity check results into destination table]    Script Date: 9/5/2025 2:26:50 PM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Inserting integrity check results into destination table', 
		@step_id=3, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'INSERT INTO DBA.dbo.BackupValidationCHECKDB (DatabaseName, StepName, StepResult, OutputMsg, RunDate)
	SELECT
		DatabaseName,
		''DBCC_CHECKDB'',
		CASE WHEN ErrorNumber = 0 THEN ''PASS'' ELSE ''FAIL''END,
		ISNULL(ErrorMessage, ''DBCC_CHECKDB completed successfully''),
		EndTime
	FROM DBA.dbo.CommandLog
	WHERE CommandType = ''DBCC_CHECKDB'' AND EndTime > DATEADD(DAY, -1, SYSDATETIME());', 
		@database_name=N'DBA', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Performance Test]    Script Date: 9/5/2025 2:26:50 PM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Performance Test', 
		@step_id=4, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'EXEC DBA.dbo.RunPerfTests_AutoTablePick @TopTables = 3;', 
		@database_name=N'DBA', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [CommanLog table cleanup]    Script Date: 9/5/2025 2:26:50 PM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'CommanLog table cleanup', 
		@step_id=5, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'DELETE FROM DBA.dbo.CommandLog WHERE StartTime < DATEADD(DAY, -30, SYSDATETIME());', 
		@database_name=N'DBA', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Mail sending]    Script Date: 9/5/2025 2:26:50 PM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Mail sending', 
		@step_id=6, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'IF OBJECT_ID(''tempdb..#TempFinalData'') IS NOT NULL
    DROP TABLE #TempFinalData;

SELECT DatabaseName,
       CHECKDB_Result,
       CHECKDB_OutputMsg,
       CHECKDB_RunDate,
       PerfTest_StepName,
       PerfTest_Result,
       PerfTest_DurationMs,
       PerfTest_OutputMsg,
       PerfTest_RunDate,
	   Restore_Type,
       Restore_SizeGB,
	   Restore_StartDate
INTO #TempFinalData
FROM [DBA].[dbo].[vw_BackupValidationResults]


---This step is creating mail body and sending mail to provided recipients

DECLARE @EmailRecipient NVARCHAR(255) = N''brodkab@jacksonlewis.com;singha@jacksonlewis.com;wilczekm@jacksonlewis.com'';		--Enter your recipients
DECLARE @EmailSubject NVARCHAR(255) = N''SQL Database restore summary'';	--Enter name of mail subject
DECLARE @EmailBody NVARCHAR(MAX);
DECLARE @ProfileName NVARCHAR(255) = N''RestoredDB_Summary''
SELECT @ProfileName = p.name FROM msdb.dbo.sysmail_principalprofile AS pp JOIN msdb.dbo.sysmail_profile AS p ON pp.profile_id = p.profile_id
WHERE pp.is_default = 1;

SELECT @EmailBody
		= N''<html>'' 
			+ N''<head>'' 
				+ N''<style>'' 
					+ N''table {border-collapse: collapse;}''
					+ N''th, td {border: 1px solid black; padding: 5px;}'' 
				+ N''</style>'' 
			+ N''</head>'' 
			+ N''<body>''
				+ N''<h2>SQL Database restore summary</h2>'' 
				+ N''<table>'' 
					+ N''<tr>'' 
						+ N''<th>DatabaseName</th>''
						+ N''<th>CHECKDB_Result</th>''
						+ N''<th>CHECKDB_OutputMsg</th>''
						+ N''<th>CHECKDB_RunDate</th>''
						+ N''<th>PerfTest_StepName</th>''
						+ N''<th>PerfTest_Result</th>''
						+ N''<th>PerfTest_DurationMs</th>'' 
						+ N''<th>PerfTest_OutputMsg</th>''
						+ N''<th>PerfTest_RunDate</th>''
						+ N''<th>Restore_Type</th>''
						+ N''<th>Restore_SizeGB</th>''
						+ N''<th>Restore_StartDate</th>''
					+ N''</tr>'';

SELECT @EmailBody
		= @EmailBody 
				+ N''<tr>'' 
					+ N''<td>'' + ISNULL(CAST(DatabaseName AS NVARCHAR(MAX)), '''') + N''</td>''
					+ N''<td>'' + ISNULL(CAST(CHECKDB_Result AS NVARCHAR(MAX)), '''') + N''</td>'' 
					+ N''<td>'' + ISNULL(CAST(CHECKDB_OutputMsg AS NVARCHAR(MAX)), '''') + N''</td>''
					+ N''<td>'' + ISNULL(CONVERT(NVARCHAR(30), CHECKDB_RunDate, 120), '''') + N''</td>''
					+ N''<td>'' + ISNULL(CAST(PerfTest_StepName AS NVARCHAR(MAX)), '''') + N''</td>''
					+ N''<td>'' + ISNULL(CAST(PerfTest_Result AS NVARCHAR(MAX)), '''') + N''</td>'' 
					+ N''<td>'' + ISNULL(CAST(PerfTest_DurationMs AS NVARCHAR(MAX)), '''') + N''</td>'' 
					+ N''<td>'' + ISNULL(CAST(PerfTest_OutputMsg AS NVARCHAR(MAX)), '''') + N''</td>''
					+ N''<td>'' + ISNULL(CONVERT(NVARCHAR(30), PerfTest_RunDate, 120), '''') + N''</td>''
					+ N''<td>'' + ISNULL(CAST(Restore_Type AS NVARCHAR(MAX)), '''') + N''</td>''
					+ N''<td>'' + ISNULL(CAST(Restore_SizeGB AS NVARCHAR(MAX)), '''') + N''</td>''
					+ N''<td>'' + ISNULL(CONVERT(NVARCHAR(30), Restore_StartDate, 120), '''') + N''</td>''

FROM #TempFinalData

SET @EmailBody = @EmailBody + N''</table>'' + N''</body>'' + N''</html>'';

SELECT @EmailBody;

---Executing stored procedure for email sending

EXEC msdb.dbo.sp_send_dbmail
    @profile_name = @ProfileName,		--''YourMailProfile'', Replace with the name of your Database Mail profile
    @recipients = @EmailRecipient,
    @subject = @EmailSubject,
    @body = @EmailBody,
    @body_format = ''HTML''', 
		@database_name=N'master', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'One-time execution', 
		@enabled=0, 
		@freq_type=1, 
		@freq_interval=0, 
		@freq_subday_type=0, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20250905, 
		@active_end_date=99991231, 
		@active_start_time=30000, 
		@active_end_time=235959, 
		@schedule_uid=N'8ff23535-6694-42bd-a2ad-673758999f26'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO
