;/************************************************************************
; *
; *	File	    : SDI_PAS.ASM
; *
; *	Description : SDI for MediaVision cards
; *
; *	Copyright (C) 1993 Otto Chrons
; *
; ***********************************************************************
;
;	Revision history of SDI_PAS.ASM
;
;	1.0	16.4.93
;		First version. Works with all PAS cards. There were some
;		troubles with 8-bit DMA but they are now fixed.
;       2.0     04.01.94
;               Converted to work with 32-bit flat model
;
; ***********************************************************************/

	IDEAL
	JUMPS
	P386N


        INCLUDE "MODEL.INC"

CSEGMENTS SDI_PAS

        MASM
	QUIRKS
	INCLUDE COMMON.INC
	INCLUDE STATE.INC
	INCLUDE MASM.INC
	IDEAL
	INCLUDE "MCP.INC"
        INCLUDE "DMA.INC"


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
        ioPort          DW ?
	saveDMAvector	DD ?
	samplingRate	DW ?
;
; This pointer points to a state table of hardware variables
;
	mvhwShadowPointer	DD	?	; points to the start of the data table

	HardwareShadowTable	DB	(size MVState) dup (?)

ENDS

CCODESEG SDI_PAS
        ASSUME ES:NOTHING

        CPUBLIC  SDI_PAS

        copyrightText   DB "SDI for PAS,PAS+ and PAS 16 v2.0 - (C) 1993,1994 Otto Chrons",0,1Ah

	PASnorm 	CARDINFO <3,0,"Pro Audio Spectrum",388h,0,0,3000,44100,1,1,1>
	PASplus		CARDINFO <4,0,"Pro Audio Spectrum+",388h,0,0,3000,44100,1,1,1>
	PAS16		CARDINFO <5,0,"Pro Audio Spectrum 16",388h,0,0,3000,44100,1,1,2>

IFDEF __PASCAL__
        SoundDevicePAS  SOUNDDEVICE < \
                _far ptr initPAS,\
                _far ptr initDMA,\
                _far ptr initRate,\
                _far ptr closePAS,\
                _far ptr closeDMA,\
                _far ptr startVoice,\
                _far ptr stopVoice,\
                _far ptr pauseVoice,\
                _far ptr resumeVoice\
                _far ptr getDMApos,\
                _far ptr speakerOn,\
                _far ptr speakerOff\
		>
ELSE
        SoundDevicePAS  SOUNDDEVICE < \
                _far ptr _initPAS,\
                _far ptr _initDMA,\
                _far ptr _initRate,\
                _far ptr _closePAS,\
                _far ptr _closeDMA,\
                _far ptr _startVoice,\
                _far ptr _stopVoice,\
                _far ptr _pauseVoice,\
                _far ptr _resumeVoice\
                _far ptr _getDMApos,\
                _far ptr _speakerOn,\
                _far ptr _speakerOff\
		>
ENDIF

;/*************************************************************************
; *
; *	Function    :	void SDI_PAS(SOUNDDEVICE far *sdi);
; *
; *	Description :	Registers Pro Audio Spectrum as a sound device
; *
; *	Input       :	Pointer to SD structure
; *
; *	Returns     :	Fills SD structure accordingly
; *
; ************************************************************************/

CPROC   SDI_PAS @@sdi

        ENTERPROC       _di _si

	cld
        LESDI   [@@sdi]
        mov     _si,offset SoundDevicePAS
        mov     _cx,SIZE SOUNDDEVICE
IF16    <cli>
        _segcs
	rep movsb			; Copy structure
IF16    <sti>
        sub     _ax,_ax                 ; indicate successful init
        LEAVEPROC       _di _si
	ret
ENDP

;/*************************************************************************
; *
; *	Function    :	playDMA
; *
; *	Description :	Plays current buffer through DMA
; *
; ************************************************************************/

PROC	playDMA NEAR

	PUSHES
        push    _di

	mov	ax,60000

        LESDI   [mvhwShadowPointer]

	push	ax

        cli

	mov     al,01110100b            ; 74h Timer 1 & rate generator
	mov	dx,TMRCTLR
	xor	dx,[ioPort]		; xlate the board address


	out     dx,al
        mov     [ESDI+_tmrctlr],al      ; local timer control register

	pop	ax

	mov     dx,SAMPLECNT
	xor	dx,[ioPort]		; xlate the board address
        mov     [ESDI+_samplecnt],ax

	out     dx,al
        jmp $+2
	xchg	ah,al
	out	dx,al

        sti
@@exit:
        pop     _di
	POPES

	ret
ENDP

;/*************************************************************************
; *
; *	Function    : 	interruptDMA
; *
; *	Description :	DMA interrupt routine for continuos playing.
; *
;/************************************************************************/

PROC    interruptDMA NEAR

;	sti
;	push	ax
;	push	dx
;	push	ds
;	mov	ax,@data
;	mov	ds,ax			; DS = data segment
;
;	mov	dx,INTRCTLRST		; clear the interrupt
;	xor     dx,[ioPort]		; xlate the board address
;	in	al,dx
;
;	cmp	[mcpStatus],111b	; Inited and playing
;	jne	@@exit
;	call	playDMA			; Output current buffer
;@@exit:
;	mov	al,20h			; End Of Interrupt (EOI)
;	out	20h,al
;	cmp	[SoundCard.dmaIRQ],7
;	jle	@@10
;	out	0A0h,al
;@@10:
;	pop	ds
;	pop	dx
;	pop	ax
	iret				; Interrupt return
ENDP


;/*************************************************************************
; *
; *	Function    : calcsamplerate
; *
; *	Description : Calculates new sampling rate
; *
; *	Input       : EAX sampling rate
; *
; ************************************************************************/

PROC	calcsamplerate NEAR

        pushes
        push    _di
	LESDI	[mvhwShadowPointer]

;
; make sure sample rate does not exceed 88200
;
	mov	ecx,eax
	cmp	ecx,88200
	ja	CaSaRa_bad
;
; load 1193180 in bx:cx for 32x32 bit division
;
	mov	eax,001234DCh
	sub	edx,edx
	div	ecx
        mov     [ESDI+_samplerate],ax   ; save just the low order
	sub	ecx,ecx
	mov	cx,ax
	mov	eax,001234DCh
	sub	edx,edx
	div	ecx
	jmp	short CaSaRa_exit
;
CaSaRa_bad:
;
CaSaRa_exit:

        pop     _di
        popes
	ret
ENDP

;/*************************************************************************
; *
; *	Function    : int initPAS(CARDINFO *scard);
; *
; *	Description : Initializes a PAS card.
; *
; *	Input       : Pointer to CARDINFO structure
; *
; *	Returns     : 0 no error
; *		      other = error
; *
; *************************************************************************/

CPROC   initPAS @@scard
        LOCALVAR   _dword retvalue

        ENTERPROC       _di _si
        mov     [DWORD retvalue],-1
        LESSI   [@@scard]
	mov	al,[ESSI+CARDINFO.ID]
        mov     _si,offset PASnorm      ; SI = source
	cmp	al,ID_PAS		; Check for valid ID
	je	@@idOK
        mov     _si,offset PASplus      ; SI = source
	cmp	al,ID_PASPLUS
	je	@@idOK
        mov     _si,offset PAS16        ; SI = source
	cmp	al,ID_PAS16
	jne	@@exit
@@idOK:
        PUSHDS
        POPES
        mov     _di,offset SoundCard    ; ES:DI = destination
        mov     _cx,SIZE CARDINFO
	cld
IFDEF __16__
        cli
	segcs
ENDIF
	rep	movsb			; Copy information
IF16    sti

        LESSI   [@@scard]
	mov	ax,[ESSI+CARDINFO.ioPort]
	mov	[SoundCard.ioPort],ax
	mov	al,[ESSI+CARDINFO.DMAIRQ]
	cmp	al,16 			; Is it > 15?
	jae	@@exit
	mov	[SoundCard.DMAIRQ],al
	mov	al,[ESSI+CARDINFO.DMAchannel]
	cmp	al,4			; Channel 4 is invalid
	je	@@exit
	cmp	al,8
	jae	@@exit			; So are > 7
	mov	[SoundCard.DMAchannel],al

	mov	bh,[ESSI+CARDINFO.stereo]
	cmp	bh,1
	ja	@@exit

	mov	bl,[ESSI+CARDINFO.sampleSize]

	mov	[SoundCard.sampleSize],bl	; Save values
	mov	[SoundCard.stereo],bh

;
; setup a pointer to our local hardware state table
;
        lea     _bx,[HardwareShadowTable]
IFDEF __16__
        mov     [WORD mvhwShadowPointer+0],bx
        mov     [WORD mvhwShadowPointer+2],ds
	push	ds
	pop	es
ELSE
        mov     [mvhwShadowPointer],ebx
ENDIF
        mov     _di,_bx
        mov     _cx,SIZE MVState         ; Clear state table
	sub	al,al
	rep	stosb
        mov     [_bx+MVSTATE._crosschannel],9    ; cross channel l-2-l, r-2-r
        mov     [_bx+MVSTATE._audiofilt],31h     ; lowest filter setting
;
; find the int 2F interface and if found, use it's state table pointer

	mov	ax,0BC00h		; MVSOUND.SYS ID check
	mov	bx,'??'
	sub	cx,cx
	sub	dx,dx

	int	2fh			; will return something if loaded

	xor	bx,cx
	xor	bx,dx
	cmp	bx,'MV'                 ; is the int 2F interface here?
	jnz	imvsp_done		; no, exit home

	mov	ax,0BC02H		; get the pointer
	int     2fh
	cmp	ax,'MV'                 ; busy or intercepted
	jnz	imvsp_done

IFDEF __16__
        mov     [WORD mvhwShadowPointer+0],bx
        mov     [WORD mvhwShadowPointer+2],dx
ELSE
        and     ebx,0FFFFh              ; Convert to linear address
        and     edx,0FFFFh
        shl     edx,4
        add     edx,ebx
        mov     [mvhwShadowPointer],edx
ENDIF

imvsp_done:

	mov	dx,[SoundCard.ioPort]
	xor	dx,DEFAULT_BASE
	mov	[ioPort],dx

	mov	dx,INTRCTLRST			; flush any pending PCM irq
	xor	dx,[ioPort]			; xlate the board address
	out	dx,al

	or	[mcpStatus],S_INIT	; indicate successful initialization
        mov     [DWORD retvalue],0
@@exit:
        mov     _ax,[retvalue]
        LEAVEPROC _di _si
	ret
ENDP

;/***********************************************************************
; *
; *	Function    :	int getDMApos():
; *
; *	Description :	Returns the position of DMA transfer
; *
; **********************************************************************/

CPROC   getDMApos

        ecall   dmaGetPos
        add     _ax,[bufferSize]         ; AX = DMA position

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

        ENTERPROC       _di _si

	sub	eax,eax
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
        mov     ax,[word @@sample_rate]
	cmp	[SoundCard.stereo],0
	je	@@mono
	shl	eax,1
@@mono:
	call	calcsamplerate
	mov	cl,[SoundCard.stereo]
	shr	eax,cl
	mov	[samplingRate],ax

        LESDI   [mvhwShadowPointer]
	mov     al,00110110b            ; 36h Timer 0 & square wave
	mov	dx,TMRCTLR
	xor	dx,[ioPort]		; xlate the board address

	cli

	out	dx,al			; setup the mode, etc
        mov     [ESDI+_tmrctlr],al

        mov     ax,[ESDI+_samplerate]   ; pre-calculated & saved in prior code
	mov	dx,SAMPLERATE
	xor	dx,[ioPort]		; xlate the board address
	out	dx,al			; output the timer value

        jmp $+2

	xchg    ah,al
	out	dx,al
	sti
@@exit:
	movzx	eax,[samplingRate]
        LEAVEPROC       _di _si
	ret
ENDP

;/*************************************************************************
; *
; *	Function    :	speakerOn
; *
; *	Description :	Connects PAS speaker
; *
; ************************************************************************/

CPROC   speakerOn

	ret
ENDP

;/*************************************************************************
; *
; *	Function    :	speakerOff
; *
; *	Description :	Disconnects speaker from PAS
; *
; ************************************************************************/

CPROC   speakerOff

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

	mov     dx,CROSSCHANNEL
	xor	dx,[ioPort]

        mov     al,[ESDI+_crosschannel] ; Stop PAS' DMA transfer
	or	al,bCCdrq
        mov     [ESDI+_crosschannel],al
	out	dx,al

        mov     _cx,[bufferSize]
        ecall   dmaStart <LARGE 58h>    ; Start DMA transfer

	push    _di

        LESDI   [mvhwShadowPointer]
	cmp	[SoundCard.sampleSize],2
	jne	@@no16bit
	mov	cx,(((NOT(bSC216bit+bSC212bit) AND 0FFh)*256) + bSC216bit)
	mov	dx,SYSCONFIG2
	xor	dx,[ioPort]		; xlate the board address
	in	al,dx
	and	al,ch			; clear the bits
	or	al,cl			; set the appropriate bits
	out	dx,al
@@no16bit:
	mov	al,bCCmono		; get the stereo/mono mask bit
	cmp	[SoundCard.stereo],0
	je	@@mono
	sub	al,al
@@mono:
	or	al,bCCdac		; get the direction bit mask
        or      al,bCCenapcm            ; sti the PCM state machine
	mov     dx,CROSSCHANNEL
	xor	dx,[ioPort]	; xlate the board address

	mov	ah,0fh + bCCdrq 	; get a mask to load non PCM bits
        and     ah,[ESDI+_crosschannel]; grab all but PCM/DRQ/MONO/DIRECTION
	or	al,ah			; merge the two states
        xor     al,bCCenapcm            ; cli the PCM bit
	out	dx,al			; send to the hardware
        jmp $+2
        xor     al,bCCenapcm            ; sti the PCM bit
	out	dx,al			; send to the hardware
        mov     [ESDI+_crosschannel],al; and save the new state
;
; Setup the audio filter sample bits
;
        mov     al,[ESDI+_audiofilt]
        or      al,(bFIsrate+bFIsbuff)  ; sti the sample count/buff counters
	mov	dx,AUDIOFILT
	xor	dx,[ioPort]	; xlate the board address
	out	dx,al
        mov     [ESDI+_audiofilt],al

        mov     al,[ESDI+_crosschannel]; get the state
	mov     dx,CROSSCHANNEL
	xor     dx,[ioPort]		; xlate the board address
	or	al,bCCdrq		; set the DRQ bit to control it
	out	dx,al
        mov     [ESDI+_crosschannel],al; and save the new state
@@exit:
        pop     _di
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

	push    _di
	LESDI	[mvhwShadowPointer]
;
; clear the audio filter sample bits
;
	mov	dx,AUDIOFILT
	xor	dx,[ioPort]	; xlate the board address
        cli                         ; drop dead...
        mov     al,[ESDI+_audiofilt]    ; get the state
	and	al,not (bFIsrate+bFIsbuff) ; flush the sample timer bits
        mov     [ESDI+_audiofilt],al    ; save the new state
	out	dx,al
IDEAL
;	mov	cx,0
@@wait:
;	loop	@@wait
	cmp     [SoundCard.ID],ID_PAS16
	jne	@@no16bit
;
; cli the 16 bit stuff
;
	mov	dx,SYSCONFIG2
	xor	dx,[ioPort]	   ; xlate the board address
	in	al,dx
	and	al,not bSC216bit+bSC212bit ; flush the 16 bit stuff
	out	dx,al
;
@@no16bit:
stpc02:
;
; clear the appropriate Interrupt Control Register bit
;
	mov	ah,bICsampbuff
	and	ah,bICsamprate+bICsampbuff
	not	ah
	mov	dx,INTRCTLR
	xor	dx,[ioPort]	; xlate the board address
	in	al,dx
	and	al,ah			; kill sample timer interrupts
	out	dx,al
        mov     [ESDI+_intrctlr],al

        mov     al,[ESDI+_crosschannel] ; get the state
	mov     dx,CROSSCHANNEL
	xor     dx,[ioPort]		; xlate the board address
	and	al,not bCCdrq		; clear the DRQ bit
        and     al,not bCCenapcm        ; clear the PCM sti bit
	or	al,bCCdac
	out	dx,al

        mov     [ESDI+_crosschannel],al ; and save the new state
	ecall	dmaStop
@@exit:
	pop     _di
	ret
ENDP

;/*************************************************************************
; *
; *	Function    :	closeDMA
; *
; *	Description :   Returns DMA's IRQ vector
; *
; ************************************************************************/

CPROC closeDMA
	ret
ENDP

CPROC closePAS
	ret
ENDP

CPROC pauseVoice
	ret
ENDP

CPROC resumeVoice
	ret
ENDP

ENDS

END
