; ***********************************************************************
; *
; *     File        :   MCPLAYER.ASM
; *     Description :   Player routines for Multi Channel Player
; *                     Low level routines for Multi Channel Player
; *
; *     Copyright (C) 1992,1994 Otto Chrons
; *
; ***********************************************************************
;
;       Revision history of MCPLAYER.ASM
;
;       1.0     16.4.93
;               First version. Supports >64K samples.
;
;       1.01    16.4.93
;               New function */mcpOutput/* which returns information
;               about where output is going.
;
;               10.5.93
;               Basic panning features (left/middle/right) */mcpSetPanning/*
;
;       1.1     14.5.93
;               Full panning is now implemented
;
;       1.15    18.9.93
;               Added Surround Channel to panning
;
;	2.0	18.12.93
;		New macros for 16- and 32-bit versions
;
;       2.1     27.1.94
;               New mixing routines for 32-bit version
;               Improved performance on 486 about 25%
;
;       2.5     26.5.94
;               New 16-bit quality mode
;
;       2.6     16.6.94
;               Callback support for external digital effects
;
; ***********************************************************************/

	IDEAL
	JUMPS
	P386

	DELTA_ACCURACY = 9

	INCLUDE "MODEL.INC"
	INCLUDE "MCP.INC"               ; Common definitions
	INCLUDE "CDI.INC"

        QUALITY16 = 1                   ; Define if you want to have
                                        ; 16-bit Quality mode

IFDEF __PASCAL__
	EXTRN   mcpSampleRealAddress:FAR
        EXTRN   mcpEnableVirtualSamples:FAR
        EXTRN   mcpDisableVirtualSamples:FAR
ELSE
        EXTRN   _mcpSampleRealAddress:_FAR
        EXTRN   _mcpEnableVirtualSamples:_FAR
        EXTRN   _mcpDisableVirtualSamples:_FAR
ENDIF

STRUC   MCPOUTPUT
    position    DW ?
    start       DD ?
    length      DW ?
ENDS

MACRO   checkInit
	RETVAL  -1
	test    [mcpStatus],S_MCP
	jz      @@exit
ENDM

MACRO   calcChannel
	mov     ebx,[@@channel]
        cmp     _bx,[channelCount]
	jae     @@exit
	shl     _bx,1
	mov     bx,[chDataPtr+_bx]
ENDM

IFDEF __16__
MACRO   Qnormalize segm,offs
	LOCAL @@j
	cmp     offs,65535
	jbe     @@j
	mov     ax,segm
	movzx   eax,ax
	shl     eax,4
	add     eax,offs
	mov     offs,eax
	and     offs,0Fh
	shr     eax,4
	mov     segm,ax
@@j:
ENDM
ENDIF

CSEGMENTS MCPLAYER

CDATASEG

IFDEF   __PASCAL__

	EXTRN   mcpStatus:BYTE
	EXTRN   bufferSize:WORD
	EXTRN   dataBuf:WORD
	EXTRN   SoundCard:CARDINFO
	EXTRN   CDI_MCP:CDIDEVICE
ELSE
	CPUBLIC  mcpStatus, dataBuf, bufferSize
	CPUBLIC  SoundCard, CDI_MCP

	CDI_MCP         EQU _CDI_MCP
	mcpStatus       EQU _mcpStatus
	dataBuf         EQU _dataBuf
	bufferSize      EQU _bufferSize
	SoundCard       EQU _SoundCard

	_SoundCard       CARDINFO <>
	_CDI_MCP         CDIDEVICE <\
		_far ptr _mcpSetSample,\
		_far ptr _mcpPlaySample,\
		_far ptr _mcpSetVolume,\
		_far ptr _mcpSetRate,\
		_far ptr _nullFunction,\
		_far ptr _mcpSetPosition,\
		_far ptr _mcpSetPanning,\
		_far ptr _mcpSetMasterVolume,\
		_far ptr _mcpMuteChannel,\
		_far ptr _mcpUnmuteChannel,\
		_far ptr _mcpStopChannel,\
		_far ptr _mcpMuteAll,\
		_far ptr _mcpUnmuteAll,\
		_far ptr _mcpPoll,\
		_far ptr _mcpGetDelta,\
		_far ptr _mcpDownload,\
                _far ptr _mcpUnload,\
                _far ptr _mcpUnloadAll,\
                _far ptr _mcpGetVolume,\
		_far ptr _mcpGetRate,\
		_far ptr _mcpGetPosition,\
		_far ptr _mcpGetPanning,\
		_far ptr _mcpGetSample,\
		_far ptr _mcpSetupChannels,\
		_far ptr _mcpGetChannelStatus>

	_mcpStatus      DB 0
IFDEF __16__
	_bufferSize     DW ?
	_dataBuf        DW ?
ELSE
	_bufferSize     DD ?
	_dataBuf        DD ?
ENDIF

ENDIF
        options         DW ?
	bufferSeg       DW ?
        bufferOverrun   DW ?
	doesLoop        DB ?
	curChannel      DW ?
	firstChannel1   DW ?
	firstChannel2   DW ?
	countBytes      DW ?
	calcBUSY        DB ?
	masterVol       DB ?
	samplingRate    DW ?
IFDEF __16__
	sampleWidth     DW ?
	bufferCounter   DW ?
	bytesLeft       DW ?
	sampleSize      DW ?
	bufferFillPos   DW ?
        calcRoutine     DW ?
        channelCount    DW ?
ELSE
	sampleWidth     DD ?
	bufferCounter   DD ?
	bytesLeft       DD ?
	sampleSize      DD ?
	bufferFillPos   DD ?
	__ecx		DD ?
	jumpAddress	DD ?
	bufferBase	DD ?
        calcRoutine     DD ?
        channelCount    DD ?
ENDIF
	clearFirst      DB ?
	clearValue      DD ?
	realClearValue  DD ?
	pan             DB ?
	realpan         DB ?
	tempEDI         DD ?
	tempESI         DD ?
	calibSize       DD ?
	calibTime       DD ?
	calibDelta      DD ?
	calibStatus     DW ?
	calibBuffer     DW ?
        calibLast       DW ?
	calibCount      DW ?
	calibTotal      DW ?
	realRate        DW ?
	tempCount       DW ?
        effectRoutine   DD ?
	channelData     CHDATA MAXCHANNEL dup(<>)
	SDI             SOUNDDEVICE <>
	mcpout          MCPOUTPUT <>

	bpointer = 0
	volumeTableWord = bpointer
        volumeTable = 0
        volumeTable2 = 32*256
        soundBufferOfs = 32*256*2

        QUALITYCOUNT = 2000                     ; How many bytes to mix on one pass
        QualityBuffer = 32*256*2                ; Quality temp buffer offset
        QUALITYPASS = 8192                      ; Size of second pass table
        QualityPass2 = 32*256*2 + 2048*2        ; Offset of ---""----
        QUALITYSIZE = 2048*2 + 8192             ; Size of quality mode buffers

IFDEF QUALITY16
        QUALITYCOUNT16 = 2000
        QualityBuffer16 = 32*256*4              ; Offset of quality mode buffer
        QualityPassTable = 32*256*4+2048*4+32*4 ; Offset of second pass lookup table
        QUALITYSIZE16 = 2048*4+64*4             ; Size of quality16 mode buffers
        soundBufferOfs16 = 32*256*4             ; Offset of actual sound buffer
                                                ; in 16-bit Quality mode
ENDIF

ENDS

CCODESEG MCPLAYER

	CPUBLIC  mcpInitSoundDevice, mcpGetCardInfo
	CPUBLIC  mcpInit, mcpClose, mcpOpenSpeaker, mcpCloseSpeaker
	CPUBLIC  mcpSetupChannels, mcpStartVoice, mcpStopVoice, mcpGetChannelCount
	CPUBLIC  mcpPauseVoice, mcpResumeVoice
	CPUBLIC  mcpStopChannel, mcpMuteChannel, mcpUnmuteChannel
	CPUBLIC  mcpMuteAll, mcpUnmuteAll
	CPUBLIC  mcpGetChannelStatus, mcpGetRate, mcpGetSample
	CPUBLIC  mcpGetPosition, mcpGetVolume
	CPUBLIC  mcpSetSample, mcpPlaySample,mcpSetVolume, mcpSetRate
	CPUBLIC  mcpSetPosition, mcpSetPanning, mcpGetPanning
	CPUBLIC  mcpSetSamplingRate, mcpGetSamplingRate, mcpGetOutput
	CPUBLIC  mcpSetMasterVolume
	CPUBLIC  mcpPoll, mcpGetDelta, mcpClearBuffer
        CPUBLIC  mcpDownLoad, mcpUnloadAll, mcpUnload
        CPUBLIC  mcpSetEffectRoutine

        copyrightText   DB "MCP v2.6 - (C) 1992,1994 Otto Chrons",0,1Ah

CPROC   nullFunction

        sub     _ax,_ax
        sub     _dx,_dx
	ret
ENDP

	count = 0
	LABEL   chDataPtr WORD
	    REPT MAXCHANNEL
		DW count
		count = count + SIZE CHDATA
	    ENDM

	linearVolume    DW 01,02,03,04,05,06,07,08,09,10,11,12,13,14,15,16
			DW 17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,31

        stereoVolume    DW 01,02,04,06,07,08,09,11,12,13,15,17,18,19,21,22
                        DW 23,25,26,28,29,30,32,33,34,36,37,39,40,41,43,44


        UNROLL_SHIFT = 3
	UNROLL_COUNT = 1 SHL UNROLL_SHIFT


MACRO   makelabel lbl,a
	&lbl&a&:
ENDM

MACRO   makelabel2 lbl,a
IFDEF __32__
	DD offset &lbl&a&
ELSE
	DW offset &lbl&a&
ENDIF
ENDM
	lbl = 0
	LABEL   monoaddlbl _OFS
	REPT    UNROLL_COUNT
	    makelabel2 monoadd,%lbl
	    lbl = lbl + 1
	ENDM

	lbl = 0
	LABEL   monomovelbl _OFS
	REPT    UNROLL_COUNT
	    makelabel2 monomove,%lbl
            lbl = lbl + 1
        ENDM

        lbl = 0
	LABEL   stereoaddlbl _OFS
	REPT    UNROLL_COUNT
            makelabel2 stereoadd,%lbl
	    lbl = lbl + 1
        ENDM

        lbl = 0
	LABEL   stereoaddlblPan _OFS
	REPT    UNROLL_COUNT
            makelabel2 stereoaddPan,%lbl
            lbl = lbl + 1
        ENDM

        lbl = 0
	LABEL   stereoaddlblMID _OFS
	REPT    UNROLL_COUNT
            makelabel2 stereoaddMID,%lbl
            lbl = lbl + 1
        ENDM

        lbl = 0
	LABEL   stereoaddlblSrnd _OFS
	REPT    UNROLL_COUNT
            makelabel2 stereoaddSrnd,%lbl
            lbl = lbl + 1
        ENDM

        lbl = 0
	LABEL   stereomovelbl _OFS
	REPT    UNROLL_COUNT
            makelabel2 stereomove,%lbl
            lbl = lbl + 1
        ENDM

        lbl386 = 0
        LABEL   monoadd16lbl386 _OFS
	REPT    UNROLL_COUNT
            makelabel2 monoadd16_386,%lbl386
            lbl386 = lbl386 + 1
	ENDM

        lbl386 = 0
        LABEL   monomove16lbl386 _OFS
	REPT    UNROLL_COUNT
            makelabel2 monomove16_386,%lbl386
            lbl386 = lbl386 + 1
        ENDM

        lbl386 = 0
        LABEL   stereoadd16lbl386 _OFS
	REPT    UNROLL_COUNT
            makelabel2 stereoadd16_386,%lbl386
            lbl386 = lbl386 + 1
	ENDM

        lbl386 = 0
        LABEL   stereoadd16lbl386MID _OFS
	REPT    UNROLL_COUNT
            makelabel2 stereoadd16_386MID,%lbl386
            lbl386 = lbl386 + 1
        ENDM

        lbl386 = 0
        LABEL   stereoadd16lbl386Srnd _OFS
	REPT    UNROLL_COUNT
            makelabel2 stereoadd16_386Srnd,%lbl386
            lbl386 = lbl386 + 1
        ENDM

        lbl386 = 0
        LABEL   stereoadd16lbl386Pan _OFS
	REPT    UNROLL_COUNT
            makelabel2 stereoadd16_386Pan,%lbl386
            lbl386 = lbl386 + 1
        ENDM

        lbl386 = 0
        LABEL   stereomove16lbl386 _OFS
	REPT    UNROLL_COUNT
            makelabel2 stereomove16_386,%lbl386
            lbl386 = lbl386 + 1
        ENDM

        lbl = 0
	LABEL   postqualitylbl _OFS
        REPT    UNROLL_COUNT
	    makelabel2 postquality,%lbl
	    lbl = lbl + 1
	ENDM

IFDEF QUALITY16
        lbl386 = 0
        LABEL   monoadd16lbl386Q _OFS
	REPT    UNROLL_COUNT
            makelabel2 monoadd16_386Q,%lbl386
            lbl386 = lbl386 + 1
	ENDM

        lbl386 = 0
        LABEL   monomove16lbl386Q _OFS
	REPT    UNROLL_COUNT
            makelabel2 monomove16_386Q,%lbl386
            lbl386 = lbl386 + 1
        ENDM

        lbl386 = 0
        LABEL   stereoadd16lbl386Q _OFS
	REPT    UNROLL_COUNT
            makelabel2 stereoadd16_386Q,%lbl386
            lbl386 = lbl386 + 1
	ENDM

        lbl386 = 0
        LABEL   stereoadd16lbl386MIDQ _OFS
	REPT    UNROLL_COUNT
            makelabel2 stereoadd16_386MIDQ,%lbl386
            lbl386 = lbl386 + 1
        ENDM

        lbl386 = 0
        LABEL   stereoadd16lbl386SrndQ _OFS
	REPT    UNROLL_COUNT
            makelabel2 stereoadd16_386SrndQ,%lbl386
            lbl386 = lbl386 + 1
        ENDM

        lbl386 = 0
        LABEL   stereoadd16lbl386PanQ _OFS
	REPT    UNROLL_COUNT
            makelabel2 stereoadd16_386PanQ,%lbl386
            lbl386 = lbl386 + 1
        ENDM

        lbl386 = 0
        LABEL   stereomove16lbl386Q _OFS
	REPT    UNROLL_COUNT
            makelabel2 stereomove16_386Q,%lbl386
            lbl386 = lbl386 + 1
        ENDM

ENDIF
IFDEF __16__

MACRO   mixAdd386
        add     edi,edx                 ; increase counters
        mov     bl,[ESSI]               ; Get byte from sample
        adc     si,bp
        mov     al,[bx]                 ; Set correct volume
        add     [di],al                 ; Put one byte into buffer
ENDM

MACRO   mixMove386
        add     edi,edx                 ; increase counters
        mov     bl,[ESSI]               ; Get byte from sample
        adc     si,bp
        mov     al,[bx]                 ; Set correct volume
        mov     [di],al                 ; Put one byte into buffer
ENDM

MACRO   mixAdd386_2
        add     edi,edx                 ; increase counters
        mov     bl,[ESSI]               ; Get byte from sample
        adc     si,bp
        mov     al,[bx]                 ; Set correct volume
        add     edi,edx                 ; increase counters
        mov     bl,[ESSI]               ; Get byte from sample
        adc     si,bp
        mov     ah,[bx]                 ; Set correct volume
        add     [di],ax                 ; Put one byte into buffer
ENDM

MACRO   mixMove386_2
        add     edi,edx                 ; increase counters
        mov     bl,[ESSI]               ; Get byte from sample
        adc     si,bp
        mov     al,[bx]                 ; Set correct volume
        add     edi,edx                 ; increase counters
        mov     bl,[ESSI]               ; Get byte from sample
        adc     si,bp
        mov     ah,[bx]                 ; Set correct volume
        mov     [di],ax                 ; Put one byte into buffer
ENDM

MACRO   mixAdd386Mid
        add     edi,edx                 ; increase counters
        mov     bl,[ESSI]               ; Get byte from sample
        adc     si,bp
        mov     al,[bx]                 ; Set correct volume
	mov     ah,al
        add     [di],ax                 ; Put one byte into buffer
ENDM

MACRO   mixAdd386Srnd
        add     edi,edx                 ; increase counters
        mov     bl,[ESSI]               ; Get byte from sample
        adc     si,bp
        mov     ah,[bx]                 ; Set correct volume
        mov     al,ah
        neg     ah                      ; Phase shift 180 degrees
        add     [di],ax                 ; Put two bytes into buffer
ENDM

MACRO   mixAdd386Pan
        add     edi,edx                 ; increase counters
        mov     bl,[ESSI]               ; Get byte from sample
        adc     si,bp
        mov     al,[bx]                 ; Set correct volume
        mov     cl,bl
        mov     ah,[ecx]
        add     [di],ax                 ; Put two bytes into buffer
ENDM

;/*************************************************************************
; *
; *     Function    :   routineMono8_386
; *
; *     Description :   Calculates buffer for 8-bit mono cards in 386 mode
; *
; *************************************************************************/

PROC    routineMono8_386 NEAR

	PUSHDS
	jc      @@clear
	and     edi,0000FFFFh
	and     ebx,0000FFFFh
	shl     eax,16
	or      edi,eax                 ; High EDI is quotient
	rol     edx,16
	mov     dx,1

	cmp     [firstChannel1],0
	je      @@moveroutine

        mov     ds,[bufferSeg]
	test    di,1
	jz      @@DIok1
	dec     di
	mixAdd386
	inc     di
	dec     cx
	jcxz    @@exit
@@DIok1:
	shr     cx,1
	jcxz    @@nomore
	pushf
	sub     di,2
	push    _bx
	mov     bx,cx
	shr	cx,UNROLL_SHIFT
	inc     cx
	and     bx,UNROLL_COUNT-1
	add     bx,bx
        mov     _ax,[_bx+monoaddlbl]
	pop     _bx
	jmp     _ax
ALIGN 16
@@loop:
	lbl = UNROLL_COUNT-1
	REPT    UNROLL_COUNT
            mixAdd386_2
            makelabel monoadd,%lbl
            lbl = lbl - 1
        ENDM
        loop    @@loop
        add     di,2
        popf
@@nomore:
        jnc     @@aok2
        dec     di
        mixAdd386
        inc     di
@@aok2:
        jmp     @@exit

@@moveroutine:
        sub     bl,bl
        add     bx,volumeTable2
        mov     ds,[bufferSeg]
        test    di,1
        jz      @@DIok2
	dec     di
        mixMove386
        inc     di
        dec     cx
        jcxz    @@exit
@@DIok2:
        shr     cx,1
        jcxz    @@nomore2
        pushf
        sub     di,2
	push    _bx
        mov     bx,cx
        shr	cx,UNROLL_SHIFT
        inc     cx
        and     bx,UNROLL_COUNT-1
	add     bx,bx
        mov     _ax,[_bx+monomovelbl]
	pop     _bx
	jmp     _ax
ALIGN 16
@@loop2:
	lbl = UNROLL_COUNT-1
	REPT    UNROLL_COUNT
            mixMove386_2
            makelabel monomove,%lbl
            lbl = lbl - 1
        ENDM
        loop    @@loop2
        add     di,2
        popf
@@nomore2:
        jnc     @@aok1
        dec     di
        mixMove386
        inc     di
@@aok1:
        jmp     @@exit
@@clear:
        and     edi,0000FFFFh
        shl     eax,16
        or      edi,eax                 ; High EDI is quotient
        rol     edx,16
        mov     dx,1
        cmp     [firstChannel1],0
        mov     ds,[bufferSeg]
	jne     @@loopc2
ALIGN 4
@@loopc1:
        mov     [byte di],80h
        add     edi,edx
        adc     si,bp
        loop    @@loopc1
        jmp     @@exit
@@loopc2:
        add     edi,edx
        adc     si,bp
        loop    @@loopc2
@@exit:
        mov     eax,edi
        shr     eax,16                  ; AX = quotient
	POPDS
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   routineStereo8_386
; *
; *     Description :   Calculates buffer for 8-bit stereo cards in 386 mode
; *
; *************************************************************************/

PROC    routineStereo8_386 NEAR

        PUSHDS
        jc      @@clear
        and     edi,0000FFFFh
        and     ebx,0000FFFFh
        shl     eax,16
        or      edi,eax                 ; High EDI is quotient
        rol     edx,16
        mov     dx,2                    ; For word addressing (in stereo)
        jcxz    @@exit

        cmp     [pan],PAN_SURROUND
        je      @@Surround
        cmp     [pan],PAN_MIDDLE
        je      @@MIDroutine

        cmp     [pan],PAN_RIGHT
	je      @@10
        cmp     [firstChannel1],0
        je      @@moveroutine
        jmp     @@addroutine
@@10:
        cmp     [firstChannel2],0
        je      @@moveroutine
@@addroutine:
        sub     di,2
        mov     ds,[bufferSeg]
	push    _bx
        mov     bx,cx
        shr	cx,UNROLL_SHIFT
        inc     cx
        and     bx,UNROLL_COUNT-1
	add     bx,bx
        mov     _ax,[_bx+stereoaddlbl]
	pop     _bx
	jmp     _ax
ALIGN 16
@@loop1:
	lbl = UNROLL_COUNT-1
	REPT    UNROLL_COUNT
            mixAdd386
            makelabel stereoadd,%lbl
            lbl = lbl - 1
        ENDM
        loop    @@loop1
        add     di,2
        jmp     @@exit

@@moveroutine:
        sub     bl,bl
        add     bx,volumeTable2
        sub     di,2
        mov     ds,[bufferSeg]
	push    _bx
        mov     bx,cx
        shr	cx,UNROLL_SHIFT
        inc     cx
        and     bx,UNROLL_COUNT-1
	add     bx,bx
        mov     _ax,[_bx+stereomovelbl]
	pop     _bx
	jmp     _ax
ALIGN 16
@@loop2:
	lbl = UNROLL_COUNT-1
	REPT    UNROLL_COUNT
            mixMove386
            makelabel stereomove,%lbl
            lbl = lbl - 1
        ENDM
        loop    @@loop2
        add     di,2
        jmp     @@exit
@@MIDroutine:
        cmp     [firstChannel1],0
        jne     @@100
        pushad
        call    near @@clearFAST        ;// Clear it first
        popad
@@100:
        cmp     [firstChannel2],0
        jne     @@200
        pushad
	add     di,1
        call    near @@clearFAST        ; Clear it first
        popad
@@200:
        cmp     [realpan],PAN_MIDDLE
        je      @@addroutineMID
@@addroutinePan:
        sub     di,2
	mov     ds,[bufferSeg]
	push    _bx
	mov     bx,cx
	shr	cx,UNROLL_SHIFT
	inc     cx
	and     bx,UNROLL_COUNT-1
	add     bx,bx
        mov     _ax,[_bx+stereoaddlblPan]
	pop     _bx
        push    cx                      ; Put counter into stack
        mov     ch,bl                   ; Other volume is in BL
	and     ecx,0000FFFFh
	jmp     _ax
ALIGN 16
@@loop1Pan:
	lbl = UNROLL_COUNT-1
	REPT    UNROLL_COUNT
            mixAdd386Pan
            makelabel stereoaddPan,%lbl
            lbl = lbl - 1
        ENDM

        dec     [word ss:esp]           ; Counter is in stack
        jnz     @@loop1Pan
        pop     cx
        add     di,2
        jmp     @@exit
@@addroutineMID:
        sub     di,2
        mov     ds,[bufferSeg]
	push    _bx
        mov     bx,cx
        shr	cx,UNROLL_SHIFT
        inc     cx
        and     bx,UNROLL_COUNT-1
	add     bx,bx
        mov     _ax,[_bx+stereoaddlblMID]
	pop     _bx
	jmp     _ax
ALIGN 16
@@loop1MID:
	lbl = UNROLL_COUNT-1
	REPT    UNROLL_COUNT
            mixAdd386MID
            makelabel stereoaddMID,%lbl
            lbl = lbl - 1
        ENDM
        loop    @@loop1MID
        add     di,2
        jmp     @@exit
@@clearFAST:                            ; Fast clearing routine
        PUSHDS
        mov     al,80h
        mov     ds,[bufferseg]
        shr     cx,1
        jnc     @@loopcfast
	mov     [_di],al
        add     di,dx
        jcxz    @@fret
@@loopcfast:
	mov     [_di],al
        add     di,dx
	mov     [_di],al
        add     di,dx
        loop    @@loopcfast
@@fret:
        POPDS
        retn
@@clearMID:
        PUSHDS
        mov     al,80h
        mov     ds,[bufferseg]
@@loopcmid:
	mov     [_di],al
        add     edi,edx
        adc     si,bp
        loop    @@loopcmid
        POPDS
        retn
@@clear:
        and     edi,0000FFFFh
        shl     eax,16
        or      edi,eax                 ; High EDI is quotient
	rol     edx,16
        mov     dx,2                    ; For word addressing (in stereo)
        cmp     [pan],PAN_SURROUND
        je      @@midClear
        cmp     [pan],PAN_MIDDLE
        je      @@midClear
        cmp     [pan],PAN_RIGHT
        je      @@11
        cmp     [firstChannel1],0
        mov     ds,[bufferSeg]
        je      @@loopc1
        jmp     @@loopc2
@@11:
        cmp     [firstChannel2],0
        mov     ds,[bufferSeg]
        je      @@loopc1
@@loopc2:
        add     edi,edx
        adc     si,bp
        loop    @@loopc2
        jmp     @@exit
@@loopc1:
        mov     [byte di],80h
        add     edi,edx
        adc     si,bp
        loop    @@loopc1
        jmp     @@exit
@@midClear:
        cmp     [firstChannel1],0
        jne     @@101
        mov     [tempEDI],edi
        mov     [tempESI],esi
	push    _cx
        call    near @@clearMID         ;// Clear it first
	pop     _cx
        cmp     [firstChannel2],0
        jne     @@exit
        mov     edi,[tempEDI]
        mov     esi,[tempESI]
@@101:
        cmp     [firstChannel2],0
        jne     @@loopc2                ;// Just do the counters..
        add     di,1
        call    near @@clearMID         ;// Clear it first
        sub     di,1
	jmp     @@exit
@@Surround:
        cmp     [firstChannel1],0
        jne     @@s100
        pushad
        call    near @@clearFAST        ;// Clear it first
        popad
@@s100:
        cmp     [firstChannel2],0
        jne     @@s200
        pushad
        add     di,1
        call    near @@clearFAST        ;// Clear it first
        popad
@@s200:
        sub     di,2
        mov     ds,[bufferSeg]
	push    _bx
	mov     bx,cx
	shr	cx,UNROLL_SHIFT
	inc     cx
	and     bx,UNROLL_COUNT-1
	add     bx,bx
        mov     _ax,[_bx+stereoaddlblSrnd]
	pop     _bx
	jmp     _ax
ALIGN 16
@@loop1Srnd:
	lbl = UNROLL_COUNT-1                        ; Surround channel mixer
	REPT    UNROLL_COUNT
            mixAdd386Srnd
            makelabel stereoaddSrnd,%lbl
            lbl = lbl - 1
        ENDM
        loop    @@loop1Srnd
        add     di,2
        jmp     @@exit

@@exit:
        mov     eax,edi
        shr     eax,16                  ; AX = quotient
        POPDS
        ret
ENDP

ELSE

;/***************************************************************************\
;*
;*      32-bit mixing routines
;*
;\***************************************************************************/

MACRO   mixAdd386 sample
        add     eax,edx                 ; increase counters
        mov     bl,[esi]                ; Get byte from sample
        adc     esi,ebp
        mov     al,[es:ebx]             ; Set correct volume
        add     [edi+sample],al         ; Put one byte into buffer
ENDM

MACRO   mixMove386 sample
        add     eax,edx                 ; increase counters
        mov     bl,[esi]                ; Get byte from sample
        adc     esi,ebp
        mov     al,[es:ebx]             ; Set correct volume
        mov     [edi+sample],al         ; Put one byte into buffer
ENDM

MACRO   mixAdd386_2 sample
        add     eax,edx                 ; increase counters
        mov     bl,[esi]                ; Get byte from sample
        adc     esi,ebp
        mov     al,[es:ebx]             ; Set correct volume
        add     eax,edx                 ; increase counters
        mov     bl,[esi]                ; Get byte from sample
        adc     esi,ebp
        mov     ah,[es:ebx]             ; Set correct volume
        add     [edi+sample],ax         ; Put one byte into buffer
ENDM

MACRO   mixMove386_2 sample
        add     eax,edx                 ; increase counters
        mov     bl,[esi]                ; Get byte from sample
        adc     esi,ebp
        mov     al,[es:ebx]             ; Set correct volume
        add     eax,edx                 ; increase counters
        mov     bl,[esi]                ; Get byte from sample
        adc     esi,ebp
        mov     ah,[es:ebx]             ; Set correct volume
        mov     [edi+sample],ax         ; Put one byte into buffer
ENDM

MACRO   mixAdd386Mid sample
        add     eax,edx                 ; increase counters
        mov     bl,[esi]                ; Get byte from sample
        adc     esi,ebp
        mov     al,[es:ebx]             ; Set correct volume
	mov     ah,al
        add     [edi+sample],ax         ; Put one byte into buffer
ENDM

MACRO   mixAdd386Srnd sample
        add     eax,edx                 ; increase counters
        mov     bl,[esi]                ; Get byte from sample
        adc     esi,ebp
        mov     ah,[es:ebx]             ; Set correct volume
        mov     al,ah
        neg     ah
        add     [edi+sample],ax         ; Put one byte into buffer
ENDM

MACRO   mixAdd386Pan sample
        mov     bl,[esi]                ; Get byte from sample
        add     eax,edx                 ; increase counters
        mov     al,[es:ebx]             ; Set correct volume
        mov     cl,bl
        adc     esi,ebp
        mov     ah,[es:ecx]
        add     [edi+sample],ax         ; Put two bytes into buffer
ENDM

;/*************************************************************************
; *
; *     Function    :   routineMono8_386
; *
; *     Description :   Calculates buffer for 8-bit mono cards in 386 mode
; *
; *************************************************************************/

PROC    routineMono8_386 NEAR
        push    es
        mov     es,[bufferSeg]
        jc      @@clear
        and     ebx,0000FFFFh
        and     ebp,0000FFFFh
        shl     eax,16
        shl     edx,16

        cmp     [firstChannel1],0
        je      @@moveroutine

        test    edi,1
        jz      @@EDIok
        mixAdd386 0
        inc     edi
        dec     ecx
        jcxz    @@exit
@@EDIok:
        shr     ecx,1
        jcxz    @@nomore
        pushf
        push    ebx eax
        mov     ebx,ecx
        shr     ecx,UNROLL_SHIFT
        inc     ecx
        and     ebx,UNROLL_COUNT-1
        mov     eax,UNROLL_COUNT
        sub     eax,ebx
        mov     ebx,[ebx*4+monoaddlbl]
        shl     eax,1
        sub     edi,eax
        mov     [jumpAddress],ebx
        pop     eax ebx
        jmp     [jumpAddress]
ALIGN 16
@@loop:
	lbl = UNROLL_COUNT-1
        count = 0
	REPT    UNROLL_COUNT
            mixAdd386_2 count
            makelabel monoadd,%lbl
            lbl = lbl - 1
            count = count + 2
        ENDM
        add     edi,UNROLL_COUNT*2
        dec     ecx
        jnz     @@loop
        popf
@@nomore:
        jnc     @@exit
        mixAdd386 0
        inc     edi
        jmp     @@exit

@@moveroutine:
        sub     bl,bl
        add     ebx,volumeTable2
        test    edi,1
        jz      @@EDIokMove
        mixMove386 0
        inc     edi
        dec     ecx
        jcxz    @@exit
@@EDIokMove:
        shr     ecx,1
        jcxz    @@nomoreMove
        pushf
        push    ebx eax
        mov     ebx,ecx
        shr     ecx,UNROLL_SHIFT
        inc     ecx
        and     ebx,UNROLL_COUNT-1
        mov     eax,UNROLL_COUNT
        sub     eax,ebx
        mov     ebx,[ebx*4+monomovelbl]
        shl     eax,1
        sub     edi,eax
        mov     [jumpAddress],ebx
        pop     eax ebx
        jmp     [jumpAddress]
ALIGN 16
@@loop2:
	lbl = UNROLL_COUNT-1
        count = 0
	REPT    UNROLL_COUNT
            mixMove386_2 count
            makelabel monoMove,%lbl
            lbl = lbl - 1
            count = count + 2
        ENDM
        add     edi,UNROLL_COUNT*2
        dec     ecx
        jnz     @@loop2
        popf
@@nomoreMove:
        jnc     @@exit
        mixMove386 0
        inc     edi
        jmp     @@exit
@@clear:
        and     ebx,0000FFFFh
        shl     eax,16
        shl     edx,16
        mov     al,80h
        cmp     [firstChannel1],0
        jne     @@loopc2
ALIGN 4
@@loopc1:
        add     eax,edx
        mov     [edi],al
        adc     esi,ebp
        inc     edi
        dec     ecx
        jnz     @@loopc1
        jmp     @@exit
ALIGN 4
@@loopc2:
        inc     edi
        add     eax,edx
        adc     esi,ebp
        dec     ecx
        jnz     @@loopc2
@@exit:
        shr     eax,16                  ; AX = quotient
        pop     es
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   routineStereo8_386
; *
; *     Description :   Calculates buffer for 8-bit stereo cards in 386 mode
; *
; *************************************************************************/

PROC    routineStereo8_386 NEAR

        push    es
        mov     es,[bufferSeg]
        jc      @@clear
        and     ebx,0000FFFFh
        and     ebp,0000FFFFh
	shl     eax,16
	shl	edx,16			; High EDX is quotient

        cmp     [pan],PAN_SURROUND
	je      @@Surround
	cmp     [pan],PAN_MIDDLE
	je      @@MIDroutine
	cmp     [pan],PAN_RIGHT
	je      @@10
	cmp     [firstChannel1],0
	je      @@moveroutine
        jmp     @@addroutine
@@10:
	cmp     [firstChannel2],0
	je      @@moveroutine
@@addroutine:
        push    ebx eax
	mov     ebx,ecx
	shr	ecx,UNROLL_SHIFT
	inc     ecx
	and     ebx,UNROLL_COUNT-1
        mov     eax,UNROLL_COUNT
        sub     eax,ebx
        mov     ebx,[ebx*4+stereoaddlbl]
        shl     eax,1
        sub     edi,eax
        mov     [jumpAddress],ebx
        pop     eax ebx
	jmp     [jumpAddress]
ALIGN 16
@@loop1:
	lbl = UNROLL_COUNT-1
        count = 0
	REPT    UNROLL_COUNT
            mixAdd386 count
            makelabel stereoadd,%lbl
	    lbl = lbl - 1
            count = count + 2
        ENDM
        add     edi,UNROLL_COUNT*2
	dec     ecx
	jnz     @@loop1
	jmp     @@exit
@@moveRoutine:
        sub     bl,bl
        add     ebx,volumeTable2
        push    ebx eax
	mov     ebx,ecx
	shr	ecx,UNROLL_SHIFT
	inc     ecx
	and     ebx,UNROLL_COUNT-1
        mov     eax,UNROLL_COUNT
        sub     eax,ebx
        mov     ebx,[ebx*4+stereomovelbl]
        shl     eax,1
        sub     edi,eax
        mov     [jumpAddress],ebx
        pop     eax ebx
	jmp     [jumpAddress]
ALIGN 16
@@loop2:
	lbl = UNROLL_COUNT-1
        count = 0
	REPT    UNROLL_COUNT
            mixMove386 count
            makelabel stereomove,%lbl
	    lbl = lbl - 1
            count = count + 2
        ENDM
        add     edi,UNROLL_COUNT*2
        dec     ecx
	jnz     @@loop2
	jmp     @@exit
@@MIDroutine:                           ;// Middle routines
	cmp     [firstChannel1],0
	jne     @@100
	pushad
	call    near @@clearFAST         ;// Clear it first
	popad
@@100:
	cmp     [firstChannel2],0
	jne     @@200
	pushad
        add     edi,1
	call    near @@clearFAST         ;// Clear it first
	popad
@@200:
	cmp     [realpan],PAN_MIDDLE
	je      @@addroutineMID
@@addroutinePan:
        push    ebx eax
	mov     ebx,ecx
	shr	ecx,UNROLL_SHIFT
	inc     ecx
	and     ebx,UNROLL_COUNT-1
        mov     eax,UNROLL_COUNT
        sub     eax,ebx
        mov     ebx,[ebx*4+stereoaddlblPan]
        shl     eax,1
        sub     edi,eax
        mov     [jumpAddress],ebx
        pop     eax ebx
	mov     [__ecx],ecx
	mov     ch,bl                   ;// Other volume is in BL
	and     ecx,0000FF00h
	jmp     [jumpAddress]
ALIGN 16
@@loop1Pan:
	lbl = UNROLL_COUNT-1
        count = 0
	REPT    UNROLL_COUNT
            mixAdd386Pan count
            makelabel stereoaddPan,%lbl
	    lbl = lbl - 1
            count = count + 2
        ENDM
        add     edi,UNROLL_COUNT*2
	dec     [__ecx]
	jnz     @@loop1Pan
	jmp     @@exit
@@addroutineMID:
        push    ebx eax
	mov     ebx,ecx
	shr	ecx,UNROLL_SHIFT
	inc     ecx
	and     ebx,UNROLL_COUNT-1
        mov     eax,UNROLL_COUNT
        sub     eax,ebx
        mov     ebx,[ebx*4+stereoaddlblMID]
        shl     eax,1
        sub     edi,eax
        mov     [jumpAddress],ebx
        pop     eax ebx
	jmp     [jumpAddress]
ALIGN 16
@@loop1MID:
	lbl = UNROLL_COUNT-1
        count = 0
	REPT    UNROLL_COUNT
            mixAdd386MID count
            makelabel stereoaddMID,%lbl
	    lbl = lbl - 1
            count = count + 2
        ENDM
        add     edi,UNROLL_COUNT*2
        dec     ecx
	jnz     @@loop1MID
	jmp     @@exit

@@clearFAST:                            ; Fast clearing routine
        mov     al,80h
	shr     ecx,1
	jnc     @@loopcfast
        mov     [edi],al
        add     edi,2
	jcxz    @@fret
ALIGN 4
@@loopcfast:
        mov     [edi],al
        add     edi,2
        mov     [edi],al
        add     edi,2
	dec     ecx
	jnz     @@loopcfast
@@fret:
	retn
@@clearMID:
        mov     al,80h
ALIGN 4
@@loopcmid:
        add     eax,edx
        mov     [edi],al
        adc     esi,ebp
        add     edi,2
        dec     ecx
	jnz     @@loopcmid
	retn
@@clear:
	and     ebx,0000FFFFh
        mov     bl,80h
	shl     eax,16
	shl     edx,16
	cmp     [pan],PAN_SURROUND
	je      @@midClear
	cmp     [pan],PAN_MIDDLE
	je      @@midClear
	cmp     [pan],PAN_RIGHT
	je      @@11
	cmp     [firstChannel1],0
	je      @@loopc1
	jmp     @@loopc2
@@11:
	cmp     [firstChannel2],0
	je      @@loopc1
ALIGN 4
@@loopc2:
        add     edi,2
	add	eax,edx
	adc     esi,ebp
	dec     ecx
	jnz     @@loopc2
	jmp     @@exit
ALIGN 4
@@loopc1:
        add     eax,edx
        mov     [edi],bl
        adc     esi,ebp
        add     edi,2
        dec     ecx
	jnz     @@loopc1
	jmp     @@exit
@@midClear:
	cmp     [firstChannel1],0
	jne     @@101
	mov     [tempEDI],edi
	mov     [tempESI],esi
	push    ecx
	call    near @@clearMID         ;// Clear it first
	pop     ecx
	cmp     [firstChannel2],0
	jne     @@exit
	mov     edi,[tempEDI]
	mov     esi,[tempESI]
@@101:
	cmp     [firstChannel2],0
	jne     @@loopc2                ;// Just do the counters..
        add     edi,1
	call    near @@clearMID         ;// Clear it first
        sub     edi,1
	jmp     @@exit
@@Surround:                             ;// Middle routines
	cmp     [firstChannel1],0
	jne     @@s100
	pushad
	call    near @@clearFAST        ;// Clear it first
	popad
@@s100:
	cmp     [firstChannel2],0
	jne     @@s200
	pushad
        add     edi,1
	call    near @@clearFAST        ;// Clear it first
	popad
@@s200:
        push    ebx eax
	mov     ebx,ecx
	shr	ecx,UNROLL_SHIFT
	inc     ecx
	and     ebx,UNROLL_COUNT-1
        mov     eax,UNROLL_COUNT
        sub     eax,ebx
        mov     ebx,[ebx*4+stereoaddlblSrnd]
        shl     eax,1
        sub     edi,eax
        mov     [jumpAddress],ebx
        pop     eax ebx
	jmp     [jumpAddress]
ALIGN 16
@@loop1Srnd:
	lbl = UNROLL_COUNT-1
        count = 0
	REPT    UNROLL_COUNT
            mixAdd386Srnd count
            makelabel stereoaddSrnd,%lbl
	    lbl = lbl - 1
            count = count + 2
	ENDM
        add     edi,UNROLL_COUNT*2
        dec     ecx
	jnz     @@loop1Srnd
	jmp     @@exit
@@exit:
	shr     eax,16                  ; AX = quotient
        pop     es
        ret
ENDP

ENDIF

IFDEF __16__

;/***************************************************************************\
;*
;*      16-bit mixing routines for 16-bit code
;*
;\***************************************************************************/

MACRO   mixAdd16_386
        mov     bl,[ESSI]               ; Get byte from sample
        add     edi,edx
        mov     ax,[ebx+ebx]              ; Set correct volume
        adc     si,bp
        add     [di],ax
ENDM

MACRO   mixMove16_386
        mov     bl,[ESSI]               ; Get byte from sample
        add     edi,edx
        mov     ax,[ebx+ebx]              ; Set correct volume
        adc     si,bp
        mov     [di],ax
ENDM

MACRO   mixAdd16_386Mid
        add     edi,edx
        mov     bl,[ESSI]               ; Get byte from sample
        adc     si,bp
        mov     ax,[ebx+ebx]              ; Set correct volume
        add     [di],ax
        add     [di+2],ax
ENDM

MACRO   mixAdd16_386Srnd
        add     edi,edx
        mov     bl,[ESSI]               ; Get byte from sample
        adc     si,bp
        mov     ax,[ebx+ebx]              ; Set correct volume
        add     [di],ax
        sub     [di+2],ax               ; Phase shift 180 degrees
ENDM

MACRO   mixAdd16_386Pan
        add     edi,edx
        mov     cl,[ESSI]               ; Get byte from sample
        adc     si,bp
        mov     ax,[ecx+ecx]            ; Set correct volume
	shl     eax,16
        mov     bl,cl
        mov     ax,[ebx+ebx]
        add     [di],eax
ENDM

;/*************************************************************************
; *
; *     Function    :   routineMono16_386
; *
; *     Description :   Calculates buffer for 16-bit mono cards in 386 mode
; *
; *************************************************************************/

PROC    routineMono16_386 NEAR

        PUSHDS
        jc      @@clear
        and     ebx,0000FFFFh
        and     edi,0000FFFFh
        shl     eax,16
        or      edi,eax                 ; High EDI is quotient
        rol     edx,16
        mov     dx,2

        cmp     [firstChannel1],0
        je      @@moveroutine

        mov     ds,[bufferSeg]

        sub     di,2
        push    bx
	mov     bx,cx
        shr	cx,UNROLL_SHIFT
        inc     cx
        and     bx,UNROLL_COUNT-1
	add     bx,bx
        mov     ax,[_bx+monoadd16lbl386]
        pop     bx
        jmp     ax
ALIGN 16
@@loop:
	lbl = UNROLL_COUNT-1
	REPT    UNROLL_COUNT
            mixAdd16_386
            makelabel monoadd16_386,%lbl
            lbl = lbl - 1
        ENDM
        dec     cx
        jnz     @@loop
        add     di,2
        jmp     @@exit

@@moveroutine:
        mov     ds,[bufferSeg]

        sub     di,2
	push    _bx
	mov     bx,cx
	shr	cx,UNROLL_SHIFT
	inc     cx
	and     bx,UNROLL_COUNT-1
	add     bx,bx
        mov     ax,[_bx+monomove16lbl386]
	pop     _bx
	jmp     _ax
ALIGN 16
@@loop2:
	lbl = UNROLL_COUNT-1
	REPT    UNROLL_COUNT
            mixMove16_386
            makelabel monoMove16_386,%lbl
            lbl = lbl - 1
        ENDM
        dec     cx
        jnz     @@loop2
	add     di,2
        jmp     @@exit
@@clear:
        and     ebx,0000FFFFh
        and     edi,0000FFFFh
        shl     eax,16
        or      edi,eax                 ; High EDI is quotient
	rol     edx,16
	mov     dx,2
        cmp     [firstChannel1],0
        mov     ds,[bufferSeg]
        jne     @@loopc2
ALIGN 4
@@loopc1:
        mov     [word di],0
        add     edi,edx
        adc     si,bp
        dec     cx
        jnz     @@loopc1
        jmp     @@exit
ALIGN 4
@@loopc2:
        add     edi,edx
        adc     si,bp
        dec     cx
        jnz     @@loopc2
@@exit:
        mov     eax,edi
        shr     eax,16                  ; AX = quotient
        POPDS
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   routineStereo16_386
; *
; *     Description :   Calculates buffer for 16-bit stereo cards in 386 mode
; *
; *************************************************************************/

PROC    routineStereo16_386 NEAR

        PUSHDS
        jc      @@clear
        and     edi,0000FFFFh
        and     ebx,0000FFFFh
	shl     eax,16
        or      edi,eax                 ; High EDI is quotient
        rol     edx,16
        mov     dx,4                    ; For dword addressing (in stereo)

	cmp     [pan],PAN_SURROUND
        je      @@Surround
        cmp     [pan],PAN_MIDDLE
        je      @@MIDroutine
        cmp     [pan],PAN_RIGHT
        je      @@10
        cmp     [firstChannel1],0
        je      @@moveroutine
        jmp     @@addroutine
@@10:
        cmp     [firstChannel2],0
        je      @@moveroutine
@@addroutine:
        sub     di,4
        mov     ds,[bufferSeg]
        push    bx
        mov     bx,cx
        shr     cx,UNROLL_SHIFT
        inc     cx
        and     bx,UNROLL_COUNT-1
	add     bx,bx
        mov     ax,[bx+stereoadd16lbl386]
        pop     bx
        jmp     ax
ALIGN 16
@@loop1:
	lbl = UNROLL_COUNT-1
	REPT    UNROLL_COUNT
            mixAdd16_386
            makelabel stereoadd16_386,%lbl
	    lbl = lbl - 1
	ENDM
        dec     cx
	jnz     @@loop1
        add     di,4
	jmp     @@exit
@@moveRoutine:
        sub     di,4
	mov     ds,[bufferSeg]
        push    bx
        mov     bx,cx
        shr     cx,UNROLL_SHIFT
        inc     cx
        and     bx,UNROLL_COUNT-1
	add     bx,bx
        mov     ax,[bx+stereomove16lbl386]
        pop     bx
        jmp     ax
ALIGN 16
@@loop2:
	lbl = UNROLL_COUNT-1
	REPT    UNROLL_COUNT
            mixMove16_386
            makelabel stereomove16_386,%lbl
	    lbl = lbl - 1
	ENDM
        dec     cx
	jnz     @@loop2
        add     di,4
        jmp     @@exit
@@MIDroutine:                           ;// Middle routines
	cmp     [firstChannel1],0
	jne     @@100
	pushad
	call    near @@clearMID         ;// Clear it first
	popad
@@100:
	cmp     [firstChannel2],0
	jne     @@200
	pushad
        add     di,2
	call    near @@clearMID         ;// Clear it first
	popad
@@200:
	cmp     [realpan],PAN_MIDDLE
	je      @@addroutineMID
@@addroutinePan:
        sub     di,4
	mov     ds,[bufferSeg]
        push    bx
        mov     bx,cx
        shr     cx,UNROLL_SHIFT
        inc     cx
        and     bx,UNROLL_COUNT-1
	add     bx,bx
        mov     ax,[bx+stereoadd16lbl386Pan]
        pop     bx
        push    cx                      ;Put counter into stack
        mov     ch,bl                   ;// Other volume is in BL
	and     ecx,0000FFFFh
        jmp     ax
ALIGN 16
@@loop1Pan:
	lbl = UNROLL_COUNT-1
	REPT    UNROLL_COUNT
            mixAdd16_386Pan
            makelabel stereoadd16_386Pan,%lbl
	    lbl = lbl - 1
	ENDM

        dec     [word ss:esp]           ; Counter is in stack
        jnz     @@loop1Pan
        pop     cx
        add     di,4
	jmp     @@exit
@@addroutineMID:
        sub     di,4
	mov     ds,[bufferSeg]
        push    bx
        mov     bx,cx
        shr     cx,UNROLL_SHIFT
        inc     cx
        and     bx,UNROLL_COUNT-1
	add     bx,bx
        mov     ax,[bx+stereoadd16lbl386MID]
        pop     bx
        jmp     ax
ALIGN 16
@@loop1MID:
	lbl = UNROLL_COUNT-1
	REPT    UNROLL_COUNT
            mixAdd16_386MID
            makelabel stereoadd16_386MID,%lbl
	    lbl = lbl - 1
	ENDM
        dec     cx
	jnz     @@loop1MID
        add     di,4
	jmp     @@exit

@@clearFAST:                            ; Fast clearing routine
	PUSHDS
        sub     ax,ax
	mov     ds,[bufferseg]
        shr     cx,1
	jnc     @@loopcfast
        mov     [di],ax
        add     di,dx
	jcxz    @@fret
ALIGN 4
@@loopcfast:
        mov     [di],ax
        add     di,dx
        mov     [di],ax
        add     di,dx
        dec     cx
	jnz     @@loopcfast
@@fret:
	POPDS
	retn
@@clearMID:
	PUSHDS
        sub     ax,ax
	mov     ds,[bufferseg]
ALIGN 4
@@loopcmid:
        mov     [di],ax
	add     edi,edx
        adc     si,bp
        dec     cx
	jnz     @@loopcmid
	POPDS
	retn
@@clear:
	and     edi,0000FFFFh
	and     ebx,0000FFFFh
	shl     eax,16
	or      edi,eax                 ; High EDI is quotient
	rol     edx,16
        mov     dx,4                   ; For word addressing (in stereo)
	cmp     [pan],PAN_SURROUND
	je      @@midClear
	cmp     [pan],PAN_MIDDLE
	je      @@midClear
	cmp     [pan],PAN_RIGHT
	je      @@11
	cmp     [firstChannel1],0
	mov     ds,[bufferSeg]
	je      @@loopc1
	jmp     @@loopc2
@@11:
	cmp     [firstChannel2],0
	mov     ds,[bufferSeg]
	je      @@loopc1
ALIGN 4
@@loopc2:
	add     edi,edx
        adc     si,bp
        dec     cx
	jnz     @@loopc2
	jmp     @@exit
ALIGN 4
@@loopc1:
	mov     [word di],0h
	add     edi,edx
        adc     si,bp
        dec     cx
	jnz     @@loopc1
	jmp     @@exit
@@midClear:
	cmp     [firstChannel1],0
	jne     @@101
	mov     [tempEDI],edi
	mov     [tempESI],esi
        push    cx
	call    near @@clearMID         ;// Clear it first
        pop     cx
	cmp     [firstChannel2],0
	jne     @@exit
	mov     edi,[tempEDI]
	mov     esi,[tempESI]
@@101:
	cmp     [firstChannel2],0
	jne     @@loopc2                ;// Just do the counters..
        add     di,2
	call    near @@clearMID         ;// Clear it first
        sub     di,2
	jmp     @@exit
@@Surround:                             ;// Middle routines
	cmp     [firstChannel1],0
	jne     @@s100
	pushad
	call    near @@clearFAST        ;// Clear it first
	popad
@@s100:
	cmp     [firstChannel2],0
	jne     @@s200
	pushad
        add     di,2
	call    near @@clearFAST        ;// Clear it first
	popad
@@s200:
        sub     di,4
	mov     ds,[bufferSeg]
        push    bx
        mov     bx,cx
        shr     cx,UNROLL_SHIFT
        inc     cx
        and     bx,UNROLL_COUNT-1
	add     bx,bx
        mov     ax,[bx+stereoadd16lbl386Srnd]
        pop     bx
        jmp     ax
ALIGN 16
@@loop1Srnd:
	lbl = UNROLL_COUNT-1
	REPT    UNROLL_COUNT
            mixAdd16_386Srnd
            makelabel stereoadd16_386Srnd,%lbl
	    lbl = lbl - 1
	ENDM
        dec     cx
	jnz     @@loop1Srnd
        add     di,4
	jmp     @@exit
@@exit:
	mov     eax,edi
	shr     eax,16                  ; AX = quotient
	POPDS
	ret
ENDP

ELSE

;/***************************************************************************\
;*
;*      32-bit mixing routines for 16-bit cards
;*
;\***************************************************************************/


MACRO   mixAdd16_386 sample
        add     eax,edx
        mov     bl,[esi]                ; Get byte from sample
        adc     esi,ebp
        mov     ax,[es:ebx+ebx]         ; Set correct volume
        add     [edi+sample],ax
ENDM

MACRO   mixMove16_386 sample
        add     eax,edx
        mov     bl,[esi]                ; Get byte from sample
        adc     esi,ebp
        mov     ax,[es:ebx+ebx]         ; Set correct volume
        mov     [edi+sample],ax
ENDM

MACRO   mixAdd16_386Mid sample
        add     eax,edx
        mov     bl,[esi]                ; Get byte from sample
        adc     esi,ebp
        mov     ax,[es:ebx+ebx]         ; Set correct volume
        add     [edi+sample],ax
        add     [edi+2+sample],ax
ENDM

MACRO   mixAdd16_386Srnd sample
        add     eax,edx
        mov     bl,[esi]                ; Get byte from sample
        adc     esi,ebp
        mov     ax,[es:ebx+ebx]         ; Set correct volume
        add     [edi+sample],ax
        sub     [edi+2+sample],ax       ; Phase shift 180 degrees
ENDM

MACRO   mixAdd16_386Pan sample
        add     eax,edx
        mov     bl,[esi]                ; Get byte from sample
        adc     esi,ebp
        mov     ax,[es:ebx+ebx]         ; Set correct volume
        add     [edi+sample],ax
        mov     cl,bl
        mov     ax,[es:ecx+ecx]
        add     [edi+2+sample],ax
ENDM

;/*************************************************************************
; *
; *     Function    :   routineMono16_386
; *
; *     Description :   Calculates buffer for 16-bit mono cards in 386 mode
; *
; *************************************************************************/

PROC    routineMono16_386 NEAR

        push    es
        mov     es,[bufferSeg]
        jc      @@clear
        and     ebx,0000FFFFh
        and     ebp,0000FFFFh
        shl     eax,16
        shl     edx,16

        cmp     [firstChannel1],0
        je      @@moveroutine

        push    ebx eax
        mov     ebx,ecx
        shr     ecx,UNROLL_SHIFT
        inc     ecx
        and     ebx,UNROLL_COUNT-1
        mov     eax,UNROLL_COUNT
        sub     eax,ebx
        mov     ebx,[ebx*4+monoadd16lbl386]
        shl     eax,1
        sub     edi,eax
        mov     [jumpAddress],ebx
        pop     eax ebx
        jmp     [jumpAddress]
ALIGN 16
@@loop:
	lbl = UNROLL_COUNT-1
        count = 0
	REPT    UNROLL_COUNT
            mixAdd16_386 count
            makelabel monoadd16_386,%lbl
            lbl = lbl - 1
            count = count + 2
        ENDM
        add     edi,UNROLL_COUNT*2
        dec     ecx
        jnz     @@loop
        jmp     @@exit

@@moveroutine:
        push    ebx eax
        mov     ebx,ecx
        shr     ecx,UNROLL_SHIFT
        inc     ecx
        and     ebx,UNROLL_COUNT-1
        mov     eax,UNROLL_COUNT
        sub     eax,ebx
        mov     ebx,[ebx*4+monomove16lbl386]
        shl     eax,1
        sub     edi,eax
        mov     [jumpAddress],ebx
        pop     eax ebx
        jmp     [jumpAddress]
ALIGN 16
@@loop2:
	lbl = UNROLL_COUNT-1
        count = 0
	REPT    UNROLL_COUNT
            mixMove16_386 count
            makelabel monoMove16_386,%lbl
            lbl = lbl - 1
            count = count + 2
        ENDM
        add     edi,UNROLL_COUNT*2
        dec     ecx
        jnz     @@loop2
        jmp     @@exit
@@clear:
        and     ebx,0000FFFFh
        shl     eax,16
        shl     edx,16
        cmp     [firstChannel1],0
        jne     @@loopc2
ALIGN 4
@@loopc1:
        mov     [word edi],0
        add     edi,2
        add     eax,edx
        adc     esi,ebp
        loop    @@loopc1
        jmp     @@exit
ALIGN 4
@@loopc2:
        add     edi,2
        add     eax,edx
        adc     esi,ebp
        loop    @@loopc2
@@exit:
        shr     eax,16                  ; AX = quotient
        pop     es
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   routineStereo16_386
; *
; *     Description :   Calculates buffer for 16-bit stereo cards in 386 mode
; *
; *************************************************************************/

PROC    routineStereo16_386 NEAR

        push    es
        mov     es,[bufferSeg]
        jc      @@clear
        and     ebx,0000FFFFh
        and     ebp,0000FFFFh
	shl     eax,16
	shl	edx,16			; High EDX is quotient

        cmp     [pan],PAN_SURROUND
	je      @@Surround
	cmp     [pan],PAN_MIDDLE
	je      @@MIDroutine
	cmp     [pan],PAN_RIGHT
	je      @@10
	cmp     [firstChannel1],0
	je      @@moveroutine
        jmp     @@addroutine
@@10:
	cmp     [firstChannel2],0
	je      @@moveroutine
@@addroutine:
        push    ebx eax
	mov     ebx,ecx
	shr	ecx,UNROLL_SHIFT
	inc     ecx
	and     ebx,UNROLL_COUNT-1
        mov     eax,UNROLL_COUNT
        sub     eax,ebx
        mov     ebx,[ebx*4+stereoadd16lbl386]
        shl     eax,2
        sub     edi,eax
        mov     [jumpAddress],ebx
        pop     eax ebx
	jmp     [jumpAddress]
ALIGN 16
@@loop1:
	lbl = UNROLL_COUNT-1
        count = 0
	REPT    UNROLL_COUNT
            mixAdd16_386 count
            makelabel stereoadd16_386,%lbl
	    lbl = lbl - 1
            count = count + 4
        ENDM
        add     edi,UNROLL_COUNT*4
	dec     ecx
	jnz     @@loop1
	jmp     @@exit
@@moveRoutine:
        push    ebx eax
	mov     ebx,ecx
	shr	ecx,UNROLL_SHIFT
	inc     ecx
	and     ebx,UNROLL_COUNT-1
        mov     eax,UNROLL_COUNT
        sub     eax,ebx
        mov     ebx,[ebx*4+stereomove16lbl386]
        shl     eax,2
        sub     edi,eax
        mov     [jumpAddress],ebx
        pop     eax ebx
	jmp     [jumpAddress]
ALIGN 16
@@loop2:
	lbl = UNROLL_COUNT-1
        count = 0
	REPT    UNROLL_COUNT
            mixMove16_386 count
            makelabel stereomove16_386,%lbl
	    lbl = lbl - 1
            count = count + 4
        ENDM
        add     edi,UNROLL_COUNT*4
        dec     ecx
	jnz     @@loop2
	jmp     @@exit
@@MIDroutine:                           ;// Middle routines
	cmp     [firstChannel1],0
	jne     @@100
	pushad
	call    near @@clearFAST         ;// Clear it first
	popad
@@100:
	cmp     [firstChannel2],0
	jne     @@200
	pushad
	add     edi,2
	call    near @@clearFAST         ;// Clear it first
	popad
@@200:
	cmp     [realpan],PAN_MIDDLE
	je      @@addroutineMID
@@addroutinePan:
        push    ebx eax
	mov     ebx,ecx
	shr	ecx,UNROLL_SHIFT
	inc     ecx
	and     ebx,UNROLL_COUNT-1
        mov     eax,UNROLL_COUNT
        sub     eax,ebx
        mov     ebx,[ebx*4+stereoadd16lbl386Pan]
        shl     eax,2
        sub     edi,eax
        mov     [jumpAddress],ebx
        pop     eax ebx
	mov     [__ecx],ecx
	mov     ch,bl                   ;// Other volume is in BL
	and     ecx,0000FF00h
	jmp     [jumpAddress]
ALIGN 16
@@loop1Pan:
	lbl = UNROLL_COUNT-1
        count = 0
	REPT    UNROLL_COUNT
            mixAdd16_386Pan count
            makelabel stereoadd16_386Pan,%lbl
	    lbl = lbl - 1
            count = count + 4
        ENDM
        add     edi,UNROLL_COUNT*4
	dec     [__ecx]
	jnz     @@loop1Pan
	jmp     @@exit
@@addroutineMID:
        push    ebx eax
	mov     ebx,ecx
	shr	ecx,UNROLL_SHIFT
	inc     ecx
	and     ebx,UNROLL_COUNT-1
        mov     eax,UNROLL_COUNT
        sub     eax,ebx
        mov     ebx,[ebx*4+stereoadd16lbl386MID]
        shl     eax,2
        sub     edi,eax
        mov     [jumpAddress],ebx
        pop     eax ebx
	jmp     [jumpAddress]
ALIGN 16
@@loop1MID:
	lbl = UNROLL_COUNT-1
        count = 0
	REPT    UNROLL_COUNT
            mixAdd16_386MID count
            makelabel stereoadd16_386MID,%lbl
	    lbl = lbl - 1
            count = count + 4
        ENDM
        add     edi,UNROLL_COUNT*4
        dec     ecx
	jnz     @@loop1MID
	jmp     @@exit

@@clearFAST:                            ; Fast clearing routine
	sub     eax,eax
	shr     ecx,1
	jnc     @@loopcfast
	mov     [edi],ax
        add     edi,4
	jcxz    @@fret
ALIGN 4
@@loopcfast:
	mov     [edi],ax
	add     edi,4
	mov     [edi],ax
	add     edi,4
	dec     ecx
	jnz     @@loopcfast
@@fret:
	retn
@@clearMID:
        sub     eax,eax
ALIGN 4
@@loopcmid:
	mov     [edi],ax
	add     edi,4
	add	eax,edx
	adc     esi,ebp
	dec     ecx
	jnz     @@loopcmid
	retn
@@clear:
        sub     ebx,ebx
        shl     eax,16
	shl     edx,16
	cmp     [pan],PAN_SURROUND
	je      @@midClear
	cmp     [pan],PAN_MIDDLE
	je      @@midClear
	cmp     [pan],PAN_RIGHT
	je      @@11
	cmp     [firstChannel1],0
	je      @@loopc1
	jmp     @@loopc2
@@11:
	cmp     [firstChannel2],0
	je      @@loopc1
ALIGN 4
@@loopc2:
	add     edi,4
	add	eax,edx
	adc     esi,ebp
	dec     ecx
	jnz     @@loopc2
	jmp     @@exit
ALIGN 4
@@loopc1:
        mov     [word edi],bx
	add     edi,4
	add	eax,edx
	adc     esi,ebp
	dec     ecx
	jnz     @@loopc1
	jmp     @@exit
@@midClear:
	cmp     [firstChannel1],0
	jne     @@101
	mov     [tempEDI],edi
	mov     [tempESI],esi
	push    ecx
	call    near @@clearMID         ;// Clear it first
	pop     ecx
	cmp     [firstChannel2],0
	jne     @@exit
	mov     edi,[tempEDI]
	mov     esi,[tempESI]
@@101:
	cmp     [firstChannel2],0
	jne     @@loopc2                ;// Just do the counters..
	add     edi,2
	call    near @@clearMID         ;// Clear it first
	sub     edi,2
	jmp     @@exit
@@Surround:                             ;// Middle routines
	cmp     [firstChannel1],0
	jne     @@s100
	pushad
	call    near @@clearFAST        ;// Clear it first
	popad
@@s100:
	cmp     [firstChannel2],0
	jne     @@s200
	pushad
	add     edi,2
	call    near @@clearFAST        ;// Clear it first
	popad
@@s200:
        push    ebx eax
	mov     ebx,ecx
	shr	ecx,UNROLL_SHIFT
	inc     ecx
	and     ebx,UNROLL_COUNT-1
        mov     eax,UNROLL_COUNT
        sub     eax,ebx
        mov     ebx,[ebx*4+stereoadd16lbl386Srnd]
        shl     eax,2
        sub     edi,eax
        mov     [jumpAddress],ebx
        pop     eax ebx
	jmp     [jumpAddress]
ALIGN 16
@@loop1Srnd:
	lbl = UNROLL_COUNT-1
        count = 0
	REPT    UNROLL_COUNT
            mixAdd16_386Srnd count
            makelabel stereoadd16_386Srnd,%lbl
	    lbl = lbl - 1
            count = count + 4
	ENDM
        add     edi,UNROLL_COUNT*4
        dec     ecx
	jnz     @@loop1Srnd
	jmp     @@exit
@@exit:
	shr     eax,16                  ; AX = quotient
        pop     es
	ret
ENDP

ENDIF

IFDEF QUALITY16

IFDEF __16__

;/***************************************************************************\
;*
;*      Quality mode 16-bit mixing routines for 16-bit code
;*
;\***************************************************************************/

MACRO   mixAdd16_386Q
        mov     bl,[ESSI]               ; Get byte from sample
        add     edi,edx
        mov     eax,[ebx*4]             ; Set correct volume
        adc     si,bp
        add     [di],eax
ENDM

MACRO   mixMove16_386Q
        mov     bl,[ESSI]               ; Get byte from sample
        add     edi,edx
        mov     eax,[ebx*4]             ; Set correct volume
        adc     si,bp
        mov     [di],eax
ENDM

MACRO   mixAdd16_386MidQ
        add     edi,edx
        mov     bl,[ESSI]               ; Get byte from sample
        adc     si,bp
        mov     eax,[ebx*4]             ; Set correct volume
        add     [di],eax
        add     [di+4],eax
ENDM

MACRO   mixAdd16_386SrndQ
        add     edi,edx
        mov     bl,[ESSI]               ; Get byte from sample
        adc     si,bp
        mov     eax,[ebx*4]             ; Set correct volume
        add     [di],eax
        sub     [di+4],eax              ; Phase shift 180 degrees
ENDM

MACRO   mixAdd16_386PanQ
        add     edi,edx
        mov     bl,[ESSI]               ; Get byte from sample
        adc     si,bp
        mov     eax,[ebx*4]             ; Set correct volume
        add     [di],eax
        mov     cl,bl
        mov     eax,[ecx*4]
        add     [di+4],eax
ENDM

;/*************************************************************************
; *
; *     Function    :   routineMono16_386
; *
; *     Description :   Calculates buffer for 16-bit mono cards in 386/Q mode
; *
; *************************************************************************/

PROC    routineMono16_386Q NEAR

        PUSHDS
        jc      @@clear
        and     ebx,0000FFFFh
        and     edi,0000FFFFh
        shl     eax,16
        or      edi,eax                 ; High EDI is quotient
        rol     edx,16
        mov     dx,4

        cmp     [firstChannel1],0
        je      @@moveroutine

        mov     ds,[bufferSeg]

        sub     di,4
        push    bx
	mov     bx,cx
        shr	cx,UNROLL_SHIFT
        inc     cx
        and     bx,UNROLL_COUNT-1
	add     bx,bx
        mov     ax,[bx+monoadd16lbl386Q]
        pop     bx
        jmp     ax
ALIGN 16
@@loop:
	lbl = UNROLL_COUNT-1
	REPT    UNROLL_COUNT
            mixAdd16_386Q
            makelabel monoadd16_386Q,%lbl
            lbl = lbl - 1
        ENDM
        dec     cx
        jnz     @@loop
        add     di,4
        jmp     @@exit

@@moveroutine:
        mov     ds,[bufferSeg]

        sub     di,4
        push    bx
	mov     bx,cx
	shr	cx,UNROLL_SHIFT
	inc     cx
	and     bx,UNROLL_COUNT-1
	add     bx,bx
        mov     ax,[bx+monomove16lbl386Q]
        pop     bx
        jmp     ax
ALIGN 16
@@loop2:
	lbl = UNROLL_COUNT-1
	REPT    UNROLL_COUNT
            mixMove16_386Q
            makelabel monoMove16_386Q,%lbl
            lbl = lbl - 1
        ENDM
        dec     cx
        jnz     @@loop2
        add     di,4
        jmp     @@exit
@@clear:
        and     ebx,0000FFFFh
        and     edi,0000FFFFh
        shl     eax,16
        or      edi,eax                 ; High EDI is quotient
	rol     edx,16
        mov     dx,4
        sub     eax,eax
        cmp     [firstChannel1],0
        mov     ds,[bufferSeg]
        jne     @@loopc2
ALIGN 4
@@loopc1:
        mov     [di],eax
        add     edi,edx
        adc     si,bp
        dec     cx
        jnz     @@loopc1
        jmp     @@exit
ALIGN 4
@@loopc2:
        add     edi,edx
        adc     si,bp
        dec     cx
        jnz     @@loopc2
@@exit:
        mov     eax,edi
        shr     eax,16                  ; AX = quotient
        POPDS
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   routineStereo16_386
; *
; *     Description :   Calculates buffer for 16-bit stereo cards in 386 mode
; *
; *************************************************************************/

PROC    routineStereo16_386Q NEAR

        PUSHDS
        jc      @@clear
        and     edi,0000FFFFh
        and     ebx,0000FFFFh
	shl     eax,16
        or      edi,eax                 ; High EDI is quotient
        rol     edx,16
        mov     dx,8                    ; For qword addressing (in stereo)

	cmp     [pan],PAN_SURROUND
        je      @@Surround
        cmp     [pan],PAN_MIDDLE
        je      @@MIDroutine
        cmp     [pan],PAN_RIGHT
        je      @@10
        cmp     [firstChannel1],0
        je      @@moveroutine
        jmp     @@addroutine
@@10:
        cmp     [firstChannel2],0
        je      @@moveroutine
@@addroutine:
        sub     di,8
        mov     ds,[bufferSeg]
        push    bx
        mov     bx,cx
        shr     cx,UNROLL_SHIFT
        inc     cx
        and     bx,UNROLL_COUNT-1
	add     bx,bx
        mov     ax,[bx+stereoadd16lbl386Q]
        pop     bx
        jmp     ax
ALIGN 16
@@loop1:
	lbl = UNROLL_COUNT-1
	REPT    UNROLL_COUNT
            mixAdd16_386Q
            makelabel stereoadd16_386Q,%lbl
	    lbl = lbl - 1
	ENDM
        dec     cx
	jnz     @@loop1
        add     di,8
	jmp     @@exit
@@moveRoutine:
        sub     di,8
	mov     ds,[bufferSeg]
        push    bx
        mov     bx,cx
        shr     cx,UNROLL_SHIFT
        inc     cx
        and     bx,UNROLL_COUNT-1
	add     bx,bx
        mov     ax,[bx+stereomove16lbl386Q]
        pop     bx
        jmp     ax
ALIGN 16
@@loop2:
	lbl = UNROLL_COUNT-1
	REPT    UNROLL_COUNT
            mixMove16_386Q
            makelabel stereomove16_386Q,%lbl
	    lbl = lbl - 1
	ENDM
        dec     cx
	jnz     @@loop2
        add     di,8
        jmp     @@exit
@@MIDroutine:                           ;// Middle routines
	cmp     [firstChannel1],0
	jne     @@100
	pushad
	call    near @@clearMID         ;// Clear it first
	popad
@@100:
	cmp     [firstChannel2],0
	jne     @@200
	pushad
        add     di,4
	call    near @@clearMID         ;// Clear it first
	popad
@@200:
	cmp     [realpan],PAN_MIDDLE
	je      @@addroutineMID
@@addroutinePan:
        sub     di,8
	mov     ds,[bufferSeg]
        push    bx
        mov     bx,cx
        shr     cx,UNROLL_SHIFT
        inc     cx
        and     bx,UNROLL_COUNT-1
	add     bx,bx
        mov     ax,[bx+stereoadd16lbl386PanQ]
        pop     bx
        and     esp,0000FFFFh           ; Mask upper 16 bits
        push    cx                      ; Put counter into stack
	mov     ch,bl                   ;// Other volume is in BL
	and     ecx,0000FFFFh
        jmp     ax
ALIGN 16
@@loop1Pan:
	lbl = UNROLL_COUNT-1
	REPT    UNROLL_COUNT
            mixAdd16_386PanQ
            makelabel stereoadd16_386PanQ,%lbl
	    lbl = lbl - 1
	ENDM

        dec     [word ss:esp]           ; Counter is in stack
        jnz     @@loop1Pan
        pop     cx                      ; Pop counter
        add     di,8
	jmp     @@exit
@@addroutineMID:
        sub     di,8
	mov     ds,[bufferSeg]
        push    bx
        mov     bx,cx
        shr     cx,UNROLL_SHIFT
        inc     cx
        and     bx,UNROLL_COUNT-1
	add     bx,bx
        mov     ax,[bx+stereoadd16lbl386MIDQ]
        pop     bx
        jmp     ax
ALIGN 16
@@loop1MID:
	lbl = UNROLL_COUNT-1
	REPT    UNROLL_COUNT
            mixAdd16_386MIDQ
            makelabel stereoadd16_386MIDQ,%lbl
	    lbl = lbl - 1
	ENDM
        dec     cx
	jnz     @@loop1MID
        add     di,8
	jmp     @@exit

@@clearFAST:                            ; Fast clearing routine
	PUSHDS
        sub     eax,eax
	mov     ds,[bufferseg]
        shr     cx,1
	jnc     @@loopcfast
        mov     [di],eax
        add     di,dx
	jcxz    @@fret
ALIGN 4
@@loopcfast:
        mov     [di],eax
        add     di,dx
        mov     [di],eax
        add     di,dx
        dec     cx
	jnz     @@loopcfast
@@fret:
	POPDS
	retn
@@clearMID:
	PUSHDS
        sub     eax,eax
	mov     ds,[bufferseg]
ALIGN 4
@@loopcmid:
        mov     [di],eax
	add     edi,edx
        adc     si,bp
        dec     cx
	jnz     @@loopcmid
	POPDS
	retn
@@clear:
	and     edi,0000FFFFh
	and     ebx,0000FFFFh
	shl     eax,16
	or      edi,eax                 ; High EDI is quotient
	rol     edx,16
        mov     dx,8                    ; For qword addressing (in stereo)
        sub     eax,eax
        cmp     [pan],PAN_SURROUND
	je      @@midClear
	cmp     [pan],PAN_MIDDLE
	je      @@midClear
	cmp     [pan],PAN_RIGHT
        je      @@11
        cmp     [firstChannel1],0
	mov     ds,[bufferSeg]
	je      @@loopc1
	jmp     @@loopc2
@@11:
	cmp     [firstChannel2],0
	mov     ds,[bufferSeg]
	je      @@loopc1
ALIGN 4
@@loopc2:
	add     edi,edx
        adc     si,bp
        dec     cx
	jnz     @@loopc2
	jmp     @@exit
ALIGN 4
@@loopc1:
        mov     [dword di],eax
	add     edi,edx
        adc     si,bp
        dec     cx
	jnz     @@loopc1
	jmp     @@exit
@@midClear:
	cmp     [firstChannel1],0
	jne     @@101
	mov     [tempEDI],edi
	mov     [tempESI],esi
        push    cx
	call    near @@clearMID         ;// Clear it first
        pop     cx
	cmp     [firstChannel2],0
	jne     @@exit
	mov     edi,[tempEDI]
	mov     esi,[tempESI]
@@101:
	cmp     [firstChannel2],0
	jne     @@loopc2                ;// Just do the counters..
        add     di,4
	call    near @@clearMID         ;// Clear it first
        sub     di,4
	jmp     @@exit
@@Surround:                             ;// Middle routines
	cmp     [firstChannel1],0
	jne     @@s100
	pushad
	call    near @@clearFAST        ;// Clear it first
	popad
@@s100:
	cmp     [firstChannel2],0
	jne     @@s200
	pushad
        add     di,4
	call    near @@clearFAST        ;// Clear it first
	popad
@@s200:
        sub     di,8
	mov     ds,[bufferSeg]
        push    bx
        mov     bx,cx
        shr     cx,UNROLL_SHIFT
        inc     cx
        and     bx,UNROLL_COUNT-1
	add     bx,bx
        mov     ax,[bx+stereoadd16lbl386SrndQ]
        pop     bx
        jmp     ax
ALIGN 16
@@loop1Srnd:
	lbl = UNROLL_COUNT-1
	REPT    UNROLL_COUNT
            mixAdd16_386SrndQ
            makelabel stereoadd16_386SrndQ,%lbl
	    lbl = lbl - 1
	ENDM
        dec     cx
	jnz     @@loop1Srnd
        add     di,8
	jmp     @@exit
@@exit:
	mov     eax,edi
	shr     eax,16                  ; AX = quotient
	POPDS
	ret
ENDP

ELSE

;/***************************************************************************\
;*
;*      Quality mode 16-bit mixing routines for 32-bit code
;*
;\***************************************************************************/

MACRO   mixAdd16_386Q sample
        add     ecx,edx
        mov     bl,[esi]                ; Get byte from sample
        adc     esi,ebp
        mov     eax,[es:ebx*4]          ; Set correct volume
        add     [edi+sample],eax
ENDM

MACRO   mixMove16_386Q sample
        add     ecx,edx
        mov     bl,[esi]                ; Get byte from sample
        adc     esi,ebp
        mov     eax,[es:ebx*4]          ; Set correct volume
        mov     [edi+sample],eax
ENDM

MACRO   mixAdd16_386MidQ sample
        add     ecx,edx
        mov     bl,[esi]                ; Get byte from sample
        adc     esi,ebp
        mov     eax,[es:ebx*4]          ; Set correct volume
        add     [edi+sample],eax
        add     [edi+4+sample],eax
ENDM

MACRO   mixAdd16_386SrndQ sample
        add     ecx,edx
        mov     bl,[esi]                ; Get byte from sample
        adc     esi,ebp
        mov     eax,[es:ebx*4]          ; Set correct volume
        add     [edi+sample],eax
        sub     [edi+4+sample],eax      ; Phase shift 180 degrees
ENDM

MACRO   mixAdd16_386PanQ sample
        add     ecx,edx
        mov     bl,[esi]                ; Get byte from sample
        mov     bh,dl
        adc     esi,ebp
        mov     eax,[es:ebx*4]          ; Set correct volume
        add     [edi+sample],eax
        mov     bh,dh
        mov     eax,[es:ebx*4]
        add     [edi+4+sample],eax
ENDM

;/*************************************************************************
; *
; *     Function    :   routineMono16_386
; *
; *     Description :   Calculates buffer for 16-bit mono cards in
; *                     Quality 16-bit, 386 mode
; *
; *************************************************************************/

PROC    routineMono16_386Q NEAR

        push    es
        mov     es,[bufferSeg]
        jc      @@clear
        and     ebx,0000FFFFh
        and     ebp,0000FFFFh
        shl     eax,16
        shl     edx,16

        cmp     [firstChannel1],0
        je      @@moveroutine

        push    ebx eax
        mov     ebx,ecx
        shr     ecx,UNROLL_SHIFT
        inc     ecx
        and     ebx,UNROLL_COUNT-1
        mov     eax,UNROLL_COUNT
        sub     eax,ebx
        mov     ebx,[ebx*4+monoadd16lbl386Q]
        shl     eax,2
        sub     edi,eax
        mov     [jumpAddress],ebx
        pop     eax ebx
        mov     [__ecx],ecx
        mov     ecx,eax
        jmp     [jumpAddress]
ALIGN 16
@@loop:
	lbl = UNROLL_COUNT-1
        count = 0
	REPT    UNROLL_COUNT
            mixAdd16_386Q count
            makelabel monoadd16_386Q,%lbl
            lbl = lbl - 1
            count = count + 4
        ENDM
        add     edi,UNROLL_COUNT*4
        dec     [__ecx]
        jnz     @@loop
        mov     eax,ecx
        jmp     @@exit

@@moveroutine:
        push    ebx eax
        mov     ebx,ecx
        shr     ecx,UNROLL_SHIFT
        inc     ecx
        and     ebx,UNROLL_COUNT-1
        mov     eax,UNROLL_COUNT
        sub     eax,ebx
        mov     ebx,[ebx*4+monomove16lbl386Q]
        shl     eax,2
        sub     edi,eax
        mov     [jumpAddress],ebx
        pop     eax ebx
        mov     [__ecx],ecx
        mov     ecx,eax
        jmp     [jumpAddress]
ALIGN 16
@@loop2:
	lbl = UNROLL_COUNT-1
        count = 0
	REPT    UNROLL_COUNT
            mixMove16_386Q count
            makelabel monoMove16_386Q,%lbl
            lbl = lbl - 1
            count = count + 4
        ENDM
        add     edi,UNROLL_COUNT*4
        dec     [__ecx]
        jnz     @@loop2
        mov     eax,ecx
        jmp     @@exit
@@clear:
        sub     ebx,ebx
        shl     eax,16
        shl     edx,16
        cmp     [firstChannel1],0
        jne     @@loopc2
ALIGN 4
@@loopc1:
        mov     [dword edi],ebx
        add     edi,4
        add     eax,edx
        adc     esi,ebp
        dec     ecx
        jnz     @@loopc1
        jmp     @@exit
ALIGN 4
@@loopc2:
        add     edi,4
        add     eax,edx
        adc     esi,ebp
        dec     ecx
        jnz     @@loopc2
@@exit:
        shr     eax,16                  ; AX = quotient
        pop     es
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   routineStereo16_386Q
; *
; *     Description :   Calculates buffer for 16-bit quality mode
; *                     stereo cards in 386 mode
; *
; *************************************************************************/

PROC    routineStereo16_386Q NEAR

        push    es
        mov     es,[bufferSeg]
        jc      @@clear
        and     ebx,0000FFFFh
        and     ebp,0000FFFFh
	shl     eax,16
	shl	edx,16			; High EDX is quotient

        cmp     [pan],PAN_SURROUND
	je      @@Surround
	cmp     [pan],PAN_MIDDLE
	je      @@MIDroutine
	cmp     [pan],PAN_RIGHT
	je      @@10
	cmp     [firstChannel1],0
	je      @@moveroutine
        jmp     @@addroutine
@@10:
	cmp     [firstChannel2],0
	je      @@moveroutine
@@addroutine:
        push    ebx eax
	mov     ebx,ecx
	shr	ecx,UNROLL_SHIFT
	inc     ecx
	and     ebx,UNROLL_COUNT-1
        mov     eax,UNROLL_COUNT
        sub     eax,ebx
        mov     ebx,[ebx*4+stereoadd16lbl386Q]
        shl     eax,3
        sub     edi,eax
        mov     [jumpAddress],ebx
        pop     eax ebx
        mov     [__ecx],ecx
        mov     ecx,eax
	jmp     [jumpAddress]
ALIGN 16
@@loop1:
	lbl = UNROLL_COUNT-1
        count = 0
	REPT    UNROLL_COUNT
            mixAdd16_386Q count
            makelabel stereoadd16_386Q,%lbl
	    lbl = lbl - 1
            count = count + 8
        ENDM
        add     edi,UNROLL_COUNT*8
        dec     [__ecx]
        jnz     @@loop1
        mov     eax,ecx
        jmp     @@exit
@@moveRoutine:
        push    ebx eax
	mov     ebx,ecx
	shr	ecx,UNROLL_SHIFT
	inc     ecx
	and     ebx,UNROLL_COUNT-1
        mov     eax,UNROLL_COUNT
        sub     eax,ebx
        mov     ebx,[ebx*4+stereomove16lbl386Q]
        shl     eax,3
        sub     edi,eax
        mov     [jumpAddress],ebx
        pop     eax ebx
        mov     [__ecx],ecx
        mov     ecx,eax
	jmp     [jumpAddress]
ALIGN 16
@@loop2:
	lbl = UNROLL_COUNT-1
        count = 0
	REPT    UNROLL_COUNT
            mixMove16_386Q count
            makelabel stereomove16_386Q,%lbl
	    lbl = lbl - 1
            count = count + 8
        ENDM
        add     edi,UNROLL_COUNT*8
        dec     [__ecx]
        jnz     @@loop2
        mov     eax,ecx
	jmp     @@exit
@@MIDroutine:                           ;// Middle routines
	cmp     [firstChannel1],0
	jne     @@100
	pushad
	call    near @@clearFAST         ;// Clear it first
	popad
@@100:
	cmp     [firstChannel2],0
	jne     @@200
	pushad
        add     edi,4
	call    near @@clearFAST         ;// Clear it first
	popad
@@200:
	cmp     [realpan],PAN_MIDDLE
	je      @@addroutineMID
@@addroutinePan:
        push    ebx eax
	mov     ebx,ecx
	shr	ecx,UNROLL_SHIFT
	inc     ecx
	and     ebx,UNROLL_COUNT-1
        mov     eax,UNROLL_COUNT
        sub     eax,ebx
        mov     ebx,[ebx*4+stereoadd16lbl386PanQ]
        shl     eax,3
        sub     edi,eax
        mov     [jumpAddress],ebx
        pop     eax ebx
	mov     [__ecx],ecx
        mov     dl,bh                   ; Volumes are in  DH/DL
        mov     dh,bl
        mov     ecx,eax
        jmp     [jumpAddress]
ALIGN 16
@@loop1Pan:
	lbl = UNROLL_COUNT-1
        count = 0
	REPT    UNROLL_COUNT
            mixAdd16_386PanQ count
            makelabel stereoadd16_386PanQ,%lbl
	    lbl = lbl - 1
            count = count + 8
        ENDM
        add     edi,UNROLL_COUNT*8
	dec     [__ecx]
	jnz     @@loop1Pan
        mov     eax,ecx
	jmp     @@exit
@@addroutineMID:
        push    ebx eax
	mov     ebx,ecx
	shr	ecx,UNROLL_SHIFT
	inc     ecx
	and     ebx,UNROLL_COUNT-1
        mov     eax,UNROLL_COUNT
        sub     eax,ebx
        mov     ebx,[ebx*4+stereoadd16lbl386MIDQ]
        shl     eax,3
        sub     edi,eax
        mov     [jumpAddress],ebx
        pop     eax ebx
        mov     [__ecx],ecx
        mov     ecx,eax
	jmp     [jumpAddress]
ALIGN 16
@@loop1MID:
	lbl = UNROLL_COUNT-1
        count = 0
	REPT    UNROLL_COUNT
            mixAdd16_386MIDQ count
            makelabel stereoadd16_386MIDQ,%lbl
	    lbl = lbl - 1
            count = count + 8
        ENDM
        add     edi,UNROLL_COUNT*8
        dec     [__ecx]
	jnz     @@loop1MID
        mov     eax,ecx
	jmp     @@exit

@@clearFAST:                            ; Fast clearing routine
	sub     eax,eax
	shr     ecx,1
	jnc     @@loopcfast
        mov     [edi],eax
        add     edi,8
	jcxz    @@fret
ALIGN 4
@@loopcfast:
        mov     [edi],eax
        add     edi,8
        mov     [edi],eax
        add     edi,8
	dec     ecx
	jnz     @@loopcfast
@@fret:
	retn
@@clearMID:
        sub     eax,eax
ALIGN 4
@@loopcmid:
        mov     [edi],eax
        add     edi,8
	add	eax,edx
	adc     esi,ebp
	dec     ecx
	jnz     @@loopcmid
	retn
@@clear:
        sub     ebx,ebx
        shl     eax,16
	shl     edx,16
	cmp     [pan],PAN_SURROUND
	je      @@midClear
	cmp     [pan],PAN_MIDDLE
	je      @@midClear
	cmp     [pan],PAN_RIGHT
	je      @@11
	cmp     [firstChannel1],0
	je      @@loopc1
	jmp     @@loopc2
@@11:
	cmp     [firstChannel2],0
	je      @@loopc1
ALIGN 4
@@loopc2:
        add     edi,8
	add	eax,edx
	adc     esi,ebp
	dec     ecx
	jnz     @@loopc2
	jmp     @@exit
ALIGN 4
@@loopc1:
        mov     [edi],ebx
        add     edi,8
	add	eax,edx
	adc     esi,ebp
	dec     ecx
	jnz     @@loopc1
	jmp     @@exit
@@midClear:
	cmp     [firstChannel1],0
	jne     @@101
	mov     [tempEDI],edi
	mov     [tempESI],esi
	push    ecx
	call    near @@clearMID         ;// Clear it first
	pop     ecx
	cmp     [firstChannel2],0
	jne     @@exit
	mov     edi,[tempEDI]
	mov     esi,[tempESI]
@@101:
	cmp     [firstChannel2],0
	jne     @@loopc2                ;// Just do the counters..
        add     edi,4
	call    near @@clearMID         ;// Clear it first
        sub     edi,4
	jmp     @@exit
@@Surround:                             ;// Middle routines
	cmp     [firstChannel1],0
	jne     @@s100
	pushad
	call    near @@clearFAST        ;// Clear it first
	popad
@@s100:
	cmp     [firstChannel2],0
	jne     @@s200
	pushad
        add     edi,4
	call    near @@clearFAST        ;// Clear it first
	popad
@@s200:
        push    ebx eax
	mov     ebx,ecx
	shr	ecx,UNROLL_SHIFT
	inc     ecx
	and     ebx,UNROLL_COUNT-1
        mov     eax,UNROLL_COUNT
        sub     eax,ebx
        mov     ebx,[ebx*4+stereoadd16lbl386SrndQ]
        shl     eax,3
        sub     edi,eax
        mov     [jumpAddress],ebx
        pop     eax ebx
        mov     [__ecx],ecx
        mov     ecx,eax
	jmp     [jumpAddress]
ALIGN 16
@@loop1Srnd:
	lbl = UNROLL_COUNT-1
        count = 0
	REPT    UNROLL_COUNT
            mixAdd16_386SrndQ count
            makelabel stereoadd16_386SrndQ,%lbl
	    lbl = lbl - 1
            count = count + 8
	ENDM
        add     edi,UNROLL_COUNT*8
        dec     [__ecx]
	jnz     @@loop1Srnd
        mov     eax,ecx
	jmp     @@exit
@@exit:
	shr     eax,16                  ; AX = quotient
        pop     es
	ret
ENDP

ENDIF

ENDIF

;/*************************************************************************
; *
; *     Function    :   fillBuffer
; *
; *     Description :   Fills sound buffer. Called by calcBuffer only.
; *
; ************************************************************************/

PROC    fillBuffer NEAR

	test    [options],MCP_QUALITY   ; Is quality mode on?
	jz      @@normal

	cmp     [bufferCounter],QUALITYCOUNT
	jle     @@normal
	mov     _ax,[bufferCounter]
	mov     [tempCount],ax
@@again:
        mov     [bufferCounter],QUALITYCOUNT-16
	call    near mixBuffer
        sub     [tempCount],QUALITYCOUNT-16
	jns     @@again
	ret
@@normal:
	jmp     short mixBuffer
ENDP

;/*************************************************************************
; *
; *     Function    :    mixBuffer
; *
; *     Description :   Mixes voice data into the buffer
; *
; ************************************************************************/

PROC    mixBuffer NEAR

	ecall   mcpEnableVirtualSamples
	cld
IFDEF __16__
	mov     es,[bufferSeg]
ENDIF
	test    [options],MCP_QUALITY   ; Is quality mode on?
	jnz     @@qual1

	mov     _di,[dataBuf]
	add     _di,[bufferFillPos]      ; DI = dataBuf+fillpos
	jmp     @@over1
@@qual1:
	mov     _di,QualityBuffer        ; Fill temporary buffer
        cmp     [sampleWidth],4
        jne     @@qok
        mov     _di,QualityBuffer16      ; Fill temporary buffer (Q16)

@@qok:
IF32    <add    edi,[bufferBase]>
@@over1:
        sub     ax,ax
	mov     [firstChannel1],ax      ; Reset first_channels
	mov     [firstChannel2],ax
	sub     _bx,_bx                 ; BX = channel number
        mov     _cx,[channelCount]
	jcxz    @@exit
@@loop1:
	push    _bx                     ; Save channel number and
	mov     [curChannel],bx
	push    _di                      ; buffer address
	shl     _bx,1
	mov     bx,[chDataPtr+_bx]       ; DS:BX = channelData[_bx]
	cmp     [SoundCard.stereo],0
	jne     @@stereo
        mov     [pan],PAN_MIDDLE
        mov     [realpan],PAN_MIDDLE
        jmp     @@evenchannel
@@stereo:
	mov     al,[_bx+channelData.pan]
        mov     ah,al
	cmp     al,PAN_SURROUND
        je      @@foundPan
        mov     ah,PAN_RIGHT
        cmp     al,PAN_RIGHT            ; Is pannning close to right?
        jge     @@foundPan
        mov     ah,PAN_LEFT
        cmp     al,PAN_LEFT             ; What about left?
        jle     @@foundPan
        mov     ah,PAN_MIDDLE           ; Last we check middle
        cmp     al,PAN_MIDDLE+3
        jge     @@foundPan
        cmp     al,PAN_MIDDLE-3
        jle     @@foundPan
        mov     al,PAN_MIDDLE
@@foundPan:
        mov     [pan],ah
	mov     [realpan],al
        cmp     [pan],PAN_RIGHT
        jne     @@evenchannel
        add     _di,[sampleWidth]
@@evenchannel:
	test    [_bx+channelData.status],CH_PLAYING      ; Has channel a sample?
        jz      @@done                          ; No, jump over
	test    [_bx+channelData.status],CH_PAUSED       ; Is channel paused?
        jnz     @@done                          ; Yes, jump over
	cmp     [_bx+channelData.sampleID],0     ; Virtual sample?
	je      @@sampleOK
	push    _cx _bx _di _si                          ; Get real address...
	movzx   eax,[_bx+channelData.sampleID]
	ecall   mcpSampleRealAddress eax,[_bx+channelData.played]
	pop     _si _di _bx _cx
IFDEF __16__
	or      ax,ax
	jnz     @@ok1
	or      dx,dx                           ; Is it NULL?
	jz      @@done
ELSE
	or	eax,eax
	jz	@@done
ENDIF
@@ok1:
	mov     [WORD HIGH _bx+channelData.sPtr],dx
	mov     [WORD LOW _bx+channelData.sPtr],ax
@@sampleOK:
	push    _cx
	sub     ecx,ecx
	mov     _cx,[bufferCounter]
	mov     [bytesLeft],_cx
@@again:
	sub     esi,esi
	LESSI   [_bx+channelData.sPtr]   ; ESSI = pointer to sample
	add     esi,[_bx+channelData.played]
	mov     eax,[_bx+channelData.dLength]
	mul     ecx                             ; EDX = bytes to move
	shld    edx,eax,DELTA_ACCURACY
	mov     eax,[_bx+channelData.length]
	cmp     [_bx+channelData.loopEnd],0          ; Is sample looping?
	je      @@01
	mov     eax,[_bx+channelData.loopEnd]
@@01:
	mov     [doesLoop],0
	dec     eax
	sub     eax,[_bx+channelData.played]
	jg      @@posOK
	cmp     [_bx+channelData.loopEnd],0
	je      @@zerocalc
	mov     [doesLoop],1
@@zerocalc:
	sub     _cx,_cx                 ; We haven't mixed anything yet...
	jmp     @@endloop
@@posOK:
	cmp     eax,edx                 ; Is sample about to loop or end
	ja      @@noloop

; looping or ending
	and     [_bx+channelData.status],NOT CH_PLAYING
	cmp     [_bx+channelData.loopEnd],0
	je      @@02
	mov     [doesLoop],1
	or      [_bx+channelData.status],CH_LOOPING OR CH_PLAYING
@@02:
	mov     edx,eax
	sub     eax,eax
	shrd    eax,edx,DELTA_ACCURACY
	shr     edx,DELTA_ACCURACY
	div     [_bx+channelData.dLength]        ; Calculate how many bytes to output
	mov     _cx,_ax
@@noloop:
	jcxz    @@endloop
	push    esi
	push    _bx                      ; Save BX and CX
	push    _cx
IF16	<Qnormalize es,esi>
	push    _si
	mov     dx,[_bx+channelData.rateRem]     ; DX = remainder
	mov     bp,[_bx+channelData.rateQuo]     ; BP = whole bytes to add
        push    [_bx+channelData.saveQuo]
	cmp     [pan],PAN_SURROUND
	je      @@notPanning
	cmp     [pan],PAN_MIDDLE
        jne     @@notPanning
        cmp     [realpan],PAN_MIDDLE
        je      @@notPanning
	mov     al,[_bx+channelData.volume]      ; Panning!
	imul    [masterVol]             ; Calculate real volume
        shr     ax,6
        sub     al,1
        js      @@zeropop
        mov     bl,al
	mov     bh,al
        cmp     [realpan],PAN_MIDDLE
        jg      @@attenLeft
        mov     al,[realpan]            ; Attenuate right channel
	sub     al,PAN_LEFT
        imul    bl
        sar     ax,6
	mov     bl,al
        jmp     @@attenRight
@@attenLeft:                            ; Attenuate left channel
        mov     al,[realpan]
        sub     al,PAN_RIGHT
        neg     al
        imul    bh
        sar     ax,6
        mov     bh,al
@@attenRight:
        pop     ax                      ; AX = saveQuo
	cmp     [masterVol],0
	je      @@zero
	clc                             ; Clear carry
	call    [calcRoutine]
	jmp     @@oo
@@notPanning:
	mov     al,[_bx+channelData.volume]
	imul    [masterVol]             ; Calculate real volume
	sar     ax,6
	mov     bh,al                   ; BX = offset to volumetable
        pop     ax                      ; AX = saveQuo
        sub     bh,1
        js      @@zero
	cmp     [masterVol],0
	je      @@zero
	clc                             ; Clear carry
	call    [calcRoutine]
	jmp     @@oo
@@zeropop:
        pop     ax
@@zero:
	stc                             ; Set carry
	call    [calcRoutine]
@@oo:
	sub     edx,edx
	pop     _dx
	pop     _cx                     ; Restore BX & CX
	pop     _bx
	sub     _dx,_si
	neg     _dx
	pop     esi
	add     esi,edx
	mov     [_bx+channelData.saveQuo],ax
@@endloop:
	cmp     [doesLoop],1            ; Is sound about to loop
	jne     @@11
IF16    <movzx  esi,[WORD LOW _bx+channelData.sPtr]>
IF32    <mov    esi,[_bx+channelData.sPtr]>
	add     esi,[_bx+channelData.loopStart]  ; Update pointer
@@11:
	sub     _cx,[bytesLeft]
	neg     _cx
	mov     [bytesLeft],_cx
IF16    <movzx  eax,[WORD LOW _bx+channelData.sPtr]>
IF32    <mov    eax,[_bx+channelData.sPtr]>
	sub     esi,eax
	mov     [_bx+channelData.played],esi     ; Update 'played'
	or      _cx,_cx
	jle     @@12
	cmp     [doesLoop],1            ; Looping?
	jne     @@13                    ; No, exit
	jmp     @@again                 ; Next loop
@@13:
	test    [SoundCard.stereo],1
	jz      @@mono02
	cmp     [pan],PAN_SURROUND
	je      @@133
	cmp     [pan],PAN_MIDDLE
	jne     @@135
@@133:
	cmp     [firstChannel1],0
	jne     @@tryright
	push    _cx
	push    _di
IFDEF __16__
	mov     es,[bufferSeg]
ENDIF
	mov     eax,[clearValue]
	cmp     [sampleWidth],2
	je      @@loopStereo16MID1
        cmp     [sampleWidth],4
        je      @@loopStereo16QMID1
@@loopStereoMID1:                               ; CX is already set
        mov     [ESDI],al
        add     _di,2
	loop    @@loopStereoMID1
	pop     _di
	pop     _cx
	jmp     @@tryright
@@loopStereo16MID1:                             ; CX is already set
        mov     [ESDI],ax
        add     _di,4
	loop    @@loopStereo16MID1
	pop     _di
	pop     _cx
	jmp     @@tryright
@@loopStereo16QMID1:                             ; CX is already set
        mov     [ESDI],eax
        add     _di,8
        loop    @@loopStereo16QMID1
	pop     _di
	pop     _cx
	jmp     @@tryright
@@tryright:
	cmp     [firstChannel2],0
	jne     @@12
IFDEF __16__
	mov     es,[bufferSeg]
ENDIF
	mov     eax,[clearValue]
	add     _di,[sampleWidth]
	cmp     [sampleWidth],2
	je      @@loopStereo16MID2
        cmp     [sampleWidth],4
        je      @@loopStereo16QMID2
@@loopStereoMID2:                               ; CX is already set
        mov     [ESDI],al
        add     _di,2
        loop    @@loopStereoMID2
	jmp     @@12
@@loopStereo16MID2:                             ; CX is already set
        mov     [ESDI],ax
        add     _di,4
        loop    @@loopStereo16MID2
	jmp     @@12
@@loopStereo16QMID2:                            ; CX is already set
        mov     [ESDI],eax
        add     _di,8
        loop    @@loopStereo16QMID2
	jmp     @@12

@@135:
	cmp     [pan],PAN_RIGHT
	je      @@14
	cmp     [firstChannel1],0
	jmp     @@15
@@14:
	cmp     [firstChannel2],0
@@15:
	jne     @@12
	cld
IFDEF __16__
	mov     es,[bufferSeg]
ENDIF
        mov     eax,[clearValue]
	cmp     [sampleWidth],2
	je      @@loopStereo16
        cmp     [sampleWidth],4
        je      @@loopStereo16Q
@@loopStereo:                           ; CX is already set
        mov     [ESDI],al
        add     _di,2
        loop    @@loopStereo
        jmp     @@12
@@loopStereo16:                         ; CX is already set
        mov     [ESDI],ax
        add     _di,4
        loop    @@loopStereo16
	jmp     @@12
@@loopStereo16Q:                        ; CX is already set
        mov     [ESDI],eax
        add     _di,8
        loop    @@loopStereo16Q
	jmp     @@12
@@mono02:
	cmp     [firstChannel1],0
	jne     @@12
	cld
IFDEF __16__
	mov     es,[bufferSeg]
ENDIF
        mov     _ax,_cx
        imul    [sampleWidth]
        mov     _cx,_ax
        mov     _dx,_ax
        mov     eax,[clearValue]
        cmp     _dx,16
	jle     @@stosb2
	mov     _bx,_di
	add     _bx,_dx
	and     _bx,3                            ; BX = after counter
	sub     _cx,_cx
	sub     _cx,_di
	and     _cx,3                            ; CX = before counter
	sub     _dx,_cx
	sub     _dx,_bx
	rep     stosb
	mov     _cx,_dx
	shr     _cx,2
	rep     stosd
	mov     _cx,_bx
@@stosb2:
	rep     stosb
@@12:
	pop     _cx

	test    [SoundCard.stereo],1
	jz      @@mono01
	cmp     [pan],PAN_LEFT
	je      @@mono01
	inc     [firstChannel2]
	cmp     [pan],PAN_SURROUND
	je      @@mono01
	cmp     [pan],PAN_MIDDLE
	jne     @@done
@@mono01:
	inc     [firstChannel1]
@@done:
	pop     _di
	pop     _bx
	inc     _bx                      ; BX = next channel
	loop    @@loop1                 ; Loop through all channels
IFDEF __16__
	mov     es,[bufferSeg]
ENDIF
	test    [SoundCard.stereo],1
	jz      @@mono03
	cmp     [firstChannel1],0
	je      @@16
	cmp     [firstChannel2],0
	jne     @@quality
	mov     _cx,[bufferCounter]      ; CX = count
	add     _di,[sampleWidth]        ; Right channel
        mov     eax,[clearValue]        ; EAX = clear value
	cmp     [sampleWidth],2         ; Is sample width 2 bytes?
	je      @@16bit1                ; Jump to 16-bit clear
        cmp     [sampleWidth],4         ; Is sample width 4 bytes?
        je      @@16bit1Q               ; Jump to 16-bit quality clear
        shr     _cx,1
	jnc     @@byte0
	stosb                           ; Clear 8-bit
	inc     _di
@@byte0:
	shr     _cx,1
	jcxz    @@quality
	jnc     @@loopS2
	mov     [ESDI],al
	mov     [ESDI+2],al
	add     _di,4
@@loopS2:
	mov     [ESDI],al
	mov     [ESDI+2],al
	mov     [ESDI+4],al
	mov     [ESDI+6],al
	add     _di,8
	loop    @@loopS2
	jmp     @@quality
@@16bit1:
        shr     _cx,1                    ; Clear 16-bit
	jnc     @@byte160
        mov     [ESDI],ax
        add     _di,4
@@byte160:
	shr     _cx,1
        jcxz    @@quality
	jnc     @@loop16S2
	mov     [ESDI],ax
	mov     [ESDI+4],ax
	add     _di,8
@@loop16S2:
	mov     [ESDI],ax
	mov     [ESDI+4],ax
	mov     [ESDI+8],ax
	mov     [ESDI+12],ax
	add     _di,16
	loop    @@loop16S2
	jmp     @@quality
@@16bit1Q:
        shr     _cx,1                    ; Clear 16-bit
        jnc     @@byte160Q
        mov     [ESDI],eax
        add     _di,8
@@byte160Q:
	shr     _cx,1
        jcxz    @@quality
        jnc     @@loop16S2Q
        mov     [ESDI],eax
        mov     [ESDI+8],eax
        add     _di,16
@@loop16S2Q:
        mov     [ESDI],eax
        mov     [ESDI+8],eax
        mov     [ESDI+16],eax
        mov     [ESDI+24],eax
        add     _di,32
        loop    @@loop16S2Q
	jmp     @@quality
@@16:
	cmp     [firstChannel2],0       ; Left channel
	je      @@mono03
	mov     _cx,[bufferCounter]
        mov     eax,[clearValue]
	cmp     [sampleWidth],2         ; Is it 16-bit?
	je      @@16bit2
        cmp     [sampleWidth],4         ; Is sample width 4 bytes?
        je      @@16bit2Q               ; Jump to 16-bit quality clear
        shr     _cx,1                    ; Clear 8-bit
	jnc     @@byte1
	mov     [ESDI],al
	add     _di,2
@@byte1:
	shr     _cx,1
	jcxz    @@quality
	jnc     @@loopS3
	mov     [ESDI],al
	mov     [ESDI+2],al
	add     _di,4
@@loopS3:
	mov     [ESDI],al
	mov     [ESDI+2],al
	mov     [ESDI+4],al
	mov     [ESDI+6],al
	add     _di,8
	loop    @@loopS3
	jmp     @@quality
@@16bit2:
        shr     _cx,1                    ; Clear 16-bit
	jnc     @@byte161
	mov     [ESDI],ax
	add     _di,4
@@byte161:
	shr     _cx,1
	jcxz    @@quality
	jnc     @@loop16S3
	mov     [ESDI],ax
	mov     [ESDI+4],ax
	add     _di,8
@@loop16S3:
	mov     [ESDI],ax
	mov     [ESDI+4],ax
	mov     [ESDI+8],ax
	mov     [ESDI+12],ax
	add     _di,16
	loop    @@loop16S3
	jmp     @@quality
@@16bit2Q:
        shr     _cx,1                    ; Clear 16-bit
        jnc     @@byte161Q
        mov     [ESDI],eax
        add     _di,8
@@byte161Q:
	shr     _cx,1
	jcxz    @@quality
        jnc     @@loop16S3Q
        mov     [ESDI],eax
        mov     [ESDI+8],eax
        add     _di,16
@@loop16S3Q:
        mov     [ESDI],eax
        mov     [ESDI+8],eax
        mov     [ESDI+16],eax
        mov     [ESDI+24],eax
        add     _di,32
        loop    @@loop16S3Q
	jmp     @@quality
@@mono03:
	cmp     [firstChannel1],0
	jne     @@quality
	cld

        mov     _ax,[bufferCounter]      ; (E)AX = count
        imul    [sampleWidth]
        mov     cl,[SoundCard.stereo]
	shl     _ax,cl
        mov     _dx,_ax                 ; (E)DX = dword counter
	mov     eax,[clearValue]
	mov     _cx,_dx
	cmp     _dx,16
	jle     @@stosb
	mov     _bx,_di
	add     _bx,_dx
	and     _bx,3                    ; BX = after counter
	sub     _cx,_cx
	sub     _cx,_di
	and     _cx,3                    ; CX = before counter
	sub     _dx,_cx
	sub     _dx,_bx
	rep     stosb
	mov     _cx,_dx
        shr     _cx,2
	rep     stosd
	mov     _cx,_bx
@@stosb:
	rep     stosb

@@quality:
	test    [options],MCP_QUALITY   ; Is quality mode on?
	jz      @@exit

        cmp     [SoundCard.sampleSize],2
        je      @@quality16

	cld
	mov     _si,QualityBuffer
	mov     _di,[dataBuf]
	add     _di,[bufferFillPos]      ; DI = dataBuf+fillpos
IF32    <add    esi,[bufferBase]>
	mov     _ax,[bufferCounter]
        cmp     [SoundCard.stereo],1
        jne     @@nostq
        shl     _ax,1
@@nostq:
        mov     _cx,_ax

	PUSHDS
IF16	<mov    ds,[bufferSeg]>          ; DS = bufferSeg
	mov     _bx,_cx
	shr	_cx,UNROLL_SHIFT
	inc     _cx
	and     _bx,UNROLL_COUNT-1
	shl     _bx,1
IF32    <shl    _bx,1>
        mov     _ax,[_bx+postqualitylbl]
	shr     _bx,1
IF32    <shr    _bx,1>
	sub     _bx,UNROLL_COUNT
	neg     _bx                      ; BX = POSTCOUNT-BX/2
	sub     _di,_bx                  ; Adjust DI
	add     _bx,_bx                  ; BX = BX*2
	sub     _si,_bx                  ; Adjust SI
IFDEF __32__
	sub     ebx,ebx
	mov     edx,[bufferBase]
	add     edx,QualityPass2
ENDIF
	jmp     _ax
@@loop:
ALIGN 4
	count = 0
	count2 = 0
	lbl = UNROLL_COUNT - 1
	REPT    UNROLL_COUNT
	mov     bx,[_si+count]
IFDEF __16__
	mov     al,[_bx+QualityPass2+QUALITYPASS/2]
ELSE
	add     bx,QUALITYPASS/2
	mov     al,[ebx+edx]
ENDIF
	mov     [_di+count2],al
	count  = count+2
	count2 = count2+1
	makelabel postquality,%lbl
	lbl = lbl - 1
	ENDM
	add     _di,UNROLL_COUNT
	add     _si,UNROLL_COUNT*2
	dec     _cx
	jnz     @@loop
	POPDS
	jmp     @@exit

@@quality16:
        cld
        mov     _si,QualityBuffer16
	mov     _di,[dataBuf]
	add     _di,[bufferFillPos]      ; DI = dataBuf+fillpos
IF32    <add    esi,[bufferBase]>
        mov     _cx,[bufferCounter]
        cmp     [SoundCard.stereo],1
        jne     @@nost
        shl     _cx,1
@@nost:
        PUSHDS
IF16	<mov    ds,[bufferSeg]>          ; DS = bufferSeg
        sub     ebx,ebx
IF 0
@@q16loop:
        mov     ebx,[_si]
        mov     ebp,[_si+4]
        sar     ebx,15
        sar     ebp,15
        shl     bx,2
        shl     bp,2
        mov     eax,[bx+QualityPassTable]
        mov     edx,[ds:bp+QualityPassTable]
        mov     bx,[_si]
        mov     bp,[_si+4]
        or      bx,ax
        or      bp,dx
        shr     eax,16
        shr     edx,16
        and     bx,ax
        and     bp,dx
        mov     [_di],bx
        mov     [_di+2],bp
        add     _si,8
        add     _di,4
ENDIF
        mov     ebx,-32768
        mov     edx,32767
        shr     _cx,1
        jnc     @@q16loopStart

        mov     eax,[_si]
        cmp     eax,ebx
        jl      short @@cutdown0
        cmp     eax,edx
        jg      short @@cutup0
        mov     [_di],ax

        add     _si,4
        add     _di,2
        jmp     short @@q16loopStart

ALIGN 4
@@cutdown0:
        mov     [WORD _di],-32768
        add     _si,4
        add     _di,2
        jmp     short @@q16loopStart
ALIGN 4
@@cutup0:
        mov     [WORD _di],32767
        add     _si,4
        add     _di,2
        jmp     short @@q16loopStart
@@q16loopStart:
        jcxz    @@qdone
ALIGN 4
@@q16loop:
        mov     eax,[_si]
        cmp     eax,ebx
        jl      short @@cutdown1
        cmp     eax,edx
        jg      short @@cutup1
        mov     [_di],ax

        mov     eax,[_si+4]
        cmp     eax,ebx
        jl      short @@cutdown2
        cmp     eax,edx
        jg      short @@cutup2
        mov     [_di+2],ax

        add     _si,8
        add     _di,4
        dec     _cx
        jnz     @@q16loop
        jmp     @@qdone
ALIGN 4
@@cutdown1:
        mov     [WORD _di],-32768
        mov     eax,[_si+4]
        cmp     eax,ebx
        jl      short @@cutdown2
        cmp     eax,edx
        jg      short @@cutup2
        mov     [_di+2],ax
        add     _si,8
        add     _di,4
        dec     _cx
        jnz     @@q16loop
        jmp     @@qdone
ALIGN 4
@@cutup1:
        mov     [WORD _di],32767
        mov     eax,[_si+4]
        cmp     eax,ebx
        jl      short @@cutdown2
        cmp     eax,edx
        jg      short @@cutup2
        mov     [_di+2],ax
        add     _si,8
        add     _di,4
        dec     _cx
        jnz     @@q16loop
        jmp     @@qdone
ALIGN 4
@@cutdown2:
        mov     [WORD _di+2],-32768
        add     _si,8
        add     _di,4
        dec     _cx
        jnz     @@q16loop
        jmp     @@qdone
ALIGN 4
@@cutup2:
        mov     [WORD _di+2],32767
        add     _si,8
        add     _di,4
        dec     _cx
        jnz     @@q16loop
        jmp     @@qdone
@@qdone:
        POPDS
	jmp     @@exit
@@exit:
	ecall   mcpDisableVirtualSamples
	ret
ENDP

;/*************************************************************************
; *
; *     Function    :   void mcpPoll(long time);
; *
; *     Description :   Calculates new voice data into buffer.
; *
; ************************************************************************/

CPROC   mcpPoll @@time


	ENTERPROC	edi esi ebp
	checkInit

	movzx   eax,[samplingRate]
	sub     edx,edx
	mov     ebx,[@@time]
        imul    ebx
        mov     ebx,1000000
	idiv    ebx
        mul     [sampleSize]
        cmp     ax,8
        jl      @@exit
@@decloop:
	cmp     _ax,[bufferSize]
	jb      @@sizeok
	sub     _ax,[bufferSize]
	jmp     @@decloop
@@sizeok:
	mov     [bufferOverrun],0
	mov     _bx,[bufferFillPos]
	add     _bx,_ax
        cmp     _bx,[bufferSize]
        jle     @@10
        inc     [bufferOverrun]
@@10:
        dec     _ax
        dec     _ax                      ; Don't go over buffer limit
        sub     _dx,_dx
        div     [sampleSize]
        mov     [bufferCounter],_ax
        cmp     [bufferOverrun],0
        je      @@20
        mov     _ax,[bufferSize]
        sub     _ax,[bufferFillPos]              ; AX = bytes to buffer end
        sub     _dx,_dx
        div     [sampleSize]
        sub     [bufferCounter],_ax
	push    [bufferCounter]
        mov     [bufferCounter],_ax
        call    fillBuffer
        cmp     [effectRoutine],0
        je      @@noeffect
IFDEF __32__                                    ; Call effect routine
        sub     eax,eax
        mov     al,[SoundCard.sampleSize]
        shr     al,1
        mov     ah,[SoundCard.stereo]
        shl     ah,1
        or      al,ah
        sub     ah,ah
        mov     edx,[dataBuf]
        add     edx,[bufferFillPos]
        ecallM  [effectRoutine] edx [bufferCounter] eax
ELSE
        sub     eax,eax
        mov     al,[SoundCard.sampleSize]
        shr     al,1
        mov     ah,[SoundCard.stereo]
        shl     ah,1
        or      al,ah
        sub     ah,ah

        mov     dx,[bufferSeg]
        mov     cx,[dataBuf]
        add     cx,[bufferFillPos]
        movzx   ebx,[bufferCounter]
        ecallM  [effectRoutine] <dx cx> ebx eax
ENDIF
@@noeffect:
        pop     [bufferCounter]
        mov     [bufferFillPos],0
@@20:
        cmp     [bufferCounter],8
        jl      @@exit
        call    fillBuffer
        cmp     [effectRoutine],0
        je      @@noeffect2
IFDEF __32__                                    ; Call effect routine
        sub     eax,eax
        mov     al,[SoundCard.sampleSize]
        shr     al,1
        mov     ah,[SoundCard.stereo]
        shl     ah,1
        or      al,ah
        sub     ah,ah
        mov     edx,[dataBuf]
        add     edx,[bufferFillPos]
        ecallM  [effectRoutine] edx [bufferCounter] eax
ELSE
        sub     eax,eax
        mov     al,[SoundCard.sampleSize]
        shr     al,1
        mov     ah,[SoundCard.stereo]
        shl     ah,1
        or      al,ah
        sub     ah,ah

        mov     dx,[bufferSeg]
        mov     cx,[dataBuf]
        add     cx,[bufferFillPos]
        movzx   ebx,[bufferCounter]
        ecallM  [effectRoutine] <dx cx> ebx eax
ENDIF
@@noeffect2:
        mov     _ax,[bufferCounter]
        mul     [sampleSize]
        add     [bufferFillPos],_ax
@@exit:
	LEAVEPROC	edi esi ebp
	ret
ENDP

;/*************************************************************************
; *
; *     Function    :   void mcpClearBuffer()
; *
; *     Description :   Clears sound buffer
; *
; ************************************************************************/

CPROC   mcpClearBuffer

	ENTERPROC	_di

	checkInit
IFDEF __16__
	mov     es,[bufferSeg]
ENDIF
	mov     _di,[dataBuf]
	cld
	mov     _cx,[bufferSize]
	mov     ax,[word realClearValue]
	shr     _cx,1
	rep     stosw                   ; Clear output buffer
	adc     _cx,_cx
	rep     stosb
	test    [options],MCP_QUALITY
	jz      @@exit
	mov     _di,QualityBuffer        ; Clear quality buffer
        mov     _cx,2048
        cmp     [SoundCard.sampleSize],2
        jne     @@sizeok
        mov     _di,QualityBuffer16      ; Clear 16-bit quality buffer
        mov     _cx,2048*2
@@sizeok:
IF32    <add    edi,[bufferBase]>
        sub     ax,ax
	rep     stosw
@@exit:
	LEAVEPROC	_di
	ret
ENDP

;/*************************************************************************
; *
; *     Function    :   long mcpGetDelta():
; *
; *     Description :   Returns the empty space in sound buffer in usecs
; *
; *     Returns     :   Delta time value of empty sound buffer
; *
; ************************************************************************/

CPROC   mcpGetDelta

	ecallM  [SDI.getBufferPos]      ; AX = buffer pos
	movzx	eax,ax
	sub     _ax,[bufferFillPos]
	jg      @@10
	add     _ax,[bufferSize]        ; (E)AX = buffer delta value
@@10:
IF16	<cwde>
	sub     edx,edx
	div     [sampleSize]            ; AX = number of samples
        mov     ebx,1000000             ; Convert to æsecs
	imul    ebx
	movzx   ebx,[samplingRate]
	idiv    ebx
	sub     edx,edx
IF16	<shld    edx,eax,16>
	ret
ENDP

;/*************************************************************************
; *
; *     Function    :   int mcpInitSoundDevice(void (far *)(far *),CARDINFO *sCard);
; *
; *     Description :   Initializes the sound card specified in sCard
; *                     structure.
; *
; *     Input       :   sCard = pointer to sound card structure holding
; *                     neccessary values for initialization.
; *
; *     Returns     :   0 if successful
; *                    -1 if init fails
; *
; ************************************************************************/

CPROC   mcpInitSoundDevice @@sounddev,@@sCard
	localvar   _dword @@retvalue

	ENTERPROC _di _si

IFDEF __C16__
        ecallM  <[@@sounddev]> <offset SDI> <seg SDI>>
ELSE
IFDEF __C32__
        ecallM  <[@@sounddev]> <offset SDI>>
ELSE
	ecallM  <[@@sounddev]> <seg SDI> <offset SDI>>
ENDIF
ENDIF

	mov     [dword @@retvalue],-1
	or      ax,ax
	jnz     @@exit
	ecallM  [SDI.initDevice] [@@sCard]
	or      ax,ax
	jnz     @@exit

	movzx   _ax,[SoundCard.sampleSize]
	mov     cl,[SoundCard.stereo]           ; If stereo,
	and     cl,1
	shl     _ax,cl                           ; multiply by 2
	mov     [sampleSize],_ax                ; Real samplesize
	mov     [dword @@retvalue],0
@@exit:
	mov     eax,[@@retvalue]
	cwd
	LEAVEPROC _di _si
	ret
ENDP

;/*************************************************************************
; *
; *     Function    :   int mcpGetCardInfo(CARDINFO *sCard);
; *
; *     Description :   Fills sCard with appropriate information according
; *                     to ID-field in sCard
; *
; *     Returns     :   0 = no error
; *                    -1 = error
; *
; ************************************************************************/

CPROC   mcpGetCardInfo @@sCard

	ENTERPROC _di _si

	RETVAL  -1
	LESDI   [@@sCard]         ; ESDI points to sCard
	mov     _si,offset SoundCard
	mov     _cx,SIZE CARDINFO
	cld
	rep     movsb                   ; Copy information
	RETVAL  0
@@exit:
	LEAVEPROC _di _si
	ret
ENDP

;/*************************************************************************
; *
; *     Function    :   int mcpInit(MCPSTRC far *mcpstrc);
; *
; *     Description :   Initializes Multi Channel Player with given frequency
; *
; *     Input       :   sample_rate = frequency used to output sound
; *                     mcpstrc     = pointer to a options strcuture
; *
; *     Returns     :    0      = success
; *                     -1      = error
; *
; ************************************************************************/

CPROC   mcpInit @@mcpstrc
localvar   _dword @@retvalue
localvar   _word @@sample_rate

	ENTERPROC _di _si

	cld
	LESSI   [@@mcpstrc]
	mov     ax,[ESSI+MCPSTRUC.samplingRate]
	mov     [@@sample_rate],ax
	mov     [dword @@retvalue],-1           ; Assume error
	test    [mcpStatus],S_INIT
	jz      @@exit
	mov     ax,[SoundCard.minRate]
        test    ax,ax
        je      @@rateok1
	cmp     [@@sample_rate],ax        ; Check sample_rate
	jae     @@rateok1
	mov     [@@sample_rate],ax
	jmp     @@rateok
@@rateok1:
	mov     ax,[SoundCard.maxRate]
        test    ax,ax
        je      @@rateok
        cmp     [@@sample_rate],ax
	jbe     @@rateok
	mov     [@@sample_rate],ax
@@rateok:

	ecall   mcpOpenSpeaker          ; Connect DSP to speaker

	LESSI   [@@mcpstrc]
	cld
	mov     ax,[ESSI+MCPSTRUC.options]      ; Save option flags

        mov     [options],ax
	mov     ax,[ESSI+MCPSTRUC.bufferSeg]
	mov     [bufferSeg],ax
IFDEF __32__
        mov     eax,[ESSI+MCPSTRUC.bufferBase]
	mov	[bufferBase],eax
ENDIF

	PUSHES
        mov     [channelCount],0        ; No channels open by default
IFDEF __16__
	mov     ax,seg channelData
	mov     es,ax
ENDIF
	mov     _cx,(SIZE channelData)*MAXCHANNEL
	mov     _di,offset channelData   ; Initialize channelData by
	sub     al,al                   ; clearing it to 0
	rep     stosb
	POPES

	test    [options],MCP_QUALITY
	jnz     @@quality

	mov     [clearFirst],0          ; Assume no clearing
	mov     [clearValue],80808080h
	mov     [realClearValue],80808080h
	movzx   _cx,[SoundCard.sampleSize]
	mov     [sampleWidth],_cx
	cmp     _cx,2
	je      @@16bit
        mov     _ax,offset routineMono8_386
	cmp     [SoundCard.stereo],0
	je      @@over
        mov     _ax,offset routineStereo8_386
	jmp     @@over
@@16bit:
	mov     [clearValue],00000000h
	mov     [realClearValue],00000000h
        mov     _ax,offset routineMono16_386
	cmp     [SoundCard.stereo],0
	je      @@over
        mov     _ax,offset routineStereo16_386
	jmp     @@over
@@quality:
        cmp     [SoundCard.sampleSize],2
        je      @@quality16
        mov     [clearFirst],1          ; Clear for quality mode
	mov     [sampleWidth],2
	mov     [clearValue],00000000h
	mov     [realClearValue],80808080h
        mov     _ax,offset routineMono16_386
	cmp     [SoundCard.stereo],0
	je      @@over
        mov     _ax,offset routineStereo16_386
        jmp     @@over
@@quality16:
        mov     [clearFirst],1          ; Clear for quality mode
        mov     [sampleWidth],4
	mov     [clearValue],00000000h
        mov     [realClearValue],00000000h
        mov     _ax,offset routineMono16_386Q
	cmp     [SoundCard.stereo],0
	je      @@over
        mov     _ax,offset routineStereo16_386Q
        jmp     @@over
@@over:
        test    [options],MCP_486
        jz      @@no486
@@no486:
        mov     [calcRoutine],_ax       ; Save address of calc routine

IF16	<mov     ax,[bufferSeg]>
        mov     ebx,SoundBufferOfs      ; Calculate sound buffer offset
        test    [options],MCP_QUALITY   ; 8-bit quality mode?
        jz      @@bufok
        add     ebx,QUALITYSIZE
        cmp     [SoundCard.sampleSize],2; 16-bit quality mode?
        jne     @@bufOk
        mov     ebx,SoundBufferOfs16+QUALITYSIZE16
@@bufok:
        mov     edx,[ESSI+MCPSTRUC.bufferLinear]
        add     edx,ebx
        mov     _cx,_bx                 ; (AX):(E)CX is a pointer to sound buffer
        movzx   ebx,[ESSI+MCPSTRUC.bufferSize]
        movzx   edi,[ESSI+MCPSTRUC.reqSize]
IF16	<ecallM  [SDI.initOutput] <ax cx>,edx,ebx,edi>
IF32    <ecallM  [SDI.initOutput] edx,edx,ebx,edi>
	movzx	eax,[word @@sample_rate]
	ecallM  [SDI.initRate] eax
	mov     [samplingRate],ax

	or      [mcpStatus],S_MCP       ; Indicate successful initialization
        ecall   mcpClearBuffer
        mov     [masterVol],64
        mov     [effectRoutine],0       ; No effect routine by default
	mov     [dword @@retvalue],0
@@exit:
	mov     eax,[@@retvalue]
	cwd
	LEAVEPROC _di _si
	ret
ENDP

;/*************************************************************************
; *
; *     Function    :   void mcpClose();
; *
; *     Description :   Shuts down MCP and resets sound device
; *
; ************************************************************************/

CPROC   mcpClose

	checkInit

	ecallM  [SDI.closeOutput]
	ecall   mcpStopVoice
	ecallM  [SDI.speakerOff]

	and     [mcpStatus],NOT (S_MCP OR S_VOICE) ; Remove init indication
	sub     _ax,_ax
@@exit:
	ret
ENDP

;/*************************************************************************
; *
; *     Function    :   void mcpOpenSpeaker();
; *
; *     Description :   Open speaker for output (if supported)
; *
; ************************************************************************/

CPROC   mcpOpenSpeaker

	ecallM  [SDI.speakerOn]
	ret
ENDP

;/*************************************************************************
; *
; *     Function    :   void mcpCloseSpeaker();
; *
; *     Description :   Closes speaker (if supported)
; *
; ************************************************************************/

CPROC   mcpCloseSpeaker

	ecallM  [SDI.speakerOff]
	ret
ENDP

;/*************************************************************************
; *
; *     Function    :   fillVolumeTable
; *
; *     Description :   Fills volume table
; *
; *     Input       :   BX = channel count
; *                     AX:SI = pointer to transform table
; *
; ************************************************************************/

CPROC   fillVolumeTable
	LOCALVAR	_word @@divisor
	LOCALVAR	_word @@roundoff
	LOCALVAR	_word @@temp
	LOCALVAR	_word @@datas

	ENTERPROC
	mov     [@@datas],ax              ; datas = volume trans.table

IF16    <mov     es,[bufferSeg]>
	sub     _di,_di
IF32    <add    edi,[bufferBase]>

@@01:
	PUSHDS
IF16    <mov	ds,[@@datas]>
	shl     bx,5                    ; BL = 32 * channelCount
	mov     [@@divisor],bx            ; divisor = BL
	shr     bx,1
	mov     [@@roundoff],bx
	mov     _cx,32                   ; 1 - 32
@@loop1:
	push    _cx
	mov     _cx,256
	mov     [word @@temp],-128             ; SI = value before translation
@@loop2:
	mov     ax,[word @@temp]
	imul    [word _si]
	cmp     [word @@temp],0
	js      @@10
	add     ax,[@@roundoff]
	adc     dx,0
	jmp     @@20
@@10:
	sub     ax,[@@roundoff]
	sbb     dx,0
@@20:
	idiv    [word @@divisor]               ; AL = translated value
	mov     [ESDI+volumeTable],al
	add     al,80h
	mov     [ESDI+volumeTable2],al
	inc     _di
	inc     [word @@temp]                  ; [temp] = next value
	loop    @@loop2
	add     _si,2                    ; SI = next volume
	pop     _cx
	loop    @@loop1
	POPDS
	LEAVEPROC
	ret
ENDP

;/*************************************************************************
; *
; *     Function    :   void fillVolumeTable16
; *
; *     Description :   Fills volume table in 16-bit mode.
; *
; *     Input       :   BX = number of channels
; *                     AX:(E)SI = pointer to transform table
; *
; ************************************************************************/

CPROC   fillVolumeTable16
	LOCVARS   _word @@chs,_word @@counter,_word @@volume,_word @@temp

	ENTERPROC
	cld
@@01:
	PUSHDS
IF16	<push    ax>
	mov     [@@chs],bx
IFDEF __16__
	mov     es,[bufferSeg]
ENDIF
	mov     _di,volumeTableWord
IF32    <add    edi,[bufferBase]>
IF16	<POPDS>
	mov     [word @@counter],32
@@loop1:
	mov     [word @@temp],-128
	mov     _cx,256
@@loop2:
	movsx   eax,[word @@temp]
	sal     eax,8                   ; EAX = EAX * 256
	movzx   ebx,[word _si]
	imul    ebx
	movzx   ebx,[word @@chs]
	idiv    ebx
        sar     eax,5
        mov     [ESDI],ax               ; Save AX into volumetable
        add     _di,2
	inc     [word @@temp]
	loop    @@loop2

	add     _si,2
	dec     [word @@counter]
	jnz     @@loop1
	POPDS
	LEAVEPROC
	ret
ENDP

;/*************************************************************************
; *
; *     Function    :   void fillVolumeTable16Q
; *
; *     Description :   Fills volume table in 16-bit Quality mode.
; *
; *     Input       :   BX = number of channels
; *                     AX:(E)SI = pointer to transform table
; *
; ************************************************************************/

CPROC   fillVolumeTable16Q
	LOCVARS   _word @@chs,_word @@counter,_word @@volume,_word @@temp

	ENTERPROC
	cld
@@01:
	PUSHDS
IF16	<push    ax>
	mov     [@@chs],bx
IFDEF __16__
	mov     es,[bufferSeg]
ENDIF
	mov     _di,volumeTableWord
IF32    <add    edi,[bufferBase]>
IF16	<POPDS>
	mov     [word @@counter],32
@@loop1:
	mov     [word @@temp],-128
	mov     _cx,256
@@loop2:
	movsx   eax,[word @@temp]
	sal     eax,8                   ; EAX = EAX * 256
	movzx   ebx,[word _si]
	imul    ebx
	movzx   ebx,[word @@chs]
	idiv    ebx
        sar     eax,5
        mov     [ESDI],eax              ; Save EAX into volumetable
        add     _di,4
	inc     [word @@temp]
	loop    @@loop2

	add     _si,2
	dec     [word @@counter]
	jnz     @@loop1

        mov     _cx,32
        sub     _bx,_bx
        sub     _di,_di
@@pass2table:
        mov     [DWORD ESBX+QualityPassTable],7FFF7FFFh
        mov     [DWORD ESDI+QualityPassTable],80008000h
        add     _bx,4
        sub     _di,4
        loop    @@pass2table

        mov     [DWORD ES:QualityPassTable],0FFFF0000h
        mov     [DWORD ES:QualityPassTable-4],0FFFF0000h

        POPDS
        LEAVEPROC
	ret
ENDP


	QChannelTable DW 0,170,190,220,300,340,420,485,540
		      DW 590,630,670,700,720,730,740,750
                      DW 760,765,770,775,775,780,780,780
                      DW 785,785,785,785,785,785,785,785

;/*************************************************************************
; *
; *     Function    :   qualityVolumeTable
; *
; *     Description :   Makes a volume table for Quality mode
; *
; *     Input       :   BX = number of channels
; *                     AX:(E)SI = pointer to transform table
; *
; ************************************************************************/

CPROC   qualityVolumeTable
LOCVARS   _word @@counter,_word @@volume,_word @@temp


	ENTERPROC esi ds
	cld
IF16    <push   _ax>                      ; Save table address
	push    _si
	mov     _di,QualityPass2+QUALITYPASS/2
IF32    <add    edi,[bufferBase]>
        shl     _bx,1
	movzx   esi,[_bx+QChannelTable]  ; ESI = channel value
        mov     _bx,0
        sub     ecx,ecx
	PUSHDS
IF16    <mov	ds,[bufferSeg]>
@@loop:
	mov	eax,ecx
	imul    eax,127                 ; EAX = 127*position
	sub     edx,edx
	div     esi                     ; Divide by limit
	cmp     ax,127
	jbe     @@ok
	mov     ax,127
@@ok:
	add     al,128
	mov     [_di+_bx],al
        neg     _bx
	neg     al
	mov     [_di+_bx],al
        neg     _bx
        inc     _bx
	inc     _cx
	cmp     _cx,QUALITYPASS/2
	jl      @@loop
	POPDS

	pop     _si

        mov     _di,volumeTableWord
IF16    <mov     es,[bufferSeg]>
IF32    <add    edi,[bufferBase]>

IF16    <pop    ds>
	mov     [word @@counter],32
@@loop1:
	mov     [word @@temp],-128
	mov     _cx,256
	movzx   ebx,[word _si]
@@loop2:
	movsx   eax,[word @@temp]
	imul    ebx
	sar     eax,5
	stosw                           ; Save AX into volumetable
	inc     [word @@temp]
	loop    @@loop2
	add     _si,2
	dec     [word @@counter]
	jnz     @@loop1
	LEAVEPROC esi ds

        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   int mcpSetupChannels(short count, short *volTable);
; *
; *     Description :   Sets the new number of channels. Updates volumeTable
; *
; *     Input       :   channel_count   = number of channels to use
; *                     volumemode      = type of volume
; *                                       1   = linear
; *                                       255 = user supplied
; *
; *     Returns     :   0 on success or -1 on error
; *
; ************************************************************************/

CPROC   mcpSetupChannels @@chCount,@@volTable

	ENTERPROC _si _di

	checkInit

	cmp     [@@chCount],MAXCHANNEL    ; In legal range
	ja      @@exit
	cmp     [@@chCount],0
	je      @@exit
	cld
IFDEF __16__
        mov     ax,seg channelData
	mov     es,ax
ENDIF
	mov     edx,[@@chCount]           ; DX = channel count
        mov     _bx,[channelCount]       ; Clear channels' data
        mov     [channelCount],_dx
	sub     dx,bx
	jle     @@nonew

	shl     bx,1
	sub     al,al
@@loop:
        movzx   edi,[chDataPtr+_bx]
        add     _di,offset channelData  ; ESDI points to channel data
        mov     _cx,SIZE CHDATA
        mov     _si,_di
	rep     stosb                   ; Clear channel data
	mov     ah,PAN_MIDDLE
	cmp     [SoundCard.stereo],0
	je      @@norm
	mov     ah,PAN_LEFT
	test    bx,2
	jz      @@norm
	mov     ah,PAN_RIGHT
@@norm:
	mov     [_si+CHDATA.pan],ah
	add     bx,2
	dec     dx
	jnz     @@loop
@@nonew:
	mov     ebx,[@@chCount]
	mov     edx,[@@volTable]
IF16	<mov	ax,cs>
	mov     _si,offset linearVolume
        cmp     [SoundCard.stereo],1
        jne     @@nostereotable
        mov     _si,offset stereoVolume
@@nostereotable:
	cmp     edx,0
	je      @@doit
IFDEF __16__
	mov     ax,[word high @@volTable]
	mov     si,[word low @@volTable]
ELSE
	mov	esi,[@@volTable]
ENDIF
@@doit:
        test    [options],MCP_QUALITY           ; Is quality mode on?
	jnz     @@qual
	cmp     [SoundCard.sampleSize],2
	je      @@fill16
	ecall   fillVolumeTable
	jmp     @@10
@@fill16:
        ecall   fillVolumeTable16
	jmp     @@10
@@qual:
        cmp     [SoundCard.sampleSize],2
        je      @@fill16Q
        ecall   qualityVolumeTable
        jmp     @@10
@@fill16Q:
        ecall   fillVolumeTable16Q
@@10:
	sub     _ax,_ax
@@exit:
	LEAVEPROC _si _di
	ret
ENDP

;/*************************************************************************
; *
; *     Function    :   int mcpStartVoice();
; *
; *     Description :   Starts to output voice.
; *
; ************************************************************************/

CPROC   mcpStartVoice

	ENTERPROC _di
	checkInit
	test    [mcpStatus],S_VOICE
	jnz     @@exit

	ecallM  [SDI.startOutput]

	mov     [bufferFillPos],0
	ecall   mcpClearBuffer
	or      [mcpStatus],S_VOICE     ; Indicate we are playing
	RETVAL  0
@@exit:
	LEAVEPROC _di
	ret
ENDP

;/*************************************************************************
; *
; *     Function    :   int mcpStopVoice();
; *
; *     Description :   Stops voice output.
; *
; ************************************************************************/

CPROC   mcpStopVoice

	checkInit
	test    [mcpStatus],S_VOICE
	jz      @@exit

	and     [mcpStatus],NOT S_VOICE   ; Indicate we stoped playing
	ecall   mcpClearBuffer
	ecallM  [SDI.stopOutput]

	RETVAL  0
@@exit:
	ret
ENDP

;/*************************************************************************
; *
; *     Function    :   void mcpPauseVoice();
; *
; *     Description :   Voice is paused
; *
; ************************************************************************/

CPROC   mcpPauseVoice

	checkInit
	ecallM  [SDI.pauseOutput]
	or      [mcpStatus],S_PAUSE
@@exit:
	ret
ENDP

;/*************************************************************************
; *
; *     Function    :   void mcpResumeVoice();
; *
; *     Description :   Voice is resumed
; *
; ************************************************************************/

CPROC   mcpResumeVoice

	checkInit
	ecallM  [SDI.resumeOutput]
	and     [mcpStatus],NOT S_PAUSE
@@exit:
	ret
ENDP

;/*************************************************************************
; *
; *     Function    :   int mcpMuteChannel(int channel);
; *
; *     Description :   Mutes channel from outputting any voice.
; *
; *     Input       :   Channel number
; *
; *     Returns     :    0      = channel paused succesfully
; *                     -1      = wrong channel
; *                     -2      = channel was already paused
; *
; ************************************************************************/

CPROC   mcpMuteChannel @@channel

	ENTERPROC
	checkInit
	calcChannel

	RETVAL  -2
	test    [_bx+channelData.status],CH_PAUSED       ; Is channel already paused?
	jnz     @@exit
	or      [_bx+channelData.status],CH_PAUSED       ; No, pause it
	RETVAL  0
@@exit:
	LEAVEPROC
	ret
ENDP

;/*************************************************************************
; *
; *     Function    :   int mcpUnmuteChannel(int channel);
; *
; *     Description :   Unmutes from pause
; *
; *     Input       :   Channel number
; *
; *     Returns     :    0      = channel resumed correctly
; *                     -1      = wrong channel number
; *                     -2      = channel was not paused
; *
; ************************************************************************/

CPROC   mcpUnmuteChannel @@channel

	ENTERPROC
	checkInit
	calcChannel

	RETVAL  -2                      ; Assume error
	test    [_bx+channelData.status],CH_PAUSED       ; Is channel paused?
	jz      @@exit
	and     [_bx+channelData.status],NOT CH_PAUSED; Yes, resume it
	RETVAL  0
@@exit:
	LEAVEPROC
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   int mcpStopChannel(int channel);
; *
; *     Description :   Stops playing sample on given channel.
; *
; *     Input       :   channel number
; *
; ************************************************************************/

CPROC   mcpStopChannel @@channel

	ENTERPROC
	checkInit
	calcChannel

	RETVAL  -2                      ; Assume error
	test    [_bx+channelData.status],CH_PLAYING      ; Is channel playing?
	jz      @@exit                  ; No, exit
	and     [_bx+channelData.status],NOT CH_PLAYING ; Stop playing
	RETVAL  0                       ; No error
@@exit:
	LEAVEPROC
	ret
ENDP

;/*************************************************************************
; *
; *     Function    :   void mcpMuteAll();
; *
; *     Description :   Mutes all channels by calling pauseChannel for every
; *                     channel (0 - channelCount).
; *
; ************************************************************************/

CPROC   mcpMuteAll

	checkInit

        mov     _cx,[channelCount]
        jcxz    @@exit
        sub     edx,edx                 ; DX = channel to be paused
@@loop:
	push    _cx
	push    edx
	ecall   mcpMuteChannel edx        ; Mute every channel
	pop     edx
	inc     edx
	pop     _cx
	loop    @@loop
	RETVAL  0
@@exit:
	ret
ENDP

;/*************************************************************************
; *
; *     Function    :   int mcpUnmuteAll();
; *
; *     Description :   Unmutes all channels from pause by calling
; *                     resumeChannel for each channel.
; *
; ************************************************************************/

CPROC   mcpUnmuteAll

	checkInit
        mov     _cx,[channelCount]
	jcxz    @@exit
	sub     edx,edx                 ; DX = channel to be paused
@@loop:
	push    _cx
	push    edx
	ecall   mcpUnmuteChannel edx       ; Mute every channel
	pop     edx
        inc     edx
	pop     _cx
        loop    @@loop
        RETVAL  0
@@exit:
	ret
ENDP

;/*************************************************************************
; *
; *     Function    :   int mcpGetChannelCount(void);
; *
; *     Description :   Returns the number of channels
; *
; *     Returns     :   Channel count
; *
; ************************************************************************/

CPROC   mcpGetChannelCount

	checkInit

        mov     _ax,[channelCount]
@@exit:
	ret
ENDP

;/*************************************************************************
; *
; *     Function    :   int mcpGetChannelStatus(int channel);
; *
; *     Description :   Returns channel's status
; *
; *     Input       :   channel number
; *
; *     Returns     :    bit 0  = playing status
; *                      bit 1  = in loop
; *                      bit 2  = paused
; *                      bit 7  = error
; *
; ************************************************************************/

CPROC   mcpGetChannelStatus @@channel

	ENTERPROC
	checkInit
	calcChannel

	movzx   eax,[_bx+channelData.status]
@@exit:
	LEAVEPROC
	ret
ENDP

;/*************************************************************************
; *
; *     Function    :   int mcpSetSample(int channel, struct SAMPLEINFO *s);
; *
; *     Description :   Selects a new sample on given channel.
; *
; *     Input       :   channel = channel number
; *                     s       = pointer to structure holding sample's info
; *
; ************************************************************************/

CPROC   mcpSetSample @@channel, @@pSampleinfo

	ENTERPROC _si
	checkInit
	calcChannel

	LESSI   [@@pSampleInfo]
	mov     eax,[ESSI+SAMPLEINFO.voiceData] ; Voice pointer
	or      eax,eax                   ; is voiceData = 0
	jz      @@exit
	mov     [_bx+channelData.sPtr],eax

	mov     eax,[ESSI+SAMPLEINFO.length]    ; Length
	or      eax,eax                 ; is length = 0 ?
	jz      @@exit
	mov     [_bx+channelData.length],eax
	test    [ESSI+SAMPLEINFO.mode],SAMPLE_CONTINUE  ; Should we continue
	jz      @@cont                                  ; where we left?
	mov     eax,[_bx+channelData.played]     ; AX = current position
	cmp     [ESSI+SAMPLEINFO.loopEnd],0         ; Is sample a looping one
	je      @@01
	cmp     eax,[ESSI+SAMPLEINFO.loopEnd]   ; Past the loop end??
	jb      @@done
	mov     eax,[ESSI+SAMPLEINFO.loopStart]
	jmp     @@update
@@01:
	cmp     eax,[_bx+channelData.length]
	jb      @@done
@@cont:
	sub     eax,eax
@@update:
	mov     [_bx+channelData.played],eax     ; Reset playing offset
@@done:
	mov     eax,[ESSI+SAMPLEINFO.loopStart] ; Loop values
	mov     [_bx+channelData.loopStart],eax
	mov     eax,[ESSI+SAMPLEINFO.loopEnd]
	mov     [_bx+channelData.loopEnd],eax

	mov     ax,[ESSI+SAMPLEINFO.sampleID]
	mov     [_bx+channelData.sampleID],ax

	or      [_bx+channelData.status],CH_VALID
	RETVAL  0
@@exit:
	LEAVEPROC _si
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   int mcpPlaySample(int channel, long freq, int volume);
; *
; *     Description :   Starts playing a new note on a channel.
; *
; ************************************************************************/

CPROC   mcpPlaySample @@channel,@@freq,@@volume

	ENTERPROC
        checkInit
        calcChannel

	test    [_bx+channelData.status],CH_VALID
	jz      @@exit
	mov     eax,[@@volume]            ; Volume
	inc     al                      ; Round it
	shr     al,1
	cmp     al,32
	jbe     @@volumeOK
	mov     al,32
@@volumeOK:
	mov     [_bx+channelData.volume],al
	mov     eax,[@@freq]
	sub     edx,edx
	shld    edx,eax,32-DELTA_ACCURACY
	shl     eax,32-DELTA_ACCURACY
	movzx   ecx,[samplingRate]
	div     ecx
	mov     [_bx+channelData.dLength],eax            ; Save delta-length
	mov     eax,[@@freq]
	mov     [_bx+channelData.rate],eax
	sub     edx,edx                 ; Calculate relative rate
	div     ecx
	mov     [_bx+channelData.rateQuo],ax
	sub     eax,eax                 ; EDX:EAX = remainder*65536
	shrd    eax,edx,16
	shr     edx,16
	div     ecx                     ; EAX = remainder*65536/samplingRate
	mov     [_bx+channelData.rateRem],ax
	mov     [_bx+channelData.played],0       ; Reset playing offset
	mov     [_bx+channelData.saveQuo],0      ; Reset playing quotient
	or      [_bx+channelData.status],CH_PLAYING      ; Start playing
	and     [_bx+channelData.status],NOT CH_LOOPING  ; Start playing
	RETVAL  0
@@exit:
	LEAVEPROC
	ret
ENDP

;/*************************************************************************
; *
; *     Function    :   int mcpSetVolume(int channel, int volume);
; *
; *     Description :   Adjusts channels volume. Affects immediately.
; *
; *     Input       :   channel number, new volume = 0 - 63
; *
; ************************************************************************/

CPROC   mcpSetVolume @@channel, @@volume

	ENTERPROC
	checkInit
	calcChannel

	mov     eax,[@@volume]
	inc     al
	shr     al,1
	cmp     al,32
	jng     @@volumeOK
	mov     al,32
@@volumeOK:
	mov     [_bx+channelData.volume],al
	RETVAL  0
@@exit:
	LEAVEPROC
	ret
ENDP

;/*************************************************************************
; *
; *     Function    :   int mcpSetRate(int channel, long rate);
; *
; *     Description :   Sets a new sampling rate (frequency) on channel.
; *                     Affects immediately.
; *
; *     Input       :   channel number, new sample rate (4000 - 40000)
; *
; ************************************************************************/

CPROC   mcpSetRate @@channel, @@sample_rate

	ENTERPROC
	checkInit
	calcChannel

	mov     eax,[@@sample_rate]       ; Sample rate
	mov     [_bx+channelData.rate],eax
	sub     edx,edx
	shld    edx,eax,32-DELTA_ACCURACY
	shl     eax,32-DELTA_ACCURACY
	movzx   ecx,[samplingRate]
	div     ecx
	mov     [_bx+channelData.dLength],eax    ; Save delta-length

	mov     eax,[@@sample_rate]
	sub     edx,edx                 ; Calculate relative rate
	div     ecx
	mov     [_bx+channelData.rateQuo],ax
	sub     eax,eax                 ; EDX:EAX = remainder*65536
	shrd    eax,edx,16
	shr     edx,16
	div     ecx                     ; EAX = remainder*65536/samplingRate
	mov     [_bx+channelData.rateRem],ax
	RETVAL  0
@@exit:
	LEAVEPROC
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   int mcpSetPosition(int channel,ushort position);
; *
; *     Description :   Resets sample's playing position to value in
; *                     'position'
; *
; *     Input       :   channel number, offset to sample
; *
; *     Returns     :   -3 no sample
; *                     -4 position is bigger than sample's length
; *
; ************************************************************************/

CPROC   mcpSetPosition @@channel,@@position

	ENTERPROC
	checkInit
	calcChannel

	RETVAL  -3
	test    [_bx+channelData.status],CH_PLAYING
	jz      @@exit
	mov     eax,[@@position]
	cmp     eax,[_bx+channelData.length]
	jb      @@ok                    ; OK, position < length
	mov     eax,[_bx+channelData.length]
	mov     [_bx+channelData.played],eax     ; Stop sample
	RETVAL  -4
	jmp     @@exit
@@ok:
	mov     [_bx+channelData.played],eax     ; Set offset
	mov     [_bx+channelData.saveQuo],0

	RETVAL  0                               ; No error
@@exit:
	LEAVEPROC
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   int mcpSetSamplingRate(int rate);
; *
; *     Description :   Sets a new overall sampling rate which determines
; *                     the quality of output sound.
; *
; *     Input       :   rate = new sampling rate
; *
; ************************************************************************/

CPROC   mcpSetSamplingRate @@rate

	ENTERPROC
	checkInit

	movzx   eax,[SoundCard.minRate]
	cmp     [@@rate],eax              ; Check for illegal values
	jb      @@exit
	movzx   eax,[SoundCard.maxRate]
	cmp     [@@rate],eax
	ja      @@exit

	ecallM  [SDI.initRate] [@@rate]
	mov     [samplingRate],ax

        mov     _cx,[channelCount]      ; Calculate new sampling rates
	jcxz    @@exit                  ; for channels
	sub     ebx,ebx
@@loop:
	push    ebx
	push    ebx
	shl     bx,1
	mov     bx,[chDataPtr+_bx]
	add     _bx,offset channelData
	mov     ebx,[_bx+channelData.rate]       ; BX = channel's current rate
	pop     edx
	push    _cx
	ecall   mcpSetRate edx,ebx         ; Set same rate which in turn
	pop     _cx                      ; calculates new relative rate.
	pop     ebx
	inc     ebx                     ; Next channel
	loop    @@loop                  ; Loop through all channels
	sub     ax,ax
@@exit:
	LEAVEPROC
	ret
ENDP

;/*************************************************************************
; *
; *     Function    :   unsigned mcpGetSamplingRate();
; *
; *     Description :   Returns current sampling rate
; *
; ************************************************************************/

CPROC   mcpGetSamplingRate

IF32	<sub	eax,eax>
	mov     ax,[samplingRate]
	ret
ENDP

;/*************************************************************************
; *
; *     Function    :   int mcpSetMasterVolume(int volume)
; *
; *     Description :   Master volume affects all channels
; *
; *     Input       :   volume = 0 - 64
; *
; ************************************************************************/

CPROC   mcpSetMasterVolume @@volume

	ENTERPROC
	checkInit

	cmp     [@@volume],64
	ja      @@exit
	mov     eax,[@@volume]
	mov     [masterVol],al
@@exit:
	LEAVEPROC
	ret
ENDP

;/*************************************************************************
; *
; *     Function    :   ushort mcpGetVolume(short channel);
; *
; *     Description :   Returns the current colume on a channel
; *
; *     Input       :   Channel number
; *
; *     Returns     :   Volume (0-64)
; *
; ************************************************************************/

CPROC   mcpGetVolume @@channel

	ENTERPROC
	checkInit
	calcChannel

	movzx   eax,[_bx+channelData.volume]
	shl     eax,1                   ; Multiply by 2
@@exit:
	LEAVEPROC
	ret
ENDP

;/*************************************************************************
; *
; *     Function    :   ushort mcpGetPosition(short channel);
; *
; *     Description :   Returns the current position on a channel
; *
; *     Input       :   Channel number
; *
; *     Returns     :   Current position
; *
; ************************************************************************/

CPROC   mcpGetPosition @@channel

	ENTERPROC
	checkInit
	calcChannel

	mov     eax,[_bx+channelData.played]
IF16	<mov     dx,[WORD HIGH _bx+channelData.played]>
@@exit:
	LEAVEPROC
	ret
ENDP

;/*************************************************************************
; *
; *     Function    :   void far *mcpGetSample(short channel);
; *
; *     Description :   Returns a pointer to current sample
; *
; *     Input       :   Channel number
; *
; *     Returns     :   Pointer to sample start
; *
; ************************************************************************/

CPROC   mcpGetSample @@channel

	ENTERPROC
	checkInit
	calcChannel

	mov     eax,[_bx+channelData.sPtr]
IF16	<mov     dx,[WORD HIGH _bx+channelData.sPtr]>
	cmp     [_bx+channelData.sampleID],0
	je      @@exit
	movzx   eax,[_bx+channelData.sampleID]
	ecall   mcpSampleRealAddress eax,<LARGE 0>
@@exit:
	LEAVEPROC
	ret
ENDP

;/*************************************************************************
; *
; *     Function    :   ulong mcpGetRate(short channel);
; *
; *     Description :   Returns the current frequency of the channel
; *
; *     Input       :   Channel number
; *
; *     Returns     :   Current rate (frequency) in Hertz
; *
; ************************************************************************/

CPROC   mcpGetRate @@channel

	ENTERPROC
	checkInit
	calcChannel

	mov     eax,[_bx+channelData.rate]
IF16	<mov     dx,[WORD HIGH _bx+channelData.rate]>
@@exit:
	LEAVEPROC
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   MCPOUTPUT far *mcpGetOutput(void);
; *
; *     Description :   Returns the current output position and buffer info
; *
; *     Returns     :   Pointer to local structure
; *
; ************************************************************************/

CPROC   mcpGetOutput

	checkInit

	ecallM  [SDI.getBufferPos]      ; Get output position
	mov     [mcpout.position],ax    ; Fill in the structure
IFDEF __16__
	mov     ax,[bufferSeg]
	mov     dx,[dataBuf]
	mov     [WORD HIGH mcpout.start],ax
	mov     [WORD LOW mcpout.start],dx
ELSE
	mov	eax,[dataBuf]
	mov	[mcpout.start],eax
ENDIF
	mov     _ax,[bufferSize]
	mov     [mcpout.length],ax
	mov     _ax,offset mcpout        ; Return a far pointer to structure
IF16	<mov     dx,ds>
@@exit:
	ret
ENDP


;/*************************************************************************
; *
; *     Function    :   int mcpSetPanning(short channel, short panpos);
; *
; *     Description :   Sets the panning position of a channel
; *
; *     Input       :   Channel and new pan position
; *                     0 = middle, 63 = right, -63 = left, 100 = surround
; *
; ************************************************************************/

CPROC   mcpSetPanning @@channel, @@panpos

	ENTERPROC
	checkInit
	calcChannel

	cmp     [SoundCard.stereo],0
	je      @@exit
	mov     eax,[@@panpos]
	mov     [_bx+channelData.pan],al
	RETVAL  0
@@exit:
	LEAVEPROC
	ret
ENDP

;/*************************************************************************
; *
; *     Function    :   short mcpGetPanning(short channel);
; *
; *     Description :   Gets the panning position of a channel
; *
; *     Returns     :   pan position
; *                     0 = middle, 63 = right, -63 = left, 100 = surround
; *
; ************************************************************************/

CPROC   mcpGetPanning @@channel, @@panpos

	ENTERPROC
	checkInit
	calcChannel

	cmp     [SoundCard.stereo],0
	je      @@exit
	movsx   eax,[_bx+channelData.pan]

@@exit:
	LEAVEPROC
	ret
ENDP

;/*************************************************************************
; *
; *     Function    :   void mcpDownLoad(short channel, void *sample, void *tag, long len);
; *
; ************************************************************************/

CPROC   mcpDownLoad @@channel,@@sample,@@sampletag,@@len

	ENTERPROC
        sub     _ax,_ax
	LEAVEPROC
	ret
ENDP

;/*************************************************************************
; *
; *     Function    :   void mcpUnloadAll(void);
; *
; ************************************************************************/

CPROC   mcpUnloadAll

        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   void mcpUnload(void *sample);
; *
; ************************************************************************/

CPROC   mcpUnload @@sample

        ENTERPROC
        LEAVEPROC
        ret
ENDP

;/***************************************************************************\
;*
;* Function:    void mcpSetEffectRoutine(void (*effRoutine)(void *buffer, long offset, long length, long dataType));
;*
;* Description: Sets a new callback effect routine for MCP
;*
;* Input:       Pointer to an effect routine
;*
;\***************************************************************************/

CPROC   mcpSetEffectRoutine @@effRoutine

        ENTERPROC
        mov     eax,[@@effRoutine]
        mov     [effectRoutine],eax
        LEAVEPROC
        ret
ENDP

ENDS

END

