@echo off
if "%1" == "" goto args_count_wrong
if "%2" == "" goto args_count_ok

:args_count_wrong
echo "Usage: make-rhino <MOD filename>"
exit /b 1

:args_count_ok
set HOSTFS="..\arculator\hostfs\!Acid"

echo ---
echo Watching MOD file "%1"
echo ---

:loop  
timeout -t 1 >nul

for %%i in (%1) do echo %%~ai|find "a">nul || goto :loop
echo ---
echo File "%1" was changed at %DATE% %TIME%
echo ---
echo Splitting MOD into MUSIC and EVENTS...
echo ---

python bin\modparse.py -o music.mod -e events.bin --channel-mask 0x0f --event-mask 0xf0 "%1"

if %ERRORLEVEL% neq 0 (
	echo Failed to parse MOD!
	exit /b 1
)

echo Copy files to Arculator folder %HOSTFS%...
move music.mod "%HOSTFS%\music,001"
move events.bin "%HOSTFS%\events,ffd"

if %ERRORLEVEL% neq 0 (
	echo Failed to copy files!'
	exit /b 1
)

echo ---
echo Hit 'A' in the app to reload!
echo ---

attrib -a "%1"
goto :loop
