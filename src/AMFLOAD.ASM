;
; ************************************************************************
; *
; *    File        : AMFLOAD.ASM
; *
; *    Description : Loads an AMF format module file
; *
; *    Copyright (C) 1994 Jussi Lahdenniemi, conversion from AMFLOAD.C
; *              (C) 1992-1994 Otto Chrons
; *
; ************************************************************************
;

        ideal
        model   tpascal
        p386
        jumps

INCLUDE "AMP.INC"

dataseg

        extrn   loadOptions:word

codeseg

;        extrn   f_seek:FAR,f_read:FAR,m_alloc:FAR,m_free:FAR


        extrn   mallocf:FAR,freef:FAR,blockrd:FAR,seekf:FAR

PROC    f_seek  FAR f:dword,p:dword

        push    es fs gs eax ebx ecx edx esi edi

        call    FAR seekf Pascal,[f],[p]

        pop     edi esi edx ecx ebx eax gs fs es
        ret
ENDP

PROC    f_read  FAR w:dword,l:dword,f:dword

        push    es fs gs eax ebx ecx edx esi edi

        call    FAR blockrd Pascal,[f],[w],[word l]

        pop     edi esi edx ecx ebx eax gs fs es
        ret
ENDP

PROC    m_alloc FAR l:dword

        push    es fs gs ebx ecx esi edi

        call    FAR mallocf Pascal,[word l]

        pop     edi esi ecx ebx gs fs es
        ret
ENDP


PROC    m_free  FAR p:dword

        push    es fs gs eax ebx ecx edx esi edi

        call    FAR freef Pascal,[p]

        pop     edi esi edx ecx ebx eax gs fs es
        ret
ENDP




PROC    joinTracks2Patterns NEAR module:dword

        push    es fs si di
        les     bx,[module]
        mov     cl,[es:bx+S_MODULE.patternCount]
        mov     dl,[es:bx+S_MODULE.channelCount]
        lfs     si,[es:bx+S_MODULE.tracks]
        les     bx,[es:bx+S_MODULE.patterns]
@@loopPat:
        mov     dh,dl
        push    bx
        lea     bx,[bx+S_PATTERN.track]
@@loopTrk:
        mov     di,[es:bx]
        shl     di,2
        xchg    bx,si
        mov     eax,[fs:bx+di]
        xchg    bx,si
        mov     [es:bx],eax
        add     bx,4
        dec     dh
        jnz     @@loopTrk
        pop     bx
        add     bx,MAXTRACKS*4+2
        dec     cl
        jnz     @@loopPat
        pop     di si fs es
        ret
ENDP

        public  loadAMFasm

PROC    loadAMFasm FAR file:dword,module:dword

local   temp1:dword,sample:dword,lastins:word,insptr:word,\
        tracks:dword,trackptr:word

        push    es fs gs bx cx dx si di

        les     si,[module]
        mov     [es:si+S_MODULE.tempo],125
        mov     [es:si+S_MODULE.speed],6
        call    f_seek Pascal,[file],LARGE 0
        mov     ax,ss
        shl     eax,16
        lea     ax,[temp1]
        call    f_read Pascal,eax,LARGE 4,[file]
        mov     ax,-1
        cmp     [temp1],0e464d41h               ; latest AMF?
        jne     @@exit                          ; If not, exit.

        lea     bx,[si+S_MODULE.mname]
        call    f_read Pascal,es bx,LARGE 32,[file]
        lea     bx,[si+S_MODULE.instrumentCount]
        call    f_read Pascal,es bx,LARGE 1,[file]
        lea     bx,[si+S_MODULE.patternCount]
        call    f_read Pascal,es bx,LARGE 1,[file]
        lea     bx,[si+S_MODULE.trackCount]
        call    f_read Pascal,es bx,LARGE 2,[file]
        lea     bx,[si+S_MODULE.channelCount]
        call    f_read Pascal,es bx,LARGE 1,[file]
        lea     bx,[si+S_MODULE.channelPanning]
        call    f_read Pascal,es bx,LARGE 32,[file]
        lea     bx,[si+S_MODULE.tempo]
        call    f_read Pascal,es bx,LARGE 1,[file]
        lea     bx,[si+S_MODULE.speed]
        call    f_read Pascal,es bx,LARGE 1,[file]

        sub     eax,eax
        mov     al,[es:si+S_MODULE.patternCount]
        imul    ax,size S_PATTERN
        add     [es:si+S_MODULE.size],eax
        call    m_alloc Pascal,eax
        mov     [word es:si+S_MODULE.patterns],ax
        mov     [word es:si+2+S_MODULE.patterns],dx
        sub     eax,eax
        mov     al,[es:si+S_MODULE.instrumentCount]
        imul    ax,size S_INSTRUMENT
        add     [es:si+S_MODULE.size],eax
        call    m_alloc Pascal,eax
        mov     [word es:si+S_MODULE.instruments],ax
        mov     [word es:si+2+S_MODULE.instruments],dx
        sub     eax,eax
        mov     ax,[es:si+S_MODULE.trackCount]
        add     ax,4
        shl     ax,2
        add     [es:si+S_MODULE.size],eax
        call    m_alloc Pascal,eax
        mov     [word es:si+S_MODULE.tracks],ax
        mov     [word es:si+2+S_MODULE.tracks],dx

        sub     cx,cx
        mov     cl,[es:si+S_MODULE.patternCount]
        lfs     di,[es:si+S_MODULE.patterns]
@@tloop:
        push    di
        call    f_read Pascal,fs di,LARGE 2,[file]
        sub     dx,dx
        mov     dl,[es:si+S_MODULE.channelCount]
        add     di,2
@@iloop:
        call    f_read Pascal,fs di,LARGE 2,[file]
        add     di,4
        dec     dx
        jnz     @@iloop
        pop     di
        add     di,MAXTRACKS*4+2
        dec     cx
        jnz     @@tloop

        sub     eax,eax
        mov     al,[es:si+S_MODULE.instrumentCount]
        shl     ax,1
        add     [es:si+S_MODULE.size],eax
        call    m_alloc Pascal,eax
        mov     bx,ax
        mov     gs,dx
        mov     [word sample],bx
        mov     [word sample+2],gs
        mov     [lastins],0
        mov     [insptr],0

        sub     cx,cx
        mov     cl,[es:si+S_MODULE.instrumentCount]
        lfs     di,[es:si+S_MODULE.instruments]
@@insloop:
        call    f_read Pascal,fs di,LARGE size S_INSTRUMENT,[file]
        mov     ax,[word fs:di+S_INSTRUMENT.sample]
        cmp     ax,[lastins]
        jle     @@lessoreq
        mov     [lastins],ax
@@lessoreq:
        cmp     ax,[insptr]
        jle     @@lessoreq2
        mov     ax,bx
        mov     bx,[insptr]
        shl     bx,1
        add     bx,ax
        mov     dx,[word fs:di+S_INSTRUMENT.size]
        mov     [gs:bx],dx
        mov     bx,ax
        inc     [insptr]
@@lessoreq2:
        add     di,size S_INSTRUMENT
        dec     cx
        jnz     @@insloop
        mov     ax,[lastins]
        mov     [insptr],ax

        sub     eax,eax
        mov     ax,[es:si+S_MODULE.trackCount]
        shl     ax,1
        add     [es:si+S_MODULE.size],eax
        call    m_alloc Pascal,eax
        mov     bx,ax
        mov     gs,dx
        mov     [word tracks],bx
        mov     [word tracks+2],gs
        mov     [trackptr],0

        mov     cx,[es:si+S_MODULE.trackCount]
@@trkloop:
        call    f_read Pascal,gs bx,LARGE 2,[file]
        mov     ax,[gs:bx]
        cmp     ax,[trackptr]
        jle     @@leag
        mov     [trackptr],ax
@@leag:
        add     bx,2
        dec     cx
        jnz     @@trkloop

        lfs     di,[es:si+S_MODULE.tracks]
        mov     cx,[es:si+S_MODULE.trackCount]
        add     di,4
@@trklp2:
        mov     [dword fs:di],0
        add     di,4
        dec     cx
        jnz     @@trklp2

;        mov     cx,[trackptr]
        sub     cx,cx
@@trklp3:
        mov     bx,ss
        shl     ebx,16
        lea     bx,[temp1]
        call    f_read Pascal,ebx,LARGE 3,[file]
        sub     ebx,ebx
        mov     fs,bx
        mov     ax,[word temp1]
        test    ax,ax
        jz      @@azero
        mov     bx,ax
        push    ax
        lea     ebx,[ebx+ebx*2]
        mov     edx,ebx
        push    edx
        add     ebx,6
        add     [es:si+S_MODULE.size],ebx
        call    m_alloc Pascal,ebx
        mov     bx,ax
        mov     fs,dx
        pop     edx
        pop     ax
        mov     [fs:bx+S_TRACK.type],0
        mov     [fs:bx+S_TRACK.size],ax
        push    bx
        lea     bx,[bx+S_TRACK.note]
        call    f_read Pascal,fs bx,edx,[file]
        pop     bx
@@azero:
        mov     dx,[es:si+S_MODULE.trackCount]
        push    ds
        lds     di,[es:si+S_MODULE.tracks]
        push    bp
        lgs     bp,[tracks]
        add     di,4
        mov     ax,cx
        inc     ax
@@trilp:
        cmp     [gs:bp],ax
        jne     @@nsm
        mov     [ds:di],bx
        mov     [ds:di+2],fs
@@nsm:
        add     di,4
        add     bp,2
        dec     dx
        jnz     @@trilp
        pop     bp
        pop     ds
        inc     cx
        cmp     cx,[trackptr]
        jne     @@trklp3

        lfs     bx,[sample]
        sub     cx,cx
@@ildlp:
        cmp     [word fs:bx],0
        jz      @@stzero
        sub     eax,eax
        mov     ax,[fs:bx]
        push    eax
        add     eax,16
        add     [es:si+S_MODULE.size],eax
        call    m_alloc Pascal,eax
        mov     gs,dx
        mov     di,ax
        pop     edx
        call    f_read Pascal,gs di,edx,[file]
        sub     dx,dx
@@ildlpi:
        push    es si
        les     si,[es:si+S_MODULE.instruments]
        mov     ax,dx
        imul    ax,size S_INSTRUMENT
        add     si,ax
        mov     ax,cx
        inc     ax
        cmp     [word es:si+S_INSTRUMENT.sample],ax
        jne     @@noch
        test    [dword es:si+S_INSTRUMENT.sample],0ffff0000h
        jnz     @@noch
        mov     [word es:si+S_INSTRUMENT.sample],di
        mov     [word es:si+2+S_INSTRUMENT.sample],gs
@@noch:
        pop     si es
        inc     dx
        cmp     dl,[es:si+S_MODULE.instrumentCount]
        jne     @@ildlpi
@@stzero:
        add     bx,2
        inc     cx
        cmp     cx,[insptr]
        jne     @@ildlp
        lfs     bx,[es:si+S_MODULE.instruments]
        sub     cx,cx
        mov     cl,[es:si+S_MODULE.instrumentCount]
@@chilp:
        test    [dword fs:bx+S_INSTRUMENT.sample],0ffff0000h
        jnz     @@wnzr
        mov     [dword fs:bx+S_INSTRUMENT.sample],0
@@wnzr:
        add     bx,size S_INSTRUMENT
        dec     cx
        jnz     @@chilp
        call    joinTracks2Patterns Pascal,[module]
        call    m_free Pascal,[sample]
        call    m_free Pascal,[tracks]
        sub     ax,ax
@@exit:
        pop     di si dx cx bx gs fs es
        ret
ENDP

END
