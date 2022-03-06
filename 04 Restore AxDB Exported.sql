SET ANSI_NULLS, QUOTED_IDENTIFIER ON;
/*ej de uso desde SQLCMD
	SQLCMD -S %SQLServer% -E -i "%Folder%\Restore.sql" -v FileName="%Folder%\%FileName%"
*/

--Declaración de variables
declare @parmInRestoreFileName nvarchar(255) = N'$(FileName)'

--Declaración de variables
declare @restoreFrom nvarchar(255) = @parmInRestoreFileName

--USE [master]
ALTER DATABASE [AxDB] SET OFFLINE WITH ROLLBACK AFTER 10 SECONDS

RESTORE DATABASE [AxDB] FROM  DISK = @restoreFrom WITH  FILE = 1,  NOUNLOAD,  REPLACE,  STATS = 5

USE [AxDB]

--Actualizo nombres de compañias solo si se indicó un valor
declare @CompanyName nvarchar(10)-- = 'JonyDEV'
if (LEN(@CompanyName)>0)
begin
	print '' print 'Actualizo nombres de las compañías'
	update DPT 
		set DPT.[NAME] = @CompanyName + ' - ' + DPT.NAMEALIAS
	from AxDB.dbo.DIRPARTYTABLE as DPT
	inner join AxDB.dbo.TABLEIDTABLE as T
		on T.ID = DPT.INSTANCERELATIONTYPE
	where T.[NAME] = 'CompanyInfo'
end

declare @hostName nvarchar(100) = HOST_NAME() --Obtengo el nombre del servidor DEV
Print '' print 'Cambio el color del navegador para todos los usuarios (basado en último dígito del entorno):' + @hostName
declare @themeColor int = CASE WHEN right(@hostName, 1) between 0 and 14
							THEN right(@hostName, 1)
							ELSE 14 END --Para el resto tomo el nro de DEV
update ui set ui.THEME = @themeColor --Uso el nro del entorno para setear el ThemeColor
from AxDB.dbo.SysUserInfo ui
