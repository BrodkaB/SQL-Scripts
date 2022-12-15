----step 1 checking if instant file initialization is enabled
SELECT [servicename], [instant_file_initialization_enabled], * 
FROM sys.[dm_server_services]

----step 2 checking names of current databse files
use [Databasename]
go
select db_name() as 'DatabaseName'
       ,df.name as 'FileName'
          ,df.type_desc
          ,ds.name as 'FileGroupName'
          ,cast(df.size/128. as numeric(12,2)) as 'FileSize(MB)'
          ,cast(FILEPROPERTY(df.name,'SpaceUsed')/128. as numeric(12,2))as 'FileSpaceused(MB)'
          ,cast((FILEPROPERTY(df.name,'SpaceUsed')/128.) /  (df.size/128.) * 100 as numeric(12,2)) as 'FilePercentUsed'
          ,cast(df.size/128. - (FILEPROPERTY(df.name,'SpaceUsed')/128.) as numeric(12,2)) as 'FileFreeSpace(MB)'
          ,cast((df.size/128 - FILEPROPERTY(df.name,'SpaceUsed')/128)/(df.size/128.)*100 as numeric(12,2)) as 'FilePercentFree'
		  ,cast(df.growth/128. as numeric(12,2)) as 'FileGrowth'
          ,df.physical_name
  from sys.database_files df
  left join sys.data_spaces ds
    on  ds.data_space_id = df.data_space_id
    
---step 3 creating new database file
ALTER DATABASE [AdventureWorksDW2016] ADD FILE (NAME='AdventureWorksDW2016_Data2', FILENAME='L:\DatabasesTest\AdventureWorksDW2016_Data2.ndf', SIZE=105MB, FILEGROWTH=5MB)

---optional step if new filegroup is needed
alter database [AdventureWorks2016]
add filegroup test123;
go
alter database [AdventureWorks2016]
add file
(
	name = 'AdventureWorks2016_Data2',
	filename = 'L:\DatabasesTest\AdventureWorks2016_Data2.ndf',
	size = 100MB,
	filegrowth = 5MB
	)
to filegroup test123;
go
