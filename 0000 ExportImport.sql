﻿--Version 20220211 V1

--<INICIO> INICIALIZACION VARIABLES
PRINT '--- <INICIALIZACION VARIABLES - Inicio> ---'
	
	DROP TABLE #AxDB_BackupFiles
	CREATE TABLE #AxDB_BackupFiles
		(
			[VarName] VARCHAR(20) PRIMARY KEY,
			[VarValue] VARCHAR(255)
		)
	GO

	--FechaHora formatedo a texto
	declare @dateTime nvarchar(100) = replace(replace(replace(convert(varchar, getdate(), 20), '-', ''), ':', ''), ' ', '_')
	declare @WorkFolder nvarchar(255)			= N'J:\MSSQL_BACKUP\AxDB_BackupRestoreTool\'

	INSERT INTO #AxDB_BackupFiles SELECT 'BackupCurrentAxDB', @WorkFolder + HOST_NAME() + 'ExportImport_AxDBPrevStart_' + @dateTime + '.bak'
	INSERT INTO #AxDB_BackupFiles SELECT 'BackupToStageDB'	, @WorkFolder + HOST_NAME() + 'ExportImport_StagingAxDBImported_' + @dateTime + '.bak'

--<<<<<<<<CAMBIAR EL NOMBRE DEL ARCHIVO>>>>>>>>
----------------------------------------------------------------------------------------------
	INSERT INTO #AxDB_BackupFiles SELECT 'BackupToImport'	, @WorkFolder + 'FBM TST01 B1 1_AxDB_20220211_134629_MultiDisc.bak'
----------------------------------------------------------------------------------------------
--<<<<<<<<CAMBIAR EL NOMBRE DEL ARCHIVO>>>>>>>>

	declare @aux nvarchar(255)
	select @aux = VarValue from #AxDB_BackupFiles where VarName = 'BackupCurrentAxDB'
	print @aux
	select @aux = VarValue from #AxDB_BackupFiles where VarName = 'BackupToStageDB'
	print @aux
	select @aux = VarValue from #AxDB_BackupFiles where VarName = 'BackupToImport'
	print @aux
	
--<FIN> INICIALIZACION VARIABLES
--------------------------------------------------------------------------------------
--<INICIO> CREO AxDBOriginal SI NO EXISTE 
PRINT '--- <CREO AxDBOriginal SI NO EXISTE - Inicio> ---'

	IF DB_ID('AxDBOriginal') IS NULL
	BEGIN
		declare @BackupToOriginal nvarchar(255)
		select @BackupToOriginal = VarValue from #AxDB_BackupFiles where VarName = 'BackupCurrentAxDB' --USO la Current AxDB recien respaldada

		ALTER DATABASE [AxDBOriginal] SET OFFLINE WITH ROLLBACK AFTER 1 SECONDS

		USE [master]
		RESTORE DATABASE [AxDBOriginal]
		FROM  DISK = @BackupToOriginal
		WITH  FILE = 1,  
		MOVE N'AXDBBuild_Data' TO N'G:\MSSQL_DATA\AxDBOriginal.mdf', 
		MOVE N'AXDBBuild_Log' TO N'H:\MSSQL_LOGS\AxDBOriginal_Log.ldf',  
		NOUNLOAD,  
		STATS = 5
	
		ALTER DATABASE [AxDBOriginal] SET OFFLINE WITH ROLLBACK AFTER 1 SECONDS
	END
	GO
--<FIN> CREO AxDBOriginal SI NO EXISTE 
--------------------------------------------------------------------------------------
--<INICIO> RESPALDO LA AxDB ACTUAL
PRINT '--- <RESPALDO LA AxDB ACTUA - Inicio> ---'
	
	declare @BackupCurrentAxDB nvarchar(255)
	select @BackupCurrentAxDB = VarValue from #AxDB_BackupFiles where VarName = 'BackupCurrentAxDB'

	USE [master]
	BACKUP DATABASE [AxDB] TO  DISK = @BackupCurrentAxDB
		WITH NOFORMAT, NOINIT,  NAME = N'AxDB-Full Database Backup', SKIP, NOREWIND, NOUNLOAD, COMPRESSION,  STATS = 10

--<FIN> RESPALDO LA AxDB ACTUAL
--------------------------------------------------------------------------------------
--<INICIO> 
PRINT '--- <QUITO EL CHANGE TRACKING - Inicio> ---'

	USE AxDB
	GO
	-- Re-assign full rext catalogs to [dbo]
	DECLARE @catalogName nvarchar(256);
	DECLARE @sqlStmtTable nvarchar(512)

	DECLARE reassignFullTextCatalogCursor CURSOR FOR 
		SELECT DISTINCT name
		FROM sys.fulltext_catalogs 
       
		-- Open cursor and disable on all tables returned
		OPEN reassignFullTextCatalogCursor
		FETCH NEXT FROM reassignFullTextCatalogCursor INTO @catalogName

		WHILE @@FETCH_STATUS = 0
		BEGIN
				SET @sqlStmtTable = 'ALTER AUTHORIZATION ON Fulltext Catalog::[' + @catalogName + '] TO [dbo]'
				EXEC sp_executesql @sqlStmtTable
				FETCH NEXT FROM reassignFullTextCatalogCursor INTO @catalogName
		END
	CLOSE reassignFullTextCatalogCursor
	DEALLOCATE reassignFullTextCatalogCursor

	--Disable change tracking on tables where it is enabled.
	declare
	@SQL varchar(1000)
	set quoted_identifier off
	declare changeTrackingCursor CURSOR for
	select 'ALTER TABLE [' + t.name + '] DISABLE CHANGE_TRACKING'
	from sys.change_tracking_tables c, sys.tables t
	where t.object_id = c.object_id
	order by t.name
	OPEN changeTrackingCursor
	FETCH changeTrackingCursor into @SQL
	WHILE @@Fetch_Status = 0
	BEGIN
	exec(@SQL)
	FETCH changeTrackingCursor into @SQL
	END
	CLOSE changeTrackingCursor
	DEALLOCATE changeTrackingCursor

	--Disable change tracking on the database itself.
	ALTER DATABASE
	-- SET THE NAME OF YOUR DATABASE BELOW
	AxDB
	set CHANGE_TRACKING = OFF

--<FIN> QUITO EL CHANGE TRACKING
--------------------------------------------------------------------------------------
--<INICIO> IMPORTAR LA DB EXTERNA
PRINT '--- <IMPORTAR LA DB EXTERNA - Inicio> ---'
	
	declare @BackupToImport nvarchar(255)
	select @BackupToImport = VarValue from #AxDB_BackupFiles where VarName = 'BackupToImport' 
	
	ALTER DATABASE [AxDBOriginal] SET OFFLINE WITH ROLLBACK AFTER 1 SECONDS

	USE [master]
	RESTORE DATABASE [AxDBImported]
	FROM  DISK = @BackupToImport --ASEGURARSE DE HABER CAMBIADO EL NOMBRE DEL ARCHIVO
	WITH  FILE = 1,  
	MOVE N'AXDBBuild_Data' TO N'G:\MSSQL_DATA\AxDBImported.mdf', 
	MOVE N'AXDBBuild_Log' TO N'H:\MSSQL_LOGS\AxDBImported_Log.ldf',  
	NOUNLOAD,  
	REPLACE,
	STATS = 5

	GO
--<FIN> IMPORTAR LA DB EXTERNA
--------------------------------------------------------------------------------------
--<INICIO> REMUEVO Y REIMPORTO LOS USUARIOS DE LA DB
PRINT '--- <REMUEVO Y REIMPORTO LOS USUARIOS DE LA DB - Inicio> ---'

	--Remove the database level users from the database
	--these will be recreated after importing in SQL Server.
	use AxDBImported --******************* SET THE NEWLY RESTORED DATABASE NAME****************************

	declare
	@userSQL varchar(1000)
	set quoted_identifier off
	declare userCursor CURSOR for
	select 'DROP USER [' + name + ']'
	from sys.sysusers
	where issqlrole = 0 and hasdbaccess = 1 and name <> 'dbo' and name <> 'NT AUTHORITY\NETWORK SERVICE'
	OPEN userCursor
	FETCH userCursor into @userSQL
	WHILE @@Fetch_Status = 0
	BEGIN
	exec(@userSQL)
	FETCH userCursor into @userSQL
	END
	CLOSE userCursor
	DEALLOCATE userCursor

	--now recreate the users copying from the existing database:
	use AxDB --******************* SET THE OLD DATABASE NAME****************************
	go
	IF object_id('tempdb..#UsersToCreate') is not null
	DROP TABLE #UsersToCreate
	go
	select 'CREATE USER [' + name + '] FROM LOGIN [' + name + '] EXEC sp_addrolemember "db_owner", "' + name + '"' as sqlcommand
	into #UsersToCreate
	from sys.sysusers
	where issqlrole = 0 and hasdbaccess = 1 and name != 'dbo' and name != 'NT AUTHORITY\NETWORK SERVICE'
	go
	use AxDBImported --******************* SET THE NEWLY RESTORED DATABASE NAME****************************
	go
	declare
	@userSQL varchar(1000)
	set quoted_identifier off
	declare userCursor CURSOR for
	select sqlcommand from #UsersToCreate
	OPEN userCursor
	FETCH userCursor into @userSQL
	WHILE @@Fetch_Status = 0
	BEGIN
	exec(@userSQL)
	FETCH userCursor into @userSQL
	END
	CLOSE userCursor
	DEALLOCATE userCursor
	
--<FIN> REMUEVO Y REIMPORTO LOS USUARIOS DE LA DB
--------------------------------------------------------------------------------------
--<INICIO> CORRIJO LAS URLS Y OTRAS CONFIGURACIONES DE RETAIL
PRINT 'CORRIJO LAS URLS Y OTRAS CONFIGURACIONES DE RETAIL - Inicio'
	use AxDBImported
	update AxDBImported.dbo.RETAILCONNDATABASEPROFILE set CONNECTIONSTRING = (select CONNECTIONSTRING from AxDB.dbo.RETAILCONNDATABASEPROFILE) --Original Database

	update  AxDBImported.dbo.RetailTransactionServiceProfile 
	set SERVICEHOSTURL = (select SERVICEHOSTURL from  AxDB.dbo.RetailTransactionServiceProfile) --Original Database
		, AZURERESOURCE = (select AZURERESOURCE from  AxDB.dbo.RetailTransactionServiceProfile) --Original Database

	update toT set toT.[VALUE] = fromT.[VALUE]
	from  AxDBImported.dbo.RetailChannelProfileProperty as toT
	inner join AxDB.dbo.RetailChannelProfileProperty fromT ON fromT.[KEY_] = toT.[KEY_]

	-------------- Actualizacion de las tablas de tienda con tablas de HQ --------------
	update toT set toT.[VALUE] = fromT.[VALUE]
	from  AxDBImported.ax.RetailChannelProfileProperty as toT
	inner join AxDB.dbo.RetailChannelProfileProperty fromT ON fromT.[KEY_] = toT.[KEY]

	update  AxDBImported.ax.RetailTransactionServiceProfile 
	set SERVICEHOSTURL = (select SERVICEHOSTURL from  AxDB.dbo.RetailTransactionServiceProfile) --Original Database
		, AZURERESOURCE = (select AZURERESOURCE from  AxDB.dbo.RetailTransactionServiceProfile) --Original Database

--<FIN> CORRIJO LAS URLS Y OTRAS CONFIGURACIONES DE RETAIL
--------------------------------------------------------------------------------------
--<INICIO> FIN OFFLINE AxDB
PRINT 'PONGO LA [AxDB] En modo Offline - Inicio'
	ALTER DATABASE [AxDB] SET OFFLINE WITH ROLLBACK AFTER 1 SECONDS
--<FIN> FIN OFFLINE AxDB
--------------------------------------------------------------------------------------
--<INICIO> PREPARO LA DB IMPORTADA
PRINT '--- <PREPARO LA DB IMPORTADA - Inicio> ---'
	
	USE [AxDBImported]
	
	--Remove certificates in database from Electronic Signature usage
	DECLARE @SQLElectronicSig nvarchar(512)
	DECLARE certCursor CURSOR for
	select 'DROP CERTIFICATE ' + QUOTENAME(c.name) + ';'
	from sys.certificates c;
	OPEN certCursor;
	FETCH certCursor into @SQLElectronicSig;
	WHILE @@Fetch_Status = 0
	BEGIN
	print @SQLElectronicSig;
	exec(@SQLElectronicSig);
	FETCH certCursor into @SQLElectronicSig;
	END;
	CLOSE certCursor;
	DEALLOCATE certCursor;

	-- Re-assign full rext catalogs to [dbo]
	BEGIN
		DECLARE @catalogName nvarchar(256);
		DECLARE @sqlStmtTable nvarchar(512)

		DECLARE reassignFullTextCatalogCursor CURSOR
		   FOR SELECT DISTINCT name
		   FROM sys.fulltext_catalogs 
       
		   -- Open cursor and disable on all tables returned
		   OPEN reassignFullTextCatalogCursor
		   FETCH NEXT FROM reassignFullTextCatalogCursor INTO @catalogName

		   WHILE @@FETCH_STATUS = 0
		   BEGIN
				  SET @sqlStmtTable = 'ALTER AUTHORIZATION ON Fulltext Catalog::[' + @catalogName + '] TO [dbo]'
				  EXEC sp_executesql @sqlStmtTable
				  FETCH NEXT FROM reassignFullTextCatalogCursor INTO @catalogName
		   END
		   CLOSE reassignFullTextCatalogCursor
		   DEALLOCATE reassignFullTextCatalogCursor
	END

	--Disable change tracking on tables where it is enabled.
	declare
	@SQL varchar(1000)
	set quoted_identifier off
	declare changeTrackingCursor CURSOR for
	select 'ALTER TABLE [' + t.name + '] DISABLE CHANGE_TRACKING'
	from sys.change_tracking_tables c, sys.tables t
	where t.object_id = c.object_id
	OPEN changeTrackingCursor
	FETCH changeTrackingCursor into @SQL
	WHILE @@Fetch_Status = 0
	BEGIN
	exec(@SQL)
	FETCH changeTrackingCursor into @SQL
	END
	CLOSE changeTrackingCursor
	DEALLOCATE changeTrackingCursor

	--Disable change tracking on the database itself.
	ALTER DATABASE
	-- SET THE NAME OF YOUR DATABASE BELOW
	[AxDBImported]
	set CHANGE_TRACKING = OFF

	--Change ownership of alternate schemas to DBO
	ALTER AUTHORIZATION ON schema::shadow TO [dbo]
	ALTER AUTHORIZATION ON schema::[BACKUP] TO [dbo]

	--Delete the SYSSQLRESOURCESTATSVIEW view as it has an Azure-specific definition in it.
	--We will run db synch later to recreate the correct view for SQL Server.
	if(1=(select 1 from sys.views where name = 'SYSSQLRESOURCESTATSVIEW'))
	DROP VIEW SYSSQLRESOURCESTATSVIEW
	--Next, set system parameters ready for being a SQL Server Database.
	update sysglobalconfiguration
	set value = 'SQLSERVER'
	where name = 'BACKENDDB'
	update sysglobalconfiguration
	set value = 0
	where name = 'TEMPTABLEINAXDB'
	
	--Clean up the batch server configuration, server sessions, and printers from the previous environment.
	TRUNCATE TABLE SYSSERVERCONFIG
	TRUNCATE TABLE SYSSERVERSESSIONS
	TRUNCATE TABLE SYSCORPNETPRINTERS
	TRUNCATE TABLE SYSCLIENTSESSIONS
	TRUNCATE TABLE BATCHSERVERCONFIG
	TRUNCATE TABLE BATCHSERVERGROUP
	
	--Remove records which could lead to accidentally sending an email externally.
	UPDATE SysEmailParameters
	SET SMTPRELAYSERVERNAME = '', MAILERNONINTERACTIVE = 'SMTP' 
	--Remove encrypted SMTP Password record(s)
	TRUNCATE TABLE SYSEMAILSMTPPASSWORD
	GO
	UPDATE LogisticsElectronicAddress
	SET LOCATOR = ''
	WHERE Locator LIKE '%@%'
	GO
	TRUNCATE TABLE PrintMgmtSettings
	TRUNCATE TABLE PrintMgmtDocInstance
	
	--Set any waiting, executing, ready, or canceling batches to withhold.
	UPDATE BatchJob
	SET STATUS = 0
	WHERE STATUS IN (1,2,5,7)
	GO

	-- Clear encrypted hardware profile merchand properties
	update dbo.RETAILHARDWAREPROFILE set SECUREMERCHANTPROPERTIES = null where SECUREMERCHANTPROPERTIES is not null
--<FIN> PREPARO LA DB IMPORTADA
--------------------------------------------------------------------------------------
--<INICIO> 
PRINT '--- <QUITO EL DUAL WRITE SETTINGS - Inicio> ---'

	use AxDBImported --******************* SET THE NEWLY RESTORED DATABASE NAME****************************
	DECLARE @sqlStmtTable nvarchar(512)
	DECLARE @tableName nvarchar(512)

	DECLARE selectFullTable CURSOR FOR 
		select t.name as table_name
			--t.create_date,
			--t.modify_date
		from sys.tables t
		where schema_name(t.schema_id) = 'dbo'
		and t.name like '%DualWrite%' -- put schema name here
		order by table_name;
		
	-- Open cursor and disable on all tables returned
	OPEN selectFullTable
		FETCH NEXT FROM selectFullTable INTO @tableName

		WHILE @@FETCH_STATUS = 0
		BEGIN
			--Limpiando solo esta tabla fue suficiente para evitar el error al crear/actualizar datos de clientes
			--truncate table AxDB.dbo.DUALWRITEPROJECTCONFIGURATION

			SET @sqlStmtTable = 'TRUNCATE TABLE AxDB.dbo.[' + @tableName + ']' 
			EXEC sp_executesql @sqlStmtTable
			FETCH NEXT FROM selectFullTable INTO @tableName
		END
		CLOSE selectFullTable
	DEALLOCATE selectFullTable
	GO
--<FIN> QUITO EL DUAL WRITE SETTINGS
--------------------------------------------------------------------------------------
--<INICIO> EXPORTO LA AxDBImported EN LA QUE ESTUVIMOS TRABAJANDO
PRINT '--- <EXPORTO LA AxDBImported EN LA QUE ESTUVIMOS TRABAJANDO - Inicio> ---'

	declare @BackupToStageDB nvarchar(255)
	select @BackupToStageDB = VarValue from #AxDB_BackupFiles where VarName = 'BackupToStageDB'

	USE [master]
	BACKUP DATABASE [AxDBImported] TO  DISK = @BackupToStageDB
		WITH NOFORMAT, NOINIT,  NAME = N'AxDBImported-Full Database Backup', SKIP, NOREWIND, NOUNLOAD, COMPRESSION,  STATS = 10

	ALTER DATABASE [AxDBImported] SET OFFLINE WITH ROLLBACK AFTER 1 SECONDS
--<FIN> EXPORTO LA AxDBImported EN LA QUE ESTUVIMOS TRABAJANDO
--------------------------------------------------------------------------------------
--<INICIO> IMPORTO LA DB TRABAJADA COMO LA AxDB
PRINT '--- <IMPORTO LA DB TRABAJADA COMO LA AxDB - Inicio> ---'

	ALTER DATABASE [AxDB] SET OFFLINE WITH ROLLBACK AFTER 1 SECONDS

	USE [master]
	RESTORE DATABASE [AxDB]
	FROM  DISK = @BackupToStageDB
	WITH  FILE = 1,  
	MOVE N'AXDBBuild_Data' TO N'G:\MSSQL_DATA\AxDB.mdf', 
	MOVE N'AXDBBuild_Log' TO N'H:\MSSQL_LOGS\AxDB.ldf',  
	NOUNLOAD,  
	REPLACE,
	STATS = 5

	GO
--<FIN> IMPORTO LA DB TRABAJADA COMO LA AxDB
--------------------------------------------------------------------------------------
--<INICIO> HABILITO EL CHANGE TRACKING EN LA NUEVA DB
PRINT '--- <HABILITO EL CHANGE TRACKING EN LA NUEVA DB - Inicio> ---'

	USE AxDB
	
	--Enable again the change tracking on the database itself.
	ALTER DATABASE AxDB SET CHANGE_TRACKING = ON (CHANGE_RETENTION = 6 DAYS, AUTO_CLEANUP = ON)
	GO
	DROP PROCEDURE IF EXISTS SP_ConfigureTablesForChangeTracking
	DROP PROCEDURE IF EXISTS SP_ConfigureTablesForChangeTracking_V2
	GO
	-- Begin Refresh Retail FullText Catalogs
	DECLARE @RFTXNAME NVARCHAR(MAX);
	DECLARE @RFTXSQL NVARCHAR(MAX);
	DECLARE retail_ftx CURSOR FOR
	SELECT OBJECT_SCHEMA_NAME(object_id) + '.' + OBJECT_NAME(object_id) fullname FROM SYS.FULLTEXT_INDEXES
		WHERE FULLTEXT_CATALOG_ID = (SELECT TOP 1 FULLTEXT_CATALOG_ID FROM SYS.FULLTEXT_CATALOGS WHERE NAME = 'COMMERCEFULLTEXTCATALOG');
	OPEN retail_ftx;
	FETCH NEXT FROM retail_ftx INTO @RFTXNAME;

	BEGIN TRY
		WHILE @@FETCH_STATUS = 0  
		BEGIN  
			PRINT 'Refreshing Full Text Index ' + @RFTXNAME;
			EXEC SP_FULLTEXT_TABLE @RFTXNAME, 'activate';
			SET @RFTXSQL = 'ALTER FULLTEXT INDEX ON ' + @RFTXNAME + ' START FULL POPULATION';
			EXEC SP_EXECUTESQL @RFTXSQL;
			FETCH NEXT FROM retail_ftx INTO @RFTXNAME;
		END
	END TRY
	BEGIN CATCH
		PRINT error_message()
	END CATCH

	CLOSE retail_ftx;  
	DEALLOCATE retail_ftx; 
	-- End Refresh Retail FullText Catalogs
--<FIN> HABILITO EL CHANGE TRACKING EN LA NUEVA DB
