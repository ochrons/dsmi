@echo off
set casmtmp=
:paramloop
if "%1"=="" goto :nomore
if "%1"=="DEBUG" set casmtmp=%casmtmp% /zi
if "%1"=="PMP" set casmtmp=%casmtmp% /dPMP
shift
goto paramloop
:nomore
tasm %casmtmp% MCPREALA
tasm %casmtmp% MCPLAYER
tasm %casmtmp% CONVSAMP
tasm %casmtmp% GUS
tasm %casmtmp% AMPLAYER
tasm %casmtmp% CDI
tasm %casmtmp% TIMESERV
tasm %casmtmp% EMSHARD
tasm %casmtmp% VDS
tasm %casmtmp% SDI_SB
tasm %casmtmp% SDI_SB16
tasm %casmtmp% SDI_DAC
tasm %casmtmp% SDI_PAS
tasm %casmtmp% SDI_ARIA
tasm %casmtmp% SDI_WSS
tasm %casmtmp% MIXER
tasm %casmtmp% DETSBHW
tasm %casmtmp% DETSB16H
tasm %casmtmp% DETPAS
tasm %casmtmp% DETARIA
tasm %casmtmp% DETECTMV
tasm %casmtmp% DMAPROCS
set casmtmp=
