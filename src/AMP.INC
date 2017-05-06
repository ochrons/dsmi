;/************************************************************************
; *
; *     File        :   AMP.INC
; *     Description :   Definitions for Advance Module Player assembly code
; *
; *     Copyright (C) 1992 Otto Chrons
; *
; ***********************************************************************/

    AMP_INTERRUPT       = 1
    AMP_MANUAL          = 0

    MAXTRACKS   = 32

    MOD_NONE    = 0
    MOD_MOD     = 1
    MOD_STM     = 2
    MOD_AMF     = 3

    PLAYING     = 1
    PAUSED      = 2
    MANUAL      = 4

    PM_LOOP     = 1
    TEMPO_STM   = 64
    TEMPO_MOD   = 64
    SAMPLE_CONTINUE = 1

STRUC S_SAMPLEINFO                      ; Sample structure
    sample      DD ?
    length      DD ?
    loopstart   DD ?
    loopend     DD ?
    mode        DB ?
    sampleID    DW ?
    orgrate     DW ?
    rate        DD ?
    volume      DB ?
ENDS

STRUC S_TRACKDATA
    status      DW ?
    note        DB ?
    instrument  DB ?
    velocity    DB ?
    playtime    DW ?
    command     DB ?
    cmdvalue    DB ?
    panning     DB ?
ENDS

STRUC S_MODULE
    type                DB ?
    size                DD ?
    filesize            DD ?
    mname               DB 32 dup(?)
    channelCount        DB ?
    channelPanning      DB MAXTRACKS dup(?)
    instrumentCount     DB ?
    instruments         DD ?
    patternCount        DB ?
    patterns            DD ?
    trackCount          DW ?
    tracks              DD ?
    tempo               DB ?
    speed               DB ?
ENDS

STRUC S_NOTE
    timesig             DB ?
    note                DB ?
    velocity            DB ?
ENDS

STRUC S_MODCMD
    timesig             DB ?
    cmd                 DB ?
    data                DB ?
ENDS

STRUC S_TRACK
    size                DW ?
    type                DB ?
    note                S_NOTE <>
ENDS

STRUC S_PATTERN
    length              DW ?
    track               DD MAXTRACKS dup(?)
ENDS

STRUC S_INSTRUMENT
    type                DB ?
    insname             DB 32 dup(?)
    filename            DB 13 dup(?)
    sample              DD ?
    size                DD ?
    rate                DW ?
    volume              DB ?
    loopstart           DD ?
    loopend             DD ?
ENDS

STRUC S_NOTEINFO
    note                DB ?
    instrument          DB ?
    velocity            DB ?
    played              DW ?
    noteold             DW ?
ENDS

STRUC S_CMDINFO
    command             DB ?
    value               DB ?
    bendervalue         DW ?
    benderAdd           DB ?
    benderCmd           DB ?
    benderCmd2          DB ?
    arpeggio1           DD ?
    arpeggio2           DD ?
    arpeggio3           DD ?
    arpeggioPtr         DB ?
    vibratoPos          DB ?
    vibratoCmd          DB ?
    tremoloCmd          DB ?
    tremoloSpeed        DB ?
    tremoloValue        DB ?
    tremoloPos          DB ?
    offsetValue         DB ?
    delayValue          DB ?
    delayNote           DB ?
ENDS

STRUC S_TRACKINFO
    track               DD ?
    pos                 DW ?
    status              DW ?
    note                S_NOTEINFO <?>
    cmd                 S_CMDINFO <?>
    pan                 DB ?
ENDS

STRUC S_PLAYINFO
    initOptions         DW ?
    status              DB ?
    options             DW ?
    firstPattern        DB ?
    lastPattern         DB ?
    pattern             DB ?
    track               DB ?
    ticks               DW ?
    row                 DW ?
    cmdcount            DB ?
    patterndata         DD ?
    instrdata           DD ?
    tempo               DB ?
    extTempo            DB ?
    tempovalue          DB ?
    sync                DB ?
    break               DB ?
    timerValue          DW ?
    timerCount          DW ?
    channelCount        DW ?
    channelPanning      DB MAXTRACKS dup(?)
    patternLength       DW ?
ENDS

ENUM commandEnum \
        cInstr = 0,\
        cTempo,\
        cVolume,\
        cVolumeAbs,\
        cBender,\
        cBenderAbs,\
        cBenderTo,\
        cTremolo,\
        cArpeggio,\
        cVibrato,\
        cBenderVol,\
        cVibrVol,\
        cBreak,\
        cGoto,\
        cSync,\
        cRetrig,\
        cOffset,\
        cFinevol,\
        cFinetune,\
        cDelayNote,\
        cNoteCut,\
        cExtTempo,\
        cExtraFineBender,\
        cPan,\
        cLast

MACRO   checkInit
        RETVAL  -1
        test    [ampStatus],1
        jz      @@exit
ENDM

MACRO   calcTrack
        cmp     [@@track],MAXTRACKS
        jae     @@exit
        mov     ebx,[@@track]
        shl     _bx,1
        mov     bx,[_bx+trackPtr]
ENDM

