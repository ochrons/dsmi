; ************************************************************************
; *
; *     File        : MCP.INC
; *
; *     Description : Include file for assembly parts of MCP.
; *
; *     Copyright (C) 1992 Otto Chrons
; *
; ************************************************************************

STRUC CHDATA
    status      DW ?            ; bit 0 = playing status (1 = playing)
                                ; bit 1 = looping
                                ; bit 2 = paused
                                ; bit 3 = valid sample loaded
    sPtr        DD ?            ; sample's starting point
    length      DD ?            ; sample's length in bytes
    dLength     DD ?            ; how many bytes are played on each round
    played      DD ?            ; how much of the sample is played
    loopStart   DD ?            ;Ä¿
    loopEnd     DD ?            ;ÄÁÄÄ looping
    volume      DB ?            ; 0 - 32
    rate        DD ?            ; Real frequency
    rateQuo     DW ?            ;ÄÂÄÄ relative frequency
    rateRem     DW ?            ;ÄÙ   ( rate/sampling_rate )
    saveQuo     DW ?
    sampleID    DW ?
    pan         DB ?
ENDS

STRUC   CARDINFO
    ID          DB 0
    ver         DW 0
    cardname    DB 32 dup(0)
    ioPort      DW 0
    DMAIRQ      DB 0
    DMAChannel  DB 0
    minRate     DW 0
    maxRate     DW 0
    stereo      DB 0
    mixer       DB 0
    sampleSize  DB 0
    extraField  DB 8 dup(0)
ENDS

STRUC SAMPLEINFO                        ; Same structure defined in MCP.H
    voiceData   DD ?
    length      DD ?
    loopStart   DD ?
    loopEnd     DD ?
    mode        DB ?
    sampleID    DW ?
ENDS

STRUC SOUNDDEVICE
    initDevice  DD ?
    initOutput  DD ?
    initRate    DD ?
    closeDevice DD ?
    closeOutput DD ?
    startOutput DD ?
    stopOutput  DD ?
    pauseOutput DD ?
    resumeOutput DD ?
    getBufferPos DD ?
    speakerOn   DD ?
    speakerOff  DD ?
ENDS

STRUC MCPSTRUC
    samplingRate DW ?
    options     DW ?
    bufferSeg   DW ?
IFDEF __32__
    bufferBase	DD ?
ENDIF
    bufferLinear DD ?
    bufferSize  DW ?
    reqSize     DW ?
ENDS

        CH_PLAYING      = 1
        CH_LOOPING      = 2
        CH_PAUSED       = 4
        CH_VALID        = 8

        S_INIT          = 1
        S_MCP           = 2
        S_VOICE         = 4
        S_PAUSE         = 8

        ID_SOUNDBLASTER = 1
        ID_SOUNDBLASTERPRO = 2

        ID_SB           = 1
        ID_SBPRO        = 2
        ID_PAS          = 3
        ID_PASPLUS      = 4
        ID_PAS16        = 5
        ID_SB16         = 6
        ID_DAC          = 7
        ID_ARIA         = 8
        ID_WSS          = 9

        MCP_QUALITY     = 1
        MCP_486         = 2

        SAMPLE_CONTINUE = 1

        VOLUME_LINEAR   = 1
        VOLUME_ANY      = 255

        PAN_LEFT = -63
        PAN_RIGHT = 63
        PAN_MIDDLE = 0
        PAN_SURROUND = 100

        MAXCHANNEL      = 32
        dataSize        = 2048+1024

