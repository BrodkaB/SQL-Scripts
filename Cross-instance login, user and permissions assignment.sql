
/*
    Deployment: svc_AzCatalyst
    Purpose: Azure Migration Assessment
    Scope:
      - All databases except tempdb and model
      - Skip AG secondary replicas
      - Include master and msdb
      - Idempotent deployment

    0 = Preview only
    1 = Apply changes
*/

USE master;
GO

SET NOCOUNT ON;

DECLARE @LoginName sysname =
    N'LoginName';

DECLARE @ApplyChanges bit = 0; -- CHANGE TO 1 AFTER PREVIEW

/*==============================================================
  1. Deployment log
==============================================================*/

IF OBJECT_ID('tempdb..#DeploymentLog') IS NOT NULL
    DROP TABLE #DeploymentLog;

CREATE TABLE #DeploymentLog
(
    LogDate datetime2(0) DEFAULT SYSDATETIME(),
    DatabaseName sysname NULL,
    Operation nvarchar(200),
    Status nvarchar(30),
    Details nvarchar(2000)
);

/*==============================================================
  2. Create LOGIN
==============================================================*/

BEGIN TRY

    IF SUSER_ID(@LoginName) IS NULL
    BEGIN
        IF @ApplyChanges = 1
        BEGIN
            CREATE LOGIN [LoginName]
            FROM WINDOWS;
        END;

        INSERT INTO #DeploymentLog
        VALUES
        (
            DEFAULT, NULL, 'CREATE LOGIN',
            IIF(@ApplyChanges = 1, 'SUCCESS', 'PREVIEW'),
            'Login does not exist.'
        );
    END
    ELSE
    BEGIN
        IF NOT EXISTS
        (
            SELECT 1
            FROM sys.server_principals
            WHERE name = @LoginName
              AND type = 'U'
        )
        BEGIN
            THROW 50001,
                'Existing principal is not a Windows login. Deployment stopped.',
                1;
        END;

        INSERT INTO #DeploymentLog
        VALUES
        (
            DEFAULT, NULL, 'CREATE LOGIN',
            'EXISTS', 'Windows login already exists.'
        );
    END;

END TRY
BEGIN CATCH

    INSERT INTO #DeploymentLog
    VALUES
    (
        DEFAULT, NULL, 'CREATE LOGIN',
        'ERROR', ERROR_MESSAGE()
    );

END CATCH;

/* Stop if LOGIN is unavailable */

IF @ApplyChanges = 1 AND SUSER_ID(@LoginName) IS NULL
BEGIN
    INSERT INTO #DeploymentLog
    VALUES
    (
        DEFAULT, NULL, 'DEPLOYMENT',
        'ABORTED', 'Login is not available. Remaining operations skipped.'
    );

    SELECT * FROM #DeploymentLog;
    RETURN;
END;

/*==============================================================
  3. Server-level permissions
==============================================================*/

DECLARE @ServerPermissions TABLE
(
    PermissionName sysname
);

INSERT INTO @ServerPermissions
VALUES
    ('VIEW SERVER STATE'),
    ('VIEW ANY DEFINITION');

DECLARE @Permission sysname;
DECLARE @SQL nvarchar(max);

DECLARE ServerPermissionCursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT PermissionName
    FROM @ServerPermissions;

OPEN ServerPermissionCursor;

FETCH NEXT FROM ServerPermissionCursor
INTO @Permission;

WHILE @@FETCH_STATUS = 0
BEGIN

    BEGIN TRY

        SET @SQL =
            N'GRANT ' + @Permission +
            N' TO ' + QUOTENAME(@LoginName) + N';';

        IF @ApplyChanges = 1
            EXEC sys.sp_executesql @SQL;

        INSERT INTO #DeploymentLog
        VALUES
        (
            DEFAULT, NULL, 'SERVER PERMISSION: ' + @Permission,
            IIF(@ApplyChanges = 1, 'SUCCESS', 'PREVIEW'),
            'Server-level permission.'
        );

    END TRY
    BEGIN CATCH

        INSERT INTO #DeploymentLog
        VALUES
        (
            DEFAULT, NULL, 'SERVER PERMISSION: ' + @Permission,
            'ERROR', ERROR_MESSAGE()
        );

    END CATCH;

    FETCH NEXT FROM ServerPermissionCursor
    INTO @Permission;

END;

CLOSE ServerPermissionCursor;
DEALLOCATE ServerPermissionCursor;

/*==============================================================
  4. Database processing - FIXED VERSION
==============================================================*/

DECLARE @DatabaseName sysname;
DECLARE @DatabaseState nvarchar(60);
DECLARE @IsReadOnly bit;
DECLARE @GroupDatabaseId uniqueidentifier;
DECLARE @IsPrimary int;

DECLARE DatabaseCursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT
        name,
        state_desc,
        is_read_only,
        group_database_id
    FROM sys.databases
    WHERE database_id > 0
      AND name NOT IN ('tempdb', 'model')
      AND source_database_id IS NULL
    ORDER BY name;

OPEN DatabaseCursor;

FETCH NEXT FROM DatabaseCursor
INTO @DatabaseName, @DatabaseState,
     @IsReadOnly, @GroupDatabaseId;

WHILE @@FETCH_STATUS = 0
BEGIN

    IF @DatabaseState <> 'ONLINE'
    BEGIN
        INSERT INTO #DeploymentLog
        VALUES
        (
            DEFAULT, @DatabaseName, 'DATABASE PROCESSING',
            'SKIPPED', 'Database is not ONLINE.'
        );
    END

    ELSE IF @IsReadOnly = 1
    BEGIN
        INSERT INTO #DeploymentLog
        VALUES
        (
            DEFAULT, @DatabaseName, 'DATABASE PROCESSING',
            'SKIPPED', 'Database is READ_ONLY.'
        );
    END

    ELSE
    BEGIN

        SET @IsPrimary = NULL;

        IF @GroupDatabaseId IS NOT NULL
        BEGIN
            SET @IsPrimary =
                sys.fn_hadr_is_primary_replica(@DatabaseName);

            IF ISNULL(@IsPrimary, 0) <> 1
            BEGIN
                INSERT INTO #DeploymentLog
                VALUES
                (
                    DEFAULT, @DatabaseName,
                    'DATABASE PROCESSING',
                    'SKIPPED',
                    'AG database is not confirmed as PRIMARY.'
                );
            END;
        END;

        IF @GroupDatabaseId IS NULL
           OR @IsPrimary = 1
        BEGIN

            BEGIN TRY

                SET @SQL = N'
USE ' + QUOTENAME(@DatabaseName) + N';

DECLARE @LoginSID varbinary(85) =
    SUSER_SID(@LoginName);

IF EXISTS
(
    SELECT 1
    FROM sys.database_principals
    WHERE name = @LoginName
      AND sid <> @LoginSID
)
BEGIN
    THROW 50002,
        ''Existing USER has a different SID than LOGIN.'',
        1;
END;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.database_principals
    WHERE name = @LoginName
)
BEGIN
    IF @ApplyChanges = 1
    BEGIN
        CREATE USER ' + QUOTENAME(@LoginName) +
        N' FOR LOGIN ' + QUOTENAME(@LoginName) + N';
    END;
END;

IF @ApplyChanges = 1
BEGIN
    GRANT SELECT
    ON OBJECT::sys.sql_expression_dependencies
    TO ' + QUOTENAME(@LoginName) + N';

    GRANT VIEW DATABASE STATE
    TO ' + QUOTENAME(@LoginName) + N';
END;
';

                EXEC sys.sp_executesql
                    @SQL,
                    N'@LoginName sysname, @ApplyChanges bit',
                    @LoginName = @LoginName,
                    @ApplyChanges = @ApplyChanges;

                INSERT INTO #DeploymentLog
                VALUES
                (
                    DEFAULT, @DatabaseName,
                    'CREATE USER / DATABASE PERMISSIONS',
                    IIF(@ApplyChanges = 1, 'SUCCESS', 'PREVIEW'),
                    'USER and database permissions processed.'
                );

                IF @DatabaseName = 'master'
                   AND @ApplyChanges = 1
                BEGIN

                    GRANT EXECUTE
                    ON OBJECT::sys.xp_regenumkeys
                    TO [LoginName];

                    GRANT EXECUTE
                    ON OBJECT::sys.xp_instance_regread
                    TO [LoginName];

                END;

            END TRY
            BEGIN CATCH

                INSERT INTO #DeploymentLog
                VALUES
                (
                    DEFAULT, @DatabaseName,
                    'CREATE USER / DATABASE PERMISSIONS',
                    'ERROR', ERROR_MESSAGE()
                );

            END CATCH;

        END;

    END;

    FETCH NEXT FROM DatabaseCursor
    INTO @DatabaseName, @DatabaseState,
         @IsReadOnly, @GroupDatabaseId;

END;

CLOSE DatabaseCursor;
DEALLOCATE DatabaseCursor;

/*==============================================================
  5. msdb specific permissions
==============================================================*/

IF @DatabaseState IS NOT NULL
BEGIN

    DECLARE @MsdbObjects TABLE
    (
        SchemaName sysname,
        ObjectName sysname,
        PermissionName sysname
    );

    INSERT INTO @MsdbObjects
    VALUES
        ('dbo', 'agent_datetime', 'EXECUTE'),
        ('dbo', 'sysjobsteps', 'SELECT'),
        ('dbo', 'syssubsystems', 'SELECT'),
        ('dbo', 'sysjobhistory', 'SELECT'),
        ('dbo', 'syscategories', 'SELECT'),
        ('dbo', 'sysjobs', 'SELECT'),
        ('dbo', 'sysmaintplan_plans', 'SELECT'),
        ('dbo', 'syscollector_collection_sets', 'SELECT'),
        ('dbo', 'sysmail_profile', 'SELECT'),
        ('dbo', 'sysmail_profileaccount', 'SELECT'),
        ('dbo', 'sysmail_account', 'SELECT');

    DECLARE @SchemaName sysname;
    DECLARE @ObjectName sysname;

    DECLARE @MsdbPermissionCursor CURSOR;

    SET @MsdbPermissionCursor = CURSOR LOCAL FAST_FORWARD FOR
        SELECT SchemaName, ObjectName, PermissionName
        FROM @MsdbObjects;

    OPEN @MsdbPermissionCursor;

    FETCH NEXT FROM @MsdbPermissionCursor
    INTO @SchemaName, @ObjectName, @Permission;

    WHILE @@FETCH_STATUS = 0
    BEGIN

        BEGIN TRY

            SET @SQL = N'
USE msdb;

IF OBJECT_ID(N''' +
                QUOTENAME(@SchemaName) + N'.' +
                QUOTENAME(@ObjectName) + N''') IS NULL
BEGIN
    THROW 50003, ''Object does not exist in msdb.'', 1;
END;

GRANT ' + @Permission +
                N' ON OBJECT::' +
                QUOTENAME(@SchemaName) + N'.' +
                QUOTENAME(@ObjectName) +
                N' TO ' + QUOTENAME(@LoginName) + N';';

            IF @ApplyChanges = 1
                EXEC sys.sp_executesql @SQL;

            INSERT INTO #DeploymentLog
            VALUES
            (
                DEFAULT, 'msdb',
                @Permission + ' ' + @SchemaName + '.' + @ObjectName,
                IIF(@ApplyChanges = 1, 'SUCCESS', 'PREVIEW'),
                'msdb object permission.'
            );

        END TRY
        BEGIN CATCH

            INSERT INTO #DeploymentLog
            VALUES
            (
                DEFAULT, 'msdb',
                @Permission + ' ' + @SchemaName + '.' + @ObjectName,
                'ERROR', ERROR_MESSAGE()
            );

        END CATCH;

        FETCH NEXT FROM @MsdbPermissionCursor
        INTO @SchemaName, @ObjectName, @Permission;

    END;

    CLOSE @MsdbPermissionCursor;
    DEALLOCATE @MsdbPermissionCursor;

END;

/*==============================================================
  6. Final report
==============================================================*/

SELECT
    LogDate,
    DatabaseName,
    Operation,
    Status,
    Details
FROM #DeploymentLog
ORDER BY
    LogDate,
    DatabaseName,
    Operation;

SELECT
    Status,
    COUNT(*) AS TotalOperations
FROM #DeploymentLog
GROUP BY Status
ORDER BY Status;

GO

--- post implementation check
---1. Login verification
USE master;
GO

DECLARE @LoginName sysname =
    N'LoginName';

SELECT
    sp.name AS LoginName,
    sp.type_desc,
    sp.is_disabled,
    sp.sid,
    perm.permission_name,
    perm.state_desc
FROM sys.server_principals sp
LEFT JOIN sys.server_permissions perm
    ON sp.principal_id = perm.grantee_principal_id
WHERE sp.name = @LoginName;
GO

---2. Database users verification
DECLARE @LoginName sysname =
    N'LoginName';

CREATE TABLE #UserCheck
(
    DatabaseName sysname,
    UserName sysname NULL,
    UserSID varbinary(85) NULL,
    LoginSID varbinary(85) NULL,
    SID_Match bit NULL,
    Status varchar(30)
);

DECLARE @DB sysname;
DECLARE @SQL nvarchar(max);

DECLARE db_cursor CURSOR LOCAL FAST_FORWARD FOR
SELECT name
FROM sys.databases
WHERE database_id > 0
  AND name NOT IN ('tempdb', 'model')
  AND state_desc = 'ONLINE'
  AND source_database_id IS NULL;

OPEN db_cursor;

FETCH NEXT FROM db_cursor INTO @DB;

WHILE @@FETCH_STATUS = 0
BEGIN

    SET @SQL = N'
    USE ' + QUOTENAME(@DB) + N';

    INSERT INTO #UserCheck
    SELECT
        DB_NAME(),
        dp.name,
        dp.sid,
        SUSER_SID(@LoginName),
        CASE
            WHEN dp.sid = SUSER_SID(@LoginName) THEN 1
            ELSE 0
        END,
        CASE
            WHEN dp.principal_id IS NULL THEN ''MISSING''
            WHEN dp.sid = SUSER_SID(@LoginName) THEN ''OK''
            ELSE ''SID MISMATCH''
        END
    FROM (SELECT 1 AS Dummy) x
    LEFT JOIN sys.database_principals dp
        ON dp.name = @LoginName;
    ';

    EXEC sys.sp_executesql
        @SQL,
        N'@LoginName sysname',
        @LoginName = @LoginName;

    FETCH NEXT FROM db_cursor INTO @DB;

END;

CLOSE db_cursor;
DEALLOCATE db_cursor;

SELECT *
FROM #UserCheck
ORDER BY DatabaseName;

DROP TABLE #UserCheck;
GO


---3. Database permissions verification 
DECLARE @LoginName sysname =
    N'LoginName';

CREATE TABLE #PermissionCheck
(
    DatabaseName sysname,
    PermissionName sysname,
    StateDesc nvarchar(60),
    Status varchar(20)
);

DECLARE @DB sysname;
DECLARE @SQL nvarchar(max);

DECLARE db_cursor CURSOR LOCAL FAST_FORWARD FOR
SELECT name
FROM sys.databases
WHERE database_id > 0
  AND name NOT IN ('tempdb', 'model')
  AND state_desc = 'ONLINE'
  AND source_database_id IS NULL;

OPEN db_cursor;

FETCH NEXT FROM db_cursor INTO @DB;

WHILE @@FETCH_STATUS = 0
BEGIN

    SET @SQL = N'
    USE ' + QUOTENAME(@DB) + N';

    INSERT INTO #PermissionCheck
    SELECT
        DB_NAME(),
        p.permission_name,
        p.state_desc,
        CASE
            WHEN p.state_desc = ''GRANT'' THEN ''OK''
            ELSE ''CHECK''
        END
    FROM sys.database_permissions p
    INNER JOIN sys.database_principals dp
        ON p.grantee_principal_id = dp.principal_id
    WHERE dp.name = @LoginName
      AND p.permission_name IN
          (''VIEW DATABASE STATE'', ''SELECT'');
    ';

    EXEC sys.sp_executesql
        @SQL,
        N'@LoginName sysname',
        @LoginName = @LoginName;

    FETCH NEXT FROM db_cursor INTO @DB;

END;

CLOSE db_cursor;
DEALLOCATE db_cursor;

SELECT *
FROM #PermissionCheck
ORDER BY DatabaseName, PermissionName;

DROP TABLE #PermissionCheck;
GO

---4. msdb verification
USE msdb;
GO

SELECT
    dp.name AS UserName,
    o.name AS ObjectName,
    p.permission_name,
    p.state_desc
FROM sys.database_permissions p
JOIN sys.database_principals dp
    ON p.grantee_principal_id = dp.principal_id
JOIN sys.objects o
    ON p.major_id = o.object_id
WHERE dp.name = N'LoginName'
ORDER BY o.name, p.permission_name;
