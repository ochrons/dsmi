;   /*\
;---|*|----====< GetHW >====----
;---|*|
;---|*| Get the Pro Audio hardware device configuration, etc.
;---|*|
;   \*/

	ideal
        include "mcp.inc"
	quirks
	masm51
	include masm.inc
	include model.inc
        include "common.inc"
        include "target.inc"
	ideal
IFDEF	L_PASCAL
	LANG	EQU	PASCAL
	MODEL TPASCAL
ELSE
	LANG	EQU	C
	MODEL LARGE,C
ENDIF
;
;   /*\
;---|*|--------------------------==================--------------------------
;---|*|
;---|*|    The Pro AudioSpectrum Plus, Pro AudioSpectrum 16 and CDPC
;---|*|    all support relocatable I/O.  PAS hardware must occupy four
;---|*|    contiguous I/O locations.  All I/O accesses use those four addresses
;---|*|    and their 'harmonic' addresses.  Harmonic addresses are those
;---|*|    addresses that under normal circumstance would decode to the same
;---|*|    contiguous four I/O locations.  For example, harmonic addresses of
;---|*|    port 388h would include 788h, 1388h, 1788h, 1f88h, etc.
;---|*|
;---|*|    Most hardware will not conflict with the default address range of
;---|*|    388h-38Bh.  This address range is based on the I/O locations
;---|*|    chosen by Adlib and this range is supposed to be reserved for
;---|*|    SDLC or 2nd Bisynchronous communications hardware.  It has been
;---|*|    reported that an ISDN card decodes to this range also.  More
;---|*|    importantly, if a customer wants to have multiple sound cards
;---|*|    co-resident in his system, we must provide a means of relocating
;---|*|    the I/O range.
;---|*|
;---|*|    Media Vision's I/O relocation capability is software selectable to
;---|*|    any ONE of 64 4-address locations.  The possible locations are
;---|*|    depicted below:
;---|*|
;---|*| 	0     2     4	  6	8     A     C	  E
;---|*|
;---|*|   200h	|<------------- game control------------------->|
;---|*|
;---|*|   210h	|<-- expansion unit -->|	    |		|
;---|*|
;---|*|   220h	|<---- Sound Blaster decode #1 ---------------->|
;---|*|
;---|*|   230h	|<---- Sound Blaster decode #2 ---------------->|
;---|*|
;---|*|   240h	|<---- Sound Blaster decode #3 ---------------->|
;---|*|
;---|*|   250h	|<---PAS--->|<---PAS--->|<---PAS--->|<---PAS--->|
;---|*|
;---|*|   260h	|<---PAS--->|<---PAS--->|<---PAS--->|<---PAS--->|
;---|*|
;---|*|   270h	|<---PAS--->|	      |<--3rd Parallel Printer->|
;---|*|
;---|*|   280h	|<---PAS--->|<---PAS--->|<---PAS--->|<---PAS--->|
;---|*|
;---|*|   290h	|<---PAS--->|<---PAS--->|<---PAS--->|<---PAS--->|
;---|*|
;---|*|   2A0h	|<---PAS--->|<---PAS--->|<---PAS--->|<---PAS--->|
;---|*|
;---|*|   2B0h	|<---PAS--->|<---PAS--->|<---PAS--->|<---PAS--->|
;---|*|
;---|*|   2C0h	|<---PAS--->|<---PAS--->|<---PAS--->|<---PAS--->|
;---|*|
;---|*|   2D0h	|<-----------	 3270	 PC	--------------->|
;---|*|
;---|*|   2E0h	|<---PAS--->|<---PAS--->|<---PAS--->|<---PAS--->|
;---|*|
;---|*|   2F0h	|<----- reserved ------>|<-Async comm. 2 ------.|
;---|*|
;---|*| 	0     2     4	  6	8     A     C	  E
;---|*|
;---|*|   300h	|<401---------- Prototype card ---------------->|
;---|*|
;---|*|   310h	|<401---------- Prototype card ---------------->|
;---|*|
;---|*|   320h	|<401----------    hard disk   ---------------->|
;---|*|
;---|*|   330h	|<401---XT/3270-------->|<---PAS--->|<---PAS--->|
;---|*|
;---|*|   340h	|<401, PAS->|<---PAS--->|<---PAS--->|<---PAS--->|
;---|*|
;---|*|   350h	|<401, PAS->|<---PAS--->|<---PAS--->|<---PAS--->|
;---|*|
;---|*|   360h	|<401, PAS->|<---PAS--->|<---PAS--->|<---PAS--->|
;---|*|
;---|*|   370h	|<401, PAS->|	      |<--2nd Parallel Printer->|
;---|*|
;---|*|   380h	|<401, PAS->|<---PAS--->|<---PAS--->|<---PAS--->|
;---|*|
;---|*|   390h	|<401, PAS->|<---PAS--->|<---PAS--->|<---PAS--->|
;---|*|
;---|*|   3A0h	|<401, PAS->|<---PAS--->|<---PAS--->|<---PAS--->|
;---|*|
;---|*|   3B0h	|<401, Monochrome Display and Parallel 1  ----->|
;---|*|
;---|*|   3C0h	|<401, ------------ VGA   --------------------->|
;---|*|
;---|*|   3D0h	|<401,-------	 3270	 PC	--------------->|
;---|*|
;---|*|   3E0h	|<401,	reserved ------>|<---- COM 3 serial---->|
;---|*|
;---|*|   3F0h	|<401,	 Disk	 ------>|<-- Asych comm. 1 ---->|
;---|*|
;---|*|
;---|*|
;---|*|   Note: 401 indicates one of the possible locations of the
;---|*| 	MPU-401 MIDI interface.  It decodes at 3x0 - 3x1 where
;---|*| 	x is an element of {0,1,2,3,4,5,6,7,8,9,a,b,c d,e,f}
;---|*|
;---|*| 	SoundBlaster decode range is 2x0 thru 2xf where x is
;---|*| 	an element of {2,3,4}
;---|*|
;---|*|
;---|*|   It requires very little effort to support the relocation of
;---|*|   the hardware if the routines provided here are used.	Once
;---|*|   the Pro AudioSpectrum chip has been located, any I/O address
;---|*|   can be relocated by XOR-ing the address (usually contained in)
;---|*|   the DX register) with a 16-bit variable.
;---|*|
;   \*/
;

;
;---------------------------========================---------------------------
;---------------------------====< DATA SECTION >====---------------------------
;---------------------------========================---------------------------
;
	dataseg


	ID	dw ?
	DMA	db ?
	IRQ	db ?
	basea	dw ?

;
; The board base address for the original PAS card was based at 388. This will
; be XORed to the new address to derive a translation code. This code can be
; XORed back into any original PAS address resulting in the true card address.
;

VERSION_PAS             equ     0       ; Pro Audio Spectrum
VERSION_PASPLUS 	equ	1	; Pro Audio Plus card
VERSION_PAS16		equ	2	; Pro Audio 16 card
VERSION_CDPC		equ	3	; CDPC card & unit


;
; The following equates build up a mask of bits that we do wish to keep
; when comparing feature bits. The zero bits can be ignored, whereas, the
; the 1 bits must match.
;

PASdocare	equ	<(bMVA508 OR bMVDAC16 OR bMVOPL3 OR bMV101 )>
PASPLUSdocare	equ	<(bMVA508 OR bMVDAC16 OR bMVOPL3 OR bMV101 )>
PAS16docare	equ	<(bMVA508 OR bMVDAC16 OR bMVOPL3 OR bMV101 )>
CDPCdocare	equ	<(bMVA508 OR bMVDAC16 OR bMVOPL3 OR bMV101 )>

;

;
;---------------------------========================---------------------------
;---------------------------====< CODE SECTION >====---------------------------
;---------------------------========================---------------------------
;
	codeseg

	copyrightText	DB "PAS-DETECT v1.0 - (C) 1993 Otto Chrons",0,1Ah
	PASnorm		CARDINFO <3,0,"Pro Audio Spectrum",388h,0,0,3000,44100,0,1,1>
	PASplus		CARDINFO <4,0,"Pro Audio Spectrum+",388h,0,0,3000,44100,1,1,1>
	PAS16		CARDINFO <5,0,"Pro Audio Spectrum 16",388h,0,0,3000,44100,1,1,2>

	label	ProductIDTable	word
	dw	PRODUCT_PROAUDIO and PASdocare
	dw	PRODUCT_PROPLUS  and PASPLUSdocare
	dw	PRODUCT_PRO16	 and PAS16docare
	dw	PRODUCT_CDPC	 and CDPCdocare
	dw	-1
;
	label	DoCareBits	word
	dw	PASdocare
	dw	PASPLUSdocare
	dw	PAS16docare
	dw	CDPCdocare
	dw	-1				; table terminator

proc	SearchHWVersion NEAR scard:FAR PTR CARDINFO
	push	si			; save the C criticals
	push	di
;
; calculate the translation code
;
	xor	di,DEFAULT_BASE 	; di holds the translation code

ifndef NOINT2F
	mov	ax,0BC00H		; make sure MVSOUND.SYS is loaded
	mov	bx,'??'                 ; this is our way of knowing if the
	xor	cx,cx			; hardware is actually present.
	xor	dx,dx
	int	2fh			; get the ID pattern
	xor	bx,cx			; build the result
	xor	bx,dx
	cmp	bx,'MV'                 ; if not here, exit...
	jnz	sehw_bad
;
; get the MVSOUND.SYS specified DMA and IRQ channel
;
	mov     ax,0bc04h               ; get the DMA and IRQ numbers
	int	2fh
	mov	[DMA],bl
	mov	[IRQ],cl
endif

;
; grab the version # in the interrupt mask. The top few bits hold the version #
;
        mov     dx,INTRCTLR             ; board ID is in MSB 3 bits
	xor	dx,di			; adjust to other address
	in	al,dx
	cmp	al,-1			; bus float meaning not present?
	je	sehw_bad		; yes, there is no card here

	mov	ah,al			; save an original copy
	xor	al,fICrevbits		; the top bits wont change

	out	dx,al			; send out the inverted bits
	jmp	$+2
	jmp	$+2
	in	al,dx			; get it back...

	cmp	al,ah			; both should match now...
	xchg	al,ah			; (restore without touching the flags)
	out	dx,al

	jnz	sehw_bad		; we have a bad board

	and     ax,fICrevbits           ; isolate the ID bits & clear AH
	mov	cl,fICrevshr		; shift the bits into a meaningful
	shr	al,cl			; position (least signficant bits)
	mov	si,ax			; save the version #
;
; We do have hardware! Load the product bit definitions
;
	sub	bx,bx
	mov	cx,bMVSCSI		; setup bx:cx for the original PAS

	or      al,al                   ; is this the first version of h/w?
	jz	sehw_done		; yes, simple exit will do.

	call	FindBits		; load all the rest of the h/w bits
;
sehw_done:
;
; loop on a table search to find identify the board
;
	push	bx			; save this high bits
	mov	bx,-2
    ;
    sehw_05:
	add	bx,2
	cmp	[ProductIDTable+bx],-1	; at the end of the table?
	jz	sehw_bad_hw		; yes, we can't identify this board
	mov	dx,cx			; dx holds the product bits
	and	dx,[DoCareBits+bx]	; keep the bits we care about
	cmp	dx,[ProductIDTable+bx]	; do these bits match a product?
	jnz	sehw_05 		; no, keep looking

	mov	dx,bx
	shr	dx,1			; make word index a byte index
	pop	bx

	mov	ax,si			; load the h/w version #
	sub	ah,ah			; for our purposes, we will return SCSI
	xchg	ah,al			; into ah
	clc                             ; The board was identified !

	jmp	short sehw_exit
;
sehw_bad_hw:
	pop	bx			; flush the stack
	mov	ax,-2
	cwd
	stc
	jmp	short sehw_exit
;
sehw_bad:
	mov	ax,-1			; we got here due to a bad board
	cwd
	stc
;
sehw_exit:
	pop	di
	pop	si
	ret

endp

;
;   /*\
;---|*|----====< long mvGetHWVersion() >====----
;---|*|
;---|*| Detects and identifies the installed Pro AudioSpectrum.
;---|*|
;---|*| Entry Conditions:
;---|*|     word address containing the base address.
;---|*|
;---|*| Exit Conditions:
;---|*|     DX:AX = -1, the hardware is not installed.
;---|*|     DX:AX = -2, some type of hardware is installed - can't ID it.
;---|*|     DX	  = Product ID
;---|*|     AH	  = PAS hardware version
;---|*|     AL	  = SCSI, or MITSUMI CD-ROM interface installed.
;---|*|     BX:CX = the bit fields that identify the board
;---|*|     Carry is set on error
;---|*|
;   \*/

	public	detectMV

proc	detectMV scard:DWORD

	push	si			; save the C criticals
	push	di
;
; calculate the translation code
;

    ; search the default address

	mov     di,DEFAULT_BASE         ; try the first address
        mov	[basea],di
	call	SearchHWVersion LANG,[scard]
	cmp	dx,-1			; found?
	jnz	mvgehw_exit		; yes, exit now...

    ; search the first alternate address

	mov	di,ALT_BASE_1		; try the first alternate
	mov	[basea],di
	call	SearchHWVersion LANG,[scard]
	cmp	dx,-1			; found?
	jnz	mvgehw_exit		; yes, exit now...

    ; search the second alternate address

	mov	di,ALT_BASE_2		; try the second alternate
	mov	[basea],di
	call	SearchHWVersion LANG,[scard]
	cmp	dx,-1			; found?
	jnz	mvgehw_exit		; yes, exit now...

    ; search the third, or user requested alternate address

	mov	di,ALT_BASE_3		; try the third alternate
	mov	[basea],di
	call	SearchHWVersion LANG,[scard]
	cmp	dx,-1
	jne 	mvgehw_exit
	mov	ax,-1
	jmp	@@exitok
mvgehw_exit:
	les	di,[scard]
	mov	si,-1
	push	ds
	push	cs
	pop	ds
	cmp	dx,0
	jne	notNorm
	mov	si,offset PASnorm
notNorm:
	cmp	dx,1
	jne	notPlus
	mov	si,offset PASplus
notPlus:
	cmp	dx,2
	jne	not16
	mov	si,offset PAS16
not16:
	cmp	si,-1
	jne	cardok
	pop	ds
	mov	ax,-1
	jmp	@@exitok
cardok:
	mov	cx,SIZE CARDINFO
	cld
	rep	movsb
	pop	ds
	les	di,[scard]
	mov	al,[DMA]
	mov	[es:di+CARDINFO.DMAchannel],al
	mov	al,[IRQ]
	mov	[es:di+CARDINFO.DMAIRQ],al
	mov	ax,[basea]
	mov	[es:di+CARDINFO.ioPort],ax
	sub	ax,ax
@@exitok:
	pop	di
	pop	si
	ret
endp

;
;   /*\
;---|*|----====< SearchHWVersion >====----
;---|*|
;---|*| Given a specific I/O address, this routine will see if the
;---|*| hardware exists at this address.
;---|*|
;---|*| Entry Conditions:
;---|*|     DI holds the I/O address to test
;---|*|     BX:CX = bMVSCSI
;---|*|
;---|*| Exit Conditions:
;---|*|     BX:CX = the bit fields that identify the board
;---|*|
;   \*/
;
;
;   /*\
;---|*|----====< FindBit >====----
;---|*|
;---|*| Checks the installed hardware for all the feature bits.
;---|*|
;---|*| Entry Conditions:
;---|*|     DI holds the I/O address translation code
;---|*|     BX:CX = bMVSCSI
;---|*|
;---|*| Exit Conditions:
;---|*|     BX:CX = the bit fields that identify the board
;---|*|
;   \*/
;

proc	FindBits        near
;
masm
quirks

; All second generation Pro Audio cards use the MV101 and have SB emulation.
;
	or	cx,bMVSBEMUL+bMV101	; force SB emulation
;
; determine if the enhanced SCSI interface is present
;
	mov     dx,ENHANCEDSCSI         ; test for SCSI mod (U48)
	xor	dx,di			; modify via the translate code

	out	dx,al			; strobe
	jmp	$+2				; I/O bus delay
	in	al,dx			; get the bit

	and	al,1			; bit0==1 means old SCSI PAL
	cmp	al,1			; reverse sense
	sbb	ax,ax			; ax = ffff if enhanced SCSI
	and	ax,bMVENHSCSI		; save the bit
	or	cx,ax			; merge it in
;
; determine AT/PS2, CDPC slave mode
;
	mov	dx,MASTERMODRD		; check for the CDPC
	xor     dx,di                   ; modify via the translate code

	in      al,dx
	test	al,bMMRDatps2		; AT(1) or PS2(0)
	jnz	@F
	or	cx,bMVPS2
    ;
    @@:
	test	al,bMMRDmsmd		; Master(0) or Slave(1)
	jz	@F
	or	cx,bMVSLAVE
    ;
    @@:
	push	cx			; move the revision bits

	mov	dx,MASTERCHIPR
	xor	dx,di

	.errnz	bMV101_REV-(000Fh SHL 11)

	in	al,dx			; get the low 4 bits of the chip rev
	and	ax,000Fh		; into ah
	mov	cl,11			; FROM 0000 0000 0000 1111b
	shl	ax,cl			; TO   0111 1000 0000 0000b

        pop     cx
        or      cx,ax                   ; merge in the bits
;
; determine the CDROM drive type, FM chip, 8/16 bit DAC, and mixer
;
	mov	dx,SLAVEMODRD		; check for the CDPC
        xor     dx,di                   ; modify via the translate code
	in	al,dx

        test    al,bSMRDdactyp          ; 16 bit DAC?
	jz	@F			; no, its an 8 bit DAC
	or	cx,bMVDAC16		; its a 16 bit DAC
    ;
    @@:
	test	al,bSMRDfmtyp		; OPL3 chip?
	jz	@F			; no, so it's the PAS16 card
	or	cx,bMVOPL3		; is an OPL3
    ;
    @@:
	mov	dx,cx			; inference check for new mixer
	and	dx,bMVSLAVE+bMVDAC16	; Slave & 16 bit dac is the CDPC
	cmp	dx,bMVDAC16		; 16 bit DAC on master?
	jnz	@F			; no, it's the CDPC with Nation mixer
	or	cx,bMVA508
    ;
    @@:
	and	al,bSMRDdrvtyp		; isolate the CDROM drive type
	cmp	al,2			; Sony 535 interface?
	jnz	@F			; no, continue on...
	and	cx,NOT (bMVSCSI+bMVENHSCSI) ; yes, flush the SCSI bits
	or	cx,bMVSONY		    ; set the 535 bit
    ;
    @@:
;
; determine if MPU-401 emulation is active
;
        mov     dx,COMPATREGE           ; compatibility register
	xor	dx,di			; modify via translate code
	in	al,dx
	test	al,cpMPUEmulation
	jz	@F
	or	cx,bMVMPUEMUL
    ;
    @@:
	ret

endp

	end

