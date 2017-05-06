;/************************************************************************
; *
; *	File        :	SDI_SB.ASM
; *
; *	Description :	Sound Blaster (Pro) specific routines for MCP
; *
; *	Copyright (C) 1992 Otto Chrons
; *
; ************************************************************************
;
;	Revision history of SDI_SB.ASM
;
;	1.0	16.4.93
;		First version. SB and SB Pro routines.
;
;       2.0     14.2.94
;               32-bit compatibility
;		44kHz mono support for SB Pro and SB 2.0
;
; ***********************************************************************/

	IDEAL
	JUMPS
	P386N

        INCLUDE "MODEL.INC"
        INCLUDE "MCP.INC"
        INCLUDE "DMA.INC"

CSEGMENTS SDI_SB

MACRO	waitSB
	local	l1
l1:
	in	al,dx
	or	al,al
	js	l1
ENDM

MACRO	waitSBport
	local	l1

	mov	dx,[SoundBlaster.ioPort]
	add	dx,0Ch
l1:
	in	al,dx
	or	al,al
	js	l1
ENDM

MACRO	waitSBPROport
	local	l1

	mov	dx,[SoundBlasterPro.ioPort]
	add	dx,0Ch
l1:
	in	al,dx
	or	al,al
	js	l1
ENDM

CDATASEG

IFDEF __PASCAL__
        EXTRN   mcpStatus:BYTE
        EXTRN   SoundCard:CARDINFO
        EXTRN   bufferSize:WORD
        EXTRN   dataBuf:WORD
ELSE
        EXTRN   _mcpStatus:BYTE
        EXTRN   _SoundCard:CARDINFO
        SoundCard       EQU _SoundCard
        mcpStatus       EQU _mcpStatus
    IFDEF __16__
            EXTRN   _bufferSize:WORD
            EXTRN   _dataBuf:WORD
    ELSE
            EXTRN   _bufferSize:DWORD
            EXTRN   _dataBuf:DWORD
    ENDIF
        bufferSize      EQU _bufferSize
        dataBuf         EQU _dataBuf
ENDIF

IFDEF __32__
        oldIRQ                  DF ?
ELSE
        oldIRQ                  DD ?
ENDIF
        samplingRate            DW ?
	SBrate                  DB ?
	useFAST			DW ?
        ackStereoOne            DW ?
        autoInitMode            DB ?

ENDS

CCODESEG SDI_SB

        CPUBLIC  SDI_SB
        CPUBLIC  SDI_SBPro

        copyrightText   DB "SDI for SB & SB Pro v2.0 - (C) 1992,1994 Otto Chrons",0,1Ah
	SoundBlaster	CARDINFO <1,0,"Sound Blaster",220h,7,1,4000,44100,0,0,1>
	SoundBlasterPro	CARDINFO <2,0,"Sound Blaster Pro",220h,7,1,4000,44100,1,1,1>

IFDEF __PASCAL__

        SoundDeviceSB   SOUNDDEVICE < \
                _far ptr initSB,\
                _far ptr initDMA,\
                _far ptr initRate,\
                _far ptr closeSB,\
                _far ptr closeDMA,\
                _far ptr startVoice,\
                _far ptr stopVoice,\
                _far ptr pauseVoice,\
                _far ptr resumeVoice\
                _far ptr getDMApos,\
                _far ptr speakerOn,\
                _far ptr speakerOff\
		>

	SoundDeviceSBPro SOUNDDEVICE < \
                _far ptr initSBPro,\
                _far ptr initDMA,\
                _far ptr initRate,\
                _far ptr closeSB,\
                _far ptr closeDMA,\
                _far ptr startVoice,\
                _far ptr stopVoice,\
                _far ptr nullFunc,\
                _far ptr nullFunc\
                _far ptr getDMApos,\
                _far ptr speakerOn,\
                _far ptr speakerOff\
		>
ELSE
        SoundDeviceSB   SOUNDDEVICE < \
                _far ptr _initSB,\
                _far ptr _initDMA,\
                _far ptr _initRate,\
                _far ptr _closeSB,\
                _far ptr _closeDMA,\
                _far ptr _startVoice,\
                _far ptr _stopVoice,\
                _far ptr _pauseVoice,\
                _far ptr _resumeVoice\
                _far ptr _getDMApos,\
                _far ptr _speakerOn,\
                _far ptr _speakerOff\
		>

	SoundDeviceSBPro SOUNDDEVICE < \
		_far ptr _initSBPro,\
		_far ptr _initDMA,\
		_far ptr _initRate,\
		_far ptr _closeSB,\
		_far ptr _closeDMA,\
		_far ptr _startVoice,\
		_far ptr _stopVoice,\
		_far ptr _nullFunc,\
		_far ptr _nullFunc\
		_far ptr _getDMApos,\
		_far ptr _speakerOn,\
		_far ptr _speakerOff\
		>
ENDIF

;/*************************************************************************
; *
; *	Function    :	void SDI_SB(SOUNDDEVICE far *sdi);
; *
; *	Description :	Registers SB as a sound device
; *
; *	Input       :	Pointer to SD structure
; *
; *	Returns     :	Fills SD structure accordingly
; *
; ************************************************************************/

CPROC   SDI_SB @@sdi

        ENTERPROC       _si _di
	cld
        LESDI   [@@sdi]
        mov     _si,offset SoundDeviceSB
        mov     _cx,SIZE SOUNDDEVICE
IFDEF __16__
        cli
	segcs
ENDIF
	rep movsb			; Copy structure
IF16    sti
        sub     _ax,_ax                 ; indicate successful init
        LEAVEPROC       _si _di
	ret
ENDP

;/*************************************************************************
; *
; *	Function    :	void SDI_SBPro(SOUNDDEVICE far *sdi);
; *
; *	Description :	Registers SBPro as a sound device
; *
; *	Input       :	Pointer to SD structure
; *
; *	Returns     :	Fills SD structure accordingly
; *
; ************************************************************************/

CPROC   SDI_SBPro @@sdi

        ENTERPROC       _si _di
        cld
        LESDI   [@@sdi]
        mov     _si,offset SoundDeviceSBPro
        mov     _cx,SIZE SOUNDDEVICE
IFDEF __16__
        cli
	segcs
ENDIF
	rep movsb			; Copy structure
IF16    sti
        sub     _ax,_ax                 ; indicate successful init
        LEAVEPROC       _si _di
        ret
ENDP

;/*************************************************************************
; *
; *	Function    : 	checkPort_SB
; *
; *	Description :   Checks if given address is SB's I/O address
; *
; *	Input       : 	DX = port to check
; *
; *	Returns     :	AX = 0	succesful
; *		      	AX = 1	unsuccesful
; *
; ************************************************************************/

PROC    checkPort_SB NEAR

	push	dx
	add	dl,6			; Init Sound Blaster
	mov	al,1
	out	dx,al
	in	al,dx			; Wait for awhile
	in	al,dx
	in	al,dx
	in	al,dx
	in	al,dx
	in	al,dx
	in	al,dx
	in	al,dx
	mov	al,0
	out	dx,al
	sub	dl,6

	add	dl,0Eh          	; DSP data available status
        mov     _cx,1000
@@loop:
	in	al,dx			; port 22Eh
	or	al,al
	js	@@10
	loop	@@loop

	mov	ax,1
	jmp	@@exit
@@10:
	sub	dl,4
	in	al,dx			; port 22Ah
	cmp	al,0AAh			; Is ID 0AAh?
	mov	ax,0
	je	@@exit
	mov	ax,1
@@exit:
	pop	dx
	or	ax,ax			; Set zero-flag accordingly
	ret
ENDP

;/*************************************************************************
; *
; *	Function    :	cmdSB
; *
; *	Description :   Sends a command to Sound Blaster
; *
; *	Input       :	AL = Command to send
; *
; ************************************************************************/

PROC	cmdSB NEAR

	push	ecx
	mov     ecx,65535
	push	ax
	mov	dx,[SoundCard.ioPort]
	add	dl,0Ch
@@1:
	in	al,dx
        test    al,al
	jns	@@2
	dec     ecx
	jnz     @@1
@@2:
	pop	ax
	out	dx,al
	pop	ecx

	ret
ENDP

;/*************************************************************************
; *
; *	Function    :	playDMA
; *
; *	Description :	Plays current buffer through DMA
; *
; ************************************************************************/

PROC    playDMA NEAR

	push    _cx
        mov     cx,65535
	cmp	[useFAST],1
	je	@@10
        cmp     [autoInitMode],1
        je      @@15
        mov     al,14h                  ; SB's command for output
        call    cmdSB
	mov	al,cl			; Count
	call	cmdSB
	mov	al,ch
	call	cmdSB
	jmp	@@exit
@@10:
        mov     al,48h                  ; SB's command for fast output
	call	cmdSB
	mov	al,cl			; Count
	call	cmdSB
	mov	al,ch
	call	cmdSB
        mov     al,91h                  ; Start transfer
        cmp     [autoInitMode],0
        je      @@20
        mov     al,90h                  ; Autoinit mode
@@20:
        call    cmdSB
        jmp     @@exit
@@15:
        mov     al,48h                  ; SB's command for fast output
	call	cmdSB
	mov	al,cl			; Count
	call	cmdSB
	mov	al,ch
        call    cmdSB
        mov     al,1Ch                  ; Autoinit output
        call    cmdSB
@@exit:
        pop     _cx
	ret
ENDP

;/*************************************************************************
; *
; *	Function    : 	interruptDMA
; *
; *	Description :	DMA interrupt routine for continuos playing.
; *
; ************************************************************************/

PROC    interruptDMA NEAR

	push	ax
	push	dx
	push	ds
        mov     ax,DGROUP
	mov	ds,ax			; DS = data segment

	mov	dx,[SoundCard.ioPort]	; Reset SB for next DMA
	add	dl,0Eh
	in	al,dx
        cmp     [ackStereoOne],1        ; SB Pro init transfer?
        je      @@noplay
        cmp     [autoInitMode],1        ; Is autoinit mode on?
        je      @@noplay
        call    playDMA                 ; Output current buffer
@@noplay:
        mov     [ackStereoOne],0
	mov	al,20h			; End Of Interrupt (EOI)
	out	20h,al
	cmp	[SoundCard.dmaIRQ],7
	jle	@@10
	out	0A0h,al
@@10:
	pop	ds
	pop	dx
	pop	ax
IF16    iret                            ; Interrupt return
IF32    iretd
ENDP

;/*************************************************************************
; *
; *	Function    :	int getDMApos():
; *
; *	Description :	Returns the position of DMA transfer
; *
; ************************************************************************/

CPROC   getDMApos

        ecall   dmaGetPos
        add     _ax,[bufferSize]         ; AX = DMA position

	ret
ENDP


;/*************************************************************************
; *
; *	Function    :	int initSB(CARDINFO *sCard);
; *
; *	Description : 	Initializes Sound Blaster using given 'port' and
; *		      	'DMA_int' values
; *
; *	Input       : 	port 	= Sound Blaster's I/O address (210h-260h)
; *		      	DMA_int	= DMA interrupt value (2,3,5 or 7)
; *
; *	Returns     : 	 0	= success
; *			-1	= error
; *
; ************************************************************************/

CPROC   initSB @@sCard
localvar   _dword retvalue, _word retrycount

	ENTERPROC       _di _si
	LESSI   [@@sCard]
	mov     [dword retvalue],-1           ; assume error

        mov     _si,offset SoundBlaster          ; CS:SI = source
IFDEF __16__
	mov     ax,ds
	mov	es,ax
ENDIF
	mov     _di,offset SoundCard     ; ESDI = destination
	mov     _cx,SIZE CARDINFO
	cld
IF16    cli
        _segcs
	rep	movsb			; Copy information
IF16    sti

	LESSI   [@@sCard]
	mov	bx,[ESSI+CARDINFO.ioPort]
	mov	[SoundCard.ioPort],bx
	mov	bx,[ESSI+CARDINFO.minRate]
	mov	[SoundCard.minRate],bx
	mov	bx,[ESSI+CARDINFO.maxRate]
	mov	[SoundCard.maxRate],bx
	mov	bl,[ESSI+CARDINFO.DMAIRQ]
	mov	[SoundCard.DMAIRQ],bl
	mov	[SoundCard.DMAchannel],1	; Channel is always 1

	mov	dx,[SoundCard.ioPort]	; initialize Sound Blaster
	call	checkPort_SB

	mov     [word retrycount],10
@@retry:
	dec     [word retrycount]
	jnz	@@continue
	mov	ax,0			; not found
	jmp	@@done
@@continue:
	mov	al,0E1h			; Read version number
	call	cmdSB

	add	dl,2			; DX = 22Eh
	mov	_cx,1000
@@10:
	in	al,dx			; Read version high
	or	al,al
	js	@@10ok
	loop	@@10
	jmp	@@retry
@@10ok:
	sub	dl,4
	in	al,dx
	mov	ah,al

	add	dl,4
	sub	al,al
	mov	_cx,1000
@@20:
	in	al,dx			; Read version low
	or	al,al
	js	@@20ok
	loop	@@20
	jmp	@@retry
@@20ok:
	sub	dl,4
	in	al,dx
@@done:
	mov	[SoundCard.ver],ax
        mov     [autoInitMode],0
        cmp     ax,200h                 ; Is DSP ver 2.01 or greater?
        jl      @@noautoinit
        mov     [autoInitMode],1
@@noautoinit:
	mov	dx,[SoundCard.ioPort]	; initialize Sound Blaster
	add	dx,6
	mov	al,1
	out	dx,al
	in	al,dx			; Wait for awhile
	in	al,dx
	in	al,dx
	in	al,dx
	in	al,dx
	in	al,dx
	in	al,dx
	mov	al,0
	out	dx,al

	or	[mcpStatus],S_INIT	; indicate successful initialization
        mov     [ackStereoOne],0
	mov     [dword retvalue],0            ; return 0 = OK
@@exit:
        mov     _ax,[retvalue]
        LEAVEPROC       _di _si
	ret
ENDP

;/*************************************************************************
; *
; *	Function    :	int initSBpro(CARDINFO *sCard);
; *
; *	Description : 	Initializes Sound Blaster Pro using values for
; *		      	ioPort,dmaIRQ & dmaChannel in sCard
; *
; *	Input       : 	sCard   = pointer to CARDINFO-structure
; *
; *	Returns     : 	 0	= success
; *			-1	= error
; *
; ************************************************************************/

CPROC   initSBpro @@sCard
locvars   _word retryCount,_dword retvalue

	ENTERPROC       _di _si
	LESSI   [@@sCard]
	mov     [dword retvalue],-1           ; assume error
        mov     _si,offset SoundBlasterPro       ; CS:SI = source
IF16    <mov    ax,ds>
IF16    <mov    es,ax>
        mov     _di,offset SoundCard     ; ESDI = destination
        mov     _cx,SIZE CARDINFO
	cld
IF16    cli
        _segcs
	rep	movsb			; Copy information
IF16    sti

        LESSI   [@@sCard]
	mov	bx,[ESSI+CARDINFO.ioPort]
	mov	[SoundCard.ioPort],bx
	mov	bl,[ESSI+CARDINFO.DMAIRQ]
	mov	[SoundCard.DMAIRQ],bl
	mov	bl,[ESSI+CARDINFO.DMAChannel]
	mov	[SoundCard.DMAchannel],bl
	mov	bl,[ESSI+CARDINFO.stereo]
	mov	[SoundCard.stereo],bl

	mov	dx,[SoundCard.ioPort]	; initialize Sound Blaster
	call	checkPort_SB

        mov     [word retrycount],10
@@retry:
        dec     [word retrycount]
	jnz	@@continue
	mov	ax,0			; not found
	jmp	@@done
@@continue:
	mov	al,0E1h			; Read version number
	call	cmdSB

	add	dl,2			; DX = 22Eh
	sub	al,al
	mov	_cx,1000
@@10:
	in	al,dx			; Read version high
	or	al,al
	js	@@10ok
	loop	@@10
	jmp	@@retry
@@10ok:
	mov	_cx,1000
	sub	dl,4
	in	al,dx
	mov	ah,al

	add	dl,4
	sub	al,al
@@20:
	in	al,dx			; Read version low
	or	al,al
	js	@@20ok
	loop	@@20
	jmp	@@retry
@@20ok:
	sub	dl,4
	in	al,dx
@@done:
	mov	[SoundCard.ver],ax
	cmp	ax,0300h		; Is version 3.00 or higher?
	jl	@@exit			; No --> exit

        mov     [autoInitMode],1
	mov	dx,[SoundCard.ioPort]	; initialize Sound Blaster
	add	dx,6
	mov	al,1
	out	dx,al
	in	al,dx			; Wait for awhile
	in	al,dx
	in	al,dx
	in	al,dx
	in	al,dx
	in	al,dx
	in	al,dx
	mov	al,0
	out	dx,al

	or	[mcpStatus],S_INIT	; indicate successful initialization
        mov     [ackStereoOne],0
        mov     [dword retvalue],0            ; return 0 = OK
@@exit:
	mov     _ax,[retvalue]
	LEAVEPROC       _di _si
	ret
ENDP

;/*************************************************************************
; *
; *	Function    :	initDMA(void far *buffer,int maxsize, int required);
; *
; *	Description :   Init DMA for output
; *
; ************************************************************************/

CPROC   initDMA @@buffer,@@physical,@@maxSize,@@required

	ENTERPROC
	movzx   eax,[SoundCard.DMAchannel]
	ecall   dmaInit eax,[@@buffer],[@@physical],[@@maxSize],[@@required]

	mov	al,[SoundCard.DMAIRQ]
	test	al,8			; Is IRQ > 7
	jz	@@01
	add	al,60h			; Yes, base is 70h
@@01:
	push    es
	add	al,8			; AL = DMA interrupt number
	push	ax
	mov	ah,35h			; Get interrupt vector
	int	21h
IFDEF __32__
        mov     [WORD 4+oldIRQ],es
        mov     [DWORD oldIRQ],ebx
ELSE
        mov     [WORD HIGH oldIRQ],es
        mov     [WORD LOW oldIRQ],bx
ENDIF
        pop     ax                      ; Replace vector with the address
        pop     es
	mov	ah,25h			; of own interrupt routine
	push    ds
        push    cs
        pop     ds
        mov     _dx,offset interruptDMA  ; Set interrupt vector
	int	21h
        pop     ds

	mov	cl,[SoundCard.DMAIRQ]
	mov	ah,1
	test	cl,8			; Is IRQ > 7
	jnz	@@15
	shl	ah,cl
	not	ah
	in	al,21h
	and	al,ah
	out	21h,al			; Allow DMA interrupt
	jmp	@@20
@@15:
	and	cl,7
	shl	ah,cl
	not	ah
	in	al,0A1h
	and	al,ah
	out	0A1h,al			; Allow DMA interrupt
@@20:
        LEAVEPROC
	ret
ENDP

;/*************************************************************************
; *
; *	Function    :	initRate
; *
; *	Description :   Inits sound card's sampling rate
; *
; ************************************************************************/

CPROC   initRate @@sample_rate

        ENTERPROC
	mov	ax,[SoundCard.minRate]
        cmp     [word @@sample_rate],ax
	jae	@@rateok
        mov     [word @@sample_rate],ax
	jmp	@@rateok
	mov	ax,[SoundCard.maxRate]
        cmp     [word @@sample_rate],ax
	jbe	@@rateok
        mov     [word @@sample_rate],ax
@@rateok:
	cmp	[SoundCard.ID],ID_SOUNDBLASTER
	jne	@@noFAST
        cmp     [SoundCard.ver],0201h
	jl	@@noFAST
	cmp	[word @@sample_rate],22222
	jbe	@@noFAST
	mov	[useFAST],1
@@noFAST:
	cmp	[SoundCard.ID],ID_SOUNDBLASTER
	je	@@10
	cmp	[SoundCard.ID],ID_SOUNDBLASTERPRO
	jne	@@exit
	mov	[useFAST],1
@@10:
	mov	eax,0F4240h		; Calculate sampling rate for SB
	sub	edx,edx			; EDX:EAX = 1000000
	mov     ecx,[@@sample_rate]
	cmp	[SoundCard.stereo],1
	jne	@@20
	shl	ecx,1
@@20:
	div	ecx
	inc	ax
	push	ax
	neg	al			; AL = 256 - 1000000/rate
	mov	[SBrate],al
        pop     ax

	cmp	[SoundCard.stereo],1
	jne	@@30
	shl	ax,1
@@30:

	mov	bx,ax			; Calculate real sampling rate
	sub	bh,bh
	mov	ax,4240h
	mov	dx,0Fh
	div	bx			; Save sampling rate into AX
@@exit:
	cmp	[SoundCard.ID],ID_SOUNDBLASTERPRO
	jne	@@doneRate
	mov	cx,ax

@@doneRate:
	mov	[samplingRate],ax	; and save it for future use
	LEAVEPROC
	ret
ENDP

;/*************************************************************************
; *
; *	Function    :	speakerOn
; *
; *	Description :	Connects SB's Digital Signal Processor to speaker
; *
; ************************************************************************/

CPROC   speakerOn

	mov	al,0D1h
	call	cmdSB
	ret
ENDP

;/*************************************************************************
; *
; *	Function    :	speakerOff
; *
; *	Description :	Disconnects speaker from DSP
; *
; ************************************************************************/

CPROC   speakerOff

	mov	al,0D3h
	call	cmdSB
	ret
ENDP

;/*************************************************************************
; *
; *	Function    :	setStereo
; *
; *	Description :	Sets SB Pro into stereo mode
; *
; ************************************************************************/

PROC	setStereo NEAR

	cmp     [SoundCard.stereo],1
	jne	@@exit
        mov     al,00h                  ; Reset mixer
	mov	dx,[SoundCard.ioPort]
	add	dx,4
	out	dx,al

        mov     al,0Eh
	mov	dx,[SoundCard.ioPort]
	add	dx,4
	out	dx,al
        inc     dx
	in	al,dx
	or	al,00000010b		; Set stereo

	mov	ah,al
	mov	al,0Eh
	mov	dx,[SoundCard.ioPort]
	add	dx,4
	out	dx,al
	inc	dx
	mov	al,ah
	out	dx,al
@@exit:
	ret
ENDP

;/*************************************************************************
; *
; *	Function    :	startVoice
; *
; *	Description :	Starts to output voice.
; *
; ************************************************************************/

CPROC   startVoice

        cli
        mov     cl,[SoundCard.DMAIRQ]           ; Enable DMA interrupt
	mov	ah,1
	test	cl,8
	jnz	@@10
	shl	ah,cl
	not	ah
	in	al,21h
	and	al,ah
	out	21h,al
	jmp	@@20
@@10:
	and	cl,7
	shl	ah,cl
	not	ah
	in	al,0A1h
	and	al,ah
	out	0A1h,al
@@20:

        mov     al,40h                  ; Set SB's sampling rate
	call	cmdSB
	mov	al,[SBrate]
	call	cmdSB

        call    setStereo
        ecall   speakerOn

        cmp     [SoundCard.stereo],1
        jne     @@nostereo

        sti
        mov     _cx,1                   ; Output one byte
        ecall   dmaStart <LARGE 48h>

        mov     [ackStereoOne],1
        mov     al,14h
        call    cmdSB
        mov     al,0h
        call    cmdSB
        mov     al,0h
        call    cmdSB

        mov     ecx,65535
@@waitloop:
        cmp     [ackStereoOne],1
        loope   @@waitloop

        ecall   dmaStop
@@nostereo:
        sti
        mov     _cx,[bufferSize]
        ecall   dmaStart <LARGE 58h>

        call    playDMA

@@exit:
	ret
ENDP

;/*************************************************************************
; *
; *	Function    :	stopVoice
; *
; *	Description :	Stops voice output.
; *
; ************************************************************************/

CPROC   stopVoice

	cli
	mov	dx,[SoundCard.ioPort]
	add	dl,6			; Init Sound Blaster
	mov	al,1
	out	dx,al
	in	al,dx			; Wait for awhile
	in	al,dx
	in	al,dx
	in	al,dx
	in	al,dx
	in	al,dx
	in	al,dx
	in	al,dx
	mov	al,0
	out	dx,al

        mov     cl,[SoundCard.DMAIRQ]           ; Disable DMA interrupt
	mov	ah,1
	test	cl,8
	jnz	@@10
	shl	ah,cl
	in	al,21h
	or	al,ah
	out	21h,al
	jmp	@@20
@@10:
	and	cl,7
	shl	ah,cl
	in	al,0A1h
	or	al,ah
	out	0A1h,al
@@20:
        ecall   dmaStop

        mov     dx,[SoundCard.ioPort]
	add	dx,0Eh
	in	al,dx

        sti

@@exit:
	ret
ENDP

;/*************************************************************************
; *
; *	Function    :	closeDMA
; *
; *	Description :   Returns DMA's IRQ vector
; *
; ************************************************************************/

CPROC   closeDMA

	push	ds
	mov	al,[SoundCard.DMAIRQ]
	test	al,8			; Is IRQ > 7
	jz	@@01
	add	al,60h			; Yes, base is 70h
@@01:
	add	al,8
        lds     _dx,[oldIRQ]
        mov     ah,25h
	int	21h			; Restore DMA vector
	pop	ds
	ret
ENDP

;/*************************************************************************
; *
; *	Function    :	closeSB
; *
; *	Description :   Does nothing currently :)
; *
; ************************************************************************/

CPROC   closeSB
	ret
ENDP

;/*************************************************************************
; *
; *	Function    :	pauseVoice
; *
; *	Description :   Pauses voice output
; *
; ************************************************************************/

CPROC   pauseVoice
;	mov	al,0D0h
;	call	cmdSB
	ret
ENDP

;/*************************************************************************
; *
; *	Function    :	resumeVoice
; *
; *	Description :   Resumes voice output
; *
; ************************************************************************/

CPROC   resumeVoice
;	mov	al,0D4h
;	call	cmdSB
	ret
ENDP

;/*************************************************************************
; *
; *	Function    :	nullFunc
; *
; *	Description :   Does nothing...
; *
; ************************************************************************/

CPROC   nullFunc

	ret
ENDP

ENDS

END
