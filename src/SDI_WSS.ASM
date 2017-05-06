;/************************************************************************
; *
; *	File	    : SDI_WSS.ASM
; *
; *	Description : SDI for Windows Sound System
; *
; *	Copyright (C) 1993 Otto Chrons
; *
; ***********************************************************************
;
;	Revision history of SDI_WSS.ASM
;
;	1.0	20.6.93
;               First version.
;
;       2.0     14.2.94
;               32-bit compatible version
;
; ***********************************************************************/

	IDEAL
	JUMPS
	P386N


        INCLUDE "MODEL.INC"
        INCLUDE "MCP.INC"
        INCLUDE "DMA.INC"

CSEGMENTS SDI_WSS

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

	DMApage		DB ?
	DMAoffset	DW ?
	ioPort		DW ?
IF16    <saveDMAvectorOFS DW ?>
IF32    <saveDMAvectorOFS DD ?>
        saveDMAvectorSEG  DW ?
        samplingRate    DW ?

ENDS

CCODESEG SDI_WSS

        CPUBLIC  SDI_WSS

	copyrightText	DB "SDI for Windows Sound System v1.0 - (C) 1993 Otto Chrons",0,1Ah

	WSSnorm		CARDINFO <9,0,"Windows Sound System",530h,0,0,4000,48000,1,1,2>

	WSS_IRQ	DB 0,0,0,0,0,0,0,8h,0,10h,18h,20h,0,0,0,0
	WSS_DMA DB 1,2,0,3,0,0,0,0

	LABEL WSS_rates	WORD

	    DW 8000,0
	    DW 5513,1
	    DW 16000,2
	    DW 11025,3
	    DW 27429,4
	    DW 18900,5
	    DW 32000,6
	    DW 22050,7
	    DW 0,8
	    DW 37800,9
	    DW 0,0Ah
	    DW 44100,0Bh
	    DW 48000,0Ch
	    DW 33075,0Dh
	    DW 9600,0Eh
	    DW 6615,0Fh

IFDEF __PASCAL__

	SoundDeviceWSS	SOUNDDEVICE < \
                _far ptr initWSS,\
                _far ptr initDMA,\
                _far ptr initRate,\
                _far ptr closeWSS,\
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
        SoundDeviceWSS  SOUNDDEVICE < \
                _far ptr _initWSS,\
                _far ptr _initDMA,\
                _far ptr _initRate,\
                _far ptr _closeWSS,\
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

;/***************************************************************************\
;*
;* Function:    WR_WSS
;*
;* Description: Writes one cmd to WSS
;*
;* Input:       AL = register, AH = data
;*
;\***************************************************************************/

PROC    WR_WSS NEAR

        push    dx
        mov     dx,[SoundCard.ioPort]
        add     dx,4
        out     dx,al
        inc     dx
        xchg    al,ah
        out     dx,al
        xchg    al,ah
        pop     dx

        ret
ENDP

;/*************************************************************************
; *
; *	Function    :	void SDI_WSS(SOUNDDEVICE far *sdi);
; *
; *	Description :	Registers Windows Sound System as a sound device
; *
; *	Input       :	Pointer to SD structure
; *
; *	Returns     :	Fills SD structure accordingly
; *
; ************************************************************************/

CPROC   SDI_WSS @@sdi

        ENTERPROC       _di _si
	cld
        LESDI   [@@sdi]
        mov     _si,offset SoundDeviceWSS
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
        mov     ax,DGROUP
	mov	ds,ax			; DS = data segment

	mov	al,[mcpStatus]
	and	al,111b
	cmp	al,111b			; Inited and playing
	jne	@@exit
	mov	dx,[ioPort]
	add	dx,6
	mov	al,0
	out	dx,al			; Acknowledge interrupt
@@exit:
	mov	al,20h			; End Of Interrupt (EOI)
	out	20h,al
	cmp	[SoundCard.dmaIRQ],7
	jle	@@10
	out	0A0h,al
@@10:
	pop	ds
	pop	dx
	pop	ax
	iret				; Interrupt return
ENDP


;/*************************************************************************
; *
; *	Function    : int initWSS(CARDINFO *scard);
; *
; *	Description : Initializes a WSS card.
; *
; *	Input       : Pointer to CARDINFO structure
; *
; *	Returns     : 0 no error
; *		      other = error
; *
; *************************************************************************/

CPROC   initWSS @@scard
LOCALVAR   _dword retvalue

        ENTERPROC       _si _di
        mov     [dword retvalue],-1
        LESSI   [@@scard]
	mov	al,[ESSI+CARDINFO.ID]
        mov     _si,offset WSSnorm      ; SI = source
	cmp	al,ID_WSS		; Check for valid ID
	jne	@@exit
@@idOK:
IFDEF __16__
        mov     ax,ds
	mov	es,ax
ENDIF
        mov     _di,offset SoundCard     ; ES:DI = destination
        mov     _cx,SIZE CARDINFO
	cld
IF16    cli
IF16    segcs
	rep	movsb			; Copy information
IF16    sti

        LESSI   [@@scard]
	mov	ax,[ESSI+CARDINFO.ioPort]
	mov	[SoundCard.ioPort],ax
	mov	[ioPort],ax
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

        mov     dx,[ioPort]
        sub     _bx,_bx
	mov	bl,[SoundCard.DMAIRQ]
        mov     al,[WSS_IRQ+_bx]
	mov	bl,[SoundCard.DMAchannel]
        or      al,[WSS_DMA+_bx]
	out	dx,al			; Setup IRQ and DMA

	mov	al,[SoundCard.DMAIRQ]
	test	al,8			; Is IRQ > 7
	jz	@@01
	add	al,60h			; Yes, base is 70h
@@01:
	add	al,8			; AL = DMA interrupt number
        push    es
	push	ax
	mov	ah,35h			; Get interrupt vector
	int	21h
        mov     [saveDMAvectorOFS],_bx     ; Save it
        mov     [saveDMAvectorSEG],es
	pop	ax			; Replace vector with the address
        pop     es
	mov	ah,25h			; of own interrupt routine
        push    ds
        push    cs
	pop	ds
        mov     _dx,offset interruptDMA ; Set interrupt vector
	int	21h
	pop	ds

	or	[mcpStatus],S_INIT	; indicate successful initialization
        mov     [dword retvalue],0
@@exit:
        mov     _ax,[retvalue]
        LEAVEPROC       _si _di
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
; *     Function    :   initDMA(void *buffer, ulong physical, int maxsize, int required);
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
; *	Function    :	setSamplingRate
; *
; *	Description :	Sets closest sampling rate possible on WSS
; *
; *	Input       :	AX = rate wanted
; *
; *	Returns     :	AX = closest possible rate
; *
; ************************************************************************/

CPROC   setSamplingRate
LOCVARS _word delta,_word realrate

        ENTERPROC       _di _si
        mov     _cx,16                  ; 16 possible rates (actually 14)
        mov     [word delta],32000      ; Delta is very big in the beginning
        mov     _si,0                   ; SI = closest match
        mov     di,ax                   ; DI = original rate
        sub     _bx,_bx                 ; BX = index
@@loop:
        mov     ax,di
        sub     ax,[_bx+WSS_rates]
	cwd				; AX = abs(AX)
	xor	ax,dx
	sub	ax,dx
	cmp	ax,[delta]
	ja	@@next
	mov	[delta],ax		; New delta
        mov     si,[_bx+WSS_rates+2]    ; This position
        mov     ax,[_bx+WSS_rates]
	mov	[realrate],ax
@@next:
	add	bx,4
	loop	@@loop

        cmp     [SoundCard.stereo],1
	jne	@@mono
        or      si,010h                 ; Set stereo
@@mono:
	cmp	[SoundCard.sampleSize],1
	je	@@8bit
        or      si,040h                 ; Set 16-bit
@@8bit:
        mov     al,0Ah
        mov     ah,0h
        call    WR_WSS

        mov     al,0Ah
        mov     ah,40h
        call    WR_WSS

        mov     al,6
        mov     ah,0BFh
        call    WR_WSS
        mov     al,7
        mov     ah,0BFh
        call    WR_WSS                  ; Mute DACs

        mov     al,49h
        mov     ah,0Ch
        call    WR_WSS                  ; MCE on, Autocalibration

        mov     ax,si
        mov     ah,al
        mov     al,48h
        call    WR_WSS                  ; Set CODEC format

        mov     ecx,200000
@@waitinit:
        mov     dx,[ioPort]             ; Wait for init to complete
	add	dx,4
        in      al,dx
        test    al,80h
        jz      @@waitinitdone
        dec     ecx
        jnz     @@waitinit
@@waitinitdone:

        mov     al,0h
        out     dx,al                   ; MCE off

        mov     _cx,60000
        mov     eax,80000000h
@@autocalibwait:                        ; Wait for autocalibration to start
        bsf     edx,eax
        loop    @@autocalibwait

        mov     ecx,200000
@@waitcalib:
        mov     dx,[ioPort]             ; Wait for auto calib to complete
	add	dx,4
        mov     al,0Bh
        out     dx,al
        inc     dx
        in      al,dx
        test    al,20h
        jz      @@waitcalibdone
        dec     ecx
        jnz     @@waitcalib
@@waitcalibdone:

        mov     al,6
        mov     ah,3Fh
        call    WR_WSS
        mov     al,7
        mov     ah,3Fh
        call    WR_WSS                  ; Silent DACs, but unmute them

        mov     al,49h
        mov     ah,4h
        call    WR_WSS                  ; Playback single DMA

        mov     al,6
        mov     ah,0
        call    WR_WSS
        mov     al,7
        mov     ah,0
        call    WR_WSS                  ; Unmute DACs

        mov     ax,[realrate]
        LEAVEPROC       _di _si
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
        ecall   setSamplingRate
	mov	[samplingRate],ax
@@exit:
	mov	ax,[samplingRate]
        LEAVEPROC
	ret
ENDP

;/*************************************************************************
; *
; *	Function    :	speakerOn
; *
; *	Description :	Connects WSS speaker
; *
; ************************************************************************/

CPROC   speakerOn

IF 0
	mov	dx,[ioPort]
	add	dx,4
	mov	al,07h
	out	dx,al			; Mute off
	inc	dx
	in	al,dx
	and	al,7Fh
	out	dx,al

	mov	dx,[ioPort]
	add	dx,4
	mov	al,06h
	out	dx,al			; Mute off
	inc	dx
	in	al,dx
	and	al,7Fh
	out	dx,al
ENDIF
	ret
ENDP

;/*************************************************************************
; *
; *	Function    :	speakerOff
; *
; *	Description :	Disconnects speaker from WSS
; *
; ************************************************************************/

CPROC   speakerOff

IF 0
	mov	dx,[ioPort]
	add	dx,4
	mov	al,07h
	out	dx,al			; Mute on
	inc	dx
	in	al,dx
	or	al,80h
	out	dx,al

	mov	dx,[ioPort]
	add	dx,4
	mov	al,06h
	out	dx,al			; Mute on
	inc	dx
	in	al,dx
	or	al,80h
	out	dx,al
ENDIF

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

        mov     cx,65000                ; Sample count
        mov     al,0Fh
        mov     ah,cl
        call    WR_WSS

        mov     al,0Eh
        mov     ah,ch
        call    WR_WSS

        mov     al,0Ah
        mov     ah,02h
        call    WR_WSS

        mov     al,09h
        mov     ah,05h
        call    WR_WSS

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
        mov     al,0Ah
        mov     ah,02h
        call    WR_WSS

        mov     al,09h
        mov     ah,04h
        call    WR_WSS

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
        mov     _dx,[saveDMAvectorOFS]
        mov     ds,[saveDMAvectorSEG]
	mov	ah,25h
	int	21h			; Restore DMA vector
        pop     ds
	ret
ENDP

CPROC   closeWSS
	ret
ENDP

CPROC   pauseVoice
	ret
ENDP

CPROC   resumeVoice
	ret
ENDP

ENDS

END
