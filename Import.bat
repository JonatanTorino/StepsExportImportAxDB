@ECHO OFF
REM Variables
SET SQLServer=%COMPUTERNAME%
SET Folder=%cd%

REM Parametros de entrada
SET paramSQLServer=%~1
SET paramFolder=%~2
SET paramFileName=%~3
SET FileName=%paramFileName%

@ECHO OFF
IF NOT [%paramSQLServer%] == [] GOTO :InitSQLServer
GOTO :CheckParamFolder
:InitSQLServer
@echo SQL ECHO
%SQLServer%

:CheckParamFolder
IF NOT [%paramFolder%] == [] GOTO :InitFolder
GOTO :CheckParamFileName
:InitFolder
@REM SET Folder=%paramFolder%
echo %Folder%

:CheckParamFileName
IF [%paramFileName%] == [] GOTO :AskFileName
GOTO :Run

:AskFileName
SET /p FileName="RestoreFile: "

:Run
ECHO ON
@echo REM Ejecucion del restore
SQLCMD -S %SQLServer% -E -i "%Folder%\Restore.sql" -v FileName="%Folder%\%FileName%"
pause