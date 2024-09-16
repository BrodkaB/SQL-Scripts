---Checking tempdb files (how many of them are in use and their names)---

USE tempdb;
GO
SELECT 
    file_id, 
    name AS LogicalFileName, 
    size * 8 / 1024 AS SizeMB,
    type_desc
FROM sys.master_files
WHERE database_id = DB_ID('tempdb');
GO

---Tempdb files shrinking---

USE tempdb;
GO
-- Shrink File 1
DBCC SHRINKFILE (tempdev, 1024); -- tempdev is the primary data file, shrink to 1 GB (adjust as needed)
GO
-- Shrink File 2
DBCC SHRINKFILE (temp2, 1024); -- Adjust the name based on the results from the previous step
GO
-- Shrink File 3
DBCC SHRINKFILE (temp3, 1024); -- Shrinking each file to 1 GB, adjust as per your needs
GO
-- Shrink File 4
DBCC SHRINKFILE (temp4, 1024); 
GO
-- Shrink File 5
DBCC SHRINKFILE (temp5, 1024); 
GO
-- Shrink File 6
DBCC SHRINKFILE (temp6, 1024); 
GO
-- Shrink File 7
DBCC SHRINKFILE (temp7, 1024); 
GO
-- Shrink File 8
DBCC SHRINKFILE (temp8, 1024); 
GO
