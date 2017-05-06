;/************************************************************************
; *
; *     File        : FASTEXT.ASM
; *
; *     Description : Fast text routines for C
; *
; *     Copyright (C) 1993 Otto Chrons
; *
; ************************************************************************/

        IDEAL
        MODEL LARGE,C
        JUMPS
        P286

DATASEG
	PUBLIC screenSegment, quietMode

	screenSegment DW 0B800h
	quietMode     DB 0

CODESEG

        PUBLIC initFastext, updateBuffer
        PUBLIC writeBuf
        PUBLIC moveBuf, moveChar, moveStr, moveCStr, writeStr, writeCStr
        PUBLIC putChar, putAttr
        PUBLIC cursorxy

;/*************************************************************************
; *
; *     Function    :   initFastext();
; *
; *     Description :   Initializes fastext
; *
; ************************************************************************/

PROC    initFastext FAR USES di

        mov     ax,0F00h
        int     10h                     ; Get screenmode
        and     ax,007Fh
        push    ax
        cmp     al,7
        jne     @@notMono
        mov     [screenSegment],0B000h
@@notMono:
        mov     ah,0FEh
        sub     di,di
        mov     es,[screenSegment]
        int     10h
        mov     [screenSegment],es
        pop     ax
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   updateBuffer(ushort start, ushort count);
; *
; *     Description :   Updates screen buffer under DV
; *
; ************************************************************************/

PROC    updateBuffer FAR USES di, start:WORD, count:WORD

        mov     ah,0FFh
        mov     cx,[count]
        mov     di,[start]
        mov     es,[screenSegment]
        int     10h
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   void writeBuf(void *buf, ushort x, ushort y, ushort count)
; *
; *     Description :   Writes a buffer to screen
; *
; ************************************************************************/

PROC    writeBuf FAR USES si di, buf:DWORD, x:WORD, y:WORD, count:WORD

	cmp	[quietmode],1
	je	@@exit
	push    ds
	mov     ax,[screenSegment]
	mov     es,ax
        lds     si,[buf]
        mov     cx,[count]
        jcxz    @@99
        mov     ax,160
        mul     [y]
        add     ax,[x]
        add     ax,[x]
        mov     di,ax
        mov     bx,di
        cld
        rep     movsw
@@99:
        pop     ds
        cmp     [screenSegment],0B800h
        je      @@exit
        mov     di,bx
        mov     cx,[count]
        mov     ah,0FFh
        int     10h
@@exit:
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :    void moveBuf(void far *buf, ushort indent, const void far *src, ushort count)
; *
; *     Description :
; *
; ************************************************************************/

PROC    moveBuf FAR USES ds si di, buf:DWORD, indent:WORD, src:DWORD, count:WORD

        mov     cx,[count]
        jcxz    @@99

        les     di,[buf]
        lds     si,[src]
        add     di,[indent]
        add     di,[indent]
	cld
        rep     movsw
@@99:
        ret
ENDP


;/*************************************************************************
; *
; *     Function    :    void moveChar(void *buf, ushort indent, char c, ushort attr, ushort count)
; *
; *     Description :
; *
; ************************************************************************/

PROC    moveChar FAR USES di,buf:DWORD, indent:WORD, c:BYTE, attr:WORD, count:WORD

        mov     cx,[count]
        jcxz    @@99

        les     di,[buf]
        add     di,[indent]
        add     di,[indent]
        mov     al,[c]
        mov     ah,[BYTE PTR attr]
        cld
        rep     stosw
@@99:
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :    void moveStr(void far *buf, ushort indent, const char far *stri, ushort attr)
; *
; *     Description :
; *
; ************************************************************************/

PROC    moveStr FAR USES ds si di,buf:DWORD,indent:WORD,stri:DWORD,attr:WORD

        les     di,[buf]
        lds     si,[stri]
	add     di,[indent]
        add     di,[indent]
        mov     ah,[BYTE PTR attr]
        cld
        mov     cx,132
@@1:
        lodsb
        or      al,al
        jz      @@99
        stosw
        loop    @@1
@@99:
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :    void moveCStr(void far *buf, ushort indent, const char far *stri, ushort attr1, ushort attr2)
; *
; *     Description :
; *
; ************************************************************************/

PROC    moveCStr FAR USES ds si di,buf:DWORD,indent:WORD,stri:DWORD,attr1:WORD,attr2:WORD


        les     di,[buf]
        lds     si,[stri]
        add     di,[indent]
        add     di,[indent]
        mov     ah,[BYTE PTR attr1]
        mov     bx,1
        cld
        mov     cx,132
@@1:
        lodsb
        or      al,al
        jz      @@99
        cmp     al,'~'
        jne     @@4
        mov     ah,[BYTE PTR attr2]
        neg     bx
        js      @@3
	mov     ah,[BYTE PTR attr1]
@@3:    loop    @@1
@@4:
        stosw
        loop    @@1
@@99:
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :    void putChar(void far *buf, ushort indent, char c)
; *
; *     Description :
; *
; ************************************************************************/

PROC    putChar FAR USES di,buf:DWORd,indent:WORD,c:BYTE

        les     di,[buf]
        add     di,[indent]
        add     di,[indent]
        mov     al,[c]
        mov     [es:di],al
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :    void putAttribute(void far *buf, ushort indent, ushort attr)
; *
; *     Description :
; *
; ************************************************************************/

PROC    putAttr FAR USES di,buf:DWORD,indent:WORD,attr:WORD

        les     di,[buf]
        add     di,[indent]
        add     di,[indent]
        mov     al,[BYTE PTR attr]
        mov     [es:di+1],al
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :    void cursorxy(int x, int y)
; *
; *     Description :
; *
; ************************************************************************/

PROC    cursorxy FAR x:WORD,y:WORD

	cmp	[quietMode],1
	je	@@exit
	mov     ah,2
	mov     bx,0
	mov     dh,[byte ptr y]
	mov     dl,[byte ptr x]
	int     10h
@@exit:
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :    void writeStr(const char far *stri, ushort x, ushort y, ushort attr, ushort count)
; *
; *     Description :
; *
; ************************************************************************/

PROC    writeStr FAR stri:DWORD,x:WORD,y:WORD,attr:WORD,count:WORD
        LOCAL   buf:WORD:160

        cmp     [count],160
        jle     @@cntOK
        mov     [count],160
@@cntOK:
        lea     bx,[buf]
        call    moveChar C,ss bx,0,' ',[attr],80
        lea     bx,[buf]
        call    moveStr C,ss bx,0,[stri],[attr]
        lea     bx,[buf]
	call    writeBuf C,ss bx,[x],[y],[count]
	ret
ENDP

;/*************************************************************************
; *
; *     Function    :    void writeCStr(const char far *stri, ushort x, ushort y, ushort attr1, ushort attr2, ushort count)
; *
; *     Description :
; *
; ************************************************************************/

PROC    writeCStr FAR stri:DWORD,x:WORD,y:WORD,attr1:WORD,attr2:WORD,count:WORD
        LOCAL   buf:WORD:160

        cmp     [count],160
        jle     @@cntOK
        mov     [count],160
@@cntOK:
        lea     bx,[buf]
        call    moveChar C,ss bx,0,' ',[attr1],80
        lea     bx,[buf]
        call    moveCStr C,ss bx,0,[stri],[attr1],[attr2]
        lea     bx,[buf]
        call    writeBuf C,ss bx,[x],[y],[count]
        ret
ENDP

END
