# Wrapper so that `make` works from PowerShell / Windows Terminal.
# GNU make runs recipes with cmd.exe here (no sh on PATH).
# The real build is Makefile.mk, run by bin\snmake.exe via make.bat.
FOLDER := !AKlang
.PHONY: all build deploy compress seq help
all: build

build:
	cmd /c .\make.bat $(FOLDER)

deploy:
	cmd /c .\make.bat deploy

compress seq:
	cmd /c .\make.bat $@

help:
	@echo make           - build the $(FOLDER) RISC OS folder in the repo (make.bat $(FOLDER))
	@echo make deploy    - build and copy $(FOLDER) to ..\arculator\hostfs\Builds (make.bat's default)
	@echo make compress  - Shrinkler-compressed build, deployed to hostfs
	@echo make seq       - sequence-only build (Makefile.mk seq)
	@echo make help      - this list
