;/************************************************************************
; *
; *	File        :	SDI_SB16.ASM
; *
; *	Description :	Sound Blaster 16 specific routines for MCP
; *
; *	Copyright (C) 1993 Otto Chrons
; *
; ***********************************************************************
;
;	Revision history of SDI_SB16.ASM
;
;	1.0	16.4.93
;		First version. SB 16 routines. Works with 8- and 16-bit DMA
;
;       2.0     14.2.94
;               32-bit compatible
;
;       2.1     7.6.94
;               Autoinit mode (real!) from the SDK
;
; ***********************************************************************/

	IDEAL
	JUMPS
	P386N

        INCLUDE "MODEL.INC"
        INCLUDE "MCP.INC"
        INCLUDE "DMA.INC"

CSEGMENTS SDI_SB16

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

IF16    <saveDMAvectorOFFS      DW ?>
IF32    <saveDMAvectorOFFS      DD ?>
        saveDMAvectorSEG        DW ?
        samplingRate    DW ?
ENDS

CCODESEG SDI_SB16

        CPUBLIC  SDI_SB16

        copyrightText   DB "SDI for SB16 v2.0 - (C) 1993,1994 Otto Chrons",0,1Ah

        SoundBlaster16  CARDINFO <6,0,"Sound Blaster 16 ASP",220h,5,5,5000,44100,1,1,2>

IFDEF __PASCAL__
	SoundDeviceSB16	SOUNDDEVICE < \
                _far ptr initSB16,\
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
ELSE
        SoundDeviceSB16 SOUNDDEVICE < \
                _far ptr _initSB16,\
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
ENDIF

;/*************************************************************************
; *
; *	Function    :	void SDI_SB16(SOUNDDEVICE far *sdi);
; *
; *	Description :	Registers SB as a sound device
; *
; *	Input       :	Pointer to SD structure
; *
; *	Returns     :	Fills SD structure accordingly
; *
; ************************************************************************/

CPROC   SDI_SB16 @@sdi

        ENTERPROC       _di _si
	cld
        LESDI   [@@sdi]
        mov     _si,offset SoundDeviceSB16
        mov     _cx,SIZE SOUNDDEVICE
IF16    cli
IF16    segcs
	rep movsb			; Copy structure
IF16    sti
        sub     _ax,_ax                 ; indicate successful init
        LEAVEPROC       _di _si
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

	push	cx
	mov	cx,65535
	push	ax
	mov	dx,[SoundCard.ioPort]
	add	dl,0Ch
@@1:
	in	al,dx
	or	al,al
	jns	@@2
	loop	@@1
@@2:
	pop	ax
	out	dx,al
	pop	cx

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

        push    cx
        mov     cx,60001
        mov     al,0B6h                 ; SB's command for 16 bit output
        mov     ah,10h
        cmp     [SoundCard.sampleSize],2
        je      @@16bit
        mov     al,0C6h                 ; SB's command for 8 bit output
        mov     ah,00h
@@16bit:
        call    cmdSB
        mov     al,ah
	cmp	[SoundCard.stereo],0
	je	@@mono
        or      al,20h                  ; Set stereo
@@mono:
	call	cmdSB
	mov	al,cl			; Count
	call	cmdSB
	mov	al,ch
	call	cmdSB
@@exit:
        pop     cx
	ret
ENDP

;/*************************************************************************
; *
; *	Function    : 	interruptDMA
; *
; *	Description :	DMA interrupt routine for continuos playing.
; *
; ************************************************************************/

PROC    interruptDMA

	push	ax
	push	dx
	push	ds
        mov     ax,DGROUP
	mov	ds,ax			; DS = data segment

        mov     dx,[SoundCard.ioPort]   ; Ack SB for next IRQ
	add	dl,0Fh
	in	al,dx
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
	mov	al,0
	out	dx,al
	sub	dl,6

	add	dl,0Eh          	; DSP data available status
	mov	cx,1000
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
; *	Function    :	int initSB16(CARDINFO *sCard);
; *
; *	Description : 	Initializes Sound Blaster 16 using values for
; *		      	ioPort,dmaIRQ & dmaChannel in sCard
; *
; *	Input       : 	sCard   = pointer to CARDINFO-structure
; *
; *	Returns     : 	 0	= success
; *			-1	= error
; *
; ************************************************************************/

CPROC   initSB16 @@sCard
locvars   _word retryCount,_dword retvalue

        ENTERPROC
        LESSI   [@@sCard]
        mov     [dword retvalue],-1           ; assume error
	mov	dx,[ESSI+CARDINFO.ioPort]
	cmp	dx,220h			; check for valid addresses
	je	@@OK
	cmp	dx,240h			; check for valid addresses
	je	@@OK
	cmp	dx,260h			; check for valid addresses
	je	@@OK
	cmp	dx,280h
	jne	@@exit
@@OK:
	cmp	[ESSI+CARDINFO.DMAIRQ],2	; check for legal interrupt values
	je	@@DMA_OK
	cmp	[ESSI+CARDINFO.DMAIRQ],5
	je	@@DMA_OK
	cmp	[ESSI+CARDINFO.DMAIRQ],7
	je	@@DMA_OK
	cmp	[ESSI+CARDINFO.DMAIRQ],10
	jne	@@exit
@@DMA_OK:
	cmp	[ESSI+CARDINFO.DMAChannel],0	; check for legal channel values
	je	@@channelOK
	cmp	[ESSI+CARDINFO.DMAChannel],1
	je	@@channelOK
	cmp	[ESSI+CARDINFO.DMAChannel],3
	je	@@channelOK
	cmp	[ESSI+CARDINFO.DMAChannel],5
	je	@@channelOK
	cmp	[ESSI+CARDINFO.DMAChannel],6
	je	@@channelOK
	cmp	[ESSI+CARDINFO.DMAChannel],7
	jne	@@exit
@@channelOK:
        mov     _si,offset SoundBlaster16        ; DS:SI = source
IF16    <mov     ax,ds>
IF16    <mov     es,ax>
        mov     _di,offset SoundCard     ; ESDI = destination
        mov     _cx,SIZE CARDINFO
	cld
IF16    cli
IF16    segcs
	rep	movsb			; Copy information
IF16    sti

        LESSI   [@@sCard]
        mov     bx,[ESSI+CARDINFO.ioPort]
	mov	[SoundCard.ioPort],bx
	mov	bl,[ESSI+CARDINFO.DMAIRQ]
	mov	[SoundCard.DMAIRQ],bl
	mov	bl,[ESSI+CARDINFO.DMAChannel]
	mov	[SoundCard.DMAchannel],bl
        mov     bl,[ESSI+CARDINFO.sampleSize]
        mov     [SoundCard.sampleSize],bl
        mov     bl,[ESSI+CARDINFO.stereo]
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
	mov	cx,1000
@@10:
	in	al,dx			; Read version high
	or	al,al
	js	@@10ok
	loop	@@10
	jmp	@@retry
@@10ok:
	mov	cx,1000
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
	cmp	ax,0400h		; Is version 4.00 or higher?
	jl	@@exit			; No --> exit

	mov	dx,[SoundCard.ioPort]	; initialize Sound Blaster
	add	dx,6
	mov	al,1
	out	dx,al
	in	al,dx			; Wait for awhile
	in	al,dx
	in	al,dx
	in	al,dx
	in	al,dx
	mov	al,0
	out	dx,al

	or	[mcpStatus],S_INIT	; indicate successful initialization
        mov     [dword retvalue],0            ; return 0 = OK
@@exit:
        mov     _ax,[retvalue]
        LEAVEPROC
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
	add	al,8			; AL = DMA interrupt number
        push    es
        push    ax
	mov	ah,35h			; Get interrupt vector
	int	21h
        mov     [saveDMAvectorOFFS],_bx     ; Save it
        mov     [saveDMAvectorSEG],es
	pop	ax			; Replace vector with the address
        pop     es
	mov	ah,25h			; of own interrupt routine
        push    ds
        push    cs
	pop	ds
        mov     _dx,offset interruptDMA  ; Set interrupt vector
	int	21h
	pop	ds

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
        mov     cx,[word @@sample_rate]
        mov     al,41h                  ; Set SB's sampling rate
	call	cmdSB
	mov	al,ch
	call	cmdSB
	mov	al,cl
	call	cmdSB
@@exit:
        mov     [samplingRate],cx       ; and save it for future use
        mov     ax,cx
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
; *	Function    :	startVoice
; *
; *	Description :	Starts to output voice.
; *
; ************************************************************************/

CPROC   startVoice

	mov	cl,[SoundCard.DMAIRQ]		; Enable DMA interrupt
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
        mov     _cx,[bufferSize]
        ecall   dmaStart <LARGE 58h>

	call	playDMA
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
        mov     al,0D9h
        cmp     [SoundCard.sampleSize],2
        je      @@16bit
        mov     al,0DAh
@@16bit:
        call    cmdSB                   ; Stop autoinit mode transfer

        mov     dx,[SoundCard.ioPort]
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

	mov	dx,[SoundCard.ioPort]
	add	dx,0Eh
	in	al,dx
        inc     dx
        in      al,dx

	mov	cl,[SoundCard.DMAIRQ]		; Disable DMA interrupt
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

        push    ds
        mov     al,[SoundCard.DMAIRQ]
	test	al,8			; Is IRQ > 7
	jz	@@01
	add	al,60h			; Yes, base is 70h
@@01:
	add	al,8
        mov     _dx,[saveDMAvectorOFFS]
        mov     ds,[saveDMAvectorSEG]
	mov	ah,25h
	int	21h			; Restore DMA vector
        pop     ds
	ret
ENDP

CPROC   closeSB
	ret
ENDP

CPROC   pauseVoice
;	mov	al,0D0h
;	call	cmdSB
	ret
ENDP

CPROC   resumeVoice
;	mov	al,0D4h
;	call	cmdSB
	ret
ENDP

ENDS

END
