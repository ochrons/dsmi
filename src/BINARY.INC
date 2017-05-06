;$Author:   DCODY  $
;$Date:   25 Jun 1992 23:21:10  $
;$Header:   W:/sccs/inc/binary.inv   1.1   25 Jun 1992 23:21:10   DCODY  $
;$Log:   W:/sccs/inc/binary.inv  $
;
;   Rev 1.1   25 Jun 1992 23:21:10   DCODY
;added generic SB mixer channel equates
;
;   Rev 1.0   15 Jun 1992 09:58:34   BCRANE
;Initial revision.
;$Logfile:   W:/sccs/inc/binary.inv  $
;$Modtimes$
;$Revision:   1.1  $
;$Workfile:   binary.inc  $ 

;   /*\
;---|*|----====< BINARY.INC >====----
;---|*|
;---|*| Copyright (c) 1991, Media Vision, Inc.	All Rights Reserved.
;---|*|
;   \*/

;
; commands issued to the 2F interface
;

BI_INSTALLCHECK equ	0		; Check if the driver is installed
BI_GETVERSION	equ	1		; Get the version #
BI_GETSTATE	equ	2		; Get the state pointer and size
BI_GETFUNCTION	equ	3		; Get the function table pointer
BI_GETDMAIRQ	equ	4		; Get the DMA/IRQ/INT number
BI_SENDCMD	equ	5		; reserved now. see function #3
BI_GETSTATUSSTR equ	6		; Get the status string
BI_reserved1	equ	7		; reserved
BI_reserved2	equ	8		; reserved
BI_reserved3	equ	9		; reserved
BI_SETSCANCODE	equ    10		; set the hot key scan codes
BI_GETPATH	equ    11		; get the file path

;
; TRUE/FALSE & ON/OFF logic values
;

BI_TRUE 	equ	-1
BI_FALSE	equ	0

BI_ON		equ	BI_TRUE 	; on state
BI_OFF		equ	BI_FALSE	; off state

BI_INT2FCODE1	equ	0BCH		; Bryan's initials

; int 2F ID (func 0) return register values

BI_INT2FREGBX	equ	6D00h		; 'm '
BI_INT2FREGCX	equ	0076h		; ' v'
BI_INT2FREGDX	equ	2020h		; UPPERCASE XOR MASK

;
; Command Block Structure
;

bcmdblk  struc

  bc_blockID	  dw	?	; language command block	(mandatory)

  bc_devcode	  dw	?	; device code (MIXER/VOLUME/CROSS/FILTER...)

  bc_deviceselect dw	?	; INPUT|OUTPUT mixer select & more...

  bc_fromflag	  dw	?	; [FROM <term>] TRUE/FALSE
  bc_fromtype	  dw	?	; type fromvalue is type # or %
  bc_fromvalue	  dw	?	; value derived from <term>

  bc_toflag	  dw	?	; [TO <term>] TRUE/FALSE	(mandatory)
  bc_totype	  dw	?	; type fromvalue is type # or %
  bc_tovalue	  dw	?	; value derived from <term>

  breserved1	  dw	?	; reserved for internal use

  bc_leftchflag   dw	?	; set left channel  TRUE/FALSE
  bc_leftchannel  dw	?	; left channel #

  bc_ritchflag	  dw	?	; set right channel TRUE/FALSE
  bc_ritchannel   dw	?	; right channel #

  bc_secondsflag  dw	?	; TRUE/FALSE to do it over time
  bc_secondcount  dw	?	; # of seconds to spread out the command

  breserved2	  dw	?	; reserved for internal use

  bc_errorcode	  dw	?	; holds the error number
  bc_targetstr	  dd	?	; user's target string pointer

bcmdblk  ends

;
; blockID Commands
;

BI_RESETCMD	equ	0		; Reset the hardware settings
BI_SETCMD	equ	1		; SET parsed language block
BI_GETCMD	equ	2		; GET parsed language block
BI_HOLDCMD	equ	3		; Hold the queue
BI_RELCMD	equ	4		; Release the queue

;
; execode Commands
;

BI_CROSSCMD	EQU	0		; command is for the cross channel
BI_FILTERCMD	EQU	1		; command is for the filter
BI_MIXERCMD	EQU	2		; command is for the mixer
BI_REALCMD	EQU	3		; command is for the real sound switch
BI_VOLUMECMD	EQU	4		; command is for the volume

BI_LASTEXECMD	EQU	BI_VOLUMECMD	; Last valid command

;
; different logic flags for a TO condition (c_xxxxflag)
;

BI_DONTSET	equ	 0		; don't process FROM value
BI_SETFROM	equ	-1		; FROM setting is available
BI_SETTO	equ	-1		; TO setting is available (mandatory)
BI_UPTO 	equ	-2		; set up from current setting
BI_DOWNTO	equ	-3		; set down from current setting

;
; types of numeric data in FROM and TO fields (c_xxxxtype)
;

BI_TYPEINT	equ	1		; "getterm" return type
BI_TYPEPCT	equ	2		; "getterm" return type

;
; deviceselect values (c_deviceselect)
;
;       (none for the filter)

;       for mixers

BI_OUTPUTMIXER	equ	00h		; output mixer H/W select
BI_INPUTMIXER	equ	40h		; input mixer select
BI_DEFMIXER	equ	0ffh		; use the default mixer

;	for cross channel

BI_RIGHT2RIGHT	equ	01h		; right to right
BI_LEFT2RIGHT	equ	02h		; left	to right
BI_RIGHT2LEFT	equ	04h		; right to left
BI_LEFT2LEFT	equ	08h		; left	to left

;	for volume control

BI_VOLLOUD	equ	00h		; LOUDNESS switch
BI_VOLENHANCE	equ	01h		; ENHANCED stereo
BI_VOLBASS	equ	02h		; BASS (0-12)
BI_VOLTREBLE	equ	03h		; TREBLE (0-12)
BI_VOLLEFT	equ	04h		; LEFT VOLUME  (0-40)
BI_VOLRIGHT	equ	05h		; RIGHT VOLUME (0-40)
BI_VOLMODE	equ	06h		; MODE	(LEFT/STEREO/RIGHT)

BI_bVOLLOUD	equ	0001b		; enhanced bass bit
BI_bVOLENH	equ	0010b		; enhanced stereo bit

;
; left/right mixer channel selection
;

;	left channel values

BI_L_FM 	equ	01h
BI_L_IMIXER	equ	02h
BI_L_EXT	equ	03h
BI_L_INT	equ	04h
BI_L_MIC	equ	05h
BI_L_PCM	equ	06h
BI_L_SPEAKER	equ	07h
BI_L_SBDAC	equ	00h

;	right channel values

BI_R_FM 	equ	08h
BI_R_IMIXER	equ	09h
BI_R_EXT	equ	0Ah
BI_R_INT	equ	0Bh
BI_R_MIC	equ	0Ch
BI_R_PCM	equ	0Dh
BI_R_SPEAKER	equ	0Eh
BI_R_SBDAC	equ	0Fh


;   /*\
;---|*| end of binary.inc
;   \*/

