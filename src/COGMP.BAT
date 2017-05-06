if "%1"=="debug" goto :debug
bpc /b /$g+ gmp
tdstrip gmp
pklite gmp.exe
scrmble gmp.exe 30 78
goto end
:debug
bpc /b /$g+ /v gmp
:end
