@ECHO OFF
REM Variables
SET SQLServer=%COMPUTERNAME%
SET Folder=%cd%

REM Parametros de entrada
SET paramSQLServer=%~1
SET paramFolder=%~2
SET paramPostFixName=%~3
SET PostFixName=%paramPostFixName%

IF NOT [%paramSQLServer%] == [] GOTO :InitSQLServer
GOTO :CheckParamFolder
:InitSQLServer
SET SQLServer=%paramSQLServer% 

:CheckParamFolder
IF NOT [%paramFolder%] == [] GOTO :InitFolder
GOTO :CheckParamPostFixName
:InitFolder
SET Folder=%paramFolder%

:CheckParamPostFixName
IF [%paramPostFixName%] == [] GOTO :AskPostFixName
GOTO :Run

:AskPostFixName
SET /p PostFixName="Descripcion corta para sub fijo del nombre: "

:Run
ECHO ON
@echo REM Ejecicion del backup snapshot 
SQLCMD -S %SQLServer% -E -i "%Folder%\Backup.sql" -v Folder="%Folder%\" postFixName=%postFixName%
pause
