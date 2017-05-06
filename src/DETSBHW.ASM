; /***********************************************************************
; *
; *     File        : DETSBHW.ASM
; *
; *     Description : Sound Blaster hardware detection routines
; *
; *     Copyright (C) 1992,1994 Otto Chrons
; *
; ************************************************************************
;
;       Revision history of DETSBHW.ASM
;
;	1.0	16.4.93
;		First version. Detects SB, SB Pro and SB 16. Support for
;		8-bit DMA in SB16 is not implemented.
;
;       2.0     Separate software detection routine calls this one.
;               SB16 hardware detection in separate file, this routine
;               works only in real mode.
;
; ***********************************************************************/

	IDEAL
	JUMPS
	P386N

	INCLUDE "MODEL.INC"
	INCLUDE "MCP.INC"

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

CSEGMENTS DETSBHW

CDATASEG
	dmaIRQ		DB ?
	scardPtr	DD ?

ENDS

CCODESEG DETSBHW

        CPUBLIC detectSBHW, detectSBProHW

        copyrightText   DB "SB-DETECT v2.0 - (C) 1992,1994 Otto Chrons",0,1Ah
	SoundBlaster	CARDINFO <1,0,"Sound Blaster",220h,7,1,4000,44100,0,0,1>
	SoundBlasterPro	CARDINFO <2,0,"Sound Blaster Pro",220h,7,1,4000,44100,1,1,1>

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
; *	Function    : 	findDMAIRQ_SB
; *
; *	Description :	Finds SB's DMA interrupt number
; *
; *	Returns     :	AX = 0	error
; *			AX = port number (2,3,5,7)
; *
; ************************************************************************/

STRUC vect4
        v       DW 8 dup(0)
ENDS

CPROC   findDMAIRQ_SB
localvar        vect4 saveVect
localvar        _BYTE intMask

	assume DS:NOTHING

        ENTERPROC di si
	PUSHDS
	mov	ah,35h
	mov	al,8+2
	int	21h
        mov     [saveVect+2],es
        mov     [saveVect],bx
	mov	al,8+3
	int	21h
        mov     [saveVect+6],es
        mov     [saveVect+4],bx
	mov	al,8+5
	int	21h
        mov     [saveVect+10],es
        mov     [saveVect+8],bx
	mov	al,8+7
	int	21h
        mov     [saveVect+14],es
        mov     [saveVect+12],bx

	PUSHCS
	POPDS
	mov	ah,25h
	mov	dx,offset DMA2		; Set vectors
	mov	al,8+2
	int	21h
	mov	dx,offset DMA3
	mov	al,8+3
	int	21h
	mov	dx,offset DMA5
	mov	al,8+5
	int	21h
	mov	dx,offset DMA7
	mov	al,8+7
	int	21h

	in	al,21h
	mov	[intMask],al		; Save interrupt mask
	mov	al,0FFh
	out	21h,al			; Mask out all interrupts
	cli				; Disable interrupts

	POPDS

        assume  DS:DGROUP

	mov	al,[intMask]
	and	al,01010011b		; Allow DMA interrupts (2,3,5 & 7)
	out	21h,al
	sti				; Set DMA up

	mov	al,5
	out	0Ah,al			; Break on
	mov	al,0
	out	0Ch,al			; Reset counter
	mov	al,49h
	out	0Bh,al			; DMA -> DSP (output)
	mov	al,0
	out	83h,al			; page 0
	mov	al,0
	out	2,al			; offset 0
	mov	al,0
	out	2,al			; whole address is 0000:0000
	mov	al,1
	out	3,al			; count = 1
	mov	al,0
	out	3,al
	mov	al,1
	out	0Ah,al			; Break off

	LESDI	[scardPtr]
	mov	dx,[ESDI+CARDINFO.ioPort]
	add	dx,0Ch
	waitSB
	mov	al,40h                  ; Set DSP speed
	out	dx,al
	waitSB
	mov	al,0D3h			; 22222 Hz
	out	dx,al
	waitSB
	mov	al,14h			; 14h = output command
	out	dx,al
	waitSB
	mov	al,1			; digitize 1 byte
	out	dx,al
	waitSB
	mov	al,0
	out	dx,al
	mov	cx,0FFFFh		; Big loop
	mov	[dmaIRQ],0		; Clear interrupt value
@@loop:
	cmp	[dmaIRQ],0		; Wait dmaIRQ to change
	loope	@@loop			; loop if it doesn't
	LESDI	[scardPtr]
	mov	dx,[ESDI+CARDINFO.ioPort]
	add	dl,0Eh
	in	al,dx			; Reset SB

	mov	al,[intMask]
	out	21h,al			; Restore interrupt mask
	sti				; Allow interrupts

	PUSHDS
	mov	ah,25h
	lds	dx,[saveVect]
	mov	al,8+2
	int	21h
	lds	dx,[saveVect+4]
	mov	al,8+3
	int	21h
	lds	dx,[saveVect+8]
	mov	al,8+5
	int	21h
	lds	dx,[saveVect+12]
	mov	al,8+7
	int	21h
	POPDS
	sub	ax,ax
	mov	al,[dmaIRQ]		; Return with interrupt number
        LEAVEPROC di si
        ret

ENDP

;/*************************************************************************
; *
; *	Function    : 	findDMAIRQ_SBpro
; *
; *	Description :	Finds SBpro's DMA interrupt number
; *
; *	Returns     :	AX = 0	error
; *                     AX = IRQ number (2,3,5,7,10)
; *
; ************************************************************************/

CPROC   findDMAIRQ_SBpro
locvars   vect4 saveVect, _BYTE intMask1, _BYTE intMask2

	assume DS:NOTHING

        ENTERPROC di si
	PUSHDS
	mov	ah,35h
	mov	al,8+2
	int	21h
        mov     [saveVect+2],es
        mov     [saveVect],bx
	mov	al,8+5
	int	21h
        mov     [saveVect+6],es
        mov     [saveVect+4],bx
	mov	al,8+7
	int	21h
        mov     [saveVect+10],es
        mov     [saveVect+8],bx
	mov	al,72h
	int	21h
        mov     [saveVect+14],es
        mov     [saveVect+12],bx

	in	al,21h
	mov	[intMask1],al		; Save interrupt mask
	mov	al,0FFh
	out	21h,al			; Mask out all interrupts
	in	al,0A1h
	mov	[intMask2],al		; Save interrupt mask
	mov	al,0FFh
	out	0A1h,al			; Mask out all interrupts
	cli				; Disable interrupts

	PUSHCS
	POPDS
	mov	ah,25h
	mov	dx,offset DMA2		; Set vectors
	mov	al,8+2
	int	21h
	mov	dx,offset DMA5
	mov	al,8+5
	int	21h
	mov	dx,offset DMA7
	mov	al,8+7
	int	21h
	mov	dx,offset DMA10
	mov	al,72h
	int	21h
	POPDS

        assume  DS:DGROUP

	mov	al,[intMask1]
	and	al,01010011b		; Allow DMA interrupts (2,3,5 & 7)
	out	21h,al
	mov	al,[intMask2]
	and	al,11111011b		; Allow DMA interrupt 10
	out	0A1h,al
	sti

	mov	cx,1000
@@waitloop:
	in	al,21h
	loop	@@waitloop

	mov	al,4
	out	0Ah,al			; Break on
	mov	al,5
	out	0Ah,al			; Break on
	mov	al,7
	out	0Ah,al			; Break on

	LESDI	[scardPtr]
	mov	dx,[ESDI+CARDINFO.ioPort]
	add	dx,0Ch
	waitSB
	mov	al,40h                  ; Set DSP speed
	out	dx,al
	waitSB
	mov	al,0D3h			; 22222 Hz
	out	dx,al
	waitSB
	mov	al,14h			; 14h = output command
	out	dx,al
	waitSB
	mov	al,10			; digitize 1 byte
	out	dx,al
	waitSB
	mov	al,0
	out	dx,al
	sti

	mov	ax,1			; Check for DMA channel 1
        ecall    findDMAchannel_SBpro
	or	ax,ax
	jnz	@@channelFound
	mov	ax,0			; Channel 0
        ecall    findDMAchannel_SBpro
	or	ax,ax
	jnz	@@channelFound
	mov	ax,3			; Channel 3
        ecall    findDMAchannel_SBpro
	or	ax,ax
	jnz	@@channelFound
	mov	[dmaIRQ],0
@@channelFound:
	mov	[ESDI+CARDINFO.DMAChannel],al

	mov	dx,[ESDI+CARDINFO.ioPort]
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

	add	dx,0Eh			; Reset SB
	in	al,dx

	PUSHDS
	mov	ah,25h
	lds	dx,[saveVect]
	mov	al,8+2
	int	21h
	lds	dx,[saveVect+4]
	mov	al,8+5
	int	21h
	lds	dx,[saveVect+8]
	mov	al,8+7
	int	21h
	lds	dx,[saveVect+12]
	mov	al,72h
	int	21h
	POPDS

	mov	al,[intMask1]
	out	21h,al			; Restore interrupt mask
	mov	al,[intMask2]
	out	0A1h,al			; Restore interrupt mask
	sti				; Allow interrupts
@@exit:
	sub	ax,ax
	mov	al,[dmaIRQ]		; Return with interrupt number
        LEAVEPROC       di si
        ret

ENDP

;/*************************************************************************
; *
; *	Function    :	findDMAchannel_SBpro
; *
; *	Description :	Checks if given channel is the channel SBPro uses
; *
; *	Input       :	AX = Channel to test
; *
; *	Returns     :	AX = 0 if error
; *			AX = channel if OK
; *
; ************************************************************************/

CPROC   findDMAchannel_SBpro
LOCALVAR   _BYTE channel

        ENTERPROC
	mov	[channel],al
	add	al,4
	out	0Ah,al			; Break on
	mov	al,0
	out	0Ch,al			; Reset counter
	mov	al,48h
	add	al,[channel]
	out	0Bh,al			; DMA -> DSP (output)
	mov	dx,87h
        cmp     [byte channel],0
	je	@@10
	mov	dx,83h
        cmp     [byte channel],1
	je	@@10
	mov	dx,82h			; Channel is 3
@@10:
	mov	al,0
	out	dx,al			; page 0
	mov	dl,[channel]
	shl	dx,1
	mov	al,0
	out	dx,al			; offset 0
	mov	al,0
	out	dx,al			; whole address is 0000:0000
	inc	dx
	mov	al,10
	out	dx,al			; count = 10
	mov	al,0
	out	dx,al
	mov	al,[channel]
	out	0Ah,al			; Break off

	mov	cx,0FFFFh		; Big loop
	mov	[dmaIRQ],0		; Clear interrupt value
@@loop:
	cmp	[dmaIRQ],0		; Wait dmaIRQ to change
	loope	@@loop			; loop if it doesn't

	mov	al,[channel]
	add	al,4
	out	0Ah,al			; Break on
	mov	al,0
	out	0Ch,al			; Reset counter
	mov	al,[channel]
	out	0Ah,al			; Break off

	sub	ax,ax
	cmp	[dmaIRQ],0
	je	@@exit
	inc	ah			; Indicate success
	mov	al,[channel]
@@exit:
        LEAVEPROC
	ret
ENDP

;/*************************************************************************
; *
; *	Function    : 	DMAint_SB
; *
; *	Description :	Interrupt function that determines SB's interrupt
; *
; ************************************************************************/

PROC    DMAint_SB

DMA2:
	PUSHDS
	push	ax
        mov     ax,DGROUP
	mov	ds,ax
	mov	[dmaIRQ],2               ; Set interrupt number
	jmp	short @@DMAdone
DMA3:
	PUSHDS
	push	ax
        mov     ax,DGROUP
	mov	ds,ax
	mov	[dmaIRQ],3
	jmp	short @@DMAdone
DMA5:
	PUSHDS
	push	ax
        mov     ax,DGROUP
	mov	ds,ax
	mov	[dmaIRQ],5
	jmp	short @@DMAdone
DMA7:
	PUSHDS
	push	ax
        mov     ax,DGROUP
	mov	ds,ax
	mov	[dmaIRQ],7
	jmp	short @@DMAdone
DMA10:
	PUSHDS
	push	ax
        mov     ax,DGROUP
	mov	ds,ax
	mov	[dmaIRQ],10
	mov	al,20h
	out	0A0h,al
@@DMAdone:
	mov	al,20h
	out	20h,al			; EOI (end of interrupt)
	pop	ax
	POPDS
	iret
ENDP

;/*************************************************************************
; *
; *	Function    :	int detectSB(SOUNDCARD *sCard);
; *
; *	Description :	Checks for presence of SB.
; *
; *	Input	    :   sCard	= pointer to info structure
; *
; *	Returns     :	0  if succesful
; *			-1 on error (no card found)
; *
; ************************************************************************/

CPROC   detectSBHW @@scard
locvars _WORD retvalue,_word retrycount

        ENTERPROC di si
        LESDI   [@@sCard]
	mov	[WORD HIGH scardPtr],es
	mov	[WORD LOW scardPtr],di
	mov	ax,es
	or	ax,di			; Is sCard NULL?
	jz	@@nocopy
	mov	si,offset SoundBlaster
	mov	cx,SIZE CARDINFO	; Copy sound card info into buffer
	cld
	PUSHDS
	PUSHCS
	POPDS
	rep	movsb
	POPDS
        LESDI   [@@sCard]
@@nocopy:
        mov     [word retvalue],-1           ; Assume failure
	mov	dx,220h
	call	checkPort_SB
	jz	@@OK
	mov	dx,210h
	call	checkPort_SB		; Check for every possible I/O value
	jz	@@OK
	mov	dx,230h
	call	checkPort_SB
	jz	@@OK
	mov	dx,240h
	call	checkPort_SB
	jz	@@OK
	mov	dx,250h
	call	checkPort_SB
	jz	@@OK
	mov	dx,260h
	call	checkPort_SB
	jnz	@@exit			; No match found, error exit
@@OK:
	mov	[ESDI+CARDINFO.ioPort],dx	; ioPort is for internal use only

	PUSHES
	push	di
        ecall    findDMAIRQ_SB           ; Find DMA interrupt number
	pop	di
	POPES
	or	ax,ax			; 0 = error
	jz	@@exit
	mov	[ESDI+CARDINFO.DMAIRQ],al
	mov	[ESDI+CARDINFO.DMAChannel],1

        mov     [word retrycount],10
@@retry:
        dec     [word retrycount]
	jnz	@@continue
	mov	ax,0			; not found
	jmp	@@done
@@continue:
	mov	dx,[ESDI+CARDINFO.ioPort]
	add	dx,0Ch
	waitSB
	mov	al,0E1h			; Read version number
	out	dx,al

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
	mov	[ESDI+CARDINFO.ver],ax
        mov     [word retvalue],0
@@exit:
	mov	ax,[retvalue]		; Return with 'retvalue'
        LEAVEPROC di si
	ret
ENDP

;/*************************************************************************
; *
; *     Function    :   int detectSBProHW(CARDINFO *sCard);
; *
; *	Description :	Checks for presence of SB Pro.
; *
; *	Input	    :   sCard	= pointer to info structure
; *
; *	Returns     :	0  if succesful
; *			-1 on error (no card found)
; *
; ************************************************************************/

CPROC   detectSBProHW @@sCard
locvars _WORD retvalue,_word retrycount

        ENTERPROC di si

        LESDI   [@@sCard]
	mov	[WORD HIGH scardPtr],es
	mov	[WORD LOW scardPtr],di
	mov	ax,es
	or	ax,di			; Is sCard NULL?
	jz	@@nocopy
	mov	si,offset SoundBlasterPro
	mov	cx,SIZE CARDINFO	; Copy sound card info into buffer
	cld
	PUSHDS
	PUSHCS
	POPDS
	rep	movsb
	POPDS
        LESDI   [@@sCard]
@@nocopy:
        mov     [word retvalue],-1           ; Assume failure
	mov	dx,220h
	call	checkPort_SB		; Check for every possible I/O value
	jz	@@OK
	mov	dx,240h
	call	checkPort_SB
	jnz	@@exit			; No match found, error exit
@@OK:
	mov	[ESDI+CARDINFO.ioPort],dx	; ioPort is for internal use only

        mov     [word retrycount],10
@@retry:
        dec     [word retrycount]
	jnz	@@continue
	mov	ax,0			; not found
	jmp	@@done
@@continue:
	mov	dx,[ESDI+CARDINFO.ioPort]
	add	dx,0Ch
	waitSB
	mov	al,0E1h			; Read version number
	out	dx,al

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
	mov	[ESDI+CARDINFO.ver],ax
	cmp	ax,0300h
	jl	@@exit			; Not SBpro

	PUSHES
	push	di
        ecall   findDMAIRQ_SBpro        ; Find DMA interrupt number
	pop	di
	POPES
	or	ax,ax			; 0 = error
	jz	@@exit
	mov	[ESDI+CARDINFO.DMAIRQ],al

        mov     [word retvalue],0
@@exit:
	mov	ax,[retvalue]		; Return with 'retvalue'
        LEAVEPROC di si
	ret
ENDP

ENDS

END
