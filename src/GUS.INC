IF 0
MACRO   saveIRQ
	pushf
	cli
ENDM

MACRO   restoreIRQ
	popf
ENDM
ENDIF

MACRO   DELAY
	call    gusDelay
ENDM

