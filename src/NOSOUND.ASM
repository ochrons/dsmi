;/************************************************************************
; *
; *     File        :   NOSOUND.ASM
; *
; *     Description :   CDI Interface for no sound
; *
; *     Copyright (C) 1993 Otto Chrons
; *
; ***********************************************************************
;
;       Revision history of NOSOUND
;
;       1.0     27.12.93
;               This source provides only polling routines for CDI
;
; ***********************************************************************/

        IDEAL
        JUMPS
        P386

        INCLUDE "MODEL.INC"
        INCLUDE "CDI.INC"

CSEGMENTS NOSOUND

        TIME_DELTA = 100000

CDATASEG

        pseudoTime  DD ?

IFDEF __PASCAL__

        EXTRN CDI_NOSOUND:CDIDEVICE

ELSE
        CPUBLIC CDI_NOSOUND

        _CDI_NOSOUND        CDIDEVICE <\
        _far ptr _nullFunc,\
        _far ptr _nullFunc,\
        _far ptr _nullFunc,\
        _far ptr _nullFunc,\
        _far ptr _nullFunc,\
        _far ptr _nullFunc,\
        _far ptr _nullFunc,\
        _far ptr _nullFunc,\
        _far ptr _nullFunc,\
        _far ptr _nullFunc,\
        _far ptr _nullFunc,\
        _far ptr _nullFunc,\
        _far ptr _nullFunc,\
        _far ptr _nosoundPoll,\
        _far ptr _nosoundGetDelta,\
        _far ptr _nullFunc,\
        _far ptr _nullFunc,\
        _far ptr _nullFunc,\
        _far ptr _nullFunc,\
        _far ptr _nullFunc,\
        _far ptr _nullFunc,\
        _far ptr _nullFunc,\
        _far ptr _nullFunc,\
        _far ptr _nullFunc>
ENDIF

ENDS

CCODESEG NOSOUND

        CPUBLIC nosoundPoll, nosoundGetDelta
        CPUBLIC nosoundInit

MACRO   getRealTime

IFDEF __32__
        mov     eax,[46Ch]
ELSE

        mov     ax,40h
        mov     es,ax
        mov     eax,[es:6Ch]
ENDIF
        mov     edx,54925
        imul    edx
        shrd    eax,edx,8
ENDM

CPROC   nullFunc
        ret
ENDP

CPROC   nosoundInit

        getRealTime
        mov     [pseudoTime],eax

        ret
ENDP

CPROC   nosoundPoll @@time

        ENTERPROC
        getRealTime
        cmp     eax,[pseudoTime]
        jb      @@ok
        mov     [pseudoTime],eax
@@ok:
        mov     eax,[@@time]
        shr     eax,8
        add     [pseudoTime],eax
        LEAVEPROC
        ret
ENDP

CPROC   nosoundGetDelta

        getRealTime
        mov     ebx,eax
        mov     eax,[pseudoTime]
        sub     eax,ebx
        jns     @@ok
        sub     eax,eax
@@ok:
        shl     eax,8
        cmp     eax,TIME_DELTA
        jbe     @@now
        mov     eax,0
@@now:
        sub     eax,TIME_DELTA
        neg     eax
IFDEF __16__
        shld    edx,eax,16
ENDIF
        ret
ENDP

ENDS

END

