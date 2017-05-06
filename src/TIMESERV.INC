; ************************************************************************
; *
; *     File        : TS.INC
; *
; *     Description : Include file for Timer Service
; *
; *     Copyright (C) 1992 Otto Chrons
; *
; ************************************************************************


STRUC   TSROUTINE
IFDEF __32__
    routine     DF      0
ELSE
    routine     DD      0
ENDIF
    timerValue  DW      0
    timerRes    DW      0
    timerAdd    DW      0
    timerPassed DW      0
    status      DB      0
    busy        DB      0
ENDS

        TS_ACTIVE       = 1
        TS_INACTIVE     = 0

