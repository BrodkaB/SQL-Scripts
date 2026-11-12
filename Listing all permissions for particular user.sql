
USE master;
GO

DECLARE @LoginName SYSNAME = N'DOMAIN\UserName';

DROP TABLE IF EXISTS #DbUsers;
DROP TABLE IF EXISTS #DbPermissions;
DROP TABLE IF EXISTS #ServerPermissions;
DROP TABLE IF EXISTS #ServerRoles;

CREATE TABLE #DbUsers
(
    DatabaseName SYSNAME,
    DatabaseUser SYSNAME,
    UserType NVARCHAR(60),
    AuthenticationType NVARCHAR(60),
    DatabaseRole SYSNAME NULL
);

CREATE TABLE #DbPermissions
(
    DatabaseName SYSNAME,
    DatabaseUser SYSNAME,
    PermissionSource SYSNAME,
    PermissionState NVARCHAR(60),
    PermissionName SYSNAME,
    ClassDesc NVARCHAR(60),
    SecurableName NVARCHAR(512),
    ColumnName SYSNAME NULL
);

CREATE TABLE #ServerPermissions
(
    LoginName SYSNAME,
    PermissionName SYSNAME,
    PermissionState NVARCHAR(60),
    ClassDesc NVARCHAR(60)
);

CREATE TABLE #ServerRoles
(
    LoginName SYSNAME,
    ServerRole SYSNAME
);

--------------------------------------------------
-- 1. SERVER LEVEL: role membership
--------------------------------------------------

INSERT INTO #ServerRoles
SELECT
    sp.name,
    sr.name
FROM sys.server_role_members srm
JOIN sys.server_principals sr
    ON sr.principal_id = srm.role_principal_id
JOIN sys.server_principals sp
    ON sp.principal_id = srm.member_principal_id
WHERE sp.name = @LoginName;

--------------------------------------------------
-- 2. SERVER LEVEL: explicit permissions
--------------------------------------------------

INSERT INTO #ServerPermissions
SELECT
    sp.name,
    perm.permission_name,
    perm.state_desc,
    perm.class_desc
FROM sys.server_permissions perm
JOIN sys.server_principals sp
    ON sp.principal_id = perm.grantee_principal_id
WHERE sp.name = @LoginName;

--------------------------------------------------
-- 3. DATABASE LEVEL
--------------------------------------------------

DECLARE @DB SYSNAME;
DECLARE @SQL NVARCHAR(MAX);

DECLARE db_cursor CURSOR LOCAL FAST_FORWARD FOR
SELECT name
FROM sys.databases
WHERE state_desc = 'ONLINE'
  AND database_id > 4
  AND HAS_DBACCESS(name) = 1;

OPEN db_cursor;

FETCH NEXT FROM db_cursor INTO @DB;

WHILE @@FETCH_STATUS = 0
BEGIN

    SET @SQL = N'
    USE ' + QUOTENAME(@DB) + N';

    DECLARE @User SYSNAME;

    SELECT @User = dp.name
    FROM sys.database_principals dp
    JOIN sys.server_principals sp
        ON dp.sid = sp.sid
    WHERE sp.name = @LoginName
      AND dp.type IN (''S'', ''U'', ''G'', ''E'', ''X'');

    IF @User IS NOT NULL
    BEGIN

        -- Database user and role membership

        INSERT INTO #DbUsers
        SELECT
            DB_NAME(),
            dp.name,
            dp.type_desc,
            dp.authentication_type_desc,
            r.name
        FROM sys.database_principals dp
        LEFT JOIN sys.database_role_members drm
            ON drm.member_principal_id = dp.principal_id
        LEFT JOIN sys.database_principals r
            ON r.principal_id = drm.role_principal_id
        WHERE dp.name = @User;

        -- Explicit permissions assigned to user,
        -- database roles or public

        INSERT INTO #DbPermissions
        SELECT
            DB_NAME(),
            @User,
            grantee.name,
            perm.state_desc,
            perm.permission_name,
            perm.class_desc,

            CASE
                WHEN perm.class = 0
                    THEN DB_NAME()

                WHEN perm.class = 1
                    THEN
                        COALESCE(
                            OBJECT_SCHEMA_NAME(perm.major_id),
                            N''''
                        ) + N''.'' +
                        COALESCE(
                            OBJECT_NAME(perm.major_id),
                            N''<unknown>''
                        )

                WHEN perm.class = 3
                    THEN SCHEMA_NAME(perm.major_id)

                WHEN perm.class = 4
                    THEN USER_NAME(perm.major_id)

                ELSE
                    CONVERT(NVARCHAR(128), perm.major_id)
            END,

            CASE
                WHEN perm.class = 1
                     AND perm.minor_id > 0
                THEN COL_NAME(
                    perm.major_id,
                    perm.minor_id
                )
                ELSE NULL
            END

        FROM sys.database_permissions perm

        JOIN sys.database_principals grantee
            ON grantee.principal_id =
               perm.grantee_principal_id

        WHERE
            grantee.name = @User

            OR grantee.name = N''public''

            OR grantee.principal_id IN
            (
                SELECT drm.role_principal_id
                FROM sys.database_role_members drm
                JOIN sys.database_principals member
                    ON member.principal_id =
                       drm.member_principal_id
                WHERE member.name = @User
            );

    END;
    ';

    EXEC sys.sp_executesql
        @SQL,
        N'@LoginName SYSNAME',
        @LoginName = @LoginName;

    FETCH NEXT FROM db_cursor INTO @DB;

END;

CLOSE db_cursor;
DEALLOCATE db_cursor;

--------------------------------------------------
-- 4. RESULTS
--------------------------------------------------

-- Result 1: Database users and roles

SELECT *
FROM #DbUsers
ORDER BY DatabaseName, DatabaseUser, DatabaseRole;

-- Result 2: Database permissions

SELECT *
FROM #DbPermissions
ORDER BY DatabaseName, DatabaseUser,
         PermissionSource, SecurableName;

-- Result 3: Server role membership

SELECT *
FROM #ServerRoles
ORDER BY LoginName, ServerRole;

-- Result 4: Server permissions

SELECT *
FROM #ServerPermissions
ORDER BY LoginName, PermissionName;

--------------------------------------------------
-- CLEANUP (optional)
--------------------------------------------------

-- DROP TABLE IF EXISTS #DbUsers;
-- DROP TABLE IF EXISTS #DbPermissions;
-- DROP TABLE IF EXISTS #ServerPermissions;
-- DROP TABLE IF EXISTS #ServerRoles;
