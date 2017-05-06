;/************************************************************************
; *
; *     File        : SDI_DAC.ASM
; *
; *     Description : Sound Device Interface for interruptdriven DACs
; *
; *     Copyright (C) 1993 Otto Chrons
; *
; ************************************************************************
;
;       Revision history of SDI_DAC.ASM
;
;       1.0     16.4.93
;               First version. Works well, but is not optimized
;
;       1.5     3.10.93
;               Support for stereo DACs
;
;       1.6     20.4.94
;               Optimized the interrupt routines a little
;
; ***********************************************************************/

        IDEAL
        JUMPS
        LOCALS
        P386N

IFDEF   __PASCAL__
        LANG    EQU     PASCAL
        MODEL TPASCAL
ELSE
        LANG    EQU     C
        MODEL LARGE,C
ENDIF

        INCLUDE "MCP.INC"

DATASEG

        EXTRN   mcpStatus:BYTE
        EXTRN   bufferSize:WORD
        EXTRN   dataBuf:WORD
        EXTRN   SoundCard:CARDINFO

CODESEG

        PUBLIC  SDI_DAC, setDACTimer

        copyrightText   DB "SDI for DACs v1.5 - (C) 1992,1993 Otto Chrons",0,1Ah

        DACdevice CARDINFO <7,0,"Simple DAC",0,0,0,4000,60000,0,0,1>

        SoundDeviceDAC  SOUNDDEVICE < \
                far ptr initDAC,\
                far ptr initOutput,\
                far ptr initRate,\
                far ptr closeDAC,\
                far ptr closeOutput,\
                far ptr startVoice,\
                far ptr stopVoice,\
                far ptr pauseVoice,\
                far ptr resumeVoice\
                far ptr getDACpos,\
                far ptr speakerOn,\
                far ptr speakerOff\
                >

        TSrate          DW ?

        bufferPos       DW ?
        bufferSize2     DW ?
        DACbuffer       DD ?
        DACport         DW ?
        DACport2        DW ?
        DACmode         DB ?
        timerCount      DW ?
        oldint          DD ?
        oldrate         DW 65535
        nextByte        DB 0
        nextByte2       DB 0
        spkrTable       DB 256 dup(0)
        spkrBaseTable   DB 40h,40h,40h,40h,40h,40h,40h,40h,40h,40h,3Fh,3Fh,3Fh,3Fh,3Fh,3Fh
                        DB 3Fh,3Fh,3Fh,3Fh,3Fh,3Fh,3Eh,3Eh,3Eh,3Eh,3Eh,3Eh,3Eh,3Eh,3Eh,3Eh
                        DB 3Dh,3Dh,3Dh,3Dh,3Dh,3Dh,3Dh,3Dh,3Dh,3Ch,3Ch,3Ch,3Ch,3Ch,3Ch,3Ch
                        DB 3Ch,3Ch,3Ch,3Bh,3Bh,3Bh,3Bh,3Bh,3Bh,3Bh,3Bh,3Bh,3Bh,3Ah,3Ah,3Ah
                        DB 3Ah,3Ah,3Ah,3Ah,3Ah,3Ah,3Ah,39h,39h,39h,39h,39h,39h,39h,39h,39h
                        DB 39h,38h,38h,38h,38h,38h,38h,38h,38h,37h,37h,37h,37h,37h,36h,36h
                        DB 36h,36h,35h,35h,35h,35h,34h,34h,34h,33h,33h,32h,32h,31h,31h,30h
                        DB 30h,2Fh,2Eh,2Dh,2Ch,2Bh,2Ah,29h,28h,27h,26h,25h,24h,23h,22h,21h
                        DB 20h,1Fh,1Eh,1Dh,1Ch,1Bh,1Ah,19h,18h,17h,16h,15h,14h,13h,12h,11h
                        DB 11h,10h,10h,0Fh,0Fh,0Eh,0Eh,0Dh,0Dh,0Dh,0Ch,0Ch,0Ch,0Ch,0Bh,0Bh
                        DB 0Bh,0Bh,0Ah,0Ah,0Ah,0Ah,0Ah,09h,09h,09h,09h,09h,09h,09h,09h,09h
                        DB 08h,08h,08h,08h,08h,08h,08h,08h,08h,08h,08h,08h,07h,07h,07h,07h
                        DB 07h,07h,07h,06h,06h,06h,06h,06h,06h,06h,06h,06h,06h,06h,05h,05h
                        DB 05h,05h,05h,05h,05h,05h,05h,05h,04h,04h,04h,04h,04h,04h,04h,04h
                        DB 04h,04h,03h,03h,03h,03h,03h,03h,03h,03h,03h,03h,02h,02h,02h,02h
                        DB 02h,02h,02h,02h,02h,01h,01h,01h,01h,01h,01h,01h,01h,01h,01h,01h

;/*************************************************************************
; *
; *     Function    :   setTimerRate
; *
; *     Description :   Set low-level timer rate
; *
; *     Input       :   AX = new timer rate
; *
; ************************************************************************/

PROC    setTimerRate NEAR

        pushf
        cli
        mov     bx,ax
        mov     al,00110100b            ; Set timer rate
        out     43h,al
        mov     ax,bx
        out     40h,al
        mov     al,ah
        out     40h,al
        popf

        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   timerDAC
; *
; *     Description :   Interrupt routine for outputting data from buffer
; *
; ************************************************************************/

PROC    timerDAC FAR

        cli
        push    ax
        mov     al,[nextByte]
        push    dx

        mov     dx,[DACport]
        out     dx,al                   ; Output data byte

        push    di
        push    es

        les     di,[DACbuffer]          ; Get next data
        sub     di,[bufferPos]
        mov     al,[es:di]
        pop     es
        pop     di
        mov     [nextByte],al

        pop     dx
        dec     [bufferPos]
        jz      @@notOK

        mov     ax,[oldrate]
        add     [timerCount],ax
        jc      @@callold
@@notyet:
        mov     al,20h                  ; EOI
        out     20h,al

        pop     ax
        iret
@@notOK:
        mov     ax,[bufferSize2]
        mov     [bufferPos],ax

        mov     ax,[oldrate]
        add     [timerCount],ax
        jc      @@callold

        mov     al,20h                  ; EOI
        out     20h,al

        pop     ax
        iret
@@callold:
        sti
        pop     ax
        jmp     [oldint]
ENDP

;/*************************************************************************
; *
; *     Function    :   timerDACStereo1
; *
; *     Description :   Interrupt routine for outputting data from buffer
; *
; ************************************************************************/

PROC    timerDACStereo1 FAR

        cli
        push    ax
        mov     al,[nextByte]
        push    dx

        mov     dx,[DACport]
        out     dx,al                   ; Output data byte for left

        mov     dx,[DACport2]
        mov     al,[nextByte2]
        out     dx,al                   ; Output data byte for right

        push    di
        push    es

        les     di,[DACbuffer]          ; Get next data
        sub     di,[bufferPos]
        mov     ax,[es:di]
        pop     es
        pop     di
        mov     [nextByte],al
        pop     dx
        mov     [nextByte2],ah

        sub     [bufferPos],2
        jle     @@notOK

        mov     ax,[oldrate]
        add     [timerCount],ax
        jc      @@callold
@@notyet:
        mov     al,20h                  ; EOI
        out     20h,al

        pop     ax
        iret
@@notOK:
        mov     ax,[bufferSize2]
        mov     [bufferPos],ax

        mov     ax,[oldrate]
        add     [timerCount],ax
        jc      @@callold

        mov     al,20h                  ; EOI
        out     20h,al

        pop     ax
        iret
@@callold:
        sti
        pop     ax
        jmp     [oldint]
ENDP

;/*************************************************************************
; *
; *     Function    :   timerDACStereo2
; *
; *     Description :   Interrupt routine for outputting data from buffer
; *
; ************************************************************************/

PROC    timerDACStereo2 FAR

        cli
        push    ax
        push    dx

        mov     dx,[DACport]
        add     dx,2
        mov     al,1
        out     dx,al
        sub     dx,2

        mov     al,[nextByte]
        out     dx,al                   ; Output data byte for left

        add     dx,2
        mov     al,2
        out     dx,al
        sub     dx,2

        mov     al,[nextByte2]
        out     dx,al                   ; Output data byte for right

        push    di
        push    es

        les     di,[DACbuffer]          ; Get next data
        sub     di,[bufferPos]
        mov     ax,[es:di]
        pop     es
        pop     di
        mov     [nextByte],al
        pop     dx
        mov     [nextByte2],ah

        sub     [bufferPos],2
        jle     @@notOK

        mov     ax,[oldrate]
        add     [timerCount],ax
        jc      @@callold
@@notyet:

        mov     al,20h                  ; EOI
        out     20h,al

        pop     ax
        iret
@@notOK:
        mov     ax,[bufferSize2]
        mov     [bufferPos],ax

        mov     ax,[oldrate]
        add     [timerCount],ax
        jc      @@callold

        mov     al,20h                  ; EOI
        out     20h,al

        pop     ax
        iret
@@callold:
        sti
        pop     ax
        jmp     [oldint]
ENDP

;/*************************************************************************
; *
; *     Function    :   timerSpkr
; *
; *     Description :   Interrupt routine for outputting data from buffer
; *
; ************************************************************************/

PROC    timerSpkr FAR

        cli
        push    ax
        mov     al,[nextByte]
        push    dx

        mov     dx,[DACport]
        out     dx,al

        mov     al,20h                  ; EOI
        push    di
        out     20h,al

        push    es

        les     di,[DACbuffer]
        sub     di,[bufferPos]
        sub     ah,ah
        mov     al,[es:di]
        mov     di,ax
        pop     es
        mov     al,[di+spkrTable]
        pop     di
        mov     [nextByte],al
        pop     dx

        dec     [bufferPos]
        jz      @@notOK

        mov     ax,[oldrate]
        add     [timerCount],ax
        jc      @@callold
@@notyet:
        pop     ax
        iret
@@notOK:
        mov     ax,[bufferSize2]
        mov     [bufferPos],ax

        mov     ax,[oldrate]
        add     [timerCount],ax
        jc      @@callold

        pop     ax
        iret
@@callold:
        sti
        pop     ax
        jmp     [oldint]
ENDP

;/*************************************************************************
; *
; *     Function    :   void SDI_DAC(SOUNDDEVICE far *sdi);
; *
; *     Description :   Registers DAC as a sound device
; *
; *     Input       :   Pointer to SD structure
; *
; *     Returns     :   Fills SD structure accordingly
; *
; ************************************************************************/

PROC    SDI_DAC FAR USES di si,sdi:DWORD

        cld
        les     di,[sdi]
        mov     si,offset SoundDeviceDAC
        mov     cx,SIZE SOUNDDEVICE
        cli
        segcs
        rep movsb                       ; Copy structure
        sti
        sub     ax,ax                   ; indicate successful init
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   int initDAC(CARDINFO *sCard);
; *
; *     Description :   Initializes DAC using given 'port' value
; *
; *     Input       :   port    = DAC's I/O address
; *
; *     Returns     :    0      = success
; *                     -1      = error
; *
; ************************************************************************/

PROC    initDAC FAR USES si di,sCard:DWORD

        local   retval:WORD

        mov     [retval],-1             ; assume error
        mov     si,offset DACdevice     ; DS:SI = source
        mov     ax,ds
        mov     es,ax
        mov     di,offset SoundCard     ; ES:DI = destination
        mov     cx,SIZE CARDINFO
        cld
        cli
        segcs
        rep     movsb                   ; Copy information
        sti

        les     si,[sCard]
        mov     al,[es:si+CARDINFO.DMAChannel]
        cmp     al,1
        je      @@stereo1
        cmp     al,2
        je      @@stereo2

        mov     [DACmode],0             ; Normal DAC at xxx
        mov     dx,[es:si+CARDINFO.ioPort]
        mov     [SoundCard.ioPort],dx
        mov     [DACport],dx
        jmp     @@done
@@stereo1:                              ; Two DACs on LPT1 & LPT2
        mov     [DACmode],1
        mov     [SoundCard.stereo],1
        mov     ax,40h
        mov     es,ax
        mov     dx,[es:08h]             ; LPT1 address
        mov     [SoundCard.ioPort],dx
        mov     [DACport],dx
        mov     dx,[es:0Ah]             ; LPT2 address
        mov     [DACport2],dx
        jmp     @@done
@@stereo2:                              ; Stereo-on-1 at xxx
        mov     [DACmode],2
        mov     [SoundCard.stereo],1
        mov     dx,[es:si+CARDINFO.ioPort]
        mov     [SoundCard.ioPort],dx
        mov     [DACport],dx
@@done:
        or      [mcpStatus],S_INIT      ; indicate successful initialization
        mov     [retval],0              ; return 0 = OK
@@exit:
        mov     ax,[retval]
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   initOutput(void far *buffer,int maxsize, int required);
; *
; *     Description :   Init DAC timer routine for output
; *
; ************************************************************************/

PROC    initOutput FAR buffer:DWORD,linear:DWORD,maxSize:DWORD,required:DWORD

	mov     ax,[word required]           ; Is size valid?
	or      ax,ax
	je      @@getmax
	cmp     [word maxSize],ax
	jge     @@sizeOK
@@getmax:
	mov     ax,[word maxSize]
@@sizeOK:
	and     ax,NOT 3                ; 32-bit alignment
	les     bx,[buffer]
	add     bx,4
	and     bx,NOT 3
	mov     [WORD HIGH DACbuffer],es        ; Copy buffer location
	mov     [dataBuf],bx
	add     bx,ax
	mov     [WORD LOW DACbuffer],bx

        mov     [bufferSize],ax         ; Set buffer size
        mov     [bufferSize2],ax
        mov     [bufferPos],ax

        mov     ax,3508h
	int     21h                     ; Get old routine
	mov     [WORD HIGH oldint],es
	mov     [WORD LOW oldint],bx

	mov     [timerCount],65535

	mov     [TSrate],65535
	ret
ENDP

;/*************************************************************************
; *
; *     Function    :   int initRate();
; *
; *     Description :   Inits sound card's sampling rate
; *
; *     Returns     :   Real sampling rate
; *
; ************************************************************************/

PROC    initRate FAR USES di si,sample_rate:DWORD

	mov     ax,[SoundCard.minRate]
	cmp     [word sample_rate],ax        ; Check for valid rates
	jae     @@rateok
	mov     [word sample_rate],ax
	jmp     @@rateok
	mov     ax,[SoundCard.maxRate]
	cmp     [word sample_rate],ax
	jbe     @@rateok
	mov     [word sample_rate],ax
@@rateok:
	mov     dx,12h
	mov     ax,34DCh
	div     [word sample_rate]           ; Calculate timer counter
        mov     [TSrate],ax
@@exit:
        cmp     [SoundCard.ioPort],42h
	jne     @@notSpeaker

        cld
        mov     ax,cs
        mov     es,ax
        mov     di,offset spkrTable
	mov     si,offset spkrBaseTable
        mov     cx,256
@@loop:
        mov     bx,[TSrate]
        shr     bx,1
        mov     al,[cs:si]
        inc     si
        sub     ah,ah
        dec     ax
        mul     bx
        mov     bx,039h
        div     bx
        inc     ax
        stosb
        loop    @@loop

@@notSpeaker:
        mov     [oldrate],ax            ; AX = relative rate

        mov     dx,12h
        mov     ax,34DCh
        div     [TSrate]                ; Return real rate
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   speakerOn
; *
; *     Description :   Does nothing currently
; *
; ************************************************************************/

PROC    speakerOn FAR

        cmp     [SoundCard.ioPort],42h
        jne     @@exit

        in      al,61h
        or      al,3
        out     61h,al                  ; // Turn on PC speaker
@@exit:
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   speakerOff
; *
; *     Description :   Does nothing currently
; *
; ************************************************************************/

PROC    speakerOff FAR

        cmp     [SoundCard.ioPort],42h
        jne     @@exit

        in      al,61h
        and     al,NOT 3
        out     61h,al                  ; // Turn off PC speaker
@@exit:
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   startVoice
; *
; *     Description :   Starts to output voice.
; *
; ************************************************************************/

PROC    startVoice FAR

        mov     dx,offset timerDACStereo1
        cmp     [DACmode],1
        je      @@addrOK
	mov     dx,offset timerDACStereo2
        cmp     [DACmode],2
        je      @@addrOK
        mov     dx,offset timerDAC
@@addrOK:

        cmp     [SoundCard.ioPort],42h
        jne     @@notSpkr

        mov     al,0B6h
        out     43h,al
        mov     al,0B0h
        out     43h,al
        mov     al,34h
        out     43h,al

        sub     al,al
        out     42h,al
        out     42h,al
        mov     al,10010000b
        out     43h,al

        mov     dx,offset timerSpkr
@@notSpkr:
        mov     ax,2508h
        push    ds
        push    cs
        pop     ds
        int     21h
        pop     ds

@@exit:
        mov     ax,[TSrate]
        call    setTimerRate

        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   stopVoice
; *
; *     Description :   Stops voice output.
; *
; ************************************************************************/

PROC    stopVoice FAR USES ds

        mov     ax,65535
        call    setTimerRate

        lds     dx,[oldint]
        mov     ax,2508h                ; Return interrupt
        int     21h
@@exit:
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   closeOutput
; *
; *     Description :   Closes timer service
; *
; ************************************************************************/

PROC closeOutput FAR USES ds

        mov     ax,65535
        call    setTimerRate

@@exit:
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   int getDACpos();
; *
; *     Description :   Returns DAC's current position
; *
; ************************************************************************/

PROC    getDACpos FAR

        mov     ax,[bufferSize]
        sub     ax,[bufferPos]
        ret
ENDP

PROC closeDAC FAR

        ret
ENDP

PROC pauseVoice FAR

        ret
ENDP

PROC resumeVoice FAR

        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   void setDACTimer( ushort new_timer );
; *
; *     Description :   Sets new old-timer rate
; *
; ************************************************************************/

PROC    setDACTimer FAR newtimer:DWORD

	mov     dx,[TSrate]
	sub     ax,ax                   ; DX:AX = timer rate * 65536
	mov     cx,[word newtimer]      ; CX = new rate for old timer
	div     cx
	mov     [oldrate],ax            ; AX = relative rate

	ret
ENDP

END
