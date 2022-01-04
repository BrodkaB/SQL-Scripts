use master
go
DECLARE @dbname as sysname
DECLARE @select_string as varchar(4000)
DECLARE @for_string as varchar(4000)
DECLARE @init as bit

DECLARE curs CURSOR FOR
SELECT name FROM sysdatabases

OPEN CURS

FETCH NEXT FROM curs INTO @dbname

SELECT      @select_string = 'SELECT DISTINCT backup_date',
      @for_string = 'FOR database_name IN (',
      @init = 0

WHILE @@FETCH_STATUS = 0
BEGIN
      IF @init = 0
      BEGIN
            SET @init = 1

            SELECT      @select_string = @select_string + ', [' + @dbname + '] as ' + '"' + @dbname +'"',
            @for_string = @for_string +  @dbname
      END
      ELSE
      BEGIN
            SELECT      @select_string = @select_string + ', [' + @dbname + '] as ' + '"' + @dbname +'"',
                  @for_string = @for_string + ', ' + @dbname
      END
      FETCH NEXT FROM curs INTO @dbname
END

CLOSE curs
DEALLOCATE curs

PRINT @select_string
PRINT 'from
      (select isnull(backup_size / (1024 * 1024 * 1024), 0) as backup_size,
      database_name,
      cast(cast(backup_finish_date as varchar(12)) as datetime) as backup_date
      from msdb.dbo.backupset
      where type = ''d'') p
pivot
      (
      sum(backup_size)'
PRINT @for_string
PRINT ')) as pvt 
order by backup_date'
