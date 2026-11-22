# Wrapper so that `make` works from PowerShell / Windows Terminal.
# GNU make runs recipes with cmd.exe here (no sh on PATH).
# The real build is Makefile.mk, run by bin\snmake.exe via make.bat.
# Note: Makefile.mk converts assets with Python 3 (variable PYTHON2, default "py -3"; scripts ported 2026-11-22).
FOLDER := !Verse
.PHONY: all build deploy compress parts seq help
all: build

build:
	cmd /c .\make.bat $(FOLDER)

deploy:
	cmd /c .\make.bat deploy

compress parts seq:
	cmd /c .\make.bat $@

help:
	@echo make           - build the $(FOLDER) RISC OS folder in the repo (make.bat $(FOLDER))
	@echo make deploy    - build and copy $(FOLDER) to ..\arculator\hostfs (make.bat's default)
	@echo make compress  - Shrinkler-compressed build, deployed to hostfs
	@echo make parts     - separate donut / space part binaries
	@echo make seq       - sequence-only build
	@echo make help      - this list
