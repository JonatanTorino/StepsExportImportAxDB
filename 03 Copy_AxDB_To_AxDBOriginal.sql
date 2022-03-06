USE [master]
RESTORE DATABASE [AxDBOriginal]
FROM  DISK = N'J:\MSSQL_BACKUP\AxDB_BackupRestoreTool\Axx-Dev03-B1-1_AxDB_20210707_160245_AxDB_Original.bak' 
WITH  FILE = 1,  
MOVE N'AXDBBuild_Data' TO N'G:\MSSQL_DATA\AxDBOriginal.mdf', 
MOVE N'AXDBBuild_Log' TO N'H:\MSSQL_LOGS\AxDBOriginal_Log.ldf',  
NOUNLOAD,  
STATS = 5

GO

