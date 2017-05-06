;/************************************************************************
; *
; *     File        : CDI.ASM
; *
; *     Description : Channel Distributor for DSMI
; *
; *     Copyright (C) 1993 Otto Chrons
; *
; ***********************************************************************/

        IDEAL
        JUMPS
        P386

        INCLUDE "MODEL.INC"
        INCLUDE "CDI.INC"

MACRO   getDevice

        mov     ebx,[@@channel]
        movzx   _bx,[_bx+channelTable]
        imul    _bx,SIZE CDIDEVICE
        add     _bx,offset deviceTable
ENDM

CSEGMENTS CDI

CDATASEG

IFDEF   __PASCAL__
        EXTRN   cdiStatus:WORD
ELSE
        PUBLIC  cdiStatus
        cdiStatus       DW 0
ENDIF

        channelTable    DB 256 dup(?)
        deviceTable     CDIDEVICE 8 dup(<>)
        lastDevice      DW ?
ENDS

CCODESEG CDI

;/*************************************************************************
; *
; *     Function    :   long cdiInit(void);
; *
; *     Description :   Initializes CDI
; *
; *     Returns     :   0 = no error, other = error
; *
; ************************************************************************/

CPROC   cdiInit

        push    _di

        PUSHDS
        POPES
        mov     _di,offset channelTable
        sub     al,al
        cld
        mov     _cx,256
        rep     stosb                   ; Clear channel table
        mov     _di,offset deviceTable
        mov     _cx,SIZE deviceTable
        rep     stosb                   ; Clear device table
        mov     [lastDevice],0
        mov     [cdiStatus],CDI_INITED

        pop     _di
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   long cdiRegister(CDIDEVICE *cdi,long chFirst,long chLast);
; *
; *     Description :   Registers a CDI device to given channels
; *
; *     Input       :   Pointer to CDI device structure, first and last channels
; *
; *     Returns     :   0 = no error, -1 CDI not initialized,
; *                     -2 invalid channel
; *
; ************************************************************************/

CPROC   cdiRegister @@pcdi,@@chfirst,@@chlast

        ENTERPROC _di _si

        RETVAL  -1
        test    [cdiStatus],CDI_INITED
        jz      @@exit
        RETVAL  -2
        mov     edx,[@@chfirst]
        cmp     _dx,0                   ; Check channel limits
        jl      @@exit
        cmp     _dx,255
        jg      @@exit
        mov     ecx,[@@chlast]
        cmp     _cx,0
        jl      @@exit
        cmp     _cx,255
        jg      @@exit
        cmp     _cx,_dx                 ; Last channel < first?
        jl      @@exit
        mov     _di,_dx
        add     _di,offset channelTable
        PUSHDS
        POPES
        sub     al,al
        sub     _cx,_dx
        inc     _cx                     ; CX = channel count
        push    _cx _di
        cld
        repe    scasb
        mov     ax,-2
        or      _cx,_cx                 ; Are any channels reserved?
        pop     _di _cx
        jnz     @@exit
        inc     [lastDevice]
        mov     ax,[lastDevice]
        rep     stosb                   ; Reserve channels

        movzx   edi,[lastDevice]
        imul    _di,SIZE CDIDEVICE      ; DI = offset to device table
        add     _di,offset deviceTable
        PUSHDS
        PUSHDS
        POPES                           ; ES:DI points to free entry in table
        LDSSI   [@@pcdi]                ; DS:SI points to new CDI device
        mov     _cx,SIZE CDIDEVICE
        rep     movsb                   ; Copy structure
        POPDS

        RETVAL  0
@@exit:
        LEAVEPROC _di _si
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   void cdiClose(void);
; *
; *     Description :   Closes CDI
; *
; ************************************************************************/

CPROC   cdiClose

        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   void cdiSetInstrument(long @@channel, void *instrument);
; *
; *     Description :
; *
; *     Input       :
; *
; *     Returns     :
; *
; ************************************************************************/

CPROC   cdiSetInstrument @@channel, @@inst

        ENTERPROC

        getDevice
        ecallM  [_bx+CDIDEVICE.setsample] [@@channel],[@@inst]

        LEAVEPROC
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   void cdiPlayNote(long @@channel,long freq, int volume);
; *
; ************************************************************************/

CPROC   cdiPlayNote @@channel, @@freq, @@volume

        ENTERPROC
        getDevice
        ecallM  [_bx+CDIDEVICE.playsample] [@@channel],[@@freq],[@@volume]
        LEAVEPROC
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   void cdiStopNote(long @@channel);
; *
; ************************************************************************/

CPROC   cdiStopNote @@channel

        ENTERPROC
        getDevice
        ecallM  [_bx+CDIDEVICE.stopchannel] [@@channel]
        LEAVEPROC
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :    cdiSetVolume
; *
; ************************************************************************/

CPROC   cdiSetVolume @@channel,@@volume

        ENTERPROC
        getDevice
        ecallM  [_bx+CDIDEVICE.setvolume] [@@channel],[@@volume]
        LEAVEPROC
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :    cdiSetFrequency
; *
; ************************************************************************/

CPROC   cdiSetFrequency @@channel,@@freq

        ENTERPROC
        getDevice
        ecallM  [_bx+CDIDEVICE.setfrequency] [@@channel],[@@freq]
        LEAVEPROC
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :    cdiSetLinear
; *
; *     Description :
; *
; *     Input       :
; *
; *     Returns     :
; *
; ************************************************************************/

CPROC   cdiSetLinear @@channel

        ENTERPROC
        getDevice
        LEAVEPROC
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :    cdiSetPosition
; *
; ************************************************************************/

CPROC   cdiSetPosition @@channel,@@pos

        ENTERPROC
        getDevice
        ecallM  [_bx+CDIDEVICE.setposition] [@@channel],[@@pos]
        LEAVEPROC
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :    cdiSetPanning
; *
; ************************************************************************/

CPROC   cdiSetPanning @@channel,@@pan

        ENTERPROC
        getDevice
        ecallM  [_bx+CDIDEVICE.setpanning] [@@channel],[@@pan]
        LEAVEPROC
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :    cdiSetMasterVolume
; *
; ************************************************************************/

CPROC   cdiSetMasterVolume @@channel,@@volume

        ENTERPROC
        getDevice
        ecallM  [_bx+CDIDEVICE.setmastervolume] [@@volume]
        LEAVEPROC

        ret
ENDP

;/*************************************************************************
; *
; *     Function    :    cdiMute
; *
; ************************************************************************/

CPROC   cdiMute @@channel

        ENTERPROC
        getDevice
	ecallM  [_bx+CDIDEVICE.mutechannel] [@@channel]
        LEAVEPROC
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :    cdiUnmute
; *
; ************************************************************************/

CPROC   cdiUnmute @@channel

        ENTERPROC
        getDevice
	ecallM  [_bx+CDIDEVICE.unmutechannel] [@@channel]
        LEAVEPROC

        ret
ENDP

;/*************************************************************************
; *
; *     Function    :    cdiMuteAll
; *
; ************************************************************************/

CPROC   cdiMuteAll @@channel

        ENTERPROC
        getDevice
	ecallM  [_bx+CDIDEVICE.muteall]
        LEAVEPROC

        ret
ENDP

;/*************************************************************************
; *
; *     Function    :    cdiUnmuteAll
; *
; ************************************************************************/

CPROC   cdiUnmuteAll @@channel

        ENTERPROC
        getDevice
	ecallM  [_bx+CDIDEVICE.unmuteall]
        LEAVEPROC

        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   void cdiPoll(long time);
; *
; *     Description :
; *
; *     Input       :
; *
; *     Returns     :
; *
; ************************************************************************/

CPROC   cdiPoll @@channel,@@time

        ENTERPROC
        getDevice
	ecallM  [_bx+CDIDEVICE.poll] [@@time]
        LEAVEPROC

        ret
ENDP

;/*************************************************************************
; *
; *     Function    :    cdiGetDelta
; *
; *     Description :
; *
; *     Input       :
; *
; *     Returns     :
; *
; ************************************************************************/

CPROC   cdiGetDelta @@channel

        ENTERPROC
        getDevice
        ecallM  [_bx+CDIDEVICE.getdelta]
        LEAVEPROC

        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   long cdiDownloadSample(long @@channel,void *sample,long length);
; *
; *     Description :
; *
; *     Input       :
; *
; *     Returns     :
; *
; ************************************************************************/

CPROC   cdiDownloadSample @@channel,@@sample,@@sampletag,@@len

        ENTERPROC
        getDevice
        ecallM  [_bx+CDIDEVICE.download]  [@@sample],[@@sampletag],[@@len]
        LEAVEPROC

        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   void cdiUnloadAll(long @@channel);
; *
; *     Description :
; *
; ************************************************************************/

CPROC   cdiUnloadAll @@channel

        ENTERPROC
        getDevice
        ecallM  [_bx+CDIDEVICE.unloadall]
        LEAVEPROC
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   void cdiUnloadSample(long @@channel,void *sample);
; *
; *     Description :
; *
; ************************************************************************/

CPROC   cdiUnloadSample @@channel,@@sample

        ENTERPROC
        getDevice
	ecallM  [_bx+CDIDEVICE.unload] [@@sample]
        LEAVEPROC
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   ulong cdiGetVolume(long @@channel);
; *
; *     Description :   Returns the current volume on '@@channel'
; *
; ************************************************************************/

CPROC   cdiGetVolume @@channel

        ENTERPROC
        getDevice
        ecallM  [_bx+CDIDEVICE.getvolume] [@@channel]
        LEAVEPROC

        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   ulong cdiGetFrequency(long @@channel);
; *
; *     Description :   Returns the current frequency on '@@channel'
; *
; ************************************************************************/

CPROC   cdiGetFrequency @@channel

        ENTERPROC
        getDevice
        ecallM  [_bx+CDIDEVICE.getfrequency] [@@channel]
        LEAVEPROC
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   ulong cdiGetPosition(long @@channel);
; *
; *     Description :   Returns the current position on '@@channel'
; *
; ************************************************************************/

CPROC   cdiGetPosition @@channel

        ENTERPROC
        getDevice
        ecallM  [_bx+CDIDEVICE.getposition] [@@channel]
        LEAVEPROC

        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   ulong cdiGetPanning(long @@channel);
; *
; *     Description :   Returns the current pan position on '@@channel'
; *
; ************************************************************************/

CPROC   cdiGetPanning @@channel

        ENTERPROC
        getDevice
        ecallM  [_bx+CDIDEVICE.getpan] [@@channel]
        LEAVEPROC

        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   ulong cdiGetInstrument(long @@channel);
; *
; *     Description :   Returns the current sample on '@@channel'
; *
; ************************************************************************/

CPROC   cdiGetInstrument @@channel

        ENTERPROC
        getDevice
        ecallM  [_bx+CDIDEVICE.getsample] [@@channel]
        LEAVEPROC

        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   long cdiSetupChannels(long @@channel, long count, ulong *volTable);
; *
; *     Description :   Sets up 'count' channels
; *
; ************************************************************************/

CPROC   cdiSetupChannels @@channel,@@count,@@volTable

        ENTERPROC
        getDevice
        ecallM  [_bx+CDIDEVICE.setupch] [@@count],[@@volTable]
        LEAVEPROC
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   long cdiGetChannelsStatus( long @@channel );
; *
; *     Description :   Returns the 'status' of a channel
; *
; ************************************************************************/

CPROC   cdiGetChannelStatus @@channel

        ENTERPROC
        getDevice
        ecallM  [_bx+CDIDEVICE.getchannelstatus] [@@channel]
        LEAVEPROC
        ret
ENDP

ENDS

END
