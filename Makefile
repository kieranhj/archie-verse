# Wrapper so that `make` works from PowerShell / Windows Terminal.
# GNU make runs recipes with cmd.exe here (no sh on PATH).
# The real build is Makefile.mk, run by bin\snmake.exe via make.bat.
FOLDER := !dj3
.PHONY: all build deploy compress parts seq music help
all: build

build:
	cmd /c .\make.bat $(FOLDER)

deploy:
	cmd /c .\make.bat deploy

compress parts seq music:
	cmd /c .\make.bat $@

help:
	@echo make           - build the $(FOLDER) RISC OS folder in the repo (make.bat $(FOLDER))
	@echo make deploy    - build, copy $(FOLDER) to ..\arculator\hostfs and make build\django3,ddc (make.bat's default)
	@echo make compress  - Shrinkler-compressed build, deployed to hostfs
	@echo make parts / seq / music - other Makefile.mk targets, passed to make.bat
	@echo make help      - this list
