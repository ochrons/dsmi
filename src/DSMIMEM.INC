;* DSMIMEM.INC
;*
;* Copyright 1994 Otto Chrons
;*
;* First revision 05-08-94 07:15:50pm
;*
;* Revision history:
;*
;* DSMI memory management function pointers
;*

IFDEF __PASCAL__

        EXTRN D_malloc:_FAR
        EXTRN D_free:_FAR
        EXTRN D_calloc:_FAR
ELSE
        EXTRN _D_malloc:_FAR
        EXTRN _D_free:_FAR
        EXTRN _D_calloc:_FAR

        D_malloc EQU _D_malloc
        D_calloc EQU _D_calloc
        D_free EQU _D_free

ENDIF

