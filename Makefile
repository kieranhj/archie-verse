# Wrapper so that `make` works from PowerShell / Windows Terminal.
# The real build is Makefile.mk, run by the bundled bin\snmake.exe via make.bat
# (make.bat calls snmake -f Makefile.mk, so it does not recurse into this file).
# GNU make runs recipes with cmd.exe here (no sh on PATH).
.PHONY: all build folder shrink compress seq help
all: build

# Makefile.mk's default target "deploy": build !Reise and copy it to ..\arculator\hostfs\Builds.
build:
	cmd /c .\make.bat

# Build the !Reise folder only, no hostfs copy.
folder:
	cmd /c .\make.bat !Reise

shrink compress seq:
	cmd /c .\make.bat $@

help:
	@echo make           - build !Reise and copy it to ..\arculator\hostfs\Builds (make.bat = snmake -f Makefile.mk deploy)
	@echo make folder    - build !Reise only
	@echo make shrink    - Shrinkler-compressed !Reise
	@echo make compress  - shrink, then copy to hostfs
	@echo make seq       - rebuild the sequence only and copy it to hostfs
	@echo make help      - this list
	@echo See START_HERE.md
