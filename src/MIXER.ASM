;/************************************************************************
; *
; *     File        : MIXER.ASM
; *
; *     Description : Mixer functions for sound cards
; *
; *     Copyright (C) 1992 Otto Chrons
; *
; ***********************************************************************
;
;       Revision history of MIXER.ASM
;
;       1.0     16.4.93
;               First version. Mixer functions for SB Pro only.
;
; ***********************************************************************/

                IDEAL
                LOCALS
                JUMPS
                P386N

;       L_PASCAL        = 1             ; Uncomment this for pascal-style

IFDEF   L_PASCAL
        LANG    EQU     PASCAL
        MODEL TPASCAL
ELSE
        LANG    EQU     C
        MODEL LARGE,C
ENDIF
        INCLUDE "MODEL.INC"

        MIXER_SBPRO = 1

        MIX_LEFT        = 40h
        MIX_RIGHT       = 80h
        MIX_BOTH        = MIX_LEFT OR MIX_RIGHT

        MIX_IN_MIC      = 1
        MIX_IN_CD       = 2
        MIX_IN_LINE     = 3
        MIX_FILTERHIGH  = 40h

        MIX_FM_NORMAL   = 0
        MIX_FM_LEFT     = 1
        MIX_FM_RIGHT    = 2
        MIX_FM_MUTE     = MIX_FM_RIGHT OR MIX_FM_LEFT

        MIX_RESET       = 0
        MIX_MASTERVOL   = 1
        MIX_DACVOL      = 2
        MIX_FMVOL       = 3
        MIX_CDVOL       = 4
        MIX_MICVOL      = 5
        MIX_LINEVOL     = 6
        MIX_STEREO      = 7
        MIX_FILTEROUT   = 8
        MIX_FILTERIN    = 9
        MIX_INPUTLINE   = 10
        MIX_FM_MODE     = 11

        MIX_LASTFUNCT   = MIX_FM_MODE


MACRO   checkInit

        cmp     [mixerType],0
        je      @@exit
ENDM

DATASEG

        mixerType       DB ?
        mixerBase       DW ?

CODESEG

        PUBLIC  mixerInit, mixerSet, mixerGet

        LABEL SBMixerSet WORD
            DW offset SBReset
            DW offset SBMasterVolume
            DW offset SBDACVolume
            DW offset SBFMVolume
            DW offset SBCDVolume
            DW offset SBMicVolume
            DW offset SBLineVolume
            DW offset SBStereo
            DW offset SBFilterOut
            DW offset SBFilterIn
            DW offset SBInputLine
            DW offset SBFMMode

        LABEL SBMixerGet WORD
            DW offset NoFunc
            DW offset SBGetMasterVolume
            DW offset SBGetDACVolume
            DW offset SBGetFMVolume
            DW offset SBGetCDVolume
            DW offset SBGetMicVolume
            DW offset SBGetLineVolume
            DW offset SBGetStereo
            DW offset SBGetFilterOut
            DW offset SBGetFilterIn
            DW offset SBGetInputLine
            DW offset SBGetFMMode

;/*************************************************************************
; *
; *     Function    :   void mixerInit(uchar type, int ioBase);
; *
; *     Description :   Inits mixer functions
; *
; *     Input       :   type = sound card type; 1 = SB Pro
; *                     ioBase = card's I/O base address; 220h or 240h for Pro
; *
; ************************************************************************/

PROC    mixerInit FAR mixtype:BYTE,iobase:WORD

        mov     bl,[mixtype]
        cmp     bl,MIXER_SBPRO
        je      @@sbpro
        sub     bx,bx
        sub     ax,ax
        jmp     @@exit
@@sbpro:
        mov     ax,[iobase]
        cmp     ax,220h
        je      @@ok
        cmp     ax,240h
        je      @@ok
        sub     ax,ax
        jmp     @@exit
@@ok:
        add     ax,4                    ; Offset of mixer chip
@@exit:
        mov     [mixerType],bl
        mov     [mixerBase],ax
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   void mixerSet(int func, unsigned char value);
; *
; *     Description :   Sets mixer chip according to given values
; *
; *     Input       :   func = function number
; *                     value = value to use
; *
; ************************************************************************/

PROC    mixerSet FAR func:BYTE,value:BYTE

        checkInit

        cmp     [mixerType],MIXER_SBPRO
        je      @@sbpro
        jmp     @@exit
@@sbpro:
        sub     bh,bh
        mov     bl,[func]
        and     bl,03Fh                 ; mask out bits 6 & 7
        cmp     bl,MIX_LASTFUNCT
        jg      @@exit                  ; Is function valid
        shl     bl,1
        mov     al,[value]
        mov     ah,[func]
        call    [bx+SBMixerSet]  ; Call appropriate function
@@exit:
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   unsigned char mixerGet(int func);
; *
; *     Description :   Returns information about the mixer.
; *
; *     Input       :   func = function to read
; *
; *     Returns     :   Mixer chip value for given function.
; *
; ************************************************************************/

PROC    mixerGet FAR func:BYTE

        checkInit

        sub     ax,ax
        cmp     [mixerType],MIXER_SBPRO
        je      @@sbpro
        jmp     @@exit
@@sbpro:
        sub     bh,bh
        mov     bl,[func]
        and     bl,03Fh                 ; mask out bits 6 & 7
        cmp     bl,MIX_LASTFUNCT
        jg      @@exit                  ; Is function valid
        shl     bl,1
        mov     al,[value]
        mov     ah,[func]
        call    [bx+SBMixerGet] ; Call appropriate function
@@exit:
        ret
ENDP


;/*************************************************************************
; *
; *     Function    :   SBPset
; *
; *     Description :   Sets mixer chip
; *
; *     Input       :   AL = register port
; *                     AH = data port
; *
; ************************************************************************/

PROC    SBPset NEAR

        push    dx
        mov     dx,[mixerBase]
        out     dx,al
        inc     dx
        mov     al,ah
        out     dx,al
        pop     dx

        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   SBPget
; *
; *     Description :   Returns mixer chip value
; *
; *     Input       :   AL = register port
; *
; *     Returns     :   AL = data value
; *
; ************************************************************************/

PROC    SBPget NEAR

        push    dx
        mov     dx,[mixerBase]
        out     dx,al
        inc     dx
        in      al,dx
        pop     dx

        ret
ENDP


;/*************************************************************************
; *
; *     Function    :   SBReset
; *
; ************************************************************************/

PROC    SBReset NEAR

        mov     ax,0000                 ; Reset function is 0
        call    SBPset

        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   SBSetVolume
; *
; ************************************************************************/

PROC    SBSetVolume NEAR

SBMasterVolume:
        mov     bh,22h                  ; Master vol
        jmp     @@ok
SBDACVolume:
        mov     bh,04h                  ; VOC volume
        jmp     @@ok
SBFMVolume:
        mov     bh,26h                  ; FM volume
        jmp     @@ok
SBLineVolume:
        mov     bh,2Eh
        jmp     @@ok
SBCDVolume:
        mov     bh,28h
        or      ah,11000000b            ; Both channels
        jmp     @@ok
SBMicVolume:
        mov     bh,0Ah
        or      ah,11000000b            ; Both channels
        shr     al,1                    ; Divide volume by 2
        jmp     @@ok
@@ok:
        mov     cl,al                   ; Save AL
        mov     al,bh
        call    SBPget                  ; Get current volume
        mov     bl,al                   ; BL = volume
        test    ah,MIX_BOTH             ; Is either channel specified?
        jnz     @@10
        or      ah,MIX_BOTH             ; No, change both
@@10:
        test    ah,MIX_LEFT
        jz      @@noleft
        mov     al,cl                   ; CL = given volume
        shl     al,4
        and     bl,00001111b
        or      bl,al                   ; Set left channel
@@noleft:
        test    ah,MIX_RIGHT
        jz      @@noright
        mov     al,cl
        and     al,00001111b
        and     bl,11110000b
        or      bl,al
@@noright:
        mov     al,bh                   ; AL = function
        mov     ah,bl                   ; AH = volume value
        call    SBPset                  ; Set new volume
@@exit:
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   SBStereo
; *
; *     Description :   Sets stereo or mono mode
; *
; ************************************************************************/

PROC    SBStereo NEAR

        mov     bl,al
        mov     al,0Eh
        call    SBPget
        and     al,11111101b            ; Set mono
        cmp     bl,0
        je      @@setMono
        or      al,00000010b            ; Set stereo
@@setMono:
        mov     ah,al
        mov     al,0Eh
        call    SBPset
@@exit:
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   SBFilterOut
; *
; *     Description :   Enables/disables output filter
; *
; ************************************************************************/

PROC    SBFilterOut NEAR

        mov     bl,al
        mov     al,0Eh
        call    SBPget
        and     al,11011111b            ; Enable filter
        cmp     bl,1
        je      @@enableFilter
        or      al,00100000b            ; Disable filter
@@enableFilter:
        mov     ah,al
        mov     al,0Eh
        call    SBPset

        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   SBFilterIn
; *
; *     Description :   Enables/disables input filter
; *
; ************************************************************************/

PROC    SBFilterIn NEAR

        mov     bl,al
        mov     al,0Ch
        call    SBPget
        and     al,11011111b            ; Enable filter
        cmp     bl,1
        je      @@enableFilter
        or      al,00100000b            ; Disable filter
@@enableFilter:
        mov     ah,al
        mov     al,0Ch
        call    SBPset

        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   SBInputLine
; *
; *     Description :   Selects input line
; *
; ************************************************************************/

PROC    SBInputLine NEAR

        mov     bl,al
        mov     bh,al
        and     bl,3Fh                  ; Only the lower 6 bits
        mov     al,0Ch
        call    SBPget
        and     al,11110000b
        or      al,00000001b
        cmp     bl,MIX_IN_MIC
        je      @@done
        or      al,00000010b
        cmp     bl,MIX_IN_CD
        je      @@done
        or      al,00000100b            ; It must be MIX_IN_LINE
@@done:
        test    bh,MIX_FILTERHIGH
        jz      @@filterLow
        or      al,00001000b
@@filterLow:
        mov     ah,al
        mov     al,0Ch
        call    SBPset
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   SBFMMode
; *
; *     Description :   Sets FM chip's mode
; *
; ************************************************************************/

PROC    SBFMMode NEAR

        mov     bl,al
        mov     al,26h
        call    SBPget
        push    ax                      ; Save FM volume
        mov     al,06h
        call    SBPget                  ; Get FM mode
        and     al,10011111b
        test    bl,MIX_FM_LEFT
        jz      @@10
        or      al,00100000b
@@10:
        test    bl,MIX_FM_RIGHT
        jz      @@20
        or      al,01000000b
@@20:
        mov     ah,al
        mov     al,06h
        call    SBPset                  ; Set FM mode
        pop     ax
        mov     ah,al
        mov     al,26h
        call    SBPset                  ; Restore FM volume
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   SBGetVolume
; *
; ************************************************************************/

PROC    SBGetVolume NEAR

SBGetMasterVolume:
        mov     bh,22h                  ; Master vol
        jmp     @@ok
SBGetDACVolume:
        mov     bh,04h                  ; VOC volume
        jmp     @@ok
SBGetFMVolume:
        mov     bh,26h                  ; FM volume
        jmp     @@ok
SBGetLineVolume:
        mov     bh,2Eh
        jmp     @@ok
SBGetCDVolume:
        mov     bh,28h
        or      ah,11000000b            ; Both channels
        jmp     @@ok
SBGetMicVolume:
        mov     al,0Ah
        call    SBPget
        and     al,00001111b
        shl     al,1
        jmp     @@exit
@@ok:
        and     ah,11000000b
        mov     cl,al
        mov     al,bh
        call    SBPget
        cmp     ah,11000000b
        jne     @@10
        mov     ah,al
        and     al,00001111b
        shr     ah,4
        add     al,ah
        shr     al,1
        jmp     @@exit
@@10:
        cmp     ah,10000000b
        jne     @@20
        and     al,00001111b
        jmp     @@exit
@@20:
        shr     al,4
@@exit:
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   SBGetStereo
; *
; *     Description :   Is stereo or mono mode on?
; *
; ************************************************************************/

PROC    SBGetStereo NEAR

        mov     al,0Eh
        call    SBPget
        and     al,00000010b
        shr     al,1

        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   SBGetFilterOut
; *
; *     Description :   Returns output filter's status
; *
; ************************************************************************/

PROC    SBGetFilterOut NEAR

        mov     al,0Eh
        call    SBPget
        and     al,00100000b
        rol     al,3                    ; AL = 1 if filter off
        dec     al
        neg     al                      ; AL = 0 if filter off
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   SBGetFilterIn
; *
; *     Description :   Returns input filter's status
; *
; ************************************************************************/

PROC    SBGetFilterIn NEAR

        mov     al,0Ch
        call    SBPget
        and     al,00100000b
        rol     al,3                    ; AL = 1 if filter off
        dec     al
        neg     al                      ; AL = 0 if filter off
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   SBGetInputLine
; *
; *     Description :   Returns SB's input line selection
; *
; ************************************************************************/

PROC    SBGetInputLine NEAR

        mov     al,0Ch
        call    SBPget
        mov     ah,al
        and     ah,01000000b            ; AH = filter high
        mov     bl,3                    ; Assume line
        test    al,4
        jnz     @@exit
        mov     bl,2
        test    al,2
        jnz     @@exit
        mov     bl,1
@@exit:
        mov     al,bl
        or      al,ah
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   SBGetFMMode
; *
; *     Description :   Returns FM chip's mode
; *
; ************************************************************************/

PROC    SBGetFMMode NEAR

        mov     al,06h
        call    SBPget
        rol     al,3
        and     al,00000011b
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   NoFunc
; *
; *     Description :   Void function
; *
; ************************************************************************/

PROC    NoFunc NEAR

        ret
ENDP


END
