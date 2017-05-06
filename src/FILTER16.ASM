;*
;* FILTER16.ASM Filter effects for DMP.C
;*
;* Copyright 1994 Otto Chrons
;*
;* First revision 06-17-94 10:53:37pm
;*
;* Revision history:
;*
        IDEAL
        P386
        MODEL LARGE,C
        JUMPS

MACRO   filter1_16
        movsx   eax,[WORD es:di]
        add     edx,eax
        sar     edx,1
        mov     [es:di],dx
        add     di,2
        mov     edx,eax
ENDM

MACRO   filter1_16R
        movsx   eax,[WORD es:di]
        add     ebx,eax
        sar     ebx,1
        mov     [es:di],bx
        add     di,2
        mov     ebx,eax
ENDM

MACRO   filter1_8
        mov     al,[es:di]
        add     dx,ax
        shr     dx,1
        mov     [es:di],dl
        inc     di
        mov     dx,ax
ENDM

MACRO   filter1_8R
        mov     al,[es:di]
        add     bx,ax
        shr     bx,1
        mov     [es:di],bl
        inc     di
        mov     bx,ax
ENDM

MACRO   filter2_16
        movsx   eax,[WORD es:di]
        add     edx,eax
        add     edx,eax
        add     edx,eax
        sar     edx,2
        mov     [es:di],dx
        add     di,2
        mov     edx,eax
ENDM

MACRO   filter2_16R
        movsx   eax,[WORD es:di]
        add     ebx,eax
        add     ebx,eax
        add     ebx,eax
        sar     ebx,2
        mov     [es:di],bx
        add     di,2
        mov     ebx,eax
ENDM

MACRO   filter2_8
        mov     al,[es:di]
        add     dx,ax
        add     dx,ax
        add     dx,ax
        shr     dx,2
        mov     [es:di],dl
        inc     di
        mov     dx,ax
ENDM

MACRO   filter2_8R
        mov     al,[es:di]
        add     bx,ax
        add     bx,ax
        add     bx,ax
        shr     bx,2
        mov     [es:di],bl
        inc     di
        mov     bx,ax
ENDM


DATASEG

        EXTRN   filterType:WORD

        prevval         DW 128
        prevvalR        DW 128

CODESEG

        PUBLIC  filterEffectsASM

PROC    filterEffectsASM USES di, buffer:DWORD, buflen:DWORD, datatype:DWORD

        mov     ax,[filterType]
        cmp     al,1
        je      @@simpleFilter1
        cmp     al,2
        je      @@simpleFilter2
        jmp     @@exit

;/***************************************************************************\
;*
;* Simple filter 1
;*
;* y(n) = (x(n) + x(n-1))/2
;*
;\***************************************************************************/

@@simpleFilter1:

        mov     cx,[WORD buflen]
        jcxz    @@exit
        les     di,[buffer]

        mov     al,[BYTE dataType]

        test    al,2
        jz      @@monofilter1

        test    al,1
        jz      @@stereo8filter1
        movsx   edx,[prevval]
        movsx   ebx,[prevvalR]
ALIGN 4
@@stereoloopfilter1:
        filter1_16
        filter1_16R
        dec     cx
        jnz     @@stereoloopfilter1
        mov     [prevval],dx
        mov     [prevvalR],bx

        jmp     @@exit
@@stereo8filter1:
        mov     dx,[prevval]
        mov     bx,[prevvalR]
        sub     ah,ah
ALIGN 4
@@stereo8loopfilter1:
        filter1_8
        filter1_8R
        dec     cx
        jnz     @@stereo8loopfilter1
        mov     [prevval],dx
        mov     [prevvalR],bx
        jmp     @@exit
@@monofilter1:

        test    al,1
        jz      @@mono8filter1

        movsx   edx,[prevval]
ALIGN 4
@@monoloopfilter1:
        filter1_16
        dec     cx
        jnz     @@monoloopfilter1
        mov     [prevval],dx
        jmp     @@exit
@@mono8filter1:

        mov     dx,[prevval]
        sub     ah,ah
ALIGN 4
@@mono8loopfilter1:
        filter1_8
        dec     cx
        jnz     @@mono8loopfilter1
        mov     [prevval],dx
        jmp     @@exit

;/***************************************************************************\
;*
;* Simple filter 2
;*
;* y(n) = (x(n)*3 + x(n-1))/4
;*
;\***************************************************************************/


@@simpleFilter2:
        mov     cx,[WORD buflen]
        jcxz    @@exit
        les     di,[buffer]

        mov     al,[BYTE dataType]

        test    al,2
        jz      @@monofilter2

        test    al,1
        jz      @@stereo8filter2
        movsx   edx,[prevval]
        movsx   ebx,[prevvalR]
ALIGN 4
@@stereoloopfilter2:
        filter2_16
        filter2_16R
        dec     cx
        jnz     @@stereoloopfilter2
        mov     [prevval],dx
        mov     [prevvalR],bx

        jmp     @@exit
@@stereo8filter2:
        mov     dx,[prevval]
        mov     bx,[prevvalR]
        sub     ah,ah
ALIGN 4
@@stereo8loopfilter2:
        filter2_8
        filter2_8R
        dec     cx
        jnz     @@stereo8loopfilter2
        mov     [prevval],dx
        mov     [prevvalR],bx
        jmp     @@exit
@@monofilter2:

        test    al,1
        jz      @@mono8filter2

        movsx   edx,[prevval]
ALIGN 4
@@monoloopfilter2:
        filter2_16
        dec     cx
        jnz     @@monoloopfilter2
        mov     [prevval],dx
        jmp     @@exit
@@mono8filter2:

        mov     dx,[prevval]
        sub     ah,ah
ALIGN 4
@@mono8loopfilter2:
        filter2_8
        dec     cx
        jnz     @@mono8loopfilter2
        mov     [prevval],dx
@@exit:
        ret
ENDP

END
