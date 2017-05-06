
; *******************************************************
; *							*
; *	Turbo Pascal Runtime Library Version 6.0	*
; *	CRT Interface Unit				*
; *							*
; *	Copyright (C) 1988,91 Borland International	*
; *							*
; *******************************************************

	TITLE	CRT

	INCLUDE	SE.ASM

; Coordinate record

X		EQU	(BYTE PTR 0)
Y		EQU	(BYTE PTR 1)

; BIOS workspace equates

CrtMode		EQU	(BYTE PTR 49H)
CrtWidth	EQU	(BYTE PTR 4AH)
Cursor		EQU	(WORD PTR 50H)
Addr6845	EQU	(WORD PTR 63H)
Timer		EQU	(DWORD PTR 6CH)
CrtInfo		EQU	(BYTE PTR 87H)
CrtRows		EQU	(BYTE PTR 84H)

DATA	SEGMENT	WORD PUBLIC

; Externals

	EXTRN	CheckBreak:BYTE,CheckEOF:BYTE,DirectVideo:BYTE
	EXTRN	CheckSnow:BYTE,LastMode:WORD,TextAttr:BYTE
	EXTRN	WindMin:WORD,WindMax:WORD,Seg0040:WORD
	EXTRN	SegB000:WORD,SegB800:WORD

    IF DPMIVersion
	EXTRN	RealModeRegs:BYTE
    ENDIF

; Local workspace

DelayCnt	DW	?
CurCrtSize	DW	?
NormAttr	DB	?
ScanCode	DB	?
BreakFlag	DB	?

DATA	ENDS

CODE	SEGMENT	BYTE PUBLIC

	ASSUME	CS:CODE,DS:DATA

; Externals

	EXTRN	Break:NEAR

; Publics

	PUBLIC	Initialize,TextMode,Window,ClrScr,ClrEol,InsLine
	PUBLIC	DelLine,GotoXY,WhereX,WhereY,TextColor,TextBackground
	PUBLIC	LowVideo,HighVideo,NormVideo,Delay,Sound,NoSound
	PUBLIC	KeyPressed,ReadKey,AssignCrt

; One-time initialization

Initialize:

	MOV	AH,0FH
	CALL	Video
	CMP	AL,7
	JE	@@1
	CMP	AL,3
	JBE	@@1
	MOV	AX,3
	CALL	CrtInit
@@1:	CALL	CrtSetup
	MOV	AH,8
	XOR	BH,BH
	CALL	Video
	MOV	AL,AH
	AND	AL,7FH
	MOV	NormAttr,AL
	MOV	TextAttr,AL
	XOR	AX,AX
	MOV	CheckEOF,AL
	MOV	ScanCode,AL
	MOV	BreakFlag,AL
	INC	AX
	MOV	CheckBreak,AL
	MOV	ES,Seg0040
	MOV	DI,OFFSET Timer
	MOV	BL,ES:[DI]
@@2:	CMP	BL,ES:[DI]
	JE	@@2
	MOV	BL,ES:[DI]
	MOV	AX,-28
	CWD
	CALL	DelayLoop
	NOT	AX
	NOT	DX
	MOV	CX,55
	DIV	CX
	MOV	DelayCnt,AX
    IF DPMIVersion
	MOV	AX,dpmiGetRMCB
	MOV	SI,OFFSET CtrlBreak
	MOV	DI,OFFSET RealModeRegs
	PUSH	DS
	POP	ES
	PUSH	CS
	POP	DS
	INT	DPMI
	PUSH	ES
	POP	DS
	MOV	AX,dpmiSetRealInt
	MOV	BL,1BH
	INT	DPMI
    ELSE
	PUSH	DS
	PUSH	CS
	POP	DS
	MOV	DX,OFFSET CtrlBreak
	MOV	AX,dosSetInt*256+1BH
	INT	DOS
	POP	DS
    ENDIF
	RET

; Initialize CRT
; In	AL = Requested mode
;	AH = Requested font

CrtInit:

	MOV	ES,Seg0040
	AND	ES:CrtInfo,0FEH
	CMP	AL,7
	JE	@@1
	CMP	AL,4
	JB	@@1
	MOV	AL,3
@@1:	PUSH	AX
	MOV	AH,0
	CALL	Video
	POP	AX
	OR	AH,AH
	JE	@@2
	MOV	AX,1112H
	MOV	BL,0
	CALL	Video
	MOV	AX,1130H
	MOV	BH,0
	MOV	DL,0
	CALL	Video
	CMP	DL,42
	JNE	@@2
	OR	ES:CrtInfo,1
	MOV	AX,100H
	MOV	CX,600H
	CALL	Video
	MOV	AH,12H
	MOV	BL,20H
	CALL	Video
@@2:	RET

; Setup CRT variables according to selected mode

CrtSetup:

	MOV	AH,0FH
	CALL	Video
	PUSH	AX
	MOV	AX,1130H
	MOV	BH,0
	MOV	DL,0
	CALL	Video
	POP	AX
	MOV	CL,0
	OR	DL,DL
	JNE	@@1
	MOV	DL,24
	CMP	AL,3
	JA	@@1
	MOV	CL,1
@@1:	MOV	DH,DL
	MOV	DL,AH
	DEC	DL
	MOV	AH,0
	CMP	DH,24
	JBE	@@2
	MOV	AH,1
@@2:	MOV	LastMode,AX
	MOV	CurCrtSize,DX
	MOV	CheckSnow,CL
	MOV	DirectVideo,1
	XOR	AX,AX
	MOV	WindMin,AX
	MOV	WindMax,DX
	RET

; Ctrl-Break interrupt handler

CtrlBreak:

    IF DPMIVersion
	CMP	ES:CheckBreak,0
	JE	@@1
	MOV	ES:BreakFlag,1
@@1:	CLD
	LODSW
	MOV	ES:[DI].realIP,AX
	LODSW
	MOV	ES:[DI].realCS,AX
	LODSW
	MOV	ES:[DI].realFlags,AX
	ADD	ES:[DI].realSP,6
    ELSE
	PUSH	AX
	PUSH	DS
	MOV	AX,SEG DATA
	MOV	DS,AX
	CMP	CheckBreak,0
	JE	@@1
	MOV	BreakFlag,1
@@1:	POP	DS
	POP	AX
    ENDIF
	IRET

; Check for Ctrl-Break

BreakCheck:

	CMP	BreakFlag,0
	JNE	@@1
	RET
@@1:	MOV	BreakFlag,0
@@2:	MOV	AH,1
	INT	16H
	JE	@@3
	MOV	AH,0
	INT	16H
	JMP	@@2
@@3:	MOV	AL,'^'
	CALL	WriteChar
	MOV	AL,'C'
	CALL	WriteChar
	CALL	WriteCrLf
	JMP	Break

; Set CRT text mode

TextMode:

	MOV	BX,SP
	MOV	AX,SS:[BX+4]
	CALL	CrtInit
	CALL	CrtSetup
	MOV	AL,NormAttr
	MOV	TextAttr,AL
	RETF	2

; Define output window

Window:

	MOV	BX,SP
	MOV	DL,SS:[BX+10]
	MOV	DH,SS:[BX+8]
	MOV	CL,SS:[BX+6]
	MOV	CH,SS:[BX+4]
	CMP	DL,CL
	JA	@@1
	CMP	DH,CH
	JA	@@1
	DEC	DL
	JS	@@1
	DEC	DH
	JS	@@1
	DEC	CL
	CMP	CL,CurCrtSize.X
	JA	@@1
	DEC	CH
	CMP	CH,CurCrtSize.Y
	JA	@@1
	MOV	WindMin,DX
	MOV	WindMax,CX
	CALL	SetCursor
@@1:	RETF	8

; Clear screen

ClrScr:

	MOV	AX,6*256
	MOV	BH,TextAttr
	MOV	CX,WindMin
	MOV	DX,WindMax
	CALL	Video
	MOV	DX,WindMin
	CALL	SetCursor
	RETF

; Clear to end-of-line

ClrEol:

	CALL	GetCursor
	MOV	AX,6*256
	MOV	BH,TextAttr
	MOV	CX,DX
	MOV	DL,WindMax.X
	CALL	Video
	RETF

; Insert line

InsLine:

	MOV	AX,7*256+1
	JMP	SHORT InsDelLine

; Delete line

DelLine:

	MOV	AX,6*256+1

InsDelLine:

	PUSH	AX
	CALL	GetCursor
	POP	AX
	MOV	BH,TextAttr
	MOV	CL,WindMin.X
	MOV	CH,DH
	MOV	DX,WindMax
	CMP	CH,DH
	JNE	@@1
	XOR	AL,AL
@@1:	CALL	Video
	RETF

; Position cursor

GotoXY:

	MOV	BX,SP
	MOV	DL,SS:[BX+6]
	MOV	DH,SS:[BX+4]
	DEC	DL
	ADD	DL,WindMin.X
	JC	@@1
	CMP	DL,WindMax.X
	JA	@@1
	DEC	DH
	ADD	DH,WindMin.Y
	JC	@@1
	CMP	DH,WindMax.Y
	JA	@@1
	CALL	SetCursor
@@1:	RETF	4

; Return cursor X coordinate

WhereX:

	CALL	GetCursor
	MOV	AL,DL
	SUB	AL,WindMin.X
	INC	AL
	RETF

; Return cursor Y coordinate

WhereY:

	CALL	GetCursor
	MOV	AL,DH
	SUB	AL,WindMin.Y
	INC	AL
	RETF

; Set text color (color modes)

TextColor:

	MOV	BX,SP
	MOV	AL,SS:[BX+4]
	TEST	AL,0F0H
	JE	@@1
	AND	AL,0FH
	OR	AL,80H
@@1:	AND	TextAttr,70H
	OR	TextAttr,AL
	RETF	2

; Set text background (color modes)

TextBackground:

	MOV	BX,SP
	MOV	AL,SS:[BX+4]
	AND	AL,7
	MOV	CL,4
	SHL	AL,CL
	AND	TextAttr,8FH
	OR	TextAttr,AL
	RETF	2

; Select low intensity

LowVideo:

	AND	TextAttr,0F7H
	RETF

; Select high intensity

HighVideo:

	OR	TextAttr,8
	RETF

; Select normal intensity

NormVideo:

	MOV	AL,NormAttr
	MOV	TextAttr,AL
	RETF

; Delay specified number of milliseconds

Delay:

	MOV	BX,SP
	MOV	CX,SS:[BX+4]
	JCXZ	@@2
	MOV	ES,Seg0040
	XOR	DI,DI
	MOV	BL,ES:[DI]
@@1:	MOV	AX,DelayCnt
	XOR	DX,DX
	CALL	DelayLoop
	LOOP	@@1
@@2:	RETF	2

; Delay one timer tick or by CX iterations

DelayLoop:

@@1:	SUB	AX,1
	SBB	DX,0
	JC	@@2
	CMP	BL,ES:[DI]
	JE	@@1
@@2:	RET

; Start sound generator

Sound:

	MOV	BX,SP
	MOV	BX,SS:[BX+4]
	MOV	AX,34DDH
	MOV	DX,0012H
	CMP	DX,BX
	JNC	@@2
	DIV	BX
	MOV	BX,AX
	IN	AL,61H
	TEST	AL,3
	JNZ	@@1
	OR	AL,3
	OUT	61H,AL
	MOV	AL,0B6H
	OUT	43H,AL
@@1:	MOV	AL,BL
	OUT	42H,AL
	MOV	AL,BH
	OUT	42H,AL
@@2:	RETF	2

; Turn off sound generator

NoSound:

	IN	AL,61H
	AND	AL,0FCH
	OUT	61H,AL
	RETF

; Return true if key is available

KeyPressed:

	CMP	ScanCode,0
	JNE	@@1
	MOV	AH,1
	INT	16H
	MOV	AL,0
	JE	@@2
@@1:	MOV	AL,1
@@2:	RETF

; Read character from keyboard
; Out	AL = Character

ReadKey:

	MOV	AL,ScanCode
	MOV	ScanCode,0
	OR	AL,AL
	JNE	@@1
	XOR	AH,AH
	INT	16H
	OR	AL,AL
	JNE	@@1
	MOV	ScanCode,AH
	OR	AH,AH
	JNE	@@1
	MOV	AL,'C'-64
@@1:	CALL	BreakCheck
	RETF

; Assign CRT to textfile

AssignCrt:

	MOV	BX,SP
	PUSH	DS
	LDS	DI,SS:[BX+4]
	MOV	[DI].fMode,fmClosed
	MOV	[DI].fBufSize,128
	LEA	AX,[DI].fBuffer
	MOV	[DI].fBufPtr.ofs,AX
	MOV	[DI].fBufPtr.seg,DS
	MOV	[DI].fOpenProc.ofs,OFFSET CrtOpen
	MOV	[DI].fOpenProc.seg,CS
	MOV	[DI].fName,0
	POP	DS
	RETF	4

; CRT file open procedure

CrtOpen:

	MOV	BX,SP
	PUSH	DS
	LDS	DI,SS:[BX+4]
	MOV	AX,OFFSET CrtRead
	MOV	BX,OFFSET CrtReturn
	MOV	CX,BX
	CMP	[DI].fMode,fmInput
	JE	@@1
	MOV	[DI].fMode,fmOutput
	MOV	AX,OFFSET CrtWrite
	MOV	BX,AX
@@1:	MOV	[DI].fInOutProc.ofs,AX
	MOV	[DI].fInOutProc.seg,CS
	MOV	[DI].fFlushProc.ofs,BX
	MOV	[DI].fFlushProc.seg,CS
	MOV	[DI].fCloseProc.ofs,CX
	MOV	[DI].fCloseProc.seg,CS
	XOR	AX,AX
	POP	DS
	RETF	4

; CRT file read procedure

CrtRead:

	ARG	FileP,DWORD,1

	ENTRY	FAR
	LES	DI,FileP
	MOV	DX,ES:[DI].fBufSize
	DEC	DX
	DEC	DX
	MOV	SI,ES:[DI].fBufPos
	LES	DI,ES:[DI].fBufPtr
	XOR	BX,BX
@@1:	MOV	ScanCode,0
	PUSH	CS
	CALL	ReadKey
	MOV	CX,1
	CMP	AL,bs
	JE	@@2
	CMP	AL,'S'-64
	JE	@@2
	CMP	AL,'D'-64
	JE	@@3
	DEC	CX
	CMP	AL,esc
	JE	@@2
	CMP	AL,'A'-64
	JE	@@2
	CMP	AL,'F'-64
	JE	@@3
	CMP	AL,eof
	JE	@@4
	CMP	AL,cr
	JE	@@5
	CMP	AL,' '
	JB	@@1
	CMP	BX,DX
	JE	@@1
	MOV	ES:[DI+BX],AL
	INC	BX
	CALL	WriteChar
	CMP	BX,SI
	JBE	@@1
	MOV	SI,BX
	JMP	@@1
@@2:	OR	BX,BX
	JE	@@1
	MOV	AL,bs
	CALL	WriteChar
	MOV	AL,' '
	CALL	WriteChar
	MOV	AL,bs
	CALL	WriteChar
	DEC	BX
	LOOP	@@2
	JMP	@@1
@@3:	CMP	BX,SI
	JE	@@1
	MOV	AL,ES:[DI+BX]
	CMP	AL,' '
	JB	@@1
	CALL	WriteChar
	INC	BX
	LOOP	@@3
	JMP	@@1
@@4:	CMP	CheckEOF,0
	JE	@@1
	MOV	ES:[DI+BX],AL
	INC	BX
	JMP	SHORT @@6
@@5:	CALL	WriteCrLf
	MOV	WORD PTR ES:[DI+BX],cr+lf*256
	INC	BX
	INC	BX
@@6:	LES	DI,FileP
	XOR	AX,AX
	MOV	ES:[DI].fBufPos,AX
	MOV	ES:[DI].fBufEnd,BX
	EXIT

; CRT file write procedure

CrtWrite:

	MOV	BX,SP
	LES	DI,SS:[BX+4]
	MOV	CX,ES:[DI].fBufPos
	SUB	ES:[DI].fBufPos,CX
	JCXZ	@@3
	LES	DI,ES:[DI].fBufPtr
	CMP	DirectVideo,0
	JNE	@@2
@@1:	MOV	AL,ES:[DI]
	CALL	WriteChar
	INC	DI
	LOOP	@@1
	JMP	SHORT @@3
@@2:	CALL	WriteString
@@3:	CALL	BreakCheck
	XOR	AX,AX
	RETF	4

; CRT file no-op procedure

CrtReturn:

	XOR	AX,AX
	RETF	4

; Write CR/LF on CRT
; Uses	AX

WriteCrLf:

	MOV	AL,cr
	CALL	WriteChar
	MOV	AL,lf

; Write character on CRT
; In	AL = Character
; Uses	AX

WriteChar:

	PUSH	BX
	PUSH	CX
	PUSH	DX
	PUSH	ES
	PUSH	AX
	CALL	GetCursor
	POP	AX
	CMP	AL,bell
	JE	@@1
	CMP	AL,bs
	JE	@@2
	CMP	AL,cr
	JE	@@3
	CMP	AL,lf
	JE	@@4
	MOV	AH,9
	MOV	BL,TextAttr
	XOR	BH,BH
	MOV	CX,1
	PUSH	DX
	CALL	Video
	POP	DX
	INC	DL
	CMP	DL,WindMax.X
	JBE	@@5
	MOV	DL,WindMin.X
	JMP	SHORT @@4
@@1:	MOV	AH,14
	CALL	Video
	JMP	SHORT @@5
@@2:	CMP	DL,WindMin.X
	JE	@@5
	DEC	DL
	JMP	SHORT @@5
@@3:	MOV	DL,WindMin.X
	JMP	SHORT @@5
@@4:	CALL	LineFeed
@@5:	CALL	SetCursor
	POP	ES
	POP	DX
	POP	CX
	POP	BX
	RET

; Do line-feed operation
; In	DX = Cursor position
; Uses	AX,BX

LineFeed:

	INC	DH
	CMP	DH,WindMax.Y
	JBE	@@1
	DEC	DH
	PUSH	CX
	PUSH	DX
	MOV	AX,6*256+1
	MOV	BH,TextAttr
	MOV	CX,WindMin
	MOV	DX,WindMax
	CALL	Video
	POP	DX
	POP	CX
@@1:	RET

; Get cursor position
; Out	DX = Cursor position
; Uses	AX,BX,CX,DX,ES

GetCursor:

	MOV	AH,3
	XOR	BH,BH
	JMP	Video

; Set cursor position
; In	DX = Cursor position
; Uses	AX,BX,CX,DX,ES

SetCursor:

	MOV	AH,2
	XOR	BH,BH
	JMP	Video

; Write character string directly to CRT
; In	CX    = Character count
;	DX    = Position
;	ES:DI = String pointer
; Uses	AX,BX,CX,DX,SI,DI,ES

WriteString:

	PUSH	DS
	MOV	DS,Seg0040
	MOV	DX,DS:Cursor
	POP	DS
	MOV	BX,DX
	MOV	SI,DI
@@1:	MOV	AL,ES:[DI]
	CMP	AL,bell
	JE	@@2
	CMP	AL,bs
	JE	@@3
	CMP	AL,lf
	JE	@@4
	CMP	AL,cr
	JE	@@5
	INC	DI
	INC	DL
	CMP	DL,WindMax.X
	JBE	@@8
	CALL	DirectWrite
	CALL	LineFeed
	MOV	DL,WindMin.X
	JMP	SHORT @@7
@@2:	CALL	DirectWrite
	PUSH	CX
	PUSH	DX
	MOV	AX,14*256+bell
	CALL	Video
	POP	DX
	POP	CX
	JMP	SHORT @@6
@@3:	CALL	DirectWrite
	CMP	DL,WindMin.X
	JE	@@6
	DEC	DL
	JMP	SHORT @@6
@@4:	CALL	DirectWrite
	CALL	LineFeed
	JMP	SHORT @@6
@@5:	CALL	DirectWrite
	MOV	DL,WindMin.X
@@6:	INC	DI
@@7:	MOV	SI,DI
	MOV	BX,DX
@@8:	LOOP	@@1
	CALL	DirectWrite
	PUSH	DS
	MOV	DS,Seg0040
	MOV	DS:Cursor,DX
	MOV	AL,DH
	MUL	DS:CrtWidth
	XOR	DH,DH
	ADD	AX,DX
	MOV	CX,AX
	MOV	DX,DS:Addr6845
	MOV	AL,14
	OUT	DX,AL
	JMP	SHORT $+2
	MOV	AL,CH
	INC	DX
	OUT	DX,AL
	JMP	SHORT $+2
	DEC	DX
	MOV	AL,15
	OUT	DX,AL
	JMP	SHORT $+2
	MOV	AL,CL
	INC	DX
	OUT	DX,AL
	POP	DS
	RET

; Do pending direct write string
; In	BX    = Cursor position
;	ES:SI = String start address
;	ES:DI = String end address
; Uses	AX,BX,SI

DirectWrite:

	CMP	SI,DI
	JE	@@8
	PUSH	CX
	PUSH	DX
	PUSH	DI
	PUSH	DS
	PUSH	ES
	MOV	CX,DI
	SUB	CX,SI
	PUSH	DS
	MOV	DS,Seg0040
	MOV	AL,BH
	MUL	DS:CrtWidth
	XOR	BH,BH
	ADD	AX,BX
	SHL	AX,1
	MOV	DI,AX
	MOV	DX,DS:Addr6845
	ADD	DX,6
	CMP	DS:CrtMode,7
	POP	DS
	MOV	AX,SegB800
	JNE	@@1
	MOV	AX,SegB000
@@1:	MOV	BL,CheckSnow
	MOV	BH,TextAttr
	PUSH	ES
	POP	DS
	MOV	ES,AX
	CLD
	OR	BL,BL
	JE	@@5
@@2:	LODSB
	MOV	BL,AL
@@3:	IN	AL,DX
	TEST	AL,1
	JNE	@@3
	CLI
@@4:	IN	AL,DX
	TEST	AL,1
	JE	@@4
	MOV	AX,BX
	STOSW
	STI
	LOOP	@@2
	JMP	SHORT @@7
@@5:	MOV	AH,BH
@@6:	LODSB
	STOSW
	LOOP	@@6
@@7:	POP	ES
	POP	DS
	POP	DI
	POP	DX
	POP	CX
@@8:	RET

; Save registers and call BIOS video routine

Video:

	PUSH	SI
	PUSH	DI
	PUSH	BP
	PUSH	ES
	INT	10H
	POP	ES
	POP	BP
	POP	DI
	POP	SI
	RET

CODE	ENDS

	END
