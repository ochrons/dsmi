// ************************************************************************
// *
// *    File        : FASTEXT.C
// *
// *    Description : Fast directvideo routines for text output.
// *
// *    Copyright (C) 1992 Otto Chrons
// *
// ************************************************************************

#include "fastext.h"

static screenSegment = 0xB800;

void initFastext()
{
    asm {
        mov     ah,0FEh
        sub     di,di
        mov     es,[screenSegment]
        int     10h
        mov     [screenSegment],es
    }
}

void updateBuffer(ushort start,ushort count)
{
    asm {
        mov     ah,0FFh
        mov     cx,count
        mov     di,start
        mov     es,[screenSegment]
        int     10h
    }
}

void writeBuf(const void far *buf, ushort x, ushort y, ushort count)
{
    asm {
        push    ds
        mov     ax,[screenSegment]
        mov     es,ax
        lds     si,buf
        mov     cx,count
        jcxz    __99
        mov     ax,160
        mul     y
        add     ax,x
        add     ax,x
        mov     di,ax
        mov     bx,di
        cld
        rep     movsw
        cmp     [screenSegment],0B800h
        je      __99
        mov     di,bx
        mov     cx,count
        mov     ah,0FFh
        int     10h                     // Update video buffer
    }
__99:
    asm pop     ds
}

void writeStr(const char far *str, ushort x, ushort y, ushort attr, ushort count)
{
    ushort      buf[160];

    if( count > 160 ) count = 160;
    moveChar(buf,0,' ',attr,80);
    moveStr(buf,0,str,attr);
    writeBuf(buf,x,y,count);
}

void writeCStr(const char far *str, ushort x, ushort y, ushort attr1, ushort attr2, ushort count)
{
    ushort      buf[160];

    if( count > 160 ) count = 160;
    moveChar(buf,0,' ',attr1,80);
    moveCStr(buf,0,str,attr1,attr2);
    writeBuf(buf,x,y,count);
}

void moveBuf(void far *buf, ushort indent, const void far *src, ushort count)
{
    asm {
        push    ds
        mov     cx,count
        jcxz    __99

        les     di,buf
        lds     si,src
        add     di,indent
        add     di,indent
        cld
        rep     movsw
    }
__99:
    asm pop     ds
}

void moveChar(void far *buf, ushort indent, char c, ushort attr, ushort count)
{
    asm {
        mov     cx,count
        jcxz    __99

        les     di,buf
        add     di,indent
        add     di,indent
        mov     al,c
        mov     ah,[BYTE PTR attr]
        cld
        rep     stosw
    }
__99:;
}

void moveStr(void far *buf, ushort indent, const char far *str, ushort attr)
{
    asm {
        push    ds

        les     di,buf
        lds     si,str
        add     di,indent
        add     di,indent
        mov     ah,[BYTE PTR attr]
        cld
        mov     cx,132
    }
__1:
    asm {
        lodsb
        or      al,al
        jz      __99
        stosw
        loop    __1
    }
__99:
    asm pop     ds
}

void moveCStr(void far *buf, ushort indent, const char far *str, ushort attr1, ushort attr2)
{
    asm {
        push    ds

        les     di,buf
        lds     si,str
        add     di,indent
        add     di,indent
        mov     ah,[BYTE PTR attr1]
        mov     bx,1
        cld
        mov     cx,132
    }
__1:
    asm {
        lodsb
        or      al,al
        jz      __99
        cmp     al,'~'
        jne     __4
        mov     ah,[BYTE PTR attr2]
        neg     bx
        js      __3
        mov     ah,[BYTE PTR attr1]
    }
__3:asm loop    __1
__4:
    asm {
        stosw
        loop    __1
    }
__99:
    asm pop     ds
}

void putChar(void far *buf, ushort indent, char c)
{
    asm {
        les     di,buf
        add     di,indent
        add     di,indent
        mov     al,c
        mov     [es:di],al
    }
}

void putAttribute(void far *buf, ushort indent, ushort attr)
{
    asm {
        les     di,buf
        add     di,indent
        add     di,indent
        mov     al,[BYTE PTR attr]
        mov     [es:di+1],al
    }
}

void cursorxy(int x, int y)
{
    asm {
        mov     ah,2
        mov     bx,0
        mov     dh,[byte ptr y]
        mov     dl,[byte ptr x]
        int     10h
    }
}

