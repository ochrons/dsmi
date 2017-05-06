; ************************************************************************
; *
; *	File        : TS.INC
; *
; *	Description : Include file for Timer Service
; *
; *	Copyright (C) 1992 Otto Chrons
; *
; ************************************************************************


STRUC	TSROUTINE
    routine	DD	0
    timerValue	DW	0
    timerRes	DW	0
    timerAdd	DW	0
    timerPassed	DW	0
    status	DB	0
    busy	DB	0
ENDS

	TS_ACTIVE	= 1
	TS_INACTIVE	= 0

