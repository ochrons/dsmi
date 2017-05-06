;* DMA.INC      Defines for DMAPROCS
;*
;* Copyright 1994 Otto Chrons
;*
;* First revision 02-14-94 02:27:46pm
;*
;* Revision history:
;*
;*

IFDEF __PASCAL__
        EXTRN   dmaInit:_FAR
        EXTRN   dmaStart:_FAR
        EXTRN   dmaStop:_FAR
        EXTRN   dmaClose:_FAR
        EXTRN   dmaGetPos:_FAR
ELSE
        EXTRN   _dmaInit:_FAR
        EXTRN   _dmaStart:_FAR
        EXTRN   _dmaStop:_FAR
        EXTRN   _dmaClose:_FAR
        EXTRN   _dmaGetPos:_FAR

        dmaInit         EQU     _dmaInit
        dmaStart        EQU     _dmaStart
        dmaStop         EQU     _dmaStop
        dmaClose        EQU     _dmaClose
        dmaGetPos       EQU     _dmaGetPos
ENDIF

