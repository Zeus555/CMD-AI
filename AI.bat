@echo off
:: ===========================================================================
::  PRC AI 2.0 - lanzadera. Aqui no hay logica de negocio: solo se separan
::  la PREGUNTA de las OPCIONES y se arranca el nucleo.
::
::  Por que la pregunta viaja por variable de entorno y no por argv:
::    "powershell -File" parte un argumento que lleve comillas dobles internas
::    en varios trozos, y entonces el enlazador de parametros deja de
::    reconocer -Provider y compania. Comprobado:
::      AI "Di ""hola"" y adios" -Provider xai
::        argv -> <Di "hola> <y> <adios> <-Provider> <xai>
::    Con AI_QUESTION la pregunta llega byte a byte exacta.
::
::  SIN "enabledelayedexpansion" a proposito: con la expansion retrasada
::  activa cmd se comeria los signos ! de la pregunta.
::
::  -ExecutionPolicy Bypass es obligatorio: la directiva efectiva de esta
::  maquina es Restricted. Afecta SOLO a este proceso: no cambia ningun
::  ajuste del sistema ni pide permisos de administrador.
:: ===========================================================================
setlocal
chcp 65001 >nul

:: OJO: "shift" tambien desplaza %0, asi que %~dp0 dejaria de apuntar aqui.
:: Se guarda la ruta ANTES de tocar nada y ademas se usa "shift /1".
set "HERE=%~dp0"
set "AI_QUESTION="
set "ARGS="

:: El primer argumento es la pregunta salvo que empiece por guion.
:: No se mete en un bloque ( ) porque un parentesis dentro de la pregunta
:: cerraria el bloque antes de tiempo.
set "_q=%~1"
set "_skip=0"
if defined _q if not "%_q:~0,1%"=="-" set "_skip=1"
if "%_skip%"=="1" set "AI_QUESTION=%~1"
if "%_skip%"=="1" shift /1

:: Se reconstruyen SOLO las opciones, entrecomillando cada una.
:: No se puede usar %* porque %* ignora el shift.
:parse
if "%~1"=="" goto :run
set "ARGS=%ARGS% "%~1""
shift /1
goto :parse

:run
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%HERE%bin\ai.ps1"%ARGS%
exit /b %ERRORLEVEL%
