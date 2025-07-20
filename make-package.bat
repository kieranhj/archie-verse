@echo off
if "%1" == "" goto args_count_wrong
if "%2" == "" goto args_count_ok

:args_count_wrong
echo "Usage: make-package <dir name>"
exit /b 1

:args_count_ok
set ARCULATOR="..\arculator"
set HOSTFS=%ARCULATOR%\hostfs
set FOLDER=!Acid
set DST="%1"

echo Making a package for Rhino in '%DST%'...

mkdir %DST%
mkdir %DST%\bin
copy bin\modparse.py %DST%\bin
robocopy /S %ARCULATOR%\cmos %DST%\cmos
robocopy /S %ARCULATOR%\configs %DST%\configs
mkdir %DST%\hostfs
robocopy /S %ARCULATOR%\hostfs\%FOLDER% %DST%\hostfs\%FOLDER%
robocopy /S %ARCULATOR%\hostfs\!System %DST%\hostfs\!System
robocopy /S %ARCULATOR%\roms %DST%\roms

copy %ARCULATOR%\arc.cfg %DST%
copy %ARCULATOR%\arculator.exe %DST%
copy %ARCULATOR%\*.dll %DST%
copy make-rhino.bat %DST%
copy watch-rhino.bat %DST%
copy data\music\Revision_house_07_events_8ch.mod %DST%
