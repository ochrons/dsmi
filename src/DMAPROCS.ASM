;* DMAPROCS.ASM         DMA routines for DSMI
;*
;* Copyright 1994 Otto Chrons
;*
;* First revision 02-14-94 02:10:34pm
;*
;* Revision history:
;*
;*


        IDEAL
        P386N

        INCLUDE "MODEL.INC"

CSEGMENTS DMAPROCS

STRUC   DMAPORT

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

CDATASEG
        DMApage         DB ?
	DMAoffset	DW ?
        DMAchannel      DB ?
        curDMA          DMAPORT <>

IFDEF __PASCAL__
        EXTRN   bufferSize:WORD
        EXTRN   dataBuf:WORD
ELSE
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

ENDS

CCODESEG DMAPROCS

        CPUBLIC dmaInit, dmaStart, dmaStop, dmaClose, dmaGetPos

        LABEL DMAports  DMAPORT

	    DMAPORT <0,1,87h,8,9,0Ah,0Bh,0Ch,0Dh,0Eh,0Fh>
	    DMAPORT <2,3,83h,8,9,0Ah,0Bh,0Ch,0Dh,0Eh,0Fh>
	    DMAPORT <4,5,81h,8,9,0Ah,0Bh,0Ch,0Dh,0Eh,0Fh>
	    DMAPORT <6,7,82h,8,9,0Ah,0Bh,0Ch,0Dh,0Eh,0Fh>
	    DMAPORT <0,0,0,0,0,0,0,0,0,0,0>
	    DMAPORT <0C4h,0C6h,8Bh,0D0h,0D2h,0D4h,0D6h,0D8h,0DAh,0DCH,0DEh>
	    DMAPORT <0C8h,0CAh,89h,0D0h,0D2h,0D4h,0D6h,0D8h,0DAh,0DCH,0DEh>
	    DMAPORT <0CCh,0CEh,8Ah,0D0h,0D2h,0D4h,0D6h,0D8h,0DAh,0DCH,0DEh>

;/***************************************************************************\
;*
;* Function:    dmaInit
;*
;* Description: Initializes DMA counter and physical address
;*
;* Input:       buffer
;*              physical address
;*              maximum size
;*              required size
;*
;\***************************************************************************/

CPROC   dmaInit @@DMAchannel,@@buffer,@@physical,@@maxSize,@@required

        ENTERPROC _si _di
        mov     ebx,[@@DMAchannel]
        mov     [DMAchannel],bl         ; Save DMA channel value
        imul    _bx,_bx,SIZE DMAPORT
        lea     _si,[_bx+DMAports]       ; SI = DMAports[DMAchannel]
        PUSHDS
        POPES
        mov     _di,offset curDMA        ; ES:DI = curDMA
        mov     _cx,SIZE DMAPORT
IF16    cli
IF16    segcs
	rep	movsb			; Copy information
IF16    sti

        mov     ecx,[@@maxSize]
        mov     [bufferSize],_cx
IF16    <mov    bx,[WORD LOW @@buffer]>
IF32    <mov    ebx,[@@buffer]>
        add     _bx,3
        and     _bx,NOT 3
        mov     [dataBuf],_bx           ; Check if DMA buffers are on
        mov     eax,[@@physical]        ; a segment boundary
	add	eax,3
	and	eax,NOT 3
	neg	ax
	cmp	ax,cx			; Is buffer size >= data size
	ja	@@bufOK
	dec	ax
	and	ax,NOT 3
        movzx   eax,ax
        mov     [bufferSize],_ax
	shr	cx,1
	cmp	ax,cx			; Is it even half of it?
	ja	@@bufOK
	shl	cx,1
        movzx   eax,ax
        add     [dataBuf],_ax
	add	[dataBuf],7
	and	[dataBuf],NOT 3
	neg	ax
	add	ax,cx			; AX = dataSize - AX
	sub	ax,32
	and	ax,NOT 3
        movzx   eax,ax
        mov     [bufferSize],_ax
@@bufOK:
        movzx   eax,ax
        cmp     [DWORD @@required],0
	je	@@sizeok
        cmp     eax,[@@required]
	jbe	@@sizeok
        mov     eax,[@@required]
        mov     [bufferSize],_ax
@@sizeok:
	and	[bufferSize],NOT 3
	sub	ebx,ebx
        mov     eax,[@@physical]            ; Calculate DMA page and offset values
        mov     _bx,[dataBuf]

IF16    <sub    bx,[WORD LOW @@buffer]>    ; Relative offset
IF32    <sub    ebx,[@@buffer]>
	add	eax,ebx
	mov	ebx,eax
	shr	ebx,16
        cmp     [DMAChannel],4
	jb	@@8bitDMA
	push	bx
	shr	bl,1
	rcr	ax,1			; For word addressing
	pop	bx
@@8bitDMA:
	mov	[DMApage],bl
	mov	[DMAoffset],ax

        LEAVEPROC _si _di
        ret
ENDP

;/***************************************************************************\
;*
;* Function:    dmaStart
;*
;* Description: Starts DMA transfer
;*
;* Input:       (E)CX = buffersize
;*
;\***************************************************************************/

CPROC   dmaStart @@mode

        ENTERPROC
        mov     ah,[DMApage]            ; Load correct DMA page and offset
	mov	bx,[DMAoffset]		; values
        cmp     [DMAchannel],4
	jb	@@bufByte
        shr     _cx,1                   ; Word count for 16-bit DMA
@@bufByte:
        dec     _cx
	cli				; Set the DMA up and running
        mov     al,[DMAChannel]
	or	al,4
	mov	dx,[curDMA.wrsmr]
	out	dx,al			; Break On
        mov     al,[DMAChannel]
	and	al,3
        or      al,[byte @@mode]        ; DMA mode (normally 58h, autoinit)
        mov     dx,[curDMA.wrmode]
	out	dx,al
	mov	dx,[curDMA.page]
	mov	al,ah
	out	dx,al			; Page
	mov	al,0FFh
	mov	dx,[curDMA.clear]
	out	dx,al			; Reset counter

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
        mov     al,[DMAChannel]
	and	al,3
	mov	dx,[curDMA.wrsmr]
        out     dx,al                   ; Break Off, starts transfer
	sti
        LEAVEPROC
        ret
ENDP

;/***************************************************************************\
;*
;* Function:    dmaGetPos
;*
;* Description: Returns current DMA position
;*
;* Returns:     AX = position
;*
;\***************************************************************************/

CPROC   dmaGetPos
        cli
@@05:
	mov	al,0FFh
	mov	dx,[curDMA.clear]
	out	dx,al
	mov	dx,[curDMA.count]
	in	al,dx
	mov	ah,al
	in	al,dx
	xchg	ah,al
	mov	bx,ax
	in	al,dx
	mov	ah,al
	in	al,dx
	xchg	ah,al
	sub	bx,ax
	cmp	bx,64
	jg	@@05
	cmp	bx,-64
	jl	@@05
	neg	ax
        cmp     [DMAChannel],4
	jb	@@dma8
	shl	ax,1			; 16-bit to 8-bit
@@dma8:
        and     _ax,0FFFFh
        sti
        ret
ENDP

;/***************************************************************************\
;*
;* Function:    dmaStop
;*
;* Description: Stops DMA transfer
;*
;\***************************************************************************/

CPROC   dmaStop

        mov     al,[DMAChannel]         ; Reset DMA
	or	al,4
	mov	dx,[curDMA.wrsmr]
	out	dx,al
	mov	al,0
	mov	dx,[curDMA.clear]
	out	dx,al
        ret
ENDP

;/***************************************************************************\
;*
;* Function:    dmaClose
;*
;* Description: Closes DMA and stops transfer
;*
;\***************************************************************************/

CPROC   dmaClose

        ecall   dmaStop
        ret
ENDP

ENDS

END
