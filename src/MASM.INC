
;   /*\
;---|*|----====< MASM.INC >====----
;---|*|
;---|*| Copyright (c) 1992, 1991, Media Vision, Inc.  All Rights Reserved.
;---|*|
;   \*/

;---------------------------====< MASM Assembly >====--------------------------

  @ret equ 4
  FFAR  equ     <far>

  @ptr equ 4

;
; C convention stack parameters
;
wParm1          equ     [bp+2+@ret+00h]
wParm2          equ     [bp+2+@ret+02h]
wParm3          equ     [bp+2+@ret+04h]
wParm4          equ     [bp+2+@ret+06h]
wParm5          equ     [bp+2+@ret+08h]

dParm1          equ     [bp+2+@ret+00h]
dParm2          equ     [bp+2+@ret+04h]
dParm3          equ     [bp+2+@ret+08h]
dParm4          equ     [bp+2+@ret+0ch]

;
; miscellaneous equates & macros
;
; external data pointer
;
externPTR macro   nme           ;; this macro fixes a masm 5.10 bug that
        if @datasize            ;; doesn't allow equate text replacement
        extrn   nme:dword       ;; on the 'extrn' statements.
        else
        extrn   nme:word
        endif
        endm
;
; external code address
;
externADDR macro   nme          ;; this macro fixes a masm 5.10 bug that
        if @codesize            ;; doesn't allow equate text replacement
        extrn   nme:far         ;; on the 'extrn' statements.
        else
        extrn   nme:near
        endif
        endm

bptr            equ     byte ptr
wptr            equ     word ptr
dptr            equ     dword ptr

pause           equ     <jmp $+2>
disable         equ     cli
enable          equ     sti

;
; NEAR branches
;
jjnz    macro   addr
        LOCAL   jjmp
        jz      jjmp
        jmp     addr
jjmp:
        endm

jjz     macro   addr
        LOCAL   jjmp
        jnz     jjmp
        jmp     addr
jjmp:
        endm

jjc     macro   addr
        LOCAL   jjmp
        jnc     jjmp
        jmp     addr
jjmp:
        endm

jjnc    macro   addr
        LOCAL   jjmp
        jc      jjmp
        jmp     addr
jjmp:
        endm

jjb     macro   addr
        LOCAL   jjmp
        jae     jjmp
        jmp     addr
jjmp:
        endm

jjbe    macro   addr
        LOCAL   jjmp
        ja      jjmp
        jmp     addr
jjmp:
        endm

jja     macro   addr
        LOCAL   jjmp
        jbe     jjmp
        jmp     addr
jjmp:
        endm

bne     macro   label
        LOCAL   jjmp
        je      jjmp
        jmp     label
jjmp:
        endm

bnz     macro   label
        LOCAL   jjmp
        je      jjmp
        jmp     label
jjmp:
        endm

be      macro   label
        LOCAL   jjmp
        jne     jjmp
        jmp     label
jjmp:
        endm

bz      macro   label
        LOCAL   jjmp
        jne     jjmp
        jmp     label
jjmp:
        endm

bb      macro   label
        LOCAL   jjmp
        jae     jjmp
        jmp     label
jjmp:
        endm

ba      macro   label
        LOCAL   jjmp
        jbe     jjmp
        jmp     label
jjmp:
        endm

bbe     macro   label
        LOCAL   jjmp
        ja      jjmp
        jmp     label
jjmp:
        endm

bae     macro   label
        LOCAL   jjmp
        jb      jjmp
        jmp     label
jjmp:
        endm

bc      macro   label
        LOCAL   jjmp
        jnc     jjmp
        jmp     label
jjmp:
        endm

bnc     macro   label
        LOCAL   jjmp
        jc      jjmp
        jmp     label
jjmp:
        endm

bs      macro   label
        LOCAL   jjmp
        jns     jjmp
        jmp     label
jjmp:
        endm

;
; multiple shift macro for 8088
;
shrm     macro   regmem,count
        .errb   <count>
        .errnz  count GT 16
        rept    count
        shr     regmem,1
        endm
        endm

shlm     macro   regmem,count
        .errb   <count>
        .errnz  count GT 16
        rept    count
        shl     regmem,1
        endm
        endm

;
; push these registers
;
PUSHEM  MACRO   parm1,parm2,parm3,parm4,parm5,parm6,parm7,parm8,parm9
        IFNB    <parm1>
        push    parm1
        ENDIF
        IFNB    <parm2>
        push    parm2
        ENDIF
        IFNB    <parm3>
        push    parm3
        ENDIF
        IFNB    <parm4>
        push    parm4
        ENDIF
        IFNB    <parm5>
        push    parm5
        ENDIF
        IFNB    <parm6>
        push    parm6
        ENDIF
        IFNB    <parm7>
        push    parm7
        ENDIF
        IFNB    <parm8>
        push    parm8
        ENDIF
        IFNB    <parm9>
        push    parm9
        ENDIF
        ENDM
;
; pop these registers
;
POPEM   MACRO   parm1,parm2,parm3,parm4,parm5,parm6,parm7,parm8,parm9
        IFNB    <parm9>
        pop     parm9
        ENDIF
        IFNB    <parm8>
        pop     parm8
        ENDIF
        IFNB    <parm7>
        pop     parm7
        ENDIF
        IFNB    <parm6>
        pop     parm6
        ENDIF
        IFNB    <parm5>
        pop     parm5
        ENDIF
        IFNB    <parm4>
        pop     parm4
        ENDIF
        IFNB    <parm3>
        pop     parm3
        ENDIF
        IFNB    <parm2>
        pop     parm2
        ENDIF
        IFNB    <parm1>
        pop     parm1
        ENDIF
        ENDM


