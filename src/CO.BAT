@echo off
call casm
if "%1"=="6" goto tp6
bpc example1 /b
bpc example2
bpc example3
bpc example4
bpc getcpu
tasm pmpbar
bpc pmp /b /cp
goto end
:tp6
\bp\60\tpc example1 /b /$x+
\bp\60\tpc example2 /$x+
\bp\60\tpc example3 /$x+
\bp\60\tpc example4 /$x+
:end
