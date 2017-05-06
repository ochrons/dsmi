;/************************************************************************
; *
; *	File        : EMSHARD.ASM
; *
; *	Description : EMS low-level functions for EMSHM
; *
; *	Copyright (C) 1993 Otto Chrons
; *
; ***********************************************************************/

	IDEAL
	JUMPS
	P286

;	L_PASCAL	= 1		; Uncomment this for pascal-style

IFDEF	L_PASCAL
	LANG	EQU	PASCAL
	MODEL TPASCAL
ELSE
	LANG	EQU	C
	MODEL LARGE,C
ENDIF

MACRO	EMScall funct

	mov	ah,funct
	int	67h
ENDM

DATASEG

	pageFrame	DW ?
	status		DW ?
	handle		DW ?
	pageCount	DW ?

CODESEG

	PUBLIC	_emsInit, _emsAllocPages, _emsClose
	PUBLIC	_emsMapPages, _emsSaveState, _emsRestoreState, _emsQueryFree
	PUBLIC	_emsGetFrame, _emsMoveMem

;/*************************************************************************
; *
; *	Function    :	int _emsInit(void);
; *
; *	Description :	Initializes EMS handler
; *
; *	Returns     :	0 if success
; *			-1 no EMS handler
; *			-2 other error
; *
; ************************************************************************/

PROC	_emsInit FAR

	EMScall	40h			; Get status
	or	ah,ah
	jnz	@@error			; error

	EMScall	41h			; Get page frame address
	or	ah,ah
	jnz	@@error			; error
	mov	[pageFrame],bx

	EMScall	46h			; Version...
	cmp	al,40h			; is it 4.0 or above?
	jb	@@error

	mov	[handle],-1		; No handle
        mov	[pageCount],0
	mov	[status],1		; Status OK.
	sub	ax,ax			; No error
	jmp	@@exit
@@error:
	mov	ax,-2
@@exit:
	ret
ENDP

;/*************************************************************************
; *
; *	Function    :	int _emsAllocPages(int pages);
; *
; *	Description :	Allocates EMS memory
; *
; *	Input       :	pages = how many 16K pages to allocate
; *
; *	Returns     :	0 if successful
; *			-1 EMSHM not initialized
; *			-2 not enough memory
; *
; ************************************************************************/

PROC	_emsAllocPages FAR pages:WORD

	mov	al,-1
	cmp	[status],1		; Is EMSHM initialized
	jne	@@exit

	mov	bx,[pages]		; BX = pages
	or	bx,bx
	jz	@@exit

	mov	[pageCount],bx

	EMScall	43h			; Allocate...
	mov	al,-1
	or	ah,ah
	jnz	@@exit			; not enough memory??

	mov	[handle],dx		; Save handle
	mov	ax,dx
@@exit:
	ret
ENDP

;/*************************************************************************
; *
; *	Function    :	int _emsMapPages(int logical, int physical);
; *
; *	Description :	Maps logical pages into the physical region
; *
; *	Input       :	logical and physical pages
; *
; *	Returns     :	0 if successful
; *			-1 EMSHM not initialized
; *			-3 illegal logical page
; *
; ************************************************************************/

PROC	_emsMapPages FAR lpage:WORD,ppage:WORD

	mov	al,-1
	cmp	[status],1		; Is EMSHM initialized
	jne	@@exit

	mov	bx,[lpage]
	cmp	bx,[pageCount]		; Is logical page within range?
	mov	ax,-3
	jae	@@exit

	mov	ax,[ppage]		; AL = Physical page
	and	ax,3
	mov	dx,[handle]
	EMScall	44h			; Map memory

	sub	ax,ax
@@exit:
	ret
ENDP

;/*************************************************************************
; *
; *	Function    :	void _emsSaveState(void);
; *
; *	Description :	Saves EMM's state (in interrupt or so..)
; *
; ************************************************************************/

PROC	_emsSaveState FAR

	mov	dx,[handle]
	EMScall	47h

	ret
ENDP

;/*************************************************************************
; *
; *	Function    :	void _emsRestoresState(void);
; *
; *	Description :	Restores EMM's state (in interrupt or so..)
; *
; ************************************************************************/

PROC	_emsRestoreState FAR

	mov	dx,[handle]
	EMScall	48h

	ret
ENDP

;/*************************************************************************
; *
; *	Function    :	int _emsQueryFree(void);
; *
; *	Description :	Returns how many pages are available
; *
; *	Returns     :	Pages available
; *
; ************************************************************************/

PROC	_emsQueryFree FAR

	EMScall	42h			; Get unallocated pages
	or	ah,ah
	jnz	@@error
@@exit:
	mov	ax,bx			; AX = free pages
	ret
@@error:
	mov	ax,-1			; Error
	ret
ENDP

;/*************************************************************************
; *
; *	Function    :	void _emsClose(void);
; *
; *	Description :	Closes EMSHM and releases all EMS memory allocated
; *
; ************************************************************************/

PROC	_emsClose FAR

	mov	dx,[handle]
	EMScall	45h			; Deallocate all pages

	mov	[status],0		; EMSHM closed
	mov	[handle],-1

	ret
ENDP

;/*************************************************************************
; *
; *	Function    :	unsigned _emsGetFrame(void);
; *
; *	Description :	Returns EMS page frame address
; *
; *	Returns     :	Frame segment (i.e. C000h)
; *
; ************************************************************************/

PROC	_emsGetFrame FAR

	mov	ax,[pageFrame]

	ret
ENDP

;/*************************************************************************
; *
; *	Function    :	void _emsMoveMem(EMSMOVE *mm);
; *
; *	Description :	Moves memory between EMS and EMS or EMS and
; *			conventional memory.
; *
; *	Input       :	Pointer to EMSMOVE structure
; *
; ************************************************************************/

PROC	_emsMoveMem FAR USES ds si,mm:DWORD

	lds	si,[mm]
	mov	al,0
	EMScall	57h

	ret
ENDP


END
