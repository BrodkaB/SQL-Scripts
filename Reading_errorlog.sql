---creating temp table
CREATE TABLE #Temptable (
	LogDate DATETIME,
	ProcessInfo [nvarchar](100) NULL,
	Text [nvarchar](1000) NULL
	)
GO

---inserting sp. Provide errorlog file number after sp_readerrorlog
INSERT INTO #Temptable
(
	LogDate,
	ProcessInfo,
	Text
)
EXEC sp_readerrorlog
GO

--output to table
SELECT * FROM #Temptable
WHERE LogDate >= '2024-02-29 13:00:00.000' AND LogDate <= '2024-02-29 14:00:00.000' AND Text like '%create file%'
ORDER BY LogDate asc

---listing configuration for errog log files (variables etc)

exec sp_help 'sp_readerrorlog'