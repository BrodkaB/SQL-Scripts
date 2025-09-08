----This short script will allow you to track database log files growth in case of log backup issues
---Option1: Showing you all records from table that can be filtered with "WHERE CaptureTIME"

INSERT INTO msdb.dbo.LogSpaceMonitor (DatabaseName, LogSizeMB, LogSpaceUsed, Status)
EXEC ('dbcc sqlperf(logspace)')
SELECT * From msdb.dbo.LogSpaceMonitor
WHERE DatabaseName IN ('database names')
ORDER BY CaptureTime DESC

---Option2: Showing you only the most recent records

INSERT INTO msdb.dbo.LogSpaceMonitor (DatabaseName, LogSizeMB, LogSpaceUsed, Status)
EXEC ('dbcc sqlperf(logspace)')
SELECT *
FROM msdb.dbo.LogSpaceMonitor l
WHERE l.DatabaseName IN ('database names')
  AND l.CaptureTime = (
        SELECT MAX(CaptureTime) 
        FROM msdb.dbo.LogSpaceMonitor
    )
ORDER BY l.CaptureTime DESC;
