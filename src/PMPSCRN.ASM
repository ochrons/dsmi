; ***************************************************************************
;
;                                 PMPSCRN.ASM
;                                 -----------
;
;                         (C) 1993 Jussi Lahdenniemi
;
; Screen buffer copier for PMP 2.31+
;
; I doubt you'll ever have any use for this routine, but if you do, please
; feel free to use it anyway you want.
;
; ***************************************************************************

        MODEL TPASCAL
        IDEAL
        JUMPS
        P386N

DATASEG

        Extrn whereAmI:WORD,paletteMap:BYTE,segb800:WORD,colorMask:BYTE

CODESEG

        Public updateScreen

PROC    updateScreen FAR count:WORD
        local seg1:WORD,seg2:WORD,colorMoffs:WORD

        mov     es,[segb800]
        sub     esi,esi
        sub     edi,edi
        mov     si,[whereAmI]
        mov     di,si
        add     di,8192
        mov     cx,[count]
        shr     cx,1
        sub     ebx,ebx
        sub     edx,edx
        push    ebp
        sub     ebp,ebp
        mov     bp,offset paletteMap
loop1:
        mov     ax,[es:esi*2]
        mov     dl,ah
        mov     bl,ah
        and     ah,11110000b
        test    [byte ptr ds:si+colorMask],1
        jnz     donotchange
        shr     dl,4
        mov     ah,[ds:ebp+edx]
        shl     ah,4
donotchange:
        and     bl,15
        or      ah,[ds:ebp+ebx]
        mov     [es:edi*2],ax
        inc     si
        and     si,4095
        lea     di,[si+4096]
        dec     cx
        jnz     loop1
        mov     [whereAmI],si
        pop     ebp
        ret
ENDP

END
