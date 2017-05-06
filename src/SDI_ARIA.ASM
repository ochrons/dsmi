;/************************************************************************
; *
; *	File	    : SDI_ARIA.ASM
; *
; *	Description : SDI for sound cards based on Aria chipset
; *
; *	Copyright (C) 1993 Otto Chrons
; *
; ***********************************************************************
;
;	Revision history of SDI_ARIA.ASM
;
;	1.0	17.5.93
;		First version.
;
; ***********************************************************************/

	IDEAL
	JUMPS
	P386N

;	L_PASCAL	= 1		; Uncomment this for pascal-style

IFDEF   __PASCAL__
	LANG	EQU	PASCAL
	MODEL TPASCAL
ELSE
	LANG	EQU	C
	MODEL LARGE,C
ENDIF

        INCLUDE "MODEL.INC"
        INCLUDE "MCP.INC"

STRUC	DMAPORT

	addr	DW ?
	count	DW ?
	page	DW ?
	wcntrl	DW ?
	wreq	DW ?
	wrsmr	DW ?
	wrmode	DW ?
	clear	DW ?
	wrclr	DW ?
	clrmask	DW ?
	wrall	DW ?
ENDS

	PACKET_SIZE = 512

	DSP_DATA = 0
	DSP_STATUS = 2
	DSP_CONTROL = 2
	DSP_DMA_ADDRESS = 4
	DSP_DMA_DATA = 6

	INTPC_DSPRD     EQU  0001h      ; Interrupt PC on DSP read
	INTPC_DSPWR     EQU  0002h      ; Interrupt PC on DSP write
	INTDSP_PCRD     EQU  0004h      ; Interrupt DSP on PC read
	INTDSP_PCWR     EQU  0008h      ; Interrupt DSP on PC write
	INTPC_DMADONE   EQU  0010h      ; Interrupt PC on DMA completion
	SAMP_RATE       EQU  0060h      ; Sample rate mask
	 SAMP_44K       EQU  0000h      ;    44.10 kHz
	 SAMP_32K       EQU  0020h      ;    31.50 kHz
	 SAMP_22K       EQU  0040h      ;    22.05 kHz
	 SAMP_16K       EQU  0060h      ;    15.75 kHz
	C2MODE          EQU  0080h      ; Aria Wave Synthesis select
	DSP_RESET       EQU  0100h      ; Reset DSP
	DMA_DSPTOPC     EQU  0200h      ; DMA direction - DSP to PC
	DMA_XFR         EQU  0400h      ; Initiate DMA transfer
	ADC_SRC_AUX     EQU  0800h      ; ADC record source select
	ADC_STEREO      EQU  1000h      ; ADC mono/stereo select
	ADC_SRC_RIGHT   EQU  2000h      ; ADC monophonic source
	ADC_DISABLE     EQU  4000h      ; ADC enable/disable
	PORT0_BUSY      EQU  8000h      ; Data port busy flag

DATASEG

	EXTRN	mcpStatus:BYTE
	EXTRN	bufferSize:WORD
	EXTRN	dataBuf:WORD
	EXTRN	SoundCard:CARDINFO

	DMApage		DB ?
	DMAoffset	DW ?
	ioPort		DW ?
	saveDMAvector	DD ?
	samplingRate	DW ?
	curDMA		DMAPORT <>
	audioRate	DW ?
	flipflop	DW ?
	playing		DB ?
	bufcount	DW ?

CODESEG

	PUBLIC	SDI_ARIA

	copyrightText	DB "SDI for Aria v1.0 - (C) 1993 Otto Chrons",0,1Ah

	Aria		CARDINFO <8,0,"Aria sound card",290h,10,5,4000,44100,1,1,2>

	LABEL DMAports	DMAPORT

	    DMAPORT <0,1,87h,8,9,0Ah,0Bh,0Ch,0Dh,0Eh,0Fh>
	    DMAPORT <2,3,83h,8,9,0Ah,0Bh,0Ch,0Dh,0Eh,0Fh>
	    DMAPORT <4,5,81h,8,9,0Ah,0Bh,0Ch,0Dh,0Eh,0Fh>
	    DMAPORT <6,7,82h,8,9,0Ah,0Bh,0Ch,0Dh,0Eh,0Fh>
	    DMAPORT <0,0,0,0,0,0,0,0,0,0,0>
	    DMAPORT <0C4h,0C6h,8Bh,0D0h,0D2h,0D4h,0D6h,0D8h,0DAh,0DCH,0DEh>
	    DMAPORT <0C8h,0CAh,89h,0D0h,0D2h,0D4h,0D6h,0D8h,0DAh,0DCH,0DEh>
	    DMAPORT <0CCh,0CEh,8Ah,0D0h,0D2h,0D4h,0D6h,0D8h,0DAh,0DCH,0DEh>

	SoundDeviceAria	SOUNDDEVICE < \
		far ptr initAria,\
		far ptr initDMA,\
		far ptr initRate,\
		far ptr closeAria,\
		far ptr closeDMA,\
		far ptr startVoice,\
		far ptr stopVoice,\
		far ptr pauseVoice,\
		far ptr resumeVoice\
		far ptr getDMApos,\
		far ptr speakerOn,\
		far ptr speakerOff\
		>

;************************************************************************
;
; Macro to select digital audio FIFO buffer location
;
; Input:  di = audio channel number (word index 0, 2, 4 or 6)
;         ax = DSP FIFO flag address (6100h or 6101h)
;
; Output: ax = buffer location (DSP address)
;         dx = DMA address port
;
; Destroys:  bx, si
;
;************************************************************************

MACRO	setFIFOaddr
	LOCAL   get1

	mov     dx, [ioPort]
	add     dx, DSP_DMA_ADDRESS
	out     dx, ax          ; select address in DSP RAM
	inc     dx
	inc     dx
	in      ax, dx          ; read value
	mov     bx, ax          ; offset in bx

	push    cx              ; compute offset to FIFO
	mov     cx, di          ; channel number in cx
	shr     cx, 1
	inc     cx              ; channel + 1
	shl     cx, 1           ; channel * 2
	xor     ax, ax
	mov     si, PACKET_SIZE
get1:
	add     ax, si
	loop    get1
	pop     cx

	mov     si, ax
	mov     ax, 8000h
	sub     ax, si
	add     ax, bx

	dec     dx
	dec     dx
	out     dx, ax          ; set the FIFO address for DSP RAM
ENDM

;/*************************************************************************
; *
; *	Function    :	void SDI_ARIA(SOUNDDEVICE far *sdi);
; *
; *	Description :	Registers Aria as a sound device
; *
; *	Input       :	Pointer to SD structure
; *
; *	Returns     :	Fills SD structure accordingly
; *
; ************************************************************************/

PROC	SDI_ARIA FAR USES di si,sdi:DWORD

	cld
	LESDI	[sdi]
	mov	si,offset SoundDeviceAria
	mov	cx,SIZE SOUNDDEVICE
	cli
	segcs
	rep movsb			; Copy structure
	sti
	sub	ax,ax			; indicate successful init
	ret
ENDP


;/*************************************************************************
; *
; *	Function    :	AriaCMD
; *
; *	Description :  	Sends a command to Aria's DSP
; *
; *	Input       :	AX = cmd to send
; *
; ************************************************************************/

PROC    AriaCMD NEAR

	push	ax
	mov	dx,[ioPort]
	add	dx,DSP_STATUS
	mov	cx,20000
@@wait:
	in	ax,dx
	test	ax,8000h
	loopnz	@@wait

	mov	dx,[ioPort]
	pop	ax
	out	dx,ax

	ret
ENDP


;/*************************************************************************
; *
; *	Function    :	putMem16
; *
; *	Description :	Puts a word into DSP's memory
; *
; *	Input       :	BX = address, AX = value
; *
; ************************************************************************/

PROC	putMem16 NEAR

	push	ax
	mov	dx,[ioPort]
	add	dx,DSP_DMA_ADDRESS
	mov	ax,bx
	out	dx,ax
	mov	dx,[ioPort]
	add	dx,DSP_DMA_DATA
	pop	ax
	out	dx,ax

	ret
ENDP

;/*************************************************************************
; *
; *	Function    :	getMem16
; *
; *	Description :	Gets a word into DSP's memory
; *
; *	Input       :	BX = address
; *
; *	Returns	    :	AX = value
; *
; ************************************************************************/

PROC	getMem16 NEAR

	mov	dx,[ioPort]
	add	dx,DSP_DMA_ADDRESS
	mov	ax,bx
	out	dx,ax
	mov	dx,[ioPort]
	add	dx,DSP_DMA_DATA
	in	ax,dx

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

	cli
	pusha
	mov	dx,[ioPort]		; Was this interrupt generated
	in	ax,dx			; by Aria DSP?
	cmp	ax,1
	jne	@@exit

	xor	[flipflop],1
	jnz	@@notrans

	mov	ax,10h
	call	AriaCMD			; Start transfer
	mov	ax,0FFFFh
	call	AriaCMD
	jmp	@@exit
@@notrans:
	mov	ah,[DMApage]		; Load correct DMA page and offset
	mov	bx,[DMAoffset]		; values
	add	bx,[bufcount]
	mov	cx,PACKET_SIZE
	add	[bufcount],PACKET_SIZE
	mov	dx,[bufcount]
	shl	dx,1
	cmp	dx,[buffersize]
	jl	@@bok
	mov	[bufcount],0
@@bok:
	dec	cx			; Set the DMA up and running
	mov	al,[SoundCard.DMAChannel]
	or	al,4
	mov	dx,[curDMA.wrsmr]
	out	dx,al			; Break On
	mov	al,0
	mov	dx,[curDMA.clear]
	out	dx,al			; Reset counter
	mov	al,[SoundCard.DMAChannel]
	and	al,3
	or	al,048h
	mov	dx,[curDMA.wrmode]
	out	dx,al
	mov	dx,[curDMA.page]
	mov	al,ah
	out	dx,al			; Page

	mov	dx,[curDMA.addr]
	mov	al,bl
	out	dx,al			; Offset
	mov	al,bh
	out	dx,al

	mov	dx,[curDMA.count]
	mov	al,cl
	out	dx,al			; Count
	mov	al,ch
	out	dx,al
	mov	al,[SoundCard.DMAChannel]
	and	al,3
	mov	dx,[curDMA.wrsmr]
	out	dx,al			; Break Off

	mov	di,0
	mov	ax,6100h		; Set address...
	setFIFOaddr

	mov	ax,INTPC_DSPWR OR INTDSP_PCWR OR C2MODE OR INTPC_DMADONE OR DMA_XFR
	or	ax,[audioRate]
	mov	dx,[ioPort]
	add	dx,DSP_CONTROL
	out	dx,ax

@@exit:
	popa
	sti
	ret
ENDP

;/*************************************************************************
; *
; *	Function    : 	interruptDMA
; *
; *	Description :	DMA interrupt routine for continuos playing.
; *
;/************************************************************************/

PROC    interruptDMA

	sti
	push	ax
	push	dx
	push	ds
	mov	ax,@data
	mov	ds,ax			; DS = data segment

	cmp	[mcpStatus],111b	; Inited and playing
	jne	@@exit
	call	playDMA			; Output current buffer
@@exit:
	mov	al,20h			; End Of Interrupt (EOI)
	cmp	[SoundCard.dmaIRQ],7
	jle	@@10
	out	0A0h,al
@@10:
	out	20h,al
	pop	ds
	pop	dx
	pop	ax
	iret				; Interrupt return
ENDP


;/*************************************************************************
; *
; *	Function    : int initAria(CARDINFO *scard);
; *
; *	Description : Initializes a Aria card.
; *
; *	Input       : Pointer to CARDINFO structure
; *
; *	Returns     : 0 no error
; *		      other = error
; *
; *************************************************************************/

PROC	initAria FAR USES si di, scard:FAR PTR CARDINFO
        LOCAL   @@retval:WORD

        mov     [@@retval],-1
	LESSI	[scard]
	mov	al,[ESSI+CARDINFO.ID]
	mov	si,offset Aria		; SI = source
	cmp	al,ID_ARIA		; Check for valid ID
	jne	@@exit
@@idOK:
	mov	ax,ds
	mov	es,ax
	mov	di,offset SoundCard	; ESDI = destination
	mov	cx,SIZE CARDINFO
	cld
	cli
	segcs
	rep	movsb			; Copy information
	sti

	LESSI	[scard]
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

	mov	al,2			; Assume 16-bit sample
	cmp	[ESSI+CARDINFO.sampleSize],2
	je	@@sizeOK
	mov	al,1			; No, it's 8-bit
@@sizeOK:
	mov	bl,[ESSI+CARDINFO.sampleSize]

	mov	[SoundCard.sampleSize],bl	; Save values
	mov	[SoundCard.stereo],bh

	mov	bl,[ESSI+CARDINFO.DMAchannel]
	sub	bh,bh
	imul	bx,bx,SIZE DMAPORT
	lea	si,[bx+DMAports]	; SI = DMAports[DMAchannel]
	mov	ax,ds
	mov	es,ax
	mov	di,offset curDMA	; ESDI = curDMA
	mov	cx,SIZE DMAPORT
	cli
	segcs
	rep	movsb			; Copy structure
	sti

	mov	dx,[SoundCard.ioPort]
	mov	[ioPort],dx

	mov	ax,00C8h		; Init Aria
	add	dx,DSP_CONTROL
	out	dx,ax

	mov	ax,0
	mov	bx,6102h		; DSP init
	call	putMem16

	cli
	mov	ax,0			; System init
	call	AriaCMD
	mov	ax,0			; Add new task
	call	AriaCMD
	mov	ax,0			; Aria Synthesizer mode, ROM module
	call	AriaCMD
	mov	ax,0			; No address
	call	AriaCMD
	mov	ax,0FFFFh		; End of command
	call	AriaCMD
	sti
	mov	cx,2000
@@loop:
	mov	dx,[ioPort]
	add	dx,DSP_STATUS
	in	ax,dx			; Delay
	mov	bx,6102h
	call	getMem16		; Get value from DSP's memory
	cmp	ax,1
	loopne	@@loop

;	jne	@@exit

	mov	dx,[ioPort]
	add	dx,DSP_CONTROL
	mov	ax,00CAh		; Init Aria mode..
	out	dx,ax

	or	[mcpStatus],S_INIT	; indicate successful initialization
	mov	[flipflop],0
        mov     [@@retval],0
@@exit:
        mov     ax,[@@retval]
	ret
ENDP

;/***********************************************************************
; *
; *	Function    :	int getDMApos():
; *
; *	Description :	Returns the position of DMA transfer
; *
; **********************************************************************/

PROC	getDMApos FAR

	mov	ax,[bufcount]
	shl	ax,1
	sub	ax,PACKET_SIZE*2
	jns	@@pos_ok
	add	ax,[bufferSize]
@@pos_ok:
	ret
ENDP

;/*************************************************************************
; *
; *	Function    :	initDMA(void far *buffer,int maxsize, int required);
; *
; *	Description :   Init DMA for output
; *
; ************************************************************************/

PROC    initDMA FAR buffer:DWORD,linear:DWORD,maxSize:DWORD,required:DWORD

        mov     cx,[word maxSize]
	mov	[bufferSize],cx
	mov	ax,[WORD HIGH buffer]
	mov	bx,[WORD LOW buffer]
	add	bx,4
	and	bx,NOT 3
	mov	[dataBuf],bx		; Check if DMA buffers are on
	mov	eax,[linear]		; a segment boundary
	neg	ax
	cmp	ax,cx			; Is buffer size >= data size
	ja	@@bufOK
	dec	ax
	and	ax,NOT 3
	mov	[bufferSize],ax
	shr	cx,1
	cmp	ax,cx			; Is it even half of it?
	ja	@@bufOK
	shl	cx,1
	add	[dataBuf],ax
	add	[dataBuf],4
	and	[dataBuf],NOT 3
	neg	ax
	add	ax,cx			; AX = dataSize - AX
	sub	ax,32
	and	ax,NOT 3
	mov	[bufferSize],ax
@@bufOK:
	cmp	[required],0
	je	@@sizeok
        cmp     ax,[word required]
	jbe	@@sizeok
        mov     ax,[word required]
	mov	[bufferSize],ax
@@sizeok:
	and	[bufferSize],NOT (PACKET_SIZE*2-1)
	jnz	@@bufsizeok
	mov	[bufferSize],PACKET_SIZE*2
@@bufsizeok:
	sub	ebx,ebx
	mov	eax,[linear]		; Calculate DMA page and offset values
	mov	bx,[dataBuf]
	sub	bx,[WORD LOW buffer]	; Relative offset
	add	eax,ebx
	mov	ebx,eax
	shr	ebx,16
	cmp	[SoundCard.DMAChannel],4
	jb	@@8bitDMA
	push	bx
	shr	bl,1
	rcr	ax,1			; For word addressing
	pop	bx
@@8bitDMA:
	mov	[DMApage],bl
	mov	[DMAoffset],ax

	cli
	mov	ax,5
	call	AriaCMD			; Set packet size
	mov	ax,PACKET_SIZE
	call	AriaCMD			; to PACKET_SIZE
	mov	ax,0FFFFh
	call	AriaCMD
	sti

	mov	al,[SoundCard.DMAIRQ]
	test	al,8			; Is IRQ > 7
	jz	@@01
	add	al,60h			; Yes, base is 70h
@@01:
	add	al,8			; AL = DMA interrupt number
	push	ax
	mov	ah,35h			; Get interrupt vector
	int	21h
	mov	[WORD LOW saveDMAvector],bx	; Save it
	mov	[WORD HIGH saveDMAvector],es
	pop	ax			; Replace vector with the address
	mov	ah,25h			; of own interrupt routine
	PUSHDS
	push	cs
	pop	ds
	mov	dx,offset interruptDMA	; Set interrupt vector
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
	ret
ENDP

;/*************************************************************************
; *
; *	Function    :	initRate
; *
; *	Description :   Inits sound card's sampling rate
; *
; ************************************************************************/

PROC    initRate FAR USES di,sample_rate:DWORD

	mov	ax,44100		; Find best match
	mov	cx,00h
	mov	di,20h
        mov     bx,[word sample_rate]
	cmp	bx,38000
	jae	@@ok
	mov	cx,40h
	mov	ax,22050
	mov	di,10h
	cmp	bx,16000
	jae	@@ok
	mov	ax,11025
	mov	di,0h
@@ok:
	mov	[audioRate],cx
	mov	[samplingRate],ax
	mov	dx,[ioPort]
	add	dx,DSP_CONTROL
	mov	ax,INTPC_DSPWR OR INTDSP_PCWR OR INTPC_DMADONE OR C2MODE
	or	ax,cx
	out	dx,ax			; Set new one

	cli
	mov	ax,6
	call	AriaCMD			; Set Playback mode
	mov	ax,0
	call	AriaCMD
	mov	ax,0FFFFh
	call	AriaCMD

	mov	ax,3
	call	AriaCMD			; Set digital audio format
	mov	ax,0
	add	al,[SoundCard.stereo]	; Set stereo
	cmp	[SoundCard.samplesize],2
	jne	@@8bit
	add	al,2			; Set 16-bit
@@8bit:
	or	ax,di
	call	AriaCMD
	mov	ax,0FFFFh
	call	AriaCMD
	sti
@@exit:
	mov	ax,[samplingRate]
	ret
ENDP

;/*************************************************************************
; *
; *	Function    :	speakerOn
; *
; *	Description :	Connects Aria speaker
; *
; ************************************************************************/

PROC	speakerOn FAR

	ret
ENDP

;/*************************************************************************
; *
; *	Function    :	speakerOff
; *
; *	Description :	Disconnects speaker from Aria
; *
; ************************************************************************/

PROC	speakerOff FAR

	ret
ENDP

;/*************************************************************************
; *
; *	Function    :	startVoice
; *
; *	Description :	Starts to output voice.
; *
; ************************************************************************/

PROC	startVoice FAR USES di

	mov	di,0
	mov	ax,6100h		; Set address...
	setFIFOaddr

	mov	ah,[DMApage]		; Load correct DMA page and offset
	mov	bx,[DMAoffset]		; values
	mov	cx,PACKET_SIZE
	dec	cx
	cli				; Set the DMA up and running
	mov	al,[SoundCard.DMAChannel]
	or	al,4
	mov	dx,[curDMA.wrsmr]
	out	dx,al			; Break On
	mov	al,0
	mov	dx,[curDMA.clear]
	out	dx,al			; Reset counter
	mov	al,[SoundCard.DMAChannel]
	and	al,3
	or	al,048h
	mov	dx,[curDMA.wrmode]
	out	dx,al
	mov	dx,[curDMA.page]
	mov	al,ah
	out	dx,al			; Page

	mov	dx,[curDMA.addr]
	mov	al,bl
	out	dx,al			; Offset
	mov	al,bh
	out	dx,al

	mov	dx,[curDMA.count]
	mov	al,cl
	out	dx,al			; Count
	mov	al,ch
	out	dx,al
	mov	al,[SoundCard.DMAChannel]
	and	al,3
	mov	dx,[curDMA.wrsmr]
	out	dx,al			; Break Off

	mov	[flipflop],0
	mov	[bufcount],PACKET_SIZE


	mov	ax,INTPC_DSPWR OR INTDSP_PCWR OR INTPC_DMADONE OR C2MODE OR DMA_XFR
	or	ax,[audioRate]
	mov	dx,[ioPort]
	add	dx,DSP_CONTROL
	out	dx,ax

	mov	ax,11h
	call	AriaCMD			; Start audio playback
	mov	ax,0
	call	AriaCMD			; On channel 0
	mov	ax,0FFFFh
	call	AriaCMD

;	mov	ax,10h
;	call	AriaCMD			; Start transfer
;	mov	ax,0FFFFh
;	call	AriaCMD
	sti
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

PROC	stopVoice FAR USES di

	cli
	mov	ax,12h
	call	AriaCMD			; Stop audio playback
	mov	ax,0
	call	AriaCMD			; on channel 0
	mov	ax,0FFFFh
	call	AriaCMD
	sti

	mov	cx,0
@@wait:
	loop	@@wait
	mov	al,[SoundCard.DMAChannel] ; Reset DMA
	or	al,4
	mov	dx,[curDMA.wrsmr]
	out	dx,al
	mov	al,0
	mov	dx,[curDMA.clear]
	out	dx,al

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
	mov	al,0
	out	0Ch,al
	mov	al,[SoundCard.DMAChannel] ; Reset DMA
	or	al,4
	out	0Ah,al
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

PROC closeDMA FAR
	PUSHDS
	mov	al,[SoundCard.DMAIRQ]
	test	al,8			; Is IRQ > 7
	jz	@@01
	add	al,60h			; Yes, base is 70h
@@01:
	add	al,8
	mov	dx,[WORD LOW saveDMAvector]
	mov	ds,[WORD HIGH saveDMAvector]
	mov	ah,25h
	int	21h			; Restore DMA vector
	POPDS
	ret
ENDP

PROC closeAria FAR

	mov	dx,[ioPort]
	add	dx,DSP_CONTROL		; Set Aria mode in control register
	mov	ax,0C8h
	out	dx,ax

	mov	ax,0
	mov	bx,6102h
	call	putMem16

	mov	ax,0
	call	AriaCMD
	mov	ax,0
	call	AriaCMD
	mov	ax,1			; Set SB mode
	call	AriaCMD
	mov	ax,0
	call	AriaCMD
	mov	ax,0FFFFh
	call	AriaCMD
	mov	cx,2000
@@loop:
	mov	dx,[ioPort]
	add	dx,DSP_STATUS
	in	ax,dx			; Delay
	mov	bx,6102h
	call	getMem16		; Get value from DSP's memory
	cmp	ax,1			; Is DSP ready?
	loopne	@@loop

	mov	dx,[ioPort]
	add	dx,DSP_CONTROL		; Set SB mode in control register
	mov	ax,040h
	out	dx,ax
	ret
ENDP

PROC pauseVoice FAR
	ret
ENDP

PROC resumeVoice FAR
	ret
ENDP


END
