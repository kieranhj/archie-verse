@echo off
if "%1" == "" goto args_count_wrong
if "%2" == "" goto args_count_ok

:args_count_wrong
echo "Usage: make-rhino <MOD filename>"
exit /b 1

:args_count_ok
if "%HOSTFS%"=="" set HOSTFS=hostfs
set FOLDER=!Acid

echo ---
echo Splitting MOD into MUSIC and EVENTS...
echo ---

python bin\modparse.py -o music.mod -e events.bin --channel-mask 0x0f --event-mask 0xf0 "%1"

if %ERRORLEVEL% neq 0 (
	echo Failed to parse MOD!
	exit /b 1
)

echo Copy files to Arculator folder %HOSTFS%\%FOLDER%...
move music.mod "%HOSTFS%\%FOLDER%\music,001"
move events.bin "%HOSTFS%\%FOLDER%\events,ffd"

if %ERRORLEVEL% neq 0 (
	echo Failed to copy files!
	exit /b 1
)

echo ---
echo Hit 'A' in the app to reload!
echo ---
