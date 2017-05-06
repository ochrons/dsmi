;/************************************************************************
; *
; *     File        : DETPAS.ASM
; *
; *     Description : PAS detection routines for DSMI
; *
; *     Copyright (C) 1993 Otto Chrons
; *
; ***********************************************************************
;
;       Revision history of DETPAS.ASM
;
;       1.0     16.4.93
;               First version. Detects all PAS types.
;
; ***********************************************************************/

        IDEAL
        P386

        INCLUDE "MODEL.INC"

CSEGMENTS DETPAS

        include "mcp.inc"
        quirks
        masm51
        include masm.inc
        include common.inc
        include target.inc
        ideal
        jumps

;
;---------------------------========================---------------------------
;---------------------------====< DATA SECTION >====---------------------------
;---------------------------========================---------------------------
;
CDATASEG

        ID      dw ?
        DMA     db ?
        IRQ     db ?
        basea   dw ?

;
; The board base address for the original PAS card was based at 388. This will
; be XORed to the new address to derive a translation code. This code can be
; XORed back into any original PAS address resulting in the true card address.
;

VERSION_PAS             equ     0       ; Pro Audio Spectrum
VERSION_PASPLUS         equ     1       ; Pro Audio Plus card
VERSION_PAS16           equ     2       ; Pro Audio 16 card
VERSION_CDPC            equ     3       ; CDPC card & unit


;
; The following equates build up a mask of bits that we do wish to keep
; when comparing feature bits. The zero bits can be ignored, whereas, the
; the 1 bits must match.
;

PASdocare       equ     <(bMVA508 OR bMVDAC16 OR bMVOPL3 OR bMV101 )>
PASPLUSdocare   equ     <(bMVA508 OR bMVDAC16 OR bMVOPL3 OR bMV101 )>
PAS16docare     equ     <(bMVA508 OR bMVDAC16 OR bMVOPL3 OR bMV101 )>
CDPCdocare      equ     <(bMVA508 OR bMVDAC16 OR bMVOPL3 OR bMV101 )>

;
ENDS
;
;---------------------------========================---------------------------
;---------------------------====< CODE SECTION >====---------------------------
;---------------------------========================---------------------------
;
CCODESEG DETPAS

        CPUBLIC         detectPAS

        copyrightText   DB "PAS-DETECT v1.0 - (C) 1993 Otto Chrons",0,1Ah
        PASnorm         CARDINFO <3,0,"Pro Audio Spectrum",388h,0,0,3000,44100,1,1,1>
        PASplus         CARDINFO <4,0,"Pro Audio Spectrum+",388h,0,0,3000,44100,1,1,1>
        PAS16           CARDINFO <5,0,"Pro Audio Spectrum 16",388h,0,0,3000,44100,1,1,2>

        IRQtable        DB 0,2,3,4,5,6,7,10,11,12,13,15,0,0,0,0

        label   ProductIDTable  word
        dw      PRODUCT_PROAUDIO and PASdocare
        dw      PRODUCT_PROPLUS  and PASPLUSdocare
        dw      PRODUCT_PRO16    and PAS16docare
        dw      PRODUCT_CDPC     and CDPCdocare
        dw      -1
;
        label   DoCareBits      word
        dw      PASdocare
        dw      PASPLUSdocare
        dw      PAS16docare
        dw      CDPCdocare
        dw      -1                              ; table terminator

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
cproc   SearchHWVersion @@scard

        ENTERPROC       _di _si
;
; calculate the translation code
;
        xor     di,DEFAULT_BASE         ; di holds the translation code

        mov     ax,0BC00H               ; make sure MVSOUND.SYS is loaded
        mov     bx,'??'                 ; this is our way of knowing if the
        xor     cx,cx                   ; hardware is actually present.
        xor     dx,dx
        int     2fh                     ; get the ID pattern
        xor     bx,cx                   ; build the result
        xor     bx,dx
        cmp     bx,'MV'                 ; if not here, exit...
        jne     @@manual_detect

; get the MVSOUND.SYS specified DMA and IRQ channel

        mov     ax,0bc04h               ; get the DMA and IRQ numbers
        int     2fh
        mov     [IRQ],cl
        mov     [DMA],bl
        jmp     short @@detected
@@manual_detect:
        mov     dx,IOCONFIG2            ; get DMA channel
        xor     dx,di
        in      al,dx
        and     al,0Fh
        cmp     al,7
        ja      sehw_bad                ; we have a bad board
        cmp     al,0
        je      sehw_bad
        cmp     al,4
        jne     @@DMAok
        sub     al,al
@@DMAok:
        mov     [DMA],al
        mov     dx,IOCONFIG3
        xor     dx,di
        in      al,dx                   ; Get IRQ (AL = 1-6 for IRQ 2-7 and
        cmp     al,0Fh                  ; 7-10 for IRQ 10-13, 11 for IRQ 15)
        ja      sehw_bad                ; we have a bad board

        mov     _bx,offset IRQtable
        and     al,0Fh
        _segcs
        xlat    [_bx]
        or      al,al
        jz      sehw_bad                ; we have a bad board
        mov     [IRQ],al
;
; grab the version # in the interrupt mask. The top few bits hold the version #
;
@@detected:
        mov     dx,INTRCTLR             ; board ID is in MSB 3 bits
        xor     dx,di                   ; adjust to other address
        in      al,dx
        cmp     al,0FFh                 ; bus float meaning not present?
        je      sehw_bad                ; yes, there is no card here

        mov     ah,al                   ; save an original copy
        xor     al,fICrevbits           ; the top bits wont change

        out     dx,al                   ; send out the inverted bits
        jmp     $+2
        jmp     $+2
        in      al,dx                   ; get it back...

        cmp     al,ah                   ; both should match now...
        xchg    al,ah                   ; (restore without touching the flags)
        out     dx,al

        jnz     sehw_bad                ; we have a bad board

        and     ax,fICrevbits           ; isolate the ID bits & clear AH
        mov     cl,fICrevshr            ; shift the bits into a meaningful
        shr     al,cl                   ; position (least signficant bits)
        mov     si,ax                   ; save the version #
;
; We do have hardware! Load the product bit definitions
;
        sub     bx,bx
        mov     cx,bMVSCSI              ; setup bx:cx for the original PAS

        or      al,al                   ; is this the first version of h/w?
        jz      sehw_done               ; yes, simple exit will do.

        call    FindBits                ; load all the rest of the h/w bits
;
sehw_done:
;
; loop on a table search to find identify the board
;
        push    _bx                      ; save this high bits
        mov     _bx,-2
    ;
    sehw_05:
        add     _bx,2
        cmp     [ProductIDTable+_bx],-1  ; at the end of the table?
        jz      sehw_bad_hw             ; yes, we can't identify this board
        mov     dx,cx                   ; dx holds the product bits
        and     dx,[DoCareBits+_bx]      ; keep the bits we care about
        cmp     dx,[ProductIDTable+_bx]  ; do these bits match a product?
        jnz     sehw_05                 ; no, keep looking

        mov     dx,bx
        shr     dx,1                    ; make word index a byte index
        pop     _bx

        mov     ax,si                   ; load the h/w version #
        sub     ah,ah                   ; for our purposes, we will return SCSI
        xchg    ah,al                   ; into ah
        clc                             ; The board was identified !

        jmp     short sehw_exit
;
sehw_bad_hw:
        pop     _bx                      ; flush the stack
        mov     ax,-2
        cwd
        stc
        jmp     short sehw_exit
;
sehw_bad:
        mov     ax,-1                   ; we got here due to a bad board
        cwd
        stc
;
sehw_exit:
        LEAVEPROC       _di _si
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
;---|*|     DX    = Product ID
;---|*|     AH    = PAS hardware version
;---|*|     AL    = SCSI, or MITSUMI CD-ROM interface installed.
;---|*|     BX:CX = the bit fields that identify the board
;---|*|     Carry is set on error
;---|*|
;   \*/


cproc   detectPAS @@scard

        ENTERPROC       _si _di
;
; calculate the translation code
;

    ; search the default address

        mov     di,DEFAULT_BASE         ; try the first address
        mov     [basea],di
        ecall   SearchHWVersion [@@scard]
        cmp     dx,-1                   ; found?
        jnz     mvgehw_exit             ; yes, exit now...

    ; search the first alternate address

        mov     di,ALT_BASE_1           ; try the first alternate
        mov     [basea],di
        ecall   SearchHWVersion [@@scard]
        cmp     dx,-1                   ; found?
        jnz     mvgehw_exit             ; yes, exit now...

    ; search the second alternate address

        mov     di,ALT_BASE_2           ; try the second alternate
        mov     [basea],di
        ecall   SearchHWVersion [@@scard]
        cmp     dx,-1                   ; found?
        jnz     mvgehw_exit             ; yes, exit now...

    ; search the third, or user requested alternate address

        mov     di,ALT_BASE_3           ; try the third alternate
        mov     [basea],di
        ecall   SearchHWVersion [@@scard]
        cmp     dx,-1
        jne     mvgehw_exit
        mov     _ax,-1
        jmp     @@exitok
mvgehw_exit:
        LESDI   [@@scard]
        mov     si,-1
        PUSHDS
        PUSHCS
        POPDS
        cmp     dx,0
        jne     notNorm
        mov     _si,offset PASnorm
notNorm:
        cmp     dx,1
        jne     notPlus
        mov     _si,offset PASplus
notPlus:
        cmp     dx,2
        jne     not16
        mov     _si,offset PAS16
not16:
        cmp     _si,-1
        jne     cardok
        POPDS
        mov     _ax,-1
        jmp     @@exitok
cardok:
        mov     _cx,SIZE CARDINFO
        cld
        rep     movsb
        POPDS
        LESDI   [@@scard]
        mov     al,[DMA]
        mov     [ESDI+CARDINFO.DMAchannel],al
        mov     al,[IRQ]
        mov     [ESDI+CARDINFO.DMAIRQ],al
        mov     ax,[basea]
        mov     [ESDI+CARDINFO.ioPort],ax
        sub     _ax,_ax
@@exitok:
        LEAVEPROC       _si _di
        ret
endp

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

proc    FindBits        near
;
masm
quirks

; All second generation Pro Audio cards use the MV101 and have SB emulation.
;
        or      cx,bMVSBEMUL+bMV101     ; force SB emulation
;
; determine if the enhanced SCSI interface is present
;
        mov     dx,ENHANCEDSCSI         ; test for SCSI mod (U48)
        xor     dx,di                   ; modify via the translate code

        out     dx,al                   ; strobe
        jmp     $+2                             ; I/O bus delay
        in      al,dx                   ; get the bit

        and     al,1                    ; bit0==1 means old SCSI PAL
        cmp     al,1                    ; reverse sense
        sbb     ax,ax                   ; ax = ffff if enhanced SCSI
        and     ax,bMVENHSCSI           ; save the bit
        or      cx,ax                   ; merge it in
;
; determine AT/PS2, CDPC slave mode
;
        mov     dx,MASTERMODRD          ; check for the CDPC
        xor     dx,di                   ; modify via the translate code

        in      al,dx
        test    al,bMMRDatps2           ; AT(1) or PS2(0)
        jnz     @F
        or      cx,bMVPS2
    ;
    @@:
        test    al,bMMRDmsmd            ; Master(0) or Slave(1)
        jz      @F
        or      cx,bMVSLAVE
    ;
    @@:
        push    cx                      ; move the revision bits

        mov     dx,MASTERCHIPR
        xor     dx,di

        .errnz  bMV101_REV-(000Fh SHL 11)

        in      al,dx                   ; get the low 4 bits of the chip rev
        and     ax,000Fh                ; into ah
        mov     cl,11                   ; FROM 0000 0000 0000 1111b
        shl     ax,cl                   ; TO   0111 1000 0000 0000b

        pop     cx
        or      cx,ax                   ; merge in the bits
;
; determine the CDROM drive type, FM chip, 8/16 bit DAC, and mixer
;
        mov     dx,SLAVEMODRD           ; check for the CDPC
        xor     dx,di                   ; modify via the translate code
        in      al,dx

        test    al,bSMRDdactyp          ; 16 bit DAC?
        jz      @F                      ; no, its an 8 bit DAC
        or      cx,bMVDAC16             ; its a 16 bit DAC
    ;
    @@:
        test    al,bSMRDfmtyp           ; OPL3 chip?
        jz      @F                      ; no, so it's the PAS16 card
        or      cx,bMVOPL3              ; is an OPL3
    ;
    @@:
        mov     dx,cx                   ; inference check for new mixer
        and     dx,bMVSLAVE+bMVDAC16    ; Slave & 16 bit dac is the CDPC
        cmp     dx,bMVDAC16             ; 16 bit DAC on master?
        jnz     @F                      ; no, it's the CDPC with Nation mixer
        or      cx,bMVA508
    ;
    @@:
        and     al,bSMRDdrvtyp          ; isolate the CDROM drive type
        cmp     al,2                    ; Sony 535 interface?
        jnz     @F                      ; no, continue on...
        and     cx,NOT (bMVSCSI+bMVENHSCSI) ; yes, flush the SCSI bits
        or      cx,bMVSONY                  ; set the 535 bit
    ;
    @@:
;
; determine if MPU-401 emulation is active
;
        mov     dx,COMPATREGE           ; compatibility register
        xor     dx,di                   ; modify via translate code
        in      al,dx
        test    al,cpMPUEmulation
        jz      @F
        or      cx,bMVMPUEMUL
    ;
    @@:
        ret

endp

ends

end

