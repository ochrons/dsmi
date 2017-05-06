; /***********************************************************************
; *
; *     File        : DETSB16H.ASM
; *
; *     Description : Sound Blaster 16 hardware detection routines
; *
; *     Copyright (C) 1992,1994 Otto Chrons
; *
; ************************************************************************
;
;       Revision history of DETSB16H.ASM
;
;       1.0     2.4.94
;               Detects SB16 using information found in mixer registers
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

CSEGMENTS DETSB16H

CDATASEG
	dmaIRQ		DB ?
	scardPtr	DD ?
ENDS

CCODESEG DETSB16H

        CPUBLIC detectSB16HW

        copyrightText   DB "SB16-DETECT v1.0 - (C) 1994 Otto Chrons",0,1Ah
	SoundBlaster16	CARDINFO <6,0,"Sound Blaster 16 ASP",220h,5,5,4000,44100,1,1,2>

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
; *	Function    : 	findDMAIRQ_SB16
; *
; *	Description :	Finds SB16's DMA interrupt number
; *
; *	Returns     :	AX = 0	error
; *			AX = IRQ number (2,5,7,10)
; *
; ************************************************************************/

CPROC   findDMAIRQ_SB16

        ENTERPROC _di _si
	LESDI	[scardPtr]
	mov	dx,[ESDI+CARDINFO.ioPort]
	add	dx,4			; Access mixer
	mov	al,80h			; Read IRQ
	out	dx,al
	inc	dx
	in	al,dx
	mov	cl,2			; Assume 2
	test	al,0001b
	jnz	@@found
	mov	cl,5
	test	al,0010b
	jnz	@@found
	mov	cl,7
	test	al,0100b
	jnz	@@found
	mov	cl,10
@@found:

	dec	dx
	mov	al,81h			; Read DMA channel
	out	dx,al
	inc	dx
	in	al,dx
	mov	ch,5
	test	al,00100000b		; Is it DMA 5?
	jnz	@@foundDMA
	mov	ch,6
	test	al,01000000b
	jnz	@@foundDMA
	mov	ch,7
	test	al,10000000b
	jnz	@@foundDMA
	mov	ch,3
	test	al,00000100b
	jnz	@@foundDMA
	mov	ch,0
	test	al,00000001b
	jnz	@@foundDMA
	mov	ch,1
@@foundDMA:
	mov	[ESDI+CARDINFO.DMAChannel],ch
	mov	al,cl			; Return IRQ in AX
	sub	ah,ah
        LEAVEPROC _di _si
	ret
ENDP

;/*************************************************************************
; *
; *     Function    :   int detectSB16HW(CARDINFO *sCard);
; *
; *	Description :	Checks for presence of SB 16 ASP.
; *
; *	Input	    :   sCard	= pointer to info structure
; *
; *	Returns     :	0  if succesful
; *			-1 on error (no card found)
; *
; ************************************************************************/

CPROC   detectSB16HW @@sCard
locvars _word retvalue,_word retrycount

        ENTERPROC       _di _si

        LESDI   [@@sCard]
IFDEF __32__
        mov     [scardPtr],edi
        test    edi,edi                 ; Is sCard NULL?
ELSE
	mov	[WORD HIGH scardPtr],es
	mov	[WORD LOW scardPtr],di
	mov	ax,es
	or	ax,di			; Is sCard NULL?
ENDIF
        jz      @@nocopy
        mov     _si,offset SoundBlaster16
        mov     _cx,SIZE CARDINFO        ; Copy sound card info into buffer
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
	call	checkPort_SB		; Check for every possible I/O value
	jz	@@OK
	mov	dx,260h
	call	checkPort_SB		; Check for every possible I/O value
	jz	@@OK
	mov	dx,280h
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
	cmp	ax,0400h
	jl	@@exit			; Not SB16

	PUSHES
        push    _di
        ecall   findDMAIRQ_SB16         ; Find DMA interrupt number
        pop     _di
	POPES
	or	ax,ax			; 0 = error
	jz	@@exit
	mov	[ESDI+CARDINFO.DMAIRQ],al

        mov     [word retvalue],0
@@exit:
        mov     ax,[retvalue]           ; Return with 'retvalue'
        LEAVEPROC _di _si
	ret
ENDP

ENDS

END
