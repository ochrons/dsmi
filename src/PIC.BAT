@echo off
tpc gmppcnv
gmppcnv
pct2pcj gmp gmp
pct2pcj gmphelp gmphelp
pct2pcj gmpinfo gmpinfo
binobj gmp.pcj gmppic.obj Piccy
binobj gmphelp.pcj gmphelp.obj HelpScreen
binobj gmpinfo.pcj gmpinfo.obj InfoScreen
