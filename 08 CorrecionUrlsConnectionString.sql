
--<INICIO> CORRIJO LAS URLS Y OTRAS CONFIGURACIONES DE RETAIL
BEGIN
PRINT 'CORRIJO LAS URLS Y OTRAS CONFIGURACIONES DE RETAIL - Inicio'
	use master
	update AxDB.dbo.RETAILCONNDATABASEPROFILE set CONNECTIONSTRING = (select CONNECTIONSTRING from AxDBOriginal.dbo.RETAILCONNDATABASEPROFILE) --Original Database

	update  AxDB.dbo.RetailTransactionServiceProfile 
	set SERVICEHOSTURL = (select SERVICEHOSTURL from  AxDBOriginal.dbo.RetailTransactionServiceProfile) --Original Database
		, AZURERESOURCE = (select AZURERESOURCE from  AxDBOriginal.dbo.RetailTransactionServiceProfile) --Original Database

	update toT set toT.[VALUE] = fromT.[VALUE]
	from  AxDB.dbo.RetailChannelProfileProperty as toT
	inner join AxDBOriginal.dbo.RetailChannelProfileProperty fromT ON fromT.[KEY_] = toT.[KEY_]

	-------------- Actualizacion de las tablas de tienda con tablas de HQ --------------
	update toT set toT.[VALUE] = fromT.[VALUE]
	from  AxDB.ax.RetailChannelProfileProperty as toT
	inner join AxDBOriginal.dbo.RetailChannelProfileProperty fromT ON fromT.[KEY_] = toT.[KEY]

	update  AxDB.ax.RetailTransactionServiceProfile 
	set SERVICEHOSTURL = (select SERVICEHOSTURL from  AxDBOriginal.dbo.RetailTransactionServiceProfile) --Original Database
		, AZURERESOURCE = (select AZURERESOURCE from  AxDBOriginal.dbo.RetailTransactionServiceProfile) --Original Database
END
GO