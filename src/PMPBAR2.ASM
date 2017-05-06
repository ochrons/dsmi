; ***************************************************************************
;
;                              PMPBAR2.ASM
;                              -----------
;
;                Color bar routine version 2, for PMP 2.31+
;
;                     (C) 1993 Jussi Lahdenniemi
;
; You may freely use this source in your own products, modified or
; unmodified, as long as you give credits to me.
;
; ***************************************************************************

        MODEL TPASCAL
        IDEAL
        JUMPS
        P386N

        tcstrbarCount   =       0
        tcstremptyColor =       tcstrbarCount+1
        tcstrstartRow   =       tcstremptyColor+1
        tcstrexitRow    =       tcstrstartRow+2
        tcstrbarColor   =       tcstrexitRow+2
        tcstrbarStart   =       tcstrbarColor+16
        tcstrbarEnd     =       tcstrbarStart+16*2
        tcstrstartRed   =       tcstrbarEnd+16*2
        tcstrstartGreen =       tcstrstartRed+1
        tcstrstartBlue  =       tcstrstartGreen+1
        tcstrendRed     =       tcstrstartBlue+1
        tcstrendGreen   =       tcstrendRed+1
        tcstrendBlue    =       tcstrendGreen+1
        tcstrdacEntry   =       tcstrendBlue+1
        tcstrstatus     =       tcstrdacEntry+1

CODESEG

        Public  drawColorBars


; Status byte:
; bit 0 : If set, the bar is visible at the moment
; bit 1 : If set, the bar should be set to visible in the next retrace
; bit 2 : If set, the bar should be set to invisible in the next retrace

PROC    drawColorBars FAR uses ecx esi edi,cstr:DWORD,gus:BYTE,ports:WORD
        local   w:word,w2:word,redInc:dword,greenInc:dword,blueInc:dword
        local   cRed:dword,cGreen:dword,cBlue:dword
        local   currentRow:word,mustChange:byte,tempcl:byte

        push    ds
        sub     esi,esi
        lds     si,[cstr]
        cmp     [byte ptr esi+tcstrbarCount],0
        jnz     notZero
        pop     ds
        ret
notZero:
        mov     [dword ptr si+tcstrstatus],0          ; Set status to zero
        mov     [dword ptr si+tcstrstatus+4],0
        mov     [dword ptr si+tcstrstatus+8],0
        mov     [dword ptr si+tcstrstatus+12],0
        mov     ax,[esi+tcstrexitRow]
        sub     ax,[esi+tcstrstartRow]
        mov     [w],ax
        sub     ax,ax
        mov     dx,1
        div     [w]
        mov     [w2],ax
        mov     al,[esi+tcstrendRed]                   ; Calculate delta
        sub     al,[esi+tcstrstartRed]                 ; red for each row
        cbw
        xor     al,ah
        sub     al,ah
        mov     bl,ah
        mov     bh,ah
        sub     ah,ah
        sub     dx,dx
        div     [w]
        sub     ah,ah
        xor     ax,bx
;        sub     ax,bx
        mov     [word ptr redInc+2],ax
        mov     ax,dx
        mul     [w2]
        xor     ax,bx
;        sub     ax,bx
        mov     [word ptr redInc],ax                    ; Saved into redInc
        mov     al,[esi+tcstrendGreen]
        sub     al,[esi+tcstrstartGreen]               ; Do the same to green
        cbw
        xor     al,ah
        sub     al,ah
        mov     bl,ah
        mov     bh,ah
        sub     ah,ah
        sub     dx,dx
        div     [w]
        sub     ah,ah
        xor     ax,bx
;        sub     ax,bx
        mov     [word ptr greenInc+2],ax
        mov     ax,dx
        mul     [w2]
        xor     ax,bx
;        sub     ax,bx
        mov     [word ptr greenInc],ax
        mov     al,[esi+tcstrendBlue]                  ; and blue
        sub     al,[esi+tcstrstartBlue]
        cbw
        xor     al,ah
        sub     al,ah
        mov     bl,ah
        mov     bh,ah
        sub     ah,ah
        sub     dx,dx
        div     [w]
        sub     ah,ah
        xor     ax,bx
;        sub     ax,bx
        mov     [word ptr blueInc+2],ax
        mov     ax,dx
        mul     [w2]
        xor     ax,bx
;        sub     ax,bx
        mov     [word ptr blueInc],ax

        sub     eax,eax
        mov     al,[esi+tcstrstartRed]
        shl     eax,16
        mov     [cRed],eax
        mov     al,[esi+tcstrstartGreen]
        shl     eax,16
        mov     [cGreen],eax
        mov     al,[esi+tcstrstartBlue]
        shl     eax,16
        mov     [cBlue],eax

        cmp     [gus],1
        je      wasgus
        cli
        jmp     wasntgus
wasgus:
        mov     al,[byte ptr ports]
        out     21h,al
        mov     al,[byte ptr ports+2]
        out     0a1h,al
wasntgus:
        mov     dx,3dah
vr:
        in      al,dx
        test    al,8
        jz      vr
        mov     dx,3c0h
        sub     al,al
        out     dx,al
        sub     ecx,ecx
lp1:
        mov     ax,[word ptr esi+tcstrbarStart+ecx*2]
        mov     bl,[esi+tcstremptyColor]
        or      ax,ax
        jnz     empty
        mov     bl,[esi+tcstrdacEntry]
        or      [byte ptr esi+tcstrstatus+ecx],1
empty:
        mov     dx,3dah
        in      al,dx
        mov     dx,3c0h
        mov     al,[byte ptr esi+tcstrbarColor+ecx]
        out     dx,al
        mov     al,bl
        out     dx,al
        inc     cl
        cmp     cl,[esi+tcstrbarCount]
        jne     lp1
        mov     al,20h
        out     dx,al

        mov     dx,3c8h
        mov     al,[esi+tcstrdacEntry]
        out     dx,al
        inc     dx
        mov     al,[esi+tcstrstartRed]
        out     dx,al
        mov     al,[esi+tcstrstartGreen]
        out     dx,al
        mov     al,[esi+tcstrstartBlue]
        out     dx,al

        mov     cx,[esi+tcstrstartRow]
        mov     [currentRow],cx
        mov     dx,3dah                         ; Wait for display
dsp:
        in      al,dx
        test    al,1
        jnz     dsp
        dec     cx
        js      mainLoop
dsp2:
        in      al,dx
        test    al,1
        jz      dsp2
        jmp     dsp

mainLoop:
        mov     dx,3c8h
        mov     al,[esi+tcstrdacEntry]
        out     dx,al
        inc     dx
        mov     eax,[cRed]
        add     eax,[redInc]
        mov     [cRed],eax
        shr     eax,16
        out     dx,al
        mov     eax,[cGreen]
        add     eax,[greenInc]
        mov     [cGreen],eax
        shr     eax,16
        out     dx,al
        mov     eax,[cBlue]
        add     eax,[blueInc]
        mov     [cBlue],eax
        shr     eax,16
        mov     [tempcl],al

        sub     ecx,ecx
checkbars:
        mov     ax,[currentRow]
        test    [byte ptr esi+tcstrstatus+ecx],1
        jz      nowInv

        cmp     [word ptr esi+tcstrbarEnd+ecx*2],ax
        jnz     noChange
        mov     [byte ptr esi+tcstrstatus+ecx],100b
        inc     [mustChange]
        jmp     noChange
nowInv:
        cmp     [word ptr esi+tcstrbarStart+ecx*2],ax
        jnz     noChange
        cmp     [word ptr esi+tcstrbarEnd+ecx*2],ax
        jz      noChange
        mov     [byte ptr esi+tcstrstatus+ecx],11b
        inc     [mustChange]
noChange:
        inc     cx
        cmp     cl,[esi+tcstrbarCount]
        jne     checkBars

        cmp     [mustChange],0
        jz      noMust
        mov     dx,3c0h
        sub     cx,cx
mustLoop:
        test    [byte ptr esi+tcstrstatus+ecx],10b
        jz      noSet
        mov     bl,[esi+tcstrbarColor+ecx]
        mov     bh,[esi+tcstrDacEntry]
        mov     dx,3dah
waitHR1:
        in      al,dx
        test    al,1
        jnz     waitHR1
waitHR12:
        in      al,dx
        test    al,1
        jz      waitHR12
        mov     dx,3c0h
        mov     al,bl
        out     dx,al
        mov     al,bh
        out     dx,al
        mov     al,20h
        out     dx,al
        mov     [byte ptr esi+tcstrstatus+ecx],1b
        dec     [mustChange]
        jmp     mustOut
noSet:
        test    [byte ptr esi+tcstrstatus+ecx],100b
        jz      must1
        mov     bl,[esi+tcstrbarColor+ecx]
        mov     bh,[esi+tcstremptyColor]
        mov     dx,3dah
waitHR2:
        in      al,dx
        test    al,1
        jnz     waitHR2
waitHR22:
        in      al,dx
        test    al,1
        jz      waitHR22
        mov     dx,3c0h
        mov     al,bl
        out     dx,al
        mov     al,bh
        out     dx,al
        mov     al,20h
        out     dx,al
        mov     [byte ptr esi+tcstrstatus+ecx],0b
        dec     [mustChange]
        jmp     mustOut
must1:
        inc     cx
        cmp     cx,[esi+tcstrbarCount]
        jne     mustLoop

noMust:
        mov     dx,3dah
waitHR3:
        in      al,dx
        test    al,1
        jnz     waitHR3
waitHR32:
        in      al,dx
        test    al,1
        jz      waitHR32
mustOut:
        mov     dx,3c9h
        mov     al,[tempcl]
        out     dx,al

        inc     [currentRow]
        mov     ax,[esi+tcstrexitRow]
        cmp     [currentRow],ax
        jb      mainLoop

        pop     ds
        ret
ENDP

END
