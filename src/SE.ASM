; *******************************************************
; *							*
; *	VERSION CONTROL EQUATES				*
; *							*
; *******************************************************

; Boolean values

FALSE		EQU	0
TRUE		EQU	NOT FALSE

; Version equates

    IFDEF _Windows_
WindowsVersion	EQU	TRUE
DPMIVersion	EQU	FALSE
    ELSE
    IFDEF _DPMI_
WindowsVersion	EQU	FALSE
DPMIVersion	EQU	TRUE
    ELSE
WindowsVersion	EQU	FALSE
DPMIVersion	EQU	FALSE
    ENDIF
    ENDIF

; *******************************************************
; *							*
; *	MACROS						*
; *							*
; *******************************************************

	LOCALS	@@

; Public variable definition macro

VAR MACRO Symbol,SType,Count
  PUBLIC Symbol
  Symbol LABEL SType
  IF Count
    DB SType * Count DUP(?)
  ENDIF
ENDM

; Parameter definition macro

ARG MACRO Symbol,SType,Count
  LOCAL Offset
  @AP = @AP + SType * Count
  Offset = @AP
  Symbol EQU (SType PTR [BP+@AF-Offset])
ENDM

@AP = 0
@AF = 0

; Local variables definition macro

LOC MACRO Symbol,SType,Count
  LOCAL Offset
  @LP = @LP + SType * Count
  Offset = @LP
  Symbol EQU (SType PTR [BP+@LF-Offset])
ENDM

@LP = 0
@LF = 0

; Stack frame modifiers

sfFar		EQU	01H		;FAR frame
sfMarkBP	EQU	02H		;Make saved BP odd
sfSaveDS	EQU	04H		;Save DS at [BP-2]
sfInitDS	EQU	08H		;Init DS using SS

; Default stack frame type

sfDefault = 0

; Stack frame types

    IF WindowsVersion
WINFAR		EQU	sfFar+sfMarkBP+sfSaveDS
    ELSE
WINFAR		EQU	sfFar
    ENDIF

; Entry code generation macro

ENTRY MACRO FrameType
  IFB <FrameType>
    @SF = sfDefault
  ELSE
    IFIDNI <FrameType>,<NEAR>
      @SF = 0
    ELSE
      IFIDNI <FrameType>,<FAR>
        @SF = sfFar
      ELSE
        @SF = FrameType
      ENDIF
    ENDIF
  ENDIF
  IF @SF AND sfMarkBP
    INC BP
  ENDIF
  PUSH BP
  MOV BP,SP
  IF @SF AND sfFar
    @AF = @AP + 6
  ELSE
    @AF = @AP + 4
  ENDIF
  IF @SF AND sfSaveDS
    PUSH DS
    @LF = -2
  ELSE
    @LF = 0
  ENDIF
  IF @LP
    SUB SP,@LP
  ENDIF
  IF @SF AND sfInitDS
    PUSH DS
    PUSH SS
    POP DS
  ENDIF
ENDM

; Exit code generation macro

EXIT MACRO ArgSize
  IF @SF AND sfInitDS
    POP DS
  ENDIF
  IF @LF - @LP
    MOV SP,BP
  ENDIF
  POP BP
  IF @SF AND sfMarkBP
    DEC BP
  ENDIF
  IFNB <ArgSize>
    @AP = ArgSize
  ENDIF
  IF @SF AND sfFar
    RETF @AP
  ELSE
    RETN @AP
  ENDIF
  @AP = 0
  @LP = 0
ENDM

; *******************************************************
; *							*
; *	EQUATES						*
; *							*
; *******************************************************

; 10-Byte record

b0		EQU	(BYTE PTR 0)
b1		EQU	(BYTE PTR 1)
b2		EQU	(BYTE PTR 2)
b3		EQU	(BYTE PTR 3)
b4		EQU	(BYTE PTR 4)
b5		EQU	(BYTE PTR 5)
b6		EQU	(BYTE PTR 6)
b7		EQU	(BYTE PTR 7)
b8		EQU	(BYTE PTR 8)
b9		EQU	(BYTE PTR 9)

; 5-Word record

w0		EQU	(WORD PTR 0)
w2		EQU	(WORD PTR 2)
w4		EQU	(WORD PTR 4)
w6		EQU	(WORD PTR 6)
w8		EQU	(WORD PTR 8)

; Pointer record

ofs		EQU	(WORD PTR 0)
seg		EQU	(WORD PTR 2)

; 8087 status word masks

mIE		EQU	0001H
mDE		EQU	0002H
mZE		EQU	0004H
mOE		EQU	0008H
mUE		EQU	0010H
mPE		EQU	0020H
mC0		EQU	0100H
mC1		EQU	0200H
mC2		EQU	0400H
mC3		EQU	4000H

; ASCII equates

bell		EQU	07H
bs		EQU	08H
tab		EQU	09H
lf		EQU	0AH
cr		EQU	0DH
eof		EQU	1AH
esc		EQU	1BH
del		EQU	7FH

; DOS interrupt vector number

DOS		EQU	21H

; DOS function codes

dosSetDrive	EQU	0EH
dosGetDrive	EQU	19H
dosSetDTA	EQU	1AH
dosSetInt	EQU	25H
dosParse	EQU	29H
dosGetDate	EQU	2AH
dosSetDate	EQU	2BH
dosGetTime	EQU	2CH
dosSetTime	EQU	2DH
dosGetVersion	EQU	30H
dosGetInt	EQU	35H
dosCreateDir	EQU	39H
dosRemoveDir	EQU	3AH
dosSetDir	EQU	3BH
dosCreate	EQU	3CH
dosOpen		EQU	3DH
dosClose	EQU	3EH
dosRead		EQU	3FH
dosWrite	EQU	40H
dosDelete	EQU	41H
dosSeek		EQU	42H
dosAttrib	EQU	43H
dosIOCtl	EQU	44H
dosGetDir	EQU	47H
dosSetMem	EQU	4AH
dosExec		EQU	4BH
dosExit		EQU	4CH
dosGetExit	EQU	4DH
dosFindFirst	EQU	4EH
dosSetPSP	EQU	50H
dosGetPSP	EQU	51H
dosMakePSP	EQU	55H
dosRename	EQU	56H
dosFDate	EQU	57H

; Program segment prefix variables

pspMemTop	EQU	(WORD PTR 02H)
pspFileTab	EQU	(BYTE PTR 18H)
pspEnvSeg	EQU	(WORD PTR 2CH)
pspFCB1		EQU	(BYTE PTR 5CH)
pspFCB2		EQU	(BYTE PTR 6CH)
pspCmdLine	EQU	(BYTE PTR 80H)

; Free-list memory record layout

mNext		EQU	(DWORD PTR 0)
mSize		EQU	(DWORD PTR 4)
mRecSize	EQU	8

; File record layout

fHandle		EQU	(WORD PTR 0)
fMode		EQU	(WORD PTR 2)
fBufSize	EQU	(WORD PTR 4)
fPrivate	EQU	(WORD PTR 6)
fBufPos		EQU	(WORD PTR 8)
fBufEnd		EQU	(WORD PTR 10)
fBufPtr		EQU	(DWORD PTR 12)
fOpenProc	EQU	(DWORD PTR 16)
fInOutProc	EQU	(DWORD PTR 20)
fFlushProc	EQU	(DWORD PTR 24)
fCloseProc	EQU	(DWORD PTR 28)
fUserData	EQU	(BYTE PTR 32)
fName		EQU	(BYTE PTR 48)
fBuffer		EQU	(BYTE PTR 128)
fRecSize	EQU	256

; fMode values

fmClosed	EQU	0D7B0H
fmInput		EQU	0D7B1H
fmOutput	EQU	0D7B2H
fmInOut		EQU	0D7B3H

; Overlay header record

ovSignature	EQU	(WORD PTR 0)
ovSaveReturn	EQU	(WORD PTR 2)
ovFilePos	EQU	(WORD PTR 4)
ovCodeSize	EQU	(WORD PTR 8)
ovFixupSize	EQU	(WORD PTR 10)
ovJumpCount	EQU	(WORD PTR 12)
ovLink		EQU	(WORD PTR 14)
ovSegment	EQU	(WORD PTR 16)
ovRetryCount	EQU	(WORD PTR 18)
ovNext		EQU	(WORD PTR 20)
ovEmsPage	EQU	(WORD PTR 22)
ovEmsOffset	EQU	(WORD PTR 24)
ovUserData	EQU	(BYTE PTR 26)
ovVectors	EQU	(BYTE PTR 32)
ovRecSize	EQU	32

; Windows data segment variables

pPtrCount	EQU	(WORD PTR DS:04H)
pLocalHeap	EQU	(WORD PTR DS:06H)
pAtomTable	EQU	(WORD PTR DS:08H)
pStackTop	EQU	(WORD PTR DS:0AH)
pStackBot	EQU	(WORD PTR DS:0CH)
pStackMin	EQU	(WORD PTR DS:0EH)

; DPMI interrupt vector

DPMI		EQU	31H

; DPMI function codes

dpmiGetDesc	EQU	0000H		;Allocate descriptors
dpmiFreeDesc	EQU	0001H		;Free descriptor
dpmiSegToDesc	EQU	0002H		;Map segment to descriptor
dpmiGetSelInc	EQU	0003H		;Get selector increment value
dpmiGetSegBase	EQU	0006H		;Get segment base address
dpmiSetSegBase	EQU	0007H		;Set segment base address
dpmiSetSegSize	EQU	0008H		;Set segment size
dpmiGetRealInt	EQU	0200H		;Get real mode int handler
dpmiSetRealInt	EQU	0201H		;Set real mode int handler
dpmiGetExcept	EQU	0202H		;Get exception handler
dpmiSetExcept	EQU	0203H		;Set exception handler
dpmiGetInt	EQU	0204H		;Get interrupt handler
dpmiSetInt	EQU	0205H		;Set interrupt handler
dpmiGetRMCB	EQU	0303H		;Get real mode call-back
dpmiGetVersion	EQU	0400H		;Get version information

; Real mode call-back registers structure

realDI		EQU	(DWORD PTR 00H)
realSI		EQU	(DWORD PTR 04H)
realBP		EQU	(DWORD PTR 08H)
realBX		EQU	(DWORD PTR 10H)
realDX		EQU	(DWORD PTR 14H)
realCX		EQU	(DWORD PTR 18H)
realAX		EQU	(DWORD PTR 1CH)
realFlags	EQU	(WORD PTR 20H)
realES		EQU	(WORD PTR 22H)
realDS		EQU	(WORD PTR 24H)
realFS		EQU	(WORD PTR 26H)
realGS		EQU	(WORD PTR 28H)
realIP		EQU	(WORD PTR 2AH)
realCS		EQU	(WORD PTR 2CH)
realSP		EQU	(WORD PTR 2EH)
realSS		EQU	(WORD PTR 30H)
realRegsSize	EQU	32H
