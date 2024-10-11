DECLARE @FileName varchar(1000)
SELECT @FileName = (SELECT 'Z:\Backup\4Всячина\[FileStore]' + convert(varchar(500), GetDate(),112) + '.bak')
BACKUP DATABASE [FileStore] TO DISK = @FileName WITH  RETAINDAYS = 1, NOFORMAT, NOINIT,  NAME = 'FileStore', SKIP, NOREWIND, NOUNLOAD, NO_COMPRESSION,  STATS = 10