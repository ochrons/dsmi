;/************************************************************************
; *
; *     File        : MCPREALA.ASM
; *
; *     Description : Defines a null function mcpSampleRealAddress;
; *
; *     Copyright (C) 1992 Otto Chrons
; *
; ***********************************************************************
;
;       Revision history of MCPREAL.ASM
;
;       1.0     16.4.93
;               First version. Returns a NULL pointer.
;
; ***********************************************************************/

        IDEAL
        JUMPS
        P386

        INCLUDE "MODEL.INC"

CSEGMENTS MCPREALA

CCODESEG MCPREALA

        CPUBLIC  mcpSampleRealAddress
        CPUBLIC  mcpEnableVirtualSamples
        CPUBLIC  mcpDisableVirtualSamples


;/*************************************************************************
; *
; *     Function    :   void far *mcpSampleRealAddress(int sampleID, long spos);
; *
; *     Description :   Null function you should override
; *
; *     Input       :   sampleID
; *
; *     Returns     :   pointer to real sample
; *
; ************************************************************************/

CPROC    mcpSampleRealAddress @@sampleID, @@spos

        ENTERPROC
        sub     eax,eax                 ; Return NULL
        mov     dx,ax

        LEAVEPROC
        ret
ENDP

CPROC   mcpEnableVirtualSamples

        ret
ENDP

CPROC   mcpDisableVirtualSamples

        ret
ENDP

ENDS

END
