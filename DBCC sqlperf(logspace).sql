----This short script will allow you to track database log files growth in case of log backup issues

INSERT INTO msdb.dbo.LogSpaceMonitor (DatabaseName, LogSizeMB, LogSpaceUsed, Status)
EXEC ('dbcc sqlperf(logspace)')
SELECT * From msdb.dbo.LogSpaceMonitor
WHERE DatabaseName IN ('database names')
ORDER BY CaptureTime DESC
