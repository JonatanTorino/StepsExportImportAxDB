
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
		SELECT @tableName
		SET @sqlStmtTable = 'SELECT * FROM AxDB.dbo.[' + @tableName + ']' 
		EXEC sp_executesql @sqlStmtTable
		FETCH NEXT FROM selectFullTable INTO @tableName
	END
	CLOSE selectFullTable
DEALLOCATE selectFullTable

GO
-------------------------------------------------------

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

		SELECT @tableName
		SET @sqlStmtTable = 'TRUNCATE TABLE AxDB.dbo.[' + @tableName + ']' 
		EXEC sp_executesql @sqlStmtTable
		FETCH NEXT FROM selectFullTable INTO @tableName
	END
	CLOSE selectFullTable
DEALLOCATE selectFullTable
