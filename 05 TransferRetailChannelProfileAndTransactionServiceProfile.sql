use AxDB
update AxDB.dbo.RETAILCONNDATABASEPROFILE set CONNECTIONSTRING = (select CONNECTIONSTRING from AxDBOriginal.dbo.RETAILCONNDATABASEPROFILE) --Original Database

update  AxDB.dbo.RetailTransactionServiceProfile 
set SERVICEHOSTURL = (select SERVICEHOSTURL from  AxDBOriginal.dbo.RetailTransactionServiceProfile) --Original Database
	, AZURERESOURCE = (select AZURERESOURCE from  AxDBOriginal.dbo.RetailTransactionServiceProfile) --Original Database

update toT set toT.[VALUE] = fromT.[VALUE]
from  AxDB.dbo.RetailChannelProfileProperty as toT
inner join AxDBOriginal.dbo.RetailChannelProfileProperty fromT ON fromT.[KEY_] = toT.[KEY_]

-------------- Actualizaci�n de las tablas de tienda con tablas de HQ --------------
update toT set toT.[VALUE] = fromT.[VALUE]
from  AxDB.ax.RetailChannelProfileProperty as toT
inner join AxDBOriginal.dbo.RetailChannelProfileProperty fromT ON fromT.[KEY_] = toT.[KEY]

update  AxDB.ax.RetailTransactionServiceProfile 
set SERVICEHOSTURL = (select SERVICEHOSTURL from  AxDBOriginal.dbo.RetailTransactionServiceProfile) --Original Database
	, AZURERESOURCE = (select AZURERESOURCE from  AxDBOriginal.dbo.RetailTransactionServiceProfile) --Original Database
------------------------------------------------------------------------------------


--Queries
/*
select SERVICEHOSTURL,AZURERESOURCE, * from  AxDB.dbo.RetailTransactionServiceProfile
select SERVICEHOSTURL,AZURERESOURCE, * from  AxDB.ax.RetailTransactionServiceProfile
select * from AxDB.dbo.RetailChannelProfileProperty
select * from AxDB.ax.RetailChannelProfileProperty
select SERVICEHOSTURL,AZURERESOURCE, * from  AxDBOriginal.dbo.RetailTransactionServiceProfile
select SERVICEHOSTURL,AZURERESOURCE, * from  AxDBOriginal.ax.RetailTransactionServiceProfile
select * from AxDBOriginal.dbo.RetailChannelProfileProperty
select * from AxDBOriginal.ax.RetailChannelProfileProperty
select CONNECTIONSTRING, * from AxDBOriginal.dbo.RETAILCONNDATABASEPROFILE
*/
