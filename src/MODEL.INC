;****************************************************************************;
;*                                                                          *;
;* File:        MODEL.INC                                                   *;
;*                                                                          *;
;****************************************************************************;

IDEAL

STRUC   _byte
	b       DB      ?
ENDS

STRUC   _word
	w       DW      ?
ENDS

STRUC   _dword
	d       DD      ?
ENDS

IFDEF __C32__

_FAR            EQU     NEAR
_OFS            EQU     DWORD
_OFSM           EQU     DD

_char           EQU     _dword
D_char          EQU     DD
_short          EQU     _dword
D_short         EQU     DD
_int            EQU     _dword
D_int           EQU     DD
_long           EQU     _dword
D_long          EQU     DD
_ptr            EQU     _dword
D_ptr           EQU     DD
__32__ = 1
_instack = 8
locs = 0
_AX             EQU     eax
_BX             EQU     ebx
_CX             EQU     ecx
_DX             EQU     edx
_SI             EQU     esi
_DI             EQU     edi
_SP             EQU     esp
_BP             EQU     ebp

MACRO   LDSSI   val
        mov     esi,val
ENDM

MACRO   LDSDI   val
        mov     edi,val
ENDM

MACRO   LDSBX   val
        mov     ebx,val
ENDM

MACRO   LESSI   val
	mov     esi,val
ENDM

MACRO   LESDI   val
	mov     edi,val
ENDM

MACRO   LESBX   val
        mov     ebx,val
ENDM

ESDI    equ     EDI
ESSI    equ     ESI
ESBX    equ     EBX

MACRO   PUSHDS
ENDM

MACRO   POPDS
ENDM

MACRO   PUSHES
ENDM

MACRO   POPES
ENDM

MACRO   PUSHCS
ENDM

MACRO   _segcs
ENDM

MACRO   _segds
ENDM

MACRO   _segss
ENDM

MACRO   _seges
ENDM

MACRO   IF32    a1
        &a1
ENDM

MACRO   IF16    a1
ENDM

ELSE
IFDEF __C16__ OR __PASCAL__

_FAR            EQU     FAR
_OFS            EQU     WORD
_OFSM           EQU     DW

_char           EQU     _word
D_char          EQU     DW
_short          EQU     _word
D_short         EQU     DW
_int            EQU     _word
D_int           EQU     DW
_long           EQU     _dword
D_long          EQU     DD
_ptr            EQU     _dword
D_ptr           EQU     DD
__16__ = 1
_instack = 6
locs = 0
_AX             EQU     ax
_BX             EQU     bx
_CX             EQU     cx
_DX             EQU     dx
_SI             EQU     si
_DI             EQU     di
_SP             EQU     sp
_BP             EQU     bp

MACRO   LDSSI   val
        lds     si,val
ENDM

MACRO   LDSDI   val
        lds     di,val
ENDM

MACRO   LDSBX   val
        lds     bx,val
ENDM

MACRO   LESSI   val
        les     si,val
ENDM

MACRO   LESDI   val
        les     di,val
ENDM

MACRO   LESBX   val
        les     bx,val
ENDM

ESDI    equ     ES:DI
ESSI    equ     ES:SI
ESBX    equ     ES:BX

MACRO   PUSHDS
        push    ds
ENDM

MACRO   POPDS
        pop     ds
ENDM

MACRO   PUSHES
        push    es
ENDM

MACRO   POPES
        pop     es
ENDM

MACRO   PUSHCS
        push    cs
ENDM

MACRO   _segcs
        segcs
ENDM

MACRO   _segds
        segds
ENDM

MACRO   _segss
	segss
ENDM

MACRO   _seges
	seges
ENDM

MACRO   IF32    a1
ENDM

MACRO   IF16    a1
	&a1
ENDM

ELSE
        ERR "You have to specify model (__C16__, __C32__ or __PASCAL__)"
ENDIF
ENDIF



MACRO   STACKARG        name
LOCAL   a

	a = args + _instack

  IFDEF __32__
	&name   EQU     <DWORD ebp+&a>
  ENDIF

  IFDEF __16__
	&name   EQU     <DWORD bp+&a>
  ENDIF
	args = args + 4
ENDM



MACRO   CPROC   procname, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, ax
LOCAL   an

  IFNB <ax>
    ERR "Too many arguments"
  ENDIF

  IFDEF __C32__
        PROC    _&procname      NEAR
  ELSE
  IFDEF __PASCAL__
      PROC      procname        FAR
  ELSE
      PROC      _&procname      FAR
  ENDIF
  ENDIF
        args = 0
        procargs = 0
        locs = 0
IFDEF __PASCAL__
        IFNB <a10>
          STACKARG  &a10
          procargs = procargs + 4
        ENDIF
        IFNB <a9>
          STACKARG  &a9
          procargs = procargs + 4
        ENDIF
        IFNB <a8>
          STACKARG  &a8
          procargs = procargs + 4
        ENDIF
        IFNB <a7>
          STACKARG  &a7
          procargs = procargs + 4
        ENDIF
        IFNB <a6>
          STACKARG  &a6
          procargs = procargs + 4
        ENDIF
        IFNB <a5>
	  STACKARG  &a5
          procargs = procargs + 4
        ENDIF
        IFNB <a4>
          STACKARG  &a4
          procargs = procargs + 4
        ENDIF
        IFNB <a3>
          STACKARG  &a3
          procargs = procargs + 4
        ENDIF
        IFNB <a2>
          STACKARG  &a2
          procargs = procargs + 4
        ENDIF
        IFNB <a1>
          STACKARG  &a1
          procargs = procargs + 4
        ENDIF
ELSE
        IFNB <a1>
          STACKARG  &a1
          procargs = procargs + 4
        ENDIF
        IFNB <a2>
          STACKARG  &a2
          procargs = procargs + 4
        ENDIF
        IFNB <a3>
          STACKARG  &a3
          procargs = procargs + 4
        ENDIF
        IFNB <a4>
          STACKARG  &a4
          procargs = procargs + 4
        ENDIF
        IFNB <a5>
          STACKARG  &a5
          procargs = procargs + 4
        ENDIF
        IFNB <a6>
          STACKARG  &a6
          procargs = procargs + 4
        ENDIF
	IFNB <a7>
          STACKARG  &a7
          procargs = procargs + 4
        ENDIF
        IFNB <a8>
          STACKARG  &a8
          procargs = procargs + 4
        ENDIF
        IFNB <a9>
          STACKARG  &a9
          procargs = procargs + 4
        ENDIF
        IFNB <a10>
          STACKARG  &a10
          procargs = procargs + 4
        ENDIF
ENDIF
ENDM


MACRO   ENTERPROC       r1,r2,r3,r4,r5,r6
        enter   (locs+3)/4*4,0
        IFNB <r1>
        push    r1 r2 r3 r4 r5 r6
        ENDIF
ENDM


MACRO   LEAVEPROC       r1,r2,r3,r4,r5,r6
        IFNB <r1>
        pop     r6 r5 r4 r3 r2 r1
        ENDIF
        leave
IFDEF __PASCAL__
        ret     procargs
ELSE
        ret
ENDIF
ENDM


MACRO   CPUBLIC p1,p2,p3,p4,p5,p6,p7,p8,p9,p10

IFDEF   __PASCAL__
	IFNB <p1>
            PUBLIC      p1
        ENDIF
        IFNB <p2>
            PUBLIC      p2
        ENDIF
        IFNB <p3>
            PUBLIC      p3
        ENDIF
        IFNB <p4>
            PUBLIC      p4
        ENDIF
        IFNB <p5>
            PUBLIC      p5
        ENDIF
        IFNB <p6>
            PUBLIC      p6
        ENDIF
        IFNB <p7>
            PUBLIC      p7
        ENDIF
        IFNB <p8>
            PUBLIC      p8
        ENDIF
        IFNB <p9>
            PUBLIC      p9
        ENDIF
        IFNB <p10>
            PUBLIC      p10
        ENDIF
ELSE
        IFNB <p1>
            PUBLIC      _&p1
        ENDIF
        IFNB <p2>
            PUBLIC      _&p2
        ENDIF
        IFNB <p3>
            PUBLIC      _&p3
        ENDIF
        IFNB <p4>
            PUBLIC      _&p4
        ENDIF
	IFNB <p5>
            PUBLIC      _&p5
        ENDIF
        IFNB <p6>
            PUBLIC      _&p6
        ENDIF
        IFNB <p7>
            PUBLIC      _&p7
        ENDIF
        IFNB <p8>
            PUBLIC      _&p8
        ENDIF
        IFNB <p9>
            PUBLIC      _&p9
        ENDIF
        IFNB <p10>
            PUBLIC      _&p10
        ENDIF
ENDIF

ENDM

MACRO   CGLOBAL p1,p2,p3,p4,p5,p6,p7,p8,p9,p10

IFDEF   __PASCAL__
        IFNB <p1>
            GLOBAL      p1
        ENDIF
        IFNB <p2>
            GLOBAL      p2
        ENDIF
        IFNB <p3>
            GLOBAL      p3
        ENDIF
        IFNB <p4>
            GLOBAL      p4
        ENDIF
        IFNB <p5>
            GLOBAL      p5
        ENDIF
        IFNB <p6>
            GLOBAL      p6
        ENDIF
        IFNB <p7>
	    GLOBAL      p7
        ENDIF
        IFNB <p8>
            GLOBAL      p8
        ENDIF
        IFNB <p9>
            GLOBAL      p9
        ENDIF
        IFNB <p10>
            GLOBAL      p10
        ENDIF
ELSE
        IFNB <p1>
            GLOBAL      _&p1
        ENDIF
        IFNB <p2>
            GLOBAL      _&p2
        ENDIF
        IFNB <p3>
            GLOBAL      _&p3
        ENDIF
        IFNB <p4>
            GLOBAL      _&p4
        ENDIF
        IFNB <p5>
            GLOBAL      _&p5
        ENDIF
        IFNB <p6>
            GLOBAL      _&p6
        ENDIF
	IFNB <p7>
            GLOBAL      _&p7
        ENDIF
        IFNB <p8>
            GLOBAL      _&p8
        ENDIF
        IFNB <p9>
            GLOBAL      _&p9
        ENDIF
        IFNB <p10>
            GLOBAL      _&p10
        ENDIF
ENDIF

ENDM

MACRO   ECALL   procname,p1,p2,p3,p4,p5,p6,p7,p8

IFDEF   __PASCAL__
        IFNB <p1>
            PUSH    p1
        ENDIF
	IFNB <p2>
	    PUSH    p2
	ENDIF
	IFNB <p3>
	    PUSH    p3
	ENDIF
	IFNB <p4>
	    PUSH    p4
	ENDIF
	IFNB <p5>
	    PUSH    p5
	ENDIF
	IFNB <p6>
	    PUSH    p6
	ENDIF
	IFNB <p7>
	    PUSH    p7
	ENDIF
	IFNB <p8>
	    PUSH    p8
	ENDIF
	CALL    FAR     procname
ELSE
        args = 0
        IFNB <p8>
            PUSH    p8
            args = args + 4
        ENDIF
        IFNB <p7>
            PUSH    p7
            args = args + 4
        ENDIF
        IFNB <p6>
            PUSH    p6
            args = args + 4
        ENDIF
        IFNB <p5>
            PUSH    p5
            args = args + 4
	ENDIF
        IFNB <p4>
            PUSH    p4
            args = args + 4
        ENDIF
        IFNB <p3>
            PUSH    p3
            args = args + 4
        ENDIF
        IFNB <p2>
            PUSH    p2
            args = args + 4
        ENDIF
        IFNB <p1>
            PUSH    p1
            args = args + 4
        ENDIF

        IFDEF __C32__
                CALL    NEAR _&procname
        ELSE
                CALL    FAR _&procname
        ENDIF

IF args NE 0
        ADD     _SP,args
ENDIF

ENDIF

ENDM


MACRO   ECALLM  procname,p1,p2,p3,p4,p5,p6,p7,p8

IFDEF   __PASCAL__
        IFNB <p1>
            PUSH    p1
        ENDIF
        IFNB <p2>
            PUSH    p2
        ENDIF
        IFNB <p3>
            PUSH    p3
        ENDIF
        IFNB <p4>
            PUSH    p4
        ENDIF
        IFNB <p5>
            PUSH    p5
        ENDIF
        IFNB <p6>
            PUSH    p6
        ENDIF
        IFNB <p7>
            PUSH    p7
        ENDIF
        IFNB <p8>
            PUSH    p8
        ENDIF
        CALL    procname
ELSE
        args = 0
        IFNB <p8>
            PUSH    p8
            args = args + 4
        ENDIF
        IFNB <p7>
            PUSH    p7
            args = args + 4
        ENDIF
	IFNB <p6>
            PUSH    p6
            args = args + 4
        ENDIF
        IFNB <p5>
            PUSH    p5
            args = args + 4
        ENDIF
        IFNB <p4>
            PUSH    p4
            args = args + 4
        ENDIF
        IFNB <p3>
            PUSH    p3
            args = args + 4
        ENDIF
        IFNB <p2>
            PUSH    p2
            args = args + 4
        ENDIF
        IFNB <p1>
            PUSH    p1
            args = args + 4
        ENDIF

	CALL    procname

IF args NE 0
        ADD     _SP,args
ENDIF

ENDIF

ENDM


MACRO   LOCALVAR        ssize, name
LOCAL   a

        locs = locs + (SIZE &ssize)
	a = 0-locs

  IFDEF __32__
        &name   EQU     ebp+a
  ENDIF
  IFDEF __16__
        &name   EQU     bp+a
  ENDIF
ENDM



MACRO   LOCVARS         s1, n1, s2, n2, s3, n3, s4, n4, s5, n5, s6, n6,\
                        s7, n7, s8, n8, s9, n9, s10, n10, sx, nx
        IFNB <sx>
          ERR "Too many local variables with single LOCVARS"
        ENDIF


        IFNB <s1>
          LOCALVAR &s1, &n1
        ENDIF
        IFNB <s2>
          LOCALVAR &s2, &n2
        ENDIF
        IFNB <s3>
          LOCALVAR &s3, &n3
        ENDIF
        IFNB <s4>
          LOCALVAR &s4, &n4
        ENDIF
        IFNB <s5>
          LOCALVAR &s5, &n5
        ENDIF
        IFNB <s6>
          LOCALVAR &s6, &n6
        ENDIF
        IFNB <s7>
          LOCALVAR &s7, &n7
        ENDIF
        IFNB <s8>
          LOCALVAR &s8, &n8
	ENDIF
	IFNB <s9>
	  LOCALVAR &s9, &n9
	ENDIF
	IFNB <s10>
	  LOCALVAR &s10, &n10
	ENDIF
ENDM




MACRO   CSEGMENTS sname
  IFDEF __C32__
	SEGMENT _DATA   DWORD PUBLIC USE32 'DATA'
	ENDS
	GROUP   DGROUP _DATA
  ELSE
  IFDEF __C16__
	SEGMENT _DATA   WORD PUBLIC USE16 'DATA'
	ENDS
	SEGMENT _BSS    WORD PUBLIC USE16 'BSS'
	ENDS

	GROUP   DGROUP  _DATA,_BSS

	SEGMENT &sname&_TEXT PARA PUBLIC USE16 'CODE'
	ENDS
  ELSE
	SEGMENT _DATA   WORD PUBLIC USE16 'DATA'
	ENDS

	GROUP   DGROUP  _DATA

	SEGMENT &sname&_TEXT PARA PUBLIC USE16 'CODE'
	ENDS
  ENDIF
  ENDIF
ENDM



MACRO   CDATASEG
  IFDEF __C32__
	SEGMENT _DATA   DWORD PUBLIC USE32 'DATA'
  ELSE
	SEGMENT _DATA   WORD PUBLIC USE16 'DATA'
  ENDIF
ENDM



MACRO   CCODESEG sname
  IFDEF __C32__
	SEGMENT _TEXT   PARA PUBLIC USE32 'CODE'
	ASSUME  cs:_TEXT, ds:DGROUP, es:DGROUP
  ELSE
	SEGMENT &sname&_TEXT PARA PUBLIC USE16 'CODE'
	ASSUME  cs:&sname&_TEXT, ds:DGROUP, es:NOTHING
  ENDIF
ENDM



MACRO   RETVAL value
        mov     _ax,value
ENDM

MACRO	memSet 	memOfs,memSize
	mov	_di,offset memOfs
IF (memSize AND 3) EQ 0
	mov	_cx,memSize/4
	rep	stosd
ELSEIF (memSize AND 1) EQ 0
	mov	_cx,memSize/2
	rep	stosw
ELSE
	mov	_cx,memSize
	rep	stosb
ENDIF

ENDM
