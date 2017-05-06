;/************************************************************************
; *
; *     File        :   CONVSAMP.ASM
; *
; *     Description :   Converts unsigned 8-bit sample into signed and vice
; *                     versa.
; *
; *     Copyright (C) 1992,1993 Otto Chrons
; *
; ***********************************************************************/

        IDEAL
        JUMPS
        P386

        INCLUDE "MODEL.INC"

CSEGMENTS CONVSAMP

CCODESEG CONVSAMP

        CPUBLIC         mcpConvertSample

;/*************************************************************************
; *
; *     Function    :   void mcpConvertSample(void far *sample, unsigned len);
; *
; *     Description :   Converts sample between signed and unsigned format
; *                     (Amiga/PC-format)
; *
; *     Input       :   sample  = pointer to sample to convert
; *                     len     = length of sample
; *
; ************************************************************************/

CPROC   mcpConvertSample @@sample,@@len

        ENTERPROC       _di

        cmp     [@@sample],0              ; Check for illegal values
        je      @@exit
@@10:
        LESDI   [@@sample]                ; Point ESDI to the sample
        mov     ecx,[@@len]
IFNDEF __C32__
        cmp     ecx,65535
        jle     @@normal
@@normalize:
        mov     ax,es
        movzx   eax,ax
        shl     eax,4
        movzx   edi,di
        add     eax,edi
        mov     edi,eax
        and     di,0Fh
        shr     eax,4
        mov     es,ax                   ; Normalize pointer
@@loop0:
        cmp     ecx,65000
        jl      @@normal
        push    ecx
        mov     cx,65000
@@loop1:
        xor     [byte ESDI],80h
        inc     di
        loop    @@loop1
        pop     ecx
        sub     ecx,65000
        jmp     @@normalize
ENDIF
@@normal:
        xor     [byte ESDI],80h
        inc     _di
        loop    @@normal
@@exit:
        LEAVEPROC       _di
        ret
ENDP

ENDS

END

