;/************************************************************************
; *
; *	File        : CPU.ASM
; *
; *	Description : Identifies the type of CPU
; *
; *	Copyright (C) 1994 Otto Chrons
; *
; ************************************************************************/

	IDEAL
	P486                            ; Allow 486 commands

	include "MODEL.INC"

CSEGMENTS CPU

CCODESEG CPU

	CPUBLIC		getCPUType

CPROC	getCPUType

	pushf
	push	bx
	push	cx
	pushf
	pop	ax
	and	ax,0fffh
	push	ax
	popf
	pushf
	pop	ax
	and	ax,0f000h
	cmp	ax,0f000h
	jne	cpu1
	mov	ax,00h			; CPU = 8086
	jmp	cpux
cpu1:
	or	ax,0f000h
	push	ax
	popf
	pushf
	pop	ax
	and	ax,0f000h
	jnz	cpu2
	mov	ax,01h			; CPU = 80286
	jmp	cpux
cpu2:
	mov	bx,sp
	and	sp,not 3
	pushfd
	pop	eax
	mov	ecx,eax
	xor	eax,40000h
	push	eax
	popfd
	pushfd
	pop	eax
	mov	sp,bx
	xor	eax,ecx
	jnz	cpu3
	mov	ax,03h                  ; CPU = 80386
	jmp	cpux
cpu3:
	mov	ax,07h			; CPU = 80486

cpux:
	pop	cx
	pop	bx
	popf
	ret
ENDP

ENDS

END
