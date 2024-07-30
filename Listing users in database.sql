USE [database name];

SELECT
	dp.name AS DatabaseUserName,
	dp.type_desc AS UserType,
	sp.name AS LoginName,
	sp.type_desc AS LoginType,
	dp.create_date,
	dp.modify_date
FROM
	sys.database_principals dp
LEFT JOIN
	 sys.server_principals sp
ON
	dp.sid=sp.sid
WHERE
	dp.type IN ('S', 'U', 'G', 'A') AND dp.name NOT IN ('INFORMATION_SCHEMA', 'sys', 'guest', 'dbo')
ORDER BY dp.name
