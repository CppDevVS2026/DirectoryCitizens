@echo off
odin build . -out:DirectoryCitizens.exe -debug
if %ERRORLEVEL% == 0 (
    echo Build OK — DirectoryCitizens.exe
) else (
    echo Build FAILED
)
