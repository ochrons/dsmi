;/************************************************************************
; *
; *     File        :   AMPLAYER.ASM
; *     Description :   Player routine for Advanced Module Player
; *                     API routines for Advanced Module Player
; *
; *     Copyright (C) 1992-1994 Otto Chrons
; *
; ***********************************************************************
;
;       Revision history of AMPLAYER.ASM
;
;       1.0     ??.??.93 :)
;               First version with DSMI, supports most module commands
;               and is rather bug free. Format is AMF.
;
;       1.01    16.4.93
;               Corrected a bug with >6 channel modules, a 'sub bh,bh' was
;               in a wrong place.
;
;       1.02    7.5.93
;               Added cmdExtraFineBender
;
;               9.5.93  Fixed bender to note
;
;               11.5.93 Added support for panning.. no need for channel
;                       orders. */ampSetPanning/*
;
;               26.7.93 Started adding CDI support
;
;               27.11.93
;               New macros for easier conversion into 32-bit flat
;               No more C or Pascal models...
;
;               8.5.94
;               A few memory optimizations, bug fixes etc.
;
;       1.70    9.5.94
;               Fixed a mad bug in ampPlayRow. Effects were run too late
;               Fixed tremolo bug
;
; ***********************************************************************/

        IDEAL
        JUMPS
        P386

        INCLUDE "MODEL.INC"
        INCLUDE "MCP.INC"
        INCLUDE "AMP.INC"
        INCLUDE "CDI.INC"

        PRD2FRQ = 6848

CSEGMENTS AMPLAYER

IFDEF __PASCAL__
        EXTRN   mcpSampleRealAddress:_FAR
ELSE
        EXTRN   _mcpSampleRealAddress:_FAR
ENDIF

CDATASEG

        EXTRN   cdiStatus:WORD

IFDEF __16__
        DB      256 dup(?)

        LABEL   stack2  WORD
        oldSP   DW ?
        oldSS   DW ?
ENDIF

IFDEF   __PASCAL__

        EXTRN   _curModule:S_MODULE
ELSE
        CPUBLIC curModule

        _curModule      S_MODULE <>
ENDIF
        trackdata       S_TRACKDATA <>
        moduleinfo      S_PLAYINFO <>
        tracks          S_TRACKINFO MAXTRACKS dup(<>)
        samples         S_SAMPLEINFO MAXTRACKS dup(<>)
        masterVol       DB MAXTRACKS dup(?)
        ampStatus       DB ?
        bufferDelta     DW ?
        timerSpeed      DW ?            ; 23863
        DMAtick         DB ?
        IRQmask         DB ?
        tsTag           DW ?
        bytes2Calculate DW ?
        temp            DW ?
        ampBusy         DB ?
        ampInterruptBusy DB ?
        timeValue       DW ?
        calced          DD ?


ENDS

CCODESEG AMPLAYER

        CPUBLIC ampInit, ampClose
        CPUBLIC ampPlayModule, ampPlayMultiplePatterns, ampPlayPattern, ampPlayRow
	CPUBLIC ampStopModule, ampPauseModule, ampResumeModule, ampGetModuleStatus
	CPUBLIC ampGetTrackData, ampGetTrackStatus, ampMuteTrack, ampUnmuteTrack
        CPUBLIC ampSetMasterVolume
        CPUBLIC ampGetPattern, ampGetRow, ampGetSync
        CPUBLIC ampGetTempo, ampSetTempo, ampSetPanning
        CPUBLIC ampBreakPattern
        CPUBLIC ampGetBufferDelta, ampInterrupt, ampPoll

        copyrightText   DB "AMP v1.70 - (C) 1992-1994 Otto Chrons",0,1Ah

        count = 0
        LABEL   trackPtr WORD
        REPT MAXTRACKS
            DW count
            count = count + SIZE S_TRACKINFO
        ENDM

        count = 0
        LABEL   samplePtr WORD
        REPT MAXTRACKS
            DW count
            count = count + SIZE S_SAMPLEINFO
        ENDM


        LABEL   frequencyTable WORD

            DW 001Fh,0021h,0023h,0026h,0028h,002Ah,002Dh,002Fh,0032h,0035h,0039h,003Ch
            DW 003Fh,0043h,0047h,004Ch,0050h,0055h,005Ah,005Fh,0065h,006Bh,0072h,0078h
            DW 007Fh,0087h,008Fh,0098h,00A1h,00AAh,00B5h,00BFh,00CBh,00D7h,00E4h,00F1h
            DW 00FFh,010Fh,011Fh,0130h,0142h,0155h,016Ah,017Fh,0196h,01AEh,01C8h,01E3h
            DW 01FFh,021Eh,023Eh,0260h,0285h,02ABh,02D4h,02FFh,032Ch,035Dh,0390h,03C6h
            DW 03FFh,043Ch,047Dh,04C1h,050Ah,0556h,05A8h,05FEh,0659h,06BAh,0720h,078Dh
            DW 0800h,0879h,08FAh,0983h,0A14h,0AADh,0B50h,0BFCh,0CB3h,0D74h,0E41h,0F1Ah
            DW 1000h,10F3h,11F5h,1306h,1428h,155Bh,16A0h,17F9h,1966h,1AE8h,1C82h,1E34h
            DW 8192,8679,9195,9741,10321,10935,11585,12274,13004,13777,14596,15464
            DW 16384,17358,18390,19483,20642,21870,23170,24548,26008,27554,29163,30928
            DW 12 dup(8000h)

        LABEL   noteTable       WORD
            DW 24 dup(54783)
            DW 54783,51709,48806,46067,43482,41041,38738,36563,34511,32574,30746,29020
            DW 27391,25854,24403,23033,21741,20520,19369,18281,17255,16287,15373,14510
            DW 13695,12927,12201,11516,10870,10260,9684,9140,8627,8143,7686,7255
            DW PRD2FRQ,6463,6100,5758,5435,5130,4842,4570,4313,4071,3843,3627
            DW 3424,3231,3050,2879,2717,2565,2421,2285,2156,2035,1921,1813
            DW 1712,1615,1525,1439,1358,1282,1210,1142,1078,1017,960,906
            DW 856,807,762,719,679,641,605,571,539,508,480,453
            DW 428,403,381,359,339,320,302,285,269,254,240,226
            DW 214,201,190,179,169,160,151

        HIGH_NOTE       =       25
        LOW_NOTE        =       54783

        LABEL   vibratoTable    WORD

            DW 0,200,401,600,798,995,1188,1379
            DW 1567,1750,1930,2105,2275,2439,2597,2750
            DW 2895,3034,3165,3289,3404,3512,3611,3701
            DW 3783,3855,3918,3972,4016,4050,4075,4090
            DW 4095,4090,4075,4050,4016,3972,3918,3855
            DW 3783,3701,3611,3512,3404,3289,3165,3034
            DW 2895,2750,2597,2439,2275,2105,1930,1750
            DW 1567,1379,1188,995,798,600,401,200

        LABEL   arpeggioTable WORD

            DW 1024,1085,1149,1218,1290,1367,1448,1534,1625,1722,1825,1933
            DW 2048,2170,2298,2436

IFDEF __32__
        LABEL   commandProcs DWORD
            DD offset CMDinstrument
            DD offset CMDtempo
            DD offset CMDvolume
            DD offset CMDvolumeAbs
            DD offset CMDbender
            DD offset CMDbenderAbs
            DD offset CMDbenderTo
            DD offset CMDtremolo
            DD offset CMDarpeggio
            DD offset CMDvibrato
            DD offset CMDbenderVol
            DD offset CMDvibrVol
            DD offset CMDbreak
            DD offset CMDgoto
            DD offset CMDsync
            DD offset CMDretrig
            DD offset CMDoffset
            DD offset CMDfinevol
            DD offset CMDfinetune
            DD offset CMDdelaynote
            DD offset CMDnotecut
            DD offset CMDexttempo
            DD offset CMDextrafinebender
            DD offset CMDpanning
ELSE
        LABEL   commandProcs WORD
            DW offset CMDinstrument
            DW offset CMDtempo
            DW offset CMDvolume
            DW offset CMDvolumeAbs
            DW offset CMDbender
            DW offset CMDbenderAbs
            DW offset CMDbenderTo
            DW offset CMDtremolo
            DW offset CMDarpeggio
            DW offset CMDvibrato
            DW offset CMDbenderVol
            DW offset CMDvibrVol
            DW offset CMDbreak
            DW offset CMDgoto
            DW offset CMDsync
            DW offset CMDretrig
            DW offset CMDoffset
            DW offset CMDfinevol
            DW offset CMDfinetune
            DW offset CMDdelaynote
            DW offset CMDnotecut
            DW offset CMDexttempo
            DW offset CMDextrafinebender
            DW offset CMDpanning
ENDIF

;/***************************************************************************\
;*
;* Function:    adjustVolume
;*
;* Description: Adjusts the volume according to master volume
;*
;* Input:       @@track = track to adjust
;*              @@volume = original volume
;*
;* Returns:     EAX, adjusted volume
;*
;* Destroys:    nothing
;*
;\***************************************************************************/

CPROC   adjustVolume @@track,@@volume

        ENTERPROC       ebx
        mov     ebx,[@@track]
        mov     eax,[@@volume]
        movzx   ebx,[_bx+masterVol]
        imul    eax,ebx
        shr     eax,6                   ; Div by 64
        LEAVEPROC       ebx
        ret
ENDP


PROC    CMDnone NEAR
CMDbenderAbs:
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   CMDpanning
; *
; *     Description :   Pans channel to left or right
; *
; ************************************************************************/

PROC    CMDpanning NEAR

        mov     bx,dx
        movzx   eax,[ESDI+S_MODCMD.data]
        mov     [_bx+tracks.cmd.command],cPan
        mov     [_bx+tracks.cmd.value],al        ; AL = panning value
        cmp     al,100                          ; Surround
        je      @@ok2
        cmp     al,-63
        jge     @@ok1
        mov     al,-63
@@ok1:
        cmp     al,63
        jle     @@ok2
        mov     al,63
@@ok2:
        movzx   edx,[moduleinfo.track]
        ecall   ampSetPanning edx,eax   ; Set new panning

        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   CMDnotecut
; *
; *     Description :   Cuts note in x frames
; *
; ************************************************************************/

PROC    CMDnotecut NEAR

        mov     bx,dx
        mov     al,[ESDI+S_MODCMD.data]
        mov     [_bx+tracks.cmd.command],cNotecut
        mov     [_bx+tracks.cmd.value],al

        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   CMDdelaynote
; *
; *     Description :   Delays note from playing
; *
; ************************************************************************/

PROC    CMDdelaynote NEAR

        mov     bx,dx
        mov     cl,[ESDI+S_MODCMD.data]
        or      cl,cl                   ; Is CL = 0?
        jnz     @@valueOK
        inc     cl                      ; CL = 1 (minimum value)
@@valueOK:
        mov     [_bx+tracks.cmd.value],cl
        mov     al,[ESDI+S_MODCMD.timesig]
        cmp     al,[ESDI+3+S_MODCMD.timesig]
        jne     @@exit
        mov     al,[ESDI+3+S_NOTE.note]
        test    al,80h
        jnz     @@exit
        cmp     al,7Fh
        je      @@nonew
        mov     [_bx+tracks.note.note],al
@@nonew:
        mov     al,[ESDI+3+S_NOTE.velocity]
        cmp     al,255
        je      @@10
        mov     [_bx+tracks.note.velocity],al
@@10:
        mov     [_bx+tracks.cmd.command],cDelayNote
        add     [_bx+tracks.pos],3
@@exit:
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   void CMDfinetune
; *
; *     Description :   Changes note's pitch
; *
; ************************************************************************/

PROC    CMDfinetune NEAR

        mov     bx,dx
        mov     al,[ESDI+S_MODCMD.data]
        cbw
        mov     [_bx+tracks.cmd.command],cFinetune
        mov     [_bx+tracks.cmd.value],al
        mov     cx,[_bx+tracks.note.noteold]
        sal     ax,4                    ; * 16
        add     cx,ax
        js      @@top
        cmp     cx,HIGH_NOTE
        ja      @@noteok
@@top:
        mov     cx,HIGH_NOTE
@@noteok:
        mov     [_bx+tracks.note.noteold],cx
        sub     _ax,_ax
        mov     al,[moduleinfo.track]
        mov     _di,_ax
        shl     _di,1
        mov     di,[_di+samplePtr]
        movzx   eax,[_di+samples.orgrate]
        movzx   ecx,cx
        mov     edx,PRD2FRQ
        mul     edx
        div     ecx
        mov     [_di+samples.rate],eax
        movzx   edx,[moduleinfo.track]
        ecall   cdiSetFrequency edx,eax

        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   void CMDfinevol
; *
; *     Description :   Finetunes volume up/down.
; *
; ************************************************************************/

PROC    CMDfinevol NEAR

        mov     bx,dx
        movzx   eax,[ESDI+S_MODCMD.data]
        mov     [_bx+tracks.cmd.command],cFinevol
        mov     [_bx+tracks.cmd.value],al        ; AL = volume change
        add     al,[_bx+tracks.note.velocity]
        jns     @@10
        sub     al,al
@@10:
        cmp     al,64
        jle     @@20
        mov     al,64
@@20:
        mov     [_bx+tracks.note.velocity],al
        movzx   edx,[moduleinfo.track]
        ecall   adjustVolume edx,eax
        ecall   cdiSetVolume edx,eax

        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   void CMDoffset
; *
; *     Description :   Sets a new sample offset
; *
; ************************************************************************/

PROC    CMDoffset NEAR

        mov     bx,dx
        mov     ah,[ESDI+S_MODCMD.data]
        mov     [_bx+tracks.cmd.command],cOffset
        or      ah,ah
        jnz     @@NewValue
        mov     ah,[_bx+tracks.cmd.offsetValue]
@@NewValue:
        mov     [_bx+tracks.cmd.offsetValue],ah
        sub     al,al
        movzx   edx,[moduleinfo.track]  ; DX = Channel
        movzx   esi,dx
        shl     _si,1
        mov     si,[_si+samplePtr]      ; DS:SI points to sample structure
        movzx   eax,ax
        cmp     eax,[_si+samples.length]
        jna     @@lengthok
        mov     eax,[_si+samples.loopstart]
@@lengthok:
        ecall   cdiSetPosition edx,eax  ; Set sample's offset

        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   void CMDretrig
; *
; *     Description :   Retrigs note rapidly
; *
; ************************************************************************/

PROC    CMDretrig NEAR

        mov     bx,dx
        mov     al,[ESDI+S_MODCMD.data]
        or      al,al
        jz      @@exit
        mov     [_bx+tracks.cmd.command],cRetrig
        mov     [_bx+tracks.cmd.value],al
@@exit:
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   CMDsync
; *
; *     Description :   Command for synchronization
; *
; ************************************************************************/

PROC    CMDsync NEAR

        mov     al,[ESDI+S_MODCMD.data]
        mov     [moduleinfo.sync],al
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   CMDvibrVol
; *
; *     Description :   Both vibrato & volume slide
; *
; ************************************************************************/

PROC    CMDvibrVol NEAR

        mov     bx,dx
        mov     al,[ESDI+S_MODCMD.data]
        mov     [_bx+tracks.cmd.command],cVibrVol
        mov     [_bx+tracks.cmd.value],al
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   CMDbenderVol
; *
; *     Description :   Both bender-to-note & volume slide
; *
; ************************************************************************/

PROC    CMDbenderVol NEAR

        mov     bx,dx
        mov     al,[ESDI+S_MODCMD.data]
        mov     [_bx+tracks.cmd.command],cBenderVol
        mov     [_bx+tracks.cmd.value],al
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   CMDtremolo
; *
; *     Description :   Vibrates sound
; *
; ************************************************************************/

PROC    CMDtremolo NEAR

        mov     bx,dx                   ; Restore BX
        mov     al,[ESDI+S_MODCMD.data]
        mov     [_bx+tracks.cmd.value],al
        mov     dl,[_bx+tracks.cmd.tremoloCmd]
        or      al,al
        jz      @@20
        mov     ah,al
        and     al,0Fh
        jz      @@10
        and     dl,0F0h
        or      dl,al
@@10:
        and     ah,0F0h
        jz      @@20
        and     dl,0Fh
        or      dl,ah
@@20:
        mov     [_bx+tracks.cmd.tremoloCmd],dl
        mov     ah,dl
        mov     al,dl
        and     al,0Fh
        shr     ah,4
        mov     [_bx+tracks.cmd.command],cTremolo
        mov     [_bx+tracks.cmd.tremoloSpeed],ah
        mov     [_bx+tracks.cmd.tremoloValue],al
@@exit:
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   CMDvibrato
; *
; *     Description :   Vibrates sound
; *
; ************************************************************************/

PROC    CMDvibrato NEAR

        mov     bx,dx                   ; Restore BX
        mov     al,[ESDI+S_MODCMD.data]
        mov     [_bx+tracks.cmd.command],cVibrato
        mov     dl,[_bx+tracks.cmd.vibratoCmd]
        or      al,al
        jz      @@20
        mov     ah,al
        and     al,0Fh
        jz      @@10
        and     dl,0F0h
        or      dl,al
@@10:
        and     ah,0F0h
        jz      @@20
        and     dl,0Fh
        or      dl,ah
@@20:
        mov     [_bx+tracks.cmd.vibratoCmd],dl
        mov     [_bx+tracks.cmd.value],dl
@@exit:
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   CMDarpeggio
; *
; *     Description :   Makes a chord
; *
; ************************************************************************/

PROC    CMDarpeggio NEAR

        mov     bx,dx                   ; Restore BX
        mov     al,[ESDI+S_MODCMD.data]
        or      al,al
        jz      @@exit
        mov     [_bx+tracks.cmd.command],cArpeggio
        mov     [_bx+tracks.cmd.value],al
        mov     al,[moduleinfo.track]
        sub     ah,ah
        movzx   esi,ax
        shl     _si,1
        mov     si,[_si+samplePtr]
        mov     ecx,[_si+samples.rate]
        mov     [_bx+tracks.cmd.arpeggio1],ecx
        mov     al,[_bx+tracks.cmd.value]
        shr     al,4
        sub     ah,ah
        movzx   esi,ax
        shl     _si,1
        movzx   eax,[_si+arpeggioTable]
        mul     ecx
        shrd    eax,edx,10                      ; EAX = EAX / 1024
        mov     [_bx+tracks.cmd.arpeggio2],eax
        mov     al,[_bx+tracks.cmd.value]
        and     ax,000Fh
        movzx   esi,ax
        shl     _si,1
        movzx   eax,[_si+arpeggioTable]
        mul     ecx
        shrd    eax,edx,10                      ; EAX = EAX / 1024
        mov     [_bx+tracks.cmd.arpeggio3],eax
@@exit:
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   CMDbenderTo
; *
; *     Description :   Slides track's pitch towards a note
; *
; ************************************************************************/

PROC    CMDbenderTo NEAR

        mov     bx,dx                   ; Restore BX
        mov     cl,[ESDI+S_MODCMD.data]
        or      cl,cl
        jnz     @@01
        mov     cl,[_bx+tracks.cmd.benderCmd]
@@01:
        mov     [_bx+tracks.cmd.benderCmd],cl
        mov     al,[ESDI+S_MODCMD.timesig]
        cmp     al,[ESDI+3+S_MODCMD.timesig]
        jne     @@10
        mov     al,[ESDI+3+S_NOTE.note]
        test    al,80h
	jnz     @@10
	cmp	al,7Fh
	jne	@@new
	mov     al,[_bx+tracks.note.note]
@@new:
        mov     [_bx+tracks.note.note],al
	sub     ah,ah
        movzx   esi,ax
        shl     _si,1
        mov     ax,[_si+noteTable]
        mov     [_bx+tracks.cmd.bendervalue],ax
        add     [_bx+tracks.pos],3
	sub	eax,eax
	mov     al,[ESDI+3+S_NOTE.velocity]
	cmp     al,255
	je      @@10
	mov     [_bx+tracks.note.velocity],al
@@10:
	push	cx _bx
	movzx   edx,[moduleinfo.track]		; Set new volume
	ecall   adjustVolume edx,eax
	ecall   cdiSetVolume edx,eax
	pop	_bx cx

	mov     ax,[_bx+tracks.cmd.bendervalue]
        cmp     ax,[_bx+tracks.note.noteold]
	jae     @@05
        neg     cl
@@05:
        mov     [_bx+tracks.cmd.command],cBenderTo
        mov     [_bx+tracks.cmd.benderAdd],cl
@@exit:
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   CMDbender
; *
; *     Description :   Slides track's pitch
; *
; ************************************************************************/

PROC    CMDbender NEAR

        mov     bx,dx                   ; Restore BX
        mov     cl,[ESDI+S_MODCMD.data]
        cmp     cl,-128
        jne     @@00
        mov     cl,[_bx+tracks.cmd.benderCmd2]
        or      cl,cl
        jl      @@01
        neg     cl
        jmp     @@01
@@00:
	or      cl,cl
        jnz     @@01
        mov     cl,[_bx+tracks.cmd.benderCmd2]
        or      cl,cl
        jg      @@01
        neg     cl
@@01:
        mov     [_bx+tracks.cmd.benderCmd2],cl
        mov     [_bx+tracks.cmd.command],cBender
        mov     [_bx+tracks.cmd.value],cl
@@exit:
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   CMDextrafinebender
; *
; *     Description :   Slides track's pitch very fine
; *
; ************************************************************************/

PROC    CMDextrafinebender NEAR

        mov     bx,dx                   ; Restore BX
        mov     al,[ESDI+S_MODCMD.data]
        cmp     al,0
        je      @@exit
        mov     [_bx+tracks.cmd.command],cExtraFineBender
        mov     [_bx+tracks.cmd.value],al
@@exit:
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   CMDvolume
; *
; *     Description :   Slides track's volume
; *
; ************************************************************************/

PROC    CMDvolume NEAR

	mov     bx,dx                   ; Restore BX
        mov     al,[ESDI+S_MODCMD.data]
        mov     [_bx+tracks.cmd.command],cVolume
        mov     [_bx+tracks.cmd.value],al
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   CMDvolumeAbs
; *
; *     Description :   Changes track's volume
; *
; ************************************************************************/

PROC    CMDvolumeAbs NEAR

        mov     bx,dx                   ; Restore BX
        sub     eax,eax
        mov     al,[ESDI+S_MODCMD.data]
        mov     [_bx+tracks.note.velocity],al
        movzx   edx,[moduleinfo.track]
        ecall   adjustVolume edx,eax
        ecall   cdiSetVolume edx,eax
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   CMDgoto
; *
; *     Description :   Changes current pattern
; *
; ************************************************************************/

PROC    CMDgoto NEAR

        mov     ah,[moduleinfo.pattern]
        mov     al,[ESDI+S_MODCMD.data] ; AL = next pattern to play
        dec     al
        cmp     al,ah
        jge     @@ok
        test    [moduleinfo.options],PM_LOOP
        jz      @@exit
@@ok:
        mov     al,[ESDI+S_MODCMD.data] ; AL = next pattern to play
        dec     al
        cmp     al,[moduleinfo.lastPattern]
        jg      @@exit
        mov     [moduleinfo.pattern],al
        mov     [moduleinfo.break],1    ; Break current pattern
@@exit:
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   CMDbreak
; *
; *     Description :   Breaks current pattern
; *
; ************************************************************************/

PROC    CMDbreak NEAR

        mov     [moduleinfo.break],1    ; End pattern
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   CMDtempo
; *
; *     Description :   Changes module's tempo
; *
; ************************************************************************/

PROC    CMDtempo NEAR

        mov     al,[ESDI+S_MODCMD.data]  ; AL = tempo
        cmp     al,[moduleinfo.tempo]   ; Is it the same
        je      @@exit
        or      al,al
        jz      @@exit
        mov     [moduleinfo.tempo],al
@@exit:
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   CMDexttempo
; *
; *     Description :   Changes module's tempo (ProTracker extended)
; *
; ************************************************************************/

PROC    CMDexttempo NEAR

        mov     al,[ESDI+S_MODCMD.data]  ; AL = tempo
        cmp     al,[moduleinfo.extTempo]        ; Is it the same
        je      @@exit
        or      al,al
        jz      @@exit
        mov     [moduleinfo.extTempo],al
        sub     ah,ah
        imul    ax,50
        sub     dx,dx
        mov     cx,125
        div     cx
        mov     [timeValue],ax
        mov     [calced],0
@@exit:
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   CMDinstrument
; *
; *     Description :   Sets a new instrument on the track
; *
; ************************************************************************/

PROC    CMDinstrument NEAR
locs=0
        LOCALVAR        _byte @@noNote

        enter   locs,0
        mov     bx,dx                   ; Restore BX
        mov     al,[ESDI+S_MODCMD.data]
        mov     [_bx+tracks.note.instrument],al
        mov     dl,[ESDI+S_MODCMD.timesig]
	mov     [byte @@noNote],1
        cmp     dl,[ESDI+3+S_MODCMD.timesig]
        jne     @@ok
        test    [ESDI+3+S_MODCMD.cmd],80h
        jnz     @@ok
        mov     [byte @@noNote],0
@@ok:
        movzx   _di,al
        imul    _di,SIZE S_INSTRUMENT
IFDEF __C32__
        mov     eax,[moduleinfo.instrdata]
        add     edi,eax
ELSE
        les     ax,[moduleinfo.instrdata]
	add     di,ax                   ; ESDI = new instrument
ENDIF
        mov     al,[moduleinfo.track]
        sub     ah,ah
        movzx   esi,ax
        shl     _si,1
        mov     si,[_si+samplePtr]      ; Copy instrument structure into
                                        ; sample structure
        mov     eax,[ESDI+S_INSTRUMENT.sample]
        mov     [_si+samples.sample],eax
        mov     eax,[ESDI+S_INSTRUMENT.size]
        mov     [_si+samples.length],eax
        mov     ax,[ESDI+S_INSTRUMENT.rate]
        mov     [_si+samples.orgrate],ax
        mov     eax,[ESDI+S_INSTRUMENT.loopstart]
        mov     [_si+samples.loopstart],eax
        mov     eax,[ESDI+S_INSTRUMENT.loopend]
        mov     [_si+samples.loopend],eax
        mov     al,[ESDI+S_INSTRUMENT.volume]
        mov     [_si+samples.volume],al
	mov     [_bx+tracks.note.velocity],al
        mov     [_si+samples.mode],SAMPLE_CONTINUE

        mov     [_si+samples.sampleID],0
        cmp     [WORD HIGH si+samples.sample],0FFFFh
        jne     @@noEMS
        mov     ax,[WORD LOW si+samples.sample]
        mov     [_si+samples.sampleID],ax
@@noEMS:
        movzx   eax,[moduleinfo.track]
        lea     _dx,[_si+samples]
IFDEF __C32__
        ecall   cdiSetInstrument eax,edx
ELSE
        ecall   cdiSetInstrument eax,<ds dx>
ENDIF
        movzx   eax,[_si+samples.volume]
        movzx   edx,[moduleinfo.track]
        ecall   adjustVolume edx,eax
        ecall   cdiSetVolume edx,eax
@@exit:
        leave
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   playCommand
; *
; *     Description :   Handles module commands
; *
; ************************************************************************/

PROC    playCommand NEAR

        push    _bx _si _di
        PUSHES

        sub     ah,ah
        mov     al,[ESDI+S_MODCMD.cmd]
        and     al,7Fh                  ; AX = command
        mov     dx,bx                   ; Save BX
        movzx   ebx,ax
        cmp     _bx,cLast
        ja      @@exit
IFDEF __C32__
        shl     _bx,2                   ; BX = command*4
ELSE
        shl     _bx,1                   ; BX = command*2
ENDIF
        call    [commandProcs+_bx]      ; Call appropriate routine
@@exit:
	POPES
        pop     _di _si _bx
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   playNote
; *
; *     Description :   Plays sample on track
; *
; ************************************************************************/

PROC    playNote NEAR

	push    _bx _si _di
	PUSHES
	mov     al,[ESDI+S_NOTE.note]
	cmp     al,07Fh
	je      @@noNewNote
	mov     [_bx+tracks.note.note],al
@@noNewNote:
        mov     al,[ESDI+S_NOTE.velocity]
        cmp     al,255
        je      @@10
        mov     [_bx+tracks.note.velocity],al
@@10:
        mov     [_bx+tracks.note.played],0
        mov     [_bx+tracks.cmd.vibratoPos],0
        movzx   edi,[moduleinfo.track]
        shl     _di,1
        mov     di,[_di+samplePtr]      ; DS:DI = sample structure
        push    ebx
        push    bx
        mov     bl,[_bx+tracks.note.note]
        sub     bh,bh
        shl     _bx,1
	mov     ax,[_bx+noteTable]
	sub     ebx,ebx
        pop     bx
	mov     [_bx+tracks.note.noteold],ax
        mov     [_bx+tracks.cmd.bendervalue],ax
        mov     bl,[_bx+tracks.note.note]
        sub     bh,bh
	shl     _bx,1
        mov     bx,[_bx+frequencyTable]
        movzx   eax,[_di+samples.orgrate]       ; EAX = frequency of middle-C
        mul     ebx                     ; DX:AX = AX*(relative frequency)
        shrd    eax,edx,10
        pop     ebx
        mov     [_di+samples.rate],eax
        mov     ecx,eax
        movzx   edx,[_bx+tracks.note.velocity]
        mov     [_di+samples.volume],dl
        movzx   eax,[moduleinfo.track]
        ecall   adjustVolume eax,edx
        mov     edx,eax
        movzx   eax,[moduleinfo.track]
        test    [_bx+tracks.status],PAUSED
        jnz     @@exit
        ecall   cdiPlayNote eax,ecx,edx
@@exit:
        POPES
        pop     _di _si _bx
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   playTrack
; *
; *     Description :   plays current note on track
; *
; *     Input       :   BX = track number to play
; *
; ************************************************************************/

CPROC   playTrack
        LOCALVAR        _word @@trck
        LOCALVAR        _byte @@oldCommand

        ENTERPROC       _cx _bx

        mov     [moduleinfo.track],bl
        shl     _bx,1
        mov     bx,[_bx+trackPtr]
        mov     [@@trck],bx
        mov     al,[_bx+tracks.cmd.command]
        mov     [byte @@oldCommand],al                  ; Save command byte
        mov     [_bx+tracks.cmd.command],0      ; Stop command
        mov     [_bx+tracks.cmd.value],0
        cmp     [_bx+tracks.pos],-1     ; Is track finished?
        je      @@exit
        LESDI   [_bx+tracks.track]
IFDEF __32__
        or      edi,edi
        jz      @@exit                  ; Yes, exit
        movzx   eax,[ebx+tracks.pos]
        add     edi,eax                 ; ESDI = track data
ELSE
        mov     ax,es
        or      ax,di                   ; Is ESDI = NULL ?
        jz      @@exit                  ; Yes, exit
        add     di,[bx+tracks.pos]     ; ESDI = track data
ENDIF
@@next:
        mov     al,[ESDI+S_NOTE.timesig]
        cmp     al,0FFh                 ; Has track ended?
        jne     @@continue
        mov     [_bx+tracks.pos],-1
        jmp     @@exit
@@continue:
        sub     ah,ah                   ; AX = next note's tick
        cmp     ax,[moduleinfo.ticks]   ; Should we react
        jg      @@exit                  ; Nope
        push    [_bx+tracks.pos]
        test    [ESDI+S_NOTE.note],80h  ; Is note actually a command?
        jz      @@note
        call    playCommand
        jmp     short @@done
@@note:
        call    playNote
@@done:
        pop     ax
        sub     ax,[_bx+tracks.pos]
        neg     ax
        cwde
        add     _di,_ax
        add     _di,3
        add     [_bx+tracks.pos],3
        jmp     @@next
@@exit:
        mov     al,[byte @@oldCommand]
        cmp     al,[_bx+tracks.cmd.command]
        je      @@alright
        movzx   edx,[moduleinfo.track]
        mov     _di,_dx
        shl     _di,1
        mov     di,[_di+samplePtr]
        ecall   cdiSetFrequency edx,[_di+samples.rate]  ; Set right rate
@@alright:
IF32    <sub    ebx,ebx>
        mov     bx,[@@trck]
        movzx   eax,[_bx+tracks.note.velocity]
        movzx   edx,[moduleinfo.track]
        ecall   adjustVolume edx,eax
        ecall   cdiSetVolume edx,eax
        LEAVEPROC       _cx _bx
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   nextPattern
; *
; *     Description :   Breaks current patterns and continues with next one
; *
; ************************************************************************/

PROC    nextPattern NEAR

        mov     [moduleinfo.ticks],0    ; Reset ticks
        sub     _ax,_ax
        mov     al,[moduleinfo.pattern]
        cmp     al,[moduleinfo.lastPattern]     ; Is it the last pattern?
        jb      @@10
        test    [moduleinfo.options],PM_LOOP
        jnz     @@20
        ecall   ampStopModule
        mov     ax,-1                   ; Stop moduleinfo
        jmp     @@exit
@@20:
        mov     al,[moduleinfo.firstPattern]
        mov     [moduleinfo.pattern],al ; Select the first pattern
@@10:
        imul    _ax,SIZE S_PATTERN
        LESDI   [moduleinfo.patterndata]
        add     _di,_ax                 ; ESDI = patterns[startpat]

        mov     ax,[ESDI+S_PATTERN.length]
        mov     [moduleinfo.patternLength],ax
IF32    <sub    ecx,ecx>
        mov     cx,[moduleinfo.channelCount]
        push    _bx
        sub     _bx,_bx
@@loop:                                 ; Copy track pointers
        mov     eax,[ESDI+S_PATTERN.track]
        mov     [_bx+tracks.track],eax
        mov     [_bx+tracks.pos],3
        add     _di,4
        add     _bx,SIZE S_TRACKINFO
        loop    @@loop
        pop     _bx
        sub     _ax,_ax                 ; Still going
@@exit:
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   slideVolume
; *
; *     Description :   Slides track's volume
; *
; ************************************************************************/

PROC    slideVolume NEAR

        movzx   eax,[_bx+tracks.cmd.value]
        add     al,[_bx+tracks.note.velocity]
        jns     @@10
        sub     al,al
@@10:
        cmp     al,64
        jle     @@20
        mov     al,64
@@20:
        mov     [_bx+tracks.note.velocity],al
        movzx   edx,[moduleinfo.track]
        ecall   adjustVolume edx,eax
        ecall   cdiSetVolume edx,eax
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   slidePitchFine
; *
; *     Description :   Slides sample's pitch very fine
; *
; ************************************************************************/

PROC    slidePitchFine NEAR

        mov     cx,[_bx+tracks.note.noteold]
        mov     al,[_bx+tracks.cmd.value]
        cbw
        add     cx,ax
        js      @@top
        or      ax,ax
        jz      @@exit
        cmp     cx,HIGH_NOTE
        ja      @@noteok
@@top:
	mov     cx,HIGH_NOTE
@@noteok:
        mov     [_bx+tracks.note.noteold],cx
        sub     _ax,_ax
        mov     al,[moduleinfo.track]
        mov     _di,_ax
        shl     _di,1
        mov     di,[_di+samplePtr]
        movzx   eax,[_di+samples.orgrate]
        movzx   ecx,cx
        mov     edx,PRD2FRQ
        mul     edx
        div     ecx
        mov     [_di+samples.rate],eax
        movzx   edx,[moduleinfo.track]
        ecall   cdiSetFrequency edx,eax
@@exit:
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   slidePitch
; *
; *     Description :   Slides sample's pitch
; *
; ************************************************************************/

PROC    slidePitch NEAR

	mov     cx,[_bx+tracks.note.noteold]
	mov     al,[_bx+tracks.cmd.value]
	cbw
	sal     ax,4                    ; * 16
	or      ax,ax
	jz      @@exit
	js	@@negative
	add     cx,ax
	jmp	@@noteok
@@negative:
	neg	ax
	cmp	ax,cx
	ja	@@top
	sub	cx,ax
	cmp	cx,HIGH_NOTE
	ja	@@noteok
@@top:
	mov     cx,HIGH_NOTE
@@noteok:
	cmp     cx,LOW_NOTE
	jb      @@noteok2
	mov     cx,LOW_NOTE
@@noteok2:
	mov     [_bx+tracks.note.noteold],cx
        sub     _ax,_ax
        mov     al,[moduleinfo.track]
        mov     _di,_ax
        shl     _di,1
        mov     di,[_di+samplePtr]
        movzx   eax,[_di+samples.orgrate]
        movzx   ecx,cx
        mov     edx,PRD2FRQ
        mul     edx
        div     ecx
        mov     [_di+samples.rate],eax
        movzx   edx,[moduleinfo.track]
        ecall   cdiSetFrequency edx,eax
@@exit:
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   slidePitchNote
; *
; *     Description :   Slides sample's pitch towards note
; *
; ************************************************************************/

PROC    slidePitchNote NEAR

	mov     cx,[_bx+tracks.note.noteold]
	mov     al,[_bx+tracks.cmd.benderAdd]
	cbw
	sal     ax,4                    ; * 16
	or      ax,ax
	jz      @@exit
	mov	dx,[_bx+tracks.cmd.bendervalue]
	sub	dx,cx
	jns	@@nosign
	neg	ax
	neg	dx
	cmp	ax,dx
	ja	@@reset
	neg	ax
	jmp	@@addit
@@nosign:
	cmp	ax,dx
	ja	@@reset
@@addit:
	add	cx,ax
	jmp     short @@20
@@reset:
	mov     cx,[_bx+tracks.cmd.bendervalue]
	jcxz	@@exit
@@20:
	mov     [_bx+tracks.note.noteold],cx
        sub     _ax,_ax
	mov     al,[moduleinfo.track]
        mov     _di,_ax
        shl     _di,1
	mov     di,[_di+samplePtr]
	movzx   eax,[_di+samples.orgrate]
	movzx   ecx,cx
	mov     edx,PRD2FRQ
        mul     edx
        div     ecx
        mov     [_di+samples.rate],eax
	movzx   edx,[moduleinfo.track]
        ecall   cdiSetFrequency edx,eax
@@exit:
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   arpeggio
; *
; *     Description :   Implements a chord on track
; *
; ************************************************************************/

PROC    arpeggio NEAR

        sub     ah,ah
        mov     al,[moduleinfo.cmdcount]
        mov     dl,3
        div     dl
	xchg    ah,al                   ; AL = remainder
        sub     ah,ah
	movzx   edi,ax
	shl     _di,2
	mov     eax,[_bx+_di+tracks.cmd.arpeggio1]
	movzx   edx,[moduleinfo.track]
	ecall   cdiSetFrequency edx,eax
	ret
ENDP

;/*************************************************************************
; *
; *     Function    :   vibrato
; *
; *     Description :   Vibrates sound
; *
; ************************************************************************/

PROC    vibrato NEAR

	mov     al,[_bx+tracks.cmd.vibratoPos]
	shr     al,2
	and     _ax,001Fh
	mov     _di,_ax
	shl     _di,1
	mov     dx,[_di+vibratoTable]
	mov     al,[_bx+tracks.cmd.vibratoCmd]
	and     al,0Fh
	mul     dx
	shrd    ax,dx,7

	mov     cx,[_bx+tracks.note.noteold]    ; CX is Amiga note value
	cmp     [_bx+tracks.cmd.vibratoPos],0
	js      @@10
	add     cx,ax
	jmp     @@20
@@10:
	sub     cx,ax
@@20:
	cmp     cx,HIGH_NOTE
	ja      @@noteok
	mov     cx,HIGH_NOTE
@@noteok:
	sub     _ax,_ax
	mov     al,[moduleinfo.track]
	mov     _di,_ax
	shl     _di,1
	mov     di,[_di+samplePtr]              ; DI = samples[track]
	movzx   eax,[_di+samples.orgrate]
	movzx   ecx,cx
	mov     edx,PRD2FRQ
	mul     edx
	div     ecx
	movzx   edx,[moduleinfo.track]
	push    _bx
	ecall   cdiSetFrequency edx,eax
	pop     _bx

	mov     al,[_bx+tracks.cmd.vibratoCmd]
	shr     al,2
	and     al,3Ch
	add     [_bx+tracks.cmd.vibratoPos],al
@@exit:
	ret
ENDP

;/*************************************************************************
; *
; *     Function    :   tremolo
; *
; *     Description :   Changes samples volume rapidly
; *
; ************************************************************************/

PROC    tremolo NEAR

        mov     al,[_bx+tracks.cmd.tremoloPos]
        shr     al,2
	and     _ax,001Fh
	mov     _di,_ax
	shl     _di,1
	mov     dx,[_di+vibratoTable]
	mov     al,[_bx+tracks.cmd.tremoloValue]
	mul     dx
	shrd    ax,dx,10
	mov     dx,ax

	movzx   cx,[_bx+tracks.note.velocity]   ; CX is volume
        cmp     [_bx+tracks.cmd.tremoloPos],0
        jns     @@10
        add     cx,dx
        jmp     @@20
@@10:
        sub     cx,dx
        jns     @@20                            ; If negative
        sub     cx,cx                           ; then zero
@@20:
        cmp     cx,64                           ; Overflow?
        jle     @@30
        mov     cx,64
@@30:
        cmp     cx,0
        jge     @@40
        mov     cx,0
@@40:
        movzx   edx,[moduleinfo.track]
        push    _bx
        movzx   ecx,cx
        ecall   adjustVolume edx,ecx
        ecall   cdiSetVolume edx,eax
        pop     _bx

        mov     al,[_bx+tracks.cmd.tremoloSpeed]
        shl     al,2
        and     al,3Ch
        add     [_bx+tracks.cmd.tremoloPos],al
@@exit:
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   benderVol
; *
; *     Description :   Runs benderTo & volume slide
; *
; ************************************************************************/

PROC    benderVol NEAR

        push    _bx
        call    slidePitchNote
        pop     _bx
        call    slideVolume

        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   vibratoVol
; *
; *     Description :   Runs vibrato & volume slide
; *
; ************************************************************************/

PROC    vibratoVol NEAR

        push    _bx
        call    vibrato
        pop     _bx
        call    slideVolume

        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   retrig
; *
; *     Description :   Retrigs note
; *
; ************************************************************************/

PROC    retrig NEAR

        mov     al,[moduleinfo.cmdcount]
        sub     ah,ah
        mov     dl,[_bx+tracks.cmd.value]
        div     dl                      ; AH = remainder
        or      ah,ah                   ; Is it zero?
        jnz     @@exit
        movzx   edx,[moduleinfo.track]  ; DX = Channel
        ecall   cdiSetPosition edx,<LARGE 0>    ; Set sample's offset
@@exit:
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   delaynote
; *
; *     Description :   Plays a delayed note
; *
; ************************************************************************/

PROC    delaynote NEAR

        mov     al,[_bx+tracks.cmd.value]
        cmp     al,[moduleinfo.cmdcount]
        jne     @@exit
        mov     [_bx+tracks.note.played],0
        sub     _ax,_ax
        mov     al,[moduleinfo.track]
        mov     _di,_ax
        shl     _di,1
        mov     di,[_di+samplePtr]      ; DS:DI = sample structure
        push    _bx
        push    _bx
        sub     _bx,_bx
        mov     bl,[_bx+tracks.note.note]
        shl     bx,1
        mov     ax,[_bx+noteTable]
	sub     ebx,ebx
        pop     _bx
        mov     [_bx+tracks.note.noteold],ax
        mov     [_bx+tracks.cmd.bendervalue],ax
        mov     bl,[_bx+tracks.note.note]
        sub     bh,bh
        shl     bx,1
        mov     bx,[_bx+frequencyTable]
        movzx   eax,[_di+samples.orgrate]       ; EAX = frequency of middle-C
        mul     ebx                     ; DX:AX = AX*(relative frequency)
        shrd    eax,edx,10
        pop     _bx
        mov     [_di+samples.rate],eax
        mov     ecx,eax
        movzx   edx,[_bx+tracks.note.velocity]
        mov     [_di+samples.volume],dl
        movzx   eax,[moduleinfo.track]
        ecall   adjustVolume eax,edx
        mov     edx,eax
        movzx   eax,[moduleinfo.track]
        test    [_bx+tracks.status],PAUSED
        jnz     @@exit
        ecall   cdiPlayNote eax,ecx,edx
@@exit:
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   notecut
; *
; *     Description :   Cuts note at x frame
; *
; ************************************************************************/

PROC    notecut NEAR

        mov     al,[_bx+tracks.cmd.value]
        or      al,al
        jz      @@goforit
        cmp     al,[moduleinfo.cmdcount]
        jne     @@exit
@@goforit:
        mov     [_bx+tracks.note.velocity],0
        movzx   eax,[moduleinfo.track]
        ecall   cdiSetVolume eax,<LARGE 0>
@@exit:
        ret
ENDP

IFDEF __32__
        LABEL   runcommandProcs

            DW  cVolume
            DD  offset slideVolume
            DW  cBender
            DD  offset slidePitch
            DW  cBenderTo
            DD  offset slidePitchNote
            DW  cVibrato
            DD  offset vibrato
            DW  cTremolo
            DD  offset tremolo
            DW  cBenderVol
            DD  offset benderVol
            DW  cVibrVol
            DD  offset vibratoVol
            DW  cDelayNote
            DD  offset delaynote
            DW  cNoteCut
            DD  offset notecut
            DW  cExtraFineBender
            DD  offset slidePitchFine
ELSE
        LABEL   runcommandProcs

            DW  cVolume
            DW  offset slideVolume
            DW  cBender
            DW  offset slidePitch
            DW  cBenderTo
            DW  offset slidePitchNote
            DW  cVibrato
            DW  offset vibrato
            DW  cTremolo
            DW  offset tremolo
            DW  cBenderVol
            DW  offset benderVol
            DW  cVibrVol
            DW  offset vibratoVol
            DW  cDelayNote
            DW  offset delaynote
            DW  cNoteCut
            DW  offset notecut
            DW  cExtraFineBender
            DW  offset slidePitchFine
ENDIF


        LABEL   alwaysProcs

IFDEF __32__
            DW  cArpeggio
            DD  offset arpeggio
            DW  cRetrig
            DD  offset retrig
ELSE
            DW  cArpeggio
            DW  offset arpeggio
            DW  cRetrig
            DW  offset retrig
ENDIF

IFDEF __32__
        lastAlways = ($-alwaysProcs)/6
        lastCommand = ($-runcommandProcs)/6
ELSE
        lastAlways = ($-alwaysProcs)/4
        lastCommand = ($-runcommandProcs)/4
ENDIF

;/*************************************************************************
; *
; *     Function    :   runCommand
; *
; *     Description :   Runs current command on track
; *
; *     Input       :   BX = track number
; *
; ************************************************************************/

PROC    runCommand NEAR

        push    _cx _bx _si
        mov     [moduleinfo.track],bl
        shl     _bx,1
        mov     bx,[_bx+trackPtr]       ; (E)BX = tracks[(E)BX]
        mov     al,[_bx+tracks.cmd.command]
        sub     ah,ah
        cmp     al,0
        je      @@exit
        mov     _cx,lastCommand
        mov     _si,offset runcommandProcs
        cmp     [moduleinfo.cmdcount],0
        jne     @@runLoop
        mov     _cx,lastAlways
        mov     _si,offset alwaysProcs
@@runLoop:
        _segcs
        cmp     ax,[_si]
        jne     @@next
        _segcs
        call    [_OFS _si+2]
        jmp     @@exit
@@next:
IFDEF __32__
        add     esi,6
ELSE
        add     si,4
ENDIF
        loop    @@runLoop
@@exit:
        pop     _si _bx _cx
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   incPlayed
; *
; *     Description :   Increases track's played value
; *
; *     Input       :   BX = track
; *
; ************************************************************************/

PROC    incPlayed NEAR

        push    _bx
        shl     _bx,1
        mov     bx,[_bx+trackPtr]       ; BX = tracks[BX]

        add     [_bx+tracks.note.played],1
        jnc     @@10
        mov     [_bx+tracks.note.played],65535
@@10:
        pop     _bx
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   void ampPlayRow();
; *
; *     Description :   Plays one tick of the module
; *
; ************************************************************************/

CPROC   ampPlayRow

        ENTERPROC edi esi

        test    [moduleinfo.status],PLAYING
        jz      @@exit
        test    [moduleinfo.status],PAUSED
        jnz     @@exit

@@dontRun:
        inc     [moduleinfo.cmdcount]
        mov     al,[moduleinfo.cmdcount]
        cmp     al,[moduleinfo.tempo]
        jb      @@noNewNote
        mov     [moduleinfo.cmdcount],0 ; Reset command counter

        cmp     [moduleinfo.break],0    ; Is break command issued?
        jne     @@break
        mov     ax,[moduleinfo.patternLength]
        cmp     [moduleinfo.ticks],ax   ; Did it go over?
        jl      @@nobreak
@@break:
        mov     [moduleinfo.break],0
        inc     [moduleinfo.pattern]
        call    nextPattern             ; Load next pattern into tracks
        or      ax,ax
        jnz     @@exit
@@nobreak:
IF32    <sub    ecx,ecx>
        mov     cx,[moduleinfo.channelCount]
        sub     _bx,_bx
@@trackLoop:
        push    _cx _bx
        ecall   playTrack
        pop     _bx _cx
        inc     _bx
        loop    @@trackLoop

        mov     ax,[moduleinfo.ticks]
        mov     [moduleinfo.row],ax
        inc     [moduleinfo.ticks]              ; Increase ticks
@@noNewNote:
IF32    <sub    ecx,ecx>
        mov     cx,[moduleinfo.channelCount]
        sub     _bx,_bx
@@loop2:
        call    runCommand
        inc     _bx
        loop    @@loop2
IF32    <sub    ecx,ecx>
        mov     cx,[moduleinfo.channelCount]
        sub     _bx,_bx
@@loopPlayed:
        call    incPlayed
        inc     _bx
        loop    @@loopPlayed
@@exit:
        LEAVEPROC edi esi
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   void ampPoll();
; *
; *     Description :   Polling routine for playing modules in the background
; *
; ************************************************************************/

CPROC   ampPoll

        ENTERPROC _di _si

        checkInit

        cmp     [ampBusy],1             ; Is AMP busy?
        je      @@exit

        mov     [ampBusy],1             ; Indicate busy
        ecall   ampGetBufferDelta
IFDEF __16__
        shl     edx,16
        and     eax,0FFFFh
        or      eax,edx
ENDIF
        mov     edi,eax                 ; EDI = delta
        ecall   cdiGetDelta <LARGE 0>
IFDEF __16__
        shl     edx,16
        and     eax,0FFFFh
        or      eax,edx
ENDIF
        mov     esi,eax                 ; ESI = buffer delta
        add     eax,[calced]
        cmp     eax,edi                 ; Is calced+bufferdelta > delta??
        jg      @@goforit
        cmp     esi,5000                ; Is buffer delta > 5msecs?
        jl      @@calcdone
        ecall   cdiPoll <LARGE 0>,esi   ; Fill buffer
        add     [calced],esi
        jmp     @@calcdone
@@goforit:
        mov     eax,edi
        sub     eax,[calced]            ; EAX = delta-calced
        sub     esi,eax                 ; ESI -= EAX
        ecall   cdiPoll <LARGE 0>,eax   ; Fill buffer
        ecall   ampPlayRow
@@playloop:
        cmp     esi,edi                 ; While ESI > EDI...
        jle     @@loopdone
        ecall   cdiPoll <LARGE 0>,edi
        sub     esi,edi
        ecall   ampPlayRow              ; Play music
        ecall   ampGetBufferDelta
        mov     edi,eax                 ; EDI = delta
        jmp     @@playloop              ; endwhile
@@loopdone:
        mov     [calced],esi
        ecall   cdiPoll <LARGE 0>,esi
@@calcdone:
        mov     [ampBusy],0
@@exit:
        LEAVEPROC _di _si
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   ampInterrupt
; *
; *     Description :   Int 8 handler taking care of module playing
; *
; ************************************************************************/

CPROC   ampInterrupt

        pushad
        push    ds
        push    es

        mov     ax,DGROUP               ; Load data segment value
        mov     ds,ax
        mov     es,ax

        cmp     [ampInterruptBusy],1
        je      @@busy

        mov     [ampInterruptBusy],1
IFDEF __16__
        cli
        mov     [oldSS],ss
        mov     [oldSP],sp

        mov     ax,ds
        mov     ss,ax
        mov     sp,offset stack2
        sti
ENDIF

;       in      al,21h
;       or      al,00000010b            ; Mask out keyboard IRQ
;       out     21h,al
        sti

        ecall   ampPoll

        cli
;       in      al,21h
;       and     al,NOT 00000010b        ; Enable keyboard IRQ
;       out     21h,al

IFDEF __16__
        mov     ss,[oldSS]
        mov     sp,[oldSP]
ENDIF
        mov     [ampInterruptBusy],0

@@busy:
        pop     es
        pop     ds
        popad
IF16    iret
IF32    iretd
ENDP

;/*************************************************************************
; *                                                                       *
; * HERE STARTS AMPRTNS                                                   *
; *                                                                       *
; ************************************************************************/

;/*************************************************************************
; *
; *     Function    :   int ampInit(int options);
; *
; *     Description :   Initializes Advanced Module Player
; *
; *     Input       :   AMP options
; *
; *     Returns     :    0 = ok
; *                     -1 = error
; *
; ************************************************************************/

CPROC   ampInit  @@options

        ENTERPROC _di

        RETVAL  -1
        test    [cdiStatus],CDI_INITED  ; Is CDI initialized?
        jz      @@exit
        mov     _di,offset moduleinfo   ; ESDI points to 'moduleinfo'
        PUSHDS
        POPES
        mov     _cx,SIZE S_PLAYINFO
        sub     al,al
        cld
        rep     stosb                   ; clear it

        mov     _di,offset tracks       ; ESDI = tracks
        mov     _cx,(SIZE S_TRACKINFO)*MAXTRACKS
        rep     stosb                   ; clear it

        mov     eax,[@@options]
        mov     [moduleinfo.initOptions],ax

        or      [ampStatus],1           ; Initialize variables
        mov     [ampBusy],0
        mov     [ampInterruptBusy],0
        mov     [timeValue],50
        mov     [calced],0

        mov     eax,-1
        mov     edx,64
        ecall   ampSetMasterVolume eax,edx      ; Set default master volume

        sub     _ax,_ax
@@exit:
        LEAVEPROC _di
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   int ampClose()
; *
; *     Description :   Closes module player.
; *
; ************************************************************************/

CPROC   ampClose

        RETVAL  -1
        test    [ampStatus],1
        jz      @@exit

        and     [ampStatus],NOT 1
        mov     [moduleinfo.status],0   ; Stop module
        sub     _ax,_ax
@@exit:
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   int ampPlayMultiplePatterns(MODULE *mod,int start,
; *                                             int end,int options)
; *
; *     Description :   Plays patterns from 'start' to 'end'
; *
; *     Input       :   options : bit 0 = 1 looping on
; *
; *     Returns     :   0 = no error, otherwise error
; *                     -1 = invalid module
; *                     -2 = not enough memory
; *
; ************************************************************************/

CPROC   ampPlayMultiplePatterns  @@module,@@startpat,@@endpat,@@options

        ENTERPROC _si _di

        checkInit

        cld
        PUSHDS
        push    ds
        pop     es
        mov     _di,offset _curModule   ; ESDI = _curModule
        LDSSI   [@@module]
IFDEF __32__
        or      esi,esi
        jnz     @@notNULL
ELSE
        mov     ax,ds
        or      ax,si                   ; is it NULL?
        jnz     @@notNULL
ENDIF
        POPDS
        RETVAL  -1
        jmp     @@exit
@@notNULL:
        mov     _cx,SIZE S_MODULE
        rep     movsb                   ; Copy module structure
        POPDS

        cmp     [_curModule.type],0
        jz      @@exit                  ; No module

        mov     ax,-2
        mov     edx,[@@startpat]
        cmp     dl,[_curModule.patternCount]
        jae     @@exit                  ; Are startpattern & endpattern
        mov     edx,[@@endpat]          ; legal?
        cmp     dl,[_curModule.patternCount]
        ja      @@exit

        mov     [moduleinfo.status],0

        mov     _di,offset tracks
        PUSHDS
        POPES
        mov     _cx,(SIZE S_TRACKINFO)*MAXTRACKS
        sub     al,al
        rep     stosb                   ; Clear tracks

        mov     [moduleinfo.tempovalue],TEMPO_STM
        cmp     [_curModule.type],MOD_STM
        je      @@10
        mov     [moduleinfo.tempovalue],TEMPO_MOD
@@10:
        mov     [moduleinfo.break],0
        mov     [moduleinfo.track],0
        mov     [moduleinfo.row],0
        mov     [moduleinfo.sync],0
        mov     [moduleinfo.ticks],0
        mov     [moduleinfo.timerCount],0
        mov     al,[_curModule.speed]
        mov     [moduleinfo.tempo],al
        mov     al,[_curModule.tempo]
        mov     [moduleinfo.extTempo],al        ; Tempos...
        sub     ah,ah
        imul    ax,50
        sub     dx,dx
        mov     cx,125
        div     cx
        mov     [timeValue],ax
        mov     [calced],0
        mov     eax,[@@startpat]
        mov     [moduleinfo.firstPattern],al
        mov     [moduleinfo.pattern],al
        mov     eax,[@@endpat]
        mov     [moduleinfo.lastPattern],al
        mov     eax,[@@options]
        mov     [moduleinfo.options],ax
        mov     eax,[_curModule.patterns]
        mov     [moduleinfo.patterndata],eax
        mov     eax,[_curModule.instruments]
        mov     [moduleinfo.instrdata],eax
        mov     al,[_curModule.channelCount]
        sub     ah,ah
        mov     [moduleinfo.channelCount],ax

        mov     _cx,MAXTRACKS
        sub     ebx,ebx
@@loop0:
        movzx   eax,[_bx+_curModule.channelPanning]
        push    eax _bx _cx
        ecall   ampSetPanning ebx,eax
        pop     _cx _bx eax
        mov     [_bx+moduleinfo.channelPanning],al
        inc     _bx
        loop    @@loop0

        call    nextPattern

IF32    <sub    ecx,ecx>
        mov     cx,[moduleinfo.channelCount]
        sub     ebx,ebx
@@resumeLoop:
        push    cx _bx
	ecall   ampUnmuteTrack ebx
        pop     _bx cx
        inc     _bx
        loop    @@resumeLoop
        movzx   _cx,[_curModule.instrumentCount]
        LESSI   [moduleinfo.instrdata]
        sub     _bx,_bx
@@insloop:
        PUSHES
        push    _si _cx _bx
        imul    _bx,SIZE S_INSTRUMENT
        add     _si,_bx
        PUSHES
        push    _si
        sub     _dx,_dx
        sub     _ax,_ax
        cmp     [ESSI+S_INSTRUMENT.sample],0
        je      @@nosample
        cmp     [WORD HIGH ESSI+S_INSTRUMENT.sample],0FFFFh
        jne     @@novirtual
        PUSHES
        push    _si
        movzx   eax,[WORD LOW ESSI+S_INSTRUMENT.sample]
        ecall   mcpSampleRealAddress eax,<LARGE 0>
        pop     _si
        POPES
        ecall   cdiDownloadSample <LARGE 0>,<dx ax>,[ESSI+S_INSTRUMENT.sample],[ESSI+S_INSTRUMENT.size]
        jmp     short @@nosample
@@novirtual:
        ecall   cdiDownloadSample <LARGE 0>,[ESSI+S_INSTRUMENT.sample],[ESSI+S_INSTRUMENT.sample],[ESSI+S_INSTRUMENT.size]
@@nosample:
        pop     _si
        POPES
        pop     _bx _cx _si
        POPES
        inc     _bx
        test    _ax,_ax                         ; Unable to download?
        jnz     @@errorexit
        loop    @@insloop
        mov     [moduleinfo.status],PLAYING
        sub     _ax,_ax
        jmp     @@exit
@@errorexit:
        movzx   _cx,[_curModule.instrumentCount]
        LESSI   [moduleinfo.instrdata]
@@unloadloop:
        cmp     [ESSI+S_INSTRUMENT.sample],0
        je      @@nousample
        PUSHES
        push    _si _cx
        ecall   cdiUnloadSample <LARGE 0>,[ESSI+S_INSTRUMENT.sample]
        pop     _cx _si
        POPES
@@nousample:
        add     _si,SIZE S_INSTRUMENT
        loop    @@unloadloop
        RETVAL  -2
@@exit:
        LEAVEPROC _si _di
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   int ampPlayModule(MODULE *mod, int options)
; *
; *     Description :   Plays the whole module
; *
; *     Input       :   options bit 0 = 1, looping on
; *
; ************************************************************************/

CPROC   ampPlayModule  @@module,@@options

        ENTERPROC

        checkInit

        LESBX   [@@module]
        cmp     [ESBX+S_MODULE.type],0
        je      @@exit
        sub     eax,eax
        movzx   edx,[ESBX+S_MODULE.patternCount]
        ecall   ampPlayMultiplePatterns [@@module],eax,edx,[@@options]
@@exit:
        LEAVEPROC
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   int ampPlayPattern(MODULE *mod, int pattern, int options)
; *
; *     Description :   Plays one pattern
; *
; *     Input       :   pattern to play, (options as above)
; *
; ************************************************************************/

CPROC   ampPlayPattern  @@module,@@pattern,@@options

        ENTERPROC

        checkInit

        LESBX   [@@module]
        cmp     [ESBX+S_MODULE.type],0
        je      @@exit
        mov     eax,[@@pattern]
        cmp     al,[ESBX+S_MODULE.patternCount]
        jae     @@exit
        ecall   ampPlayMultiplePatterns [@@module],eax,eax,[@@options]
@@exit:
        LEAVEPROC
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   int ampStopModule()
; *
; *     Description :   Stops moduleinfo module
; *
; ************************************************************************/

CPROC   ampStopModule

        push    esi

        checkInit

        mov     eax,-2
        cwd
        test    [moduleinfo.status],PLAYING
        jz      @@exit
        and     [moduleinfo.status],NOT (PLAYING OR PAUSED)
IF32    <sub    ecx,ecx>
        mov     cx,[moduleinfo.channelCount]
        sub     esi,esi
@@loop:
        push    _cx
        ecall   cdiStopNote esi
        inc     esi
        pop     _cx
        loop    @@loop

        movzx   _cx,[_curModule.instrumentCount]
        LESSI   [moduleinfo.instrdata]
@@unloadloop:
        cmp     [ESSI+S_INSTRUMENT.sample],0
        je      @@nosample
        PUSHES
        push    _si _cx
        ecall   cdiUnloadSample <LARGE 0>,[ESSI+S_INSTRUMENT.sample]
        pop     _cx _si
        POPES
@@nosample:
        add     _si,SIZE S_INSTRUMENT
        loop    @@unloadloop

        sub     _ax,_ax                 ; No error
@@exit:
        pop     esi
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   int ampPauseModule()
; *
; *     Description :   Pauses module from moduleinfo
; *
; *     Returns     :   0 = module paused
; *                    -1 = no module
; *                    -2 = module was already paused
; *
; ************************************************************************/

CPROC   ampPauseModule

        push    esi

        checkInit

        RETVAL  -2
        test    [moduleinfo.status],PAUSED
        jnz     @@exit
IF32    <sub    ecx,ecx>
        mov     cx,[moduleinfo.channelCount]
        sub     esi,esi
@@loop:
        push    _cx
	ecall   ampMuteTrack esi
        inc     esi
        pop     _cx
        loop    @@loop
        or      [moduleinfo.status],PAUSED
        sub     _ax,_ax                 ; No error
@@exit:
        pop     esi
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   int ampResumeModule()
; *
; *     Description :   Continues moduleinfo the module
; *
; *     Returns     :   0 = resumed successfully
; *                    -1 = no module
; *                    -2 = module was not paused
; *
; ************************************************************************/

CPROC   ampResumeModule

        push    esi

        checkInit

        RETVAL  -2
        test    [moduleinfo.status],PAUSED
        jz      @@exit
        and     [moduleinfo.status],NOT PAUSED
IF32    <sub    ecx,ecx>
        mov     cx,[moduleinfo.channelCount]
        sub     esi,esi
@@loop:
        push    _cx
	ecall   ampUnmuteTrack esi
        inc     esi
        pop     _cx
        loop    @@loop
        sub     _ax,_ax                 ; No error
@@exit:
        pop     esi
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   int ampGetModuleStatus()
; *
; *     Description :   Returns module's status
; *
; ************************************************************************/

CPROC   ampGetModuleStatus

        checkInit

        movzx   eax,[moduleinfo.status]
@@exit:
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   int ampGetTrackStatus(int track)
; *
; *     Description :   Returns track's status word
; *
; ************************************************************************/

CPROC   ampGetTrackStatus  @@track

        ENTERPROC

        checkInit
        calcTrack

IF32    <sub    eax,eax>
        mov     ax,[_bx+tracks.status]
@@exit:
        LEAVEPROC
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   int ampMuteTrack(int track)
; *
; *     Description :   Track stops moduleinfo until ampResumeTrack is issued
; *
; *     Input       :   track to pause
; *
; *     Returns     :   0 = paused successfully
; *                    -1 = no module
; *                    -2 = track was already paused
; *
; ************************************************************************/

CPROC   ampMuteTrack  @@track

        ENTERPROC

        checkInit
        calcTrack

        RETVAL  -2
        test    [_bx+tracks.status],PAUSED
        jnz     @@exit
        test    [moduleinfo.status],PAUSED
        jnz     @@exit
        or      [_bx+tracks.status],PAUSED
	ecall   cdiMute [@@track]
        RETVAL  0
@@exit:
        LEAVEPROC
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   int ampUnmuteTrack(int track)
; *
; *     Description :   Track continues moduleinfo
; *
; *     Input       :   track to resume
; *
; *     Returns     :   0 = resumed successfully
; *                    -1 = no module
; *                    -2 = track wasn't paused
; *
; ************************************************************************/

CPROC   ampUnmuteTrack  @@track

        ENTERPROC

        checkInit

        RETVAL  -2
        test    [moduleinfo.status],PAUSED
        jnz     @@exit

	ecall   cdiUnmute [@@track]

        calcTrack

        RETVAL  -2
        test    [_bx+tracks.status],PAUSED
        jz      @@exit
        and     [_bx+tracks.status],NOT PAUSED
        RETVAL  0
@@exit:
        LEAVEPROC
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   int ampGetPattern()
; *
; *     Description :   Returns currently moduleinfo pattern
; *
; ************************************************************************/

CPROC   ampGetPattern

        checkInit

        movzx   _ax,[moduleinfo.pattern]
@@exit:
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   int ampGetRow()
; *
; *     Description :   Returns currently moduleinfo row
; *
; ************************************************************************/

CPROC   ampGetRow

        checkInit

IF32    <sub    eax,eax>
        mov     ax,[moduleinfo.row]
@@exit:
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   int ampGetSync()
; *
; *     Description :   Returns current synchronization code and resets it
; *
; ************************************************************************/

CPROC   ampGetSync

        checkInit

        movzx   _ax,[moduleinfo.sync]
        mov     [moduleinfo.sync],0
@@exit:
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   int ampGetTempo()
; *
; *     Description :   Returns module's current tempo
; *
; ************************************************************************/

CPROC   ampGetTempo

        checkInit

IF32    <sub    eax,eax>
        mov     al,[moduleinfo.tempo]
        mov     ah,[moduleinfo.extTempo]
@@exit:
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   void ampSetTempo(int new_tempo)
; *
; *     Description :   Sets new tempo on module
; *
; *     Input       :   new_tempo , 6 = normal tempo, 3 = twice as fast
; *
; ************************************************************************/

CPROC   ampSetTempo  @@new_tempo

        ENTERPROC

        checkInit

        mov     eax,[@@new_tempo]
        or      al,al
        jz      @@notempo
        mov     [moduleinfo.tempo],al
@@notempo:
        or      ah,ah
        jz      @@exit
        mov     [moduleinfo.extTempo],ah
        mov     al,ah
        sub     ah,ah
        imul    ax,50
        sub     dx,dx
        mov     cx,125
        div     cx
        mov     [timeValue],ax
        mov     [calced],0
@@exit:
        LEAVEPROC
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   TRACKDATA  *ampGetTrackData(int track)
; *
; *     Description :   Allows program to know what note and command is
; *                     currently playing on the track.
; *
; *     Returns     :   Pointer to TRACKDATA structure which is overwritten
; *                     on every call. If error occurs, NULL is returned.
; *
; ************************************************************************/

CPROC   ampGetTrackData  @@track

        ENTERPROC       _di

        sub     ax,ax
        sub     dx,dx                   ; Return NULL on error
        test    [ampStatus],1
        jz      @@exit
        movzx   ebx,[moduleinfo.channelCount]
        cmp     [@@track],ebx
        jbe     @@ok

        mov     _di,offset trackdata
        PUSHDS
        POPES
        mov     _cx,SIZE S_TRACKDATA
        sub     al,al
        cld
        rep     stosb
        jmp     @@done
@@ok:
        mov     ebx,[@@track]
        shl     _bx,1
        mov     bx,[_bx+trackPtr]
        mov     ax,[_bx+tracks.status]
        mov     [trackdata.status],ax
        mov     al,[_bx+tracks.note.note]
        mov     [trackdata.note],al
        mov     al,[_bx+tracks.note.instrument]
        mov     [trackdata.instrument],al
        mov     al,[_bx+tracks.note.velocity]
        mov     [trackdata.velocity],al
        mov     ax,[_bx+tracks.note.played]
        mov     [trackdata.playtime],ax
        mov     al,[_bx+tracks.cmd.command]
        or      al,80h
        mov     [trackdata.command],al
        mov     al,[_bx+tracks.cmd.value]
        mov     [trackdata.cmdvalue],al
        mov     al,[_bx+tracks.pan]
        mov     [trackdata.panning],al
@@done:
IFDEF __32__
        mov     eax,offset trackdata
ELSE
        mov     dx,ds
        mov     ax,offset trackdata
ENDIF
@@exit:
        LEAVEPROC       _di
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   void ampBreakPattern(short direction);
; *
; *     Description :   Jumps to next pattern
; *
; ************************************************************************/

CPROC   ampBreakPattern  @@direct

        ENTERPROC       _di _si

        checkInit

        cmp     [moduleinfo.pattern],0
        jne     @@cont
        cmp     [@@direct],0
        js      @@exit
@@cont:
        mov     eax,[@@direct]
        cmp     eax,1
        je      @@doit
        cmp     eax,-1
        jne     @@exit
@@doit:
        add     [moduleinfo.pattern],al
        call    nextPattern
@@exit:
        LEAVEPROC       _di _si
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   long ampGetBufferDelta(void);
; *
; *     Description :   Returns the delta time, that should be mixed.
; *
; *     Returns     :   Delta time
; *
; ************************************************************************/

CPROC   ampGetBufferDelta

        checkInit

        mov     eax,1000000             ; usecs
        movzx   ebx,[timevalue]
        sub     edx,edx
        div     ebx
        shld    edx,eax,16              ; DX:AX = EAX
@@exit:
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   short ampSetPanning(short track, short panpos);
; *
; *     Description :   Sets panning for a track
; *
; *     Input       :   channel, panning position
; *
; ************************************************************************/

CPROC   ampSetPanning  @@track,@@panpos

        ENTERPROC

        checkInit
        calcTrack

        mov     eax,[@@panpos]
        mov     [_bx+tracks.pan],al

        mov     edx,[@@track]
        ecall   cdiSetPanning edx,eax
@@exit:
        LEAVEPROC
        ret
ENDP

;/***************************************************************************\
;*
;* Function:    ampSetMasterVolume @@track,@@volume
;*
;* Description: Sets master volume for a track
;*
;* Input:       track number, volume (0-63)
;*              if track = -1, then apply to all tracks
;*
;\***************************************************************************/

CPROC   ampSetMasterVolume @@track,@@volume

        ENTERPROC
        mov     ebx,[@@track]
        mov     eax,[@@volume]
        cmp     ebx,-1
        jne     @@notAll
        mov     _cx,32
        sub     _bx,_bx

@@loopAll:
        mov     [_bx+masterVol],al      ; Set master volume
        inc     _bx
        loop    @@loopAll
        jmp     @@exit
@@notAll:
        cmp     _bx,31                  ; Is it valid track
        ja      @@exit
        mov     [_bx+masterVol],al      ; Set master volume
@@exit:
        LEAVEPROC
        ret
ENDP

ENDS

END
