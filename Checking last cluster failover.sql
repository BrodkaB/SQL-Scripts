SELECT sqlserver_start_time AS LastInstanceStart, DATEDIFF(HOUR, sqlserver_start_time, GETDATE()) AS HoursSinceFailover
FROM sys.dm_os_sys_info;
