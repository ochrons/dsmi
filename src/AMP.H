// ************************************************************************
// *
// *    File        : AMP.H
// *
// *    Description : Header file for Advanced Module Player
// *
// *    Copyright (C) 1992 Otto Chrons
// *
// ************************************************************************

#ifndef __AMP_H
#define __AMP_H

#ifndef __DSMIDEF_H
#include "dsmidef.h"
#endif

enum {  cmdInstr = 0x80, cmdTempo, cmdVolume, cmdVolumeAbs, \
        cmdBender, cmdBenderAbs, cmdBenderTo, cmdTremolo, cmdArpeggio,\
        cmdVibrato, cmdToneVol, cmdVibrVol,  cmdBreak, cmdGoto, cmdSync,\
        cmdRetrig, cmdOffset, cmdFinevol, cmdFinetune , cmdNoteDelay,\
        cmdNoteCut, cmdExtTempo, cmdExtraFineBender, cmdPan };

/* FOR MODULE LOADERS ONLY */

#define CRIT_SIZE 256

/*                         */

enum {  MOD_NONE, MOD_MOD, MOD_STM, MOD_AMF, MOD_15, MOD_TREK,
        MOD_S3M, MOD_669, MOD_MTM, MOD_FAR };

#define MERR_NONE 0
#define MERR_MEMORY -1
#define MERR_FILE -2
#define MERR_TYPE -3
#define MERR_CORRUPT 1

#define LM_IML 1
#define LM_OLDTEMPO 2

#define PM_LOOP 1

#define TR_MUTED 2

#define MD_PLAYING 1
#define MD_PAUSED 2

#define MAX_TRACKS 32

#define AMP_TIMER (1193180/100)    // = 11931

#ifndef PAN_LEFT

#define PAN_LEFT -63
#define PAN_RIGHT 63
#define PAN_MIDDLE 0
#define PAN_SURROUND 100

#endif

typedef struct {
    uchar       timesig;
    uchar       note;
    uchar       velocity;
} NOTE;

typedef struct {
    uchar       timesig;
    uchar       command;
    uchar       value;
} COMMAND;

typedef struct {
    ushort      size;
    uchar       type;
    NOTE        note;
} TRACK;

typedef struct {
    short       length;
    TRACK       *track[MAX_TRACKS];
} PATTERN;

typedef struct {
    uchar       type;
    char        name[32],filename[13];
    void        *sample;
    ulong       size;
    ushort      rate;
    uchar       volume;
    ulong       loopstart,loopend;
} INSTRUMENT;

typedef struct {
    uchar       type;
    long        size;
    long        filesize;
    char        name[32];
    uchar       channelCount;
    signed char channelPanning[MAX_TRACKS];
    uchar       instrumentCount;
    INSTRUMENT  *instruments;
    uchar       patternCount;
    PATTERN     *patterns;
    ushort      trackCount;
    TRACK       *(*tracks);
    uchar       tempo,speed;
} MODULE;

typedef struct {
    ushort      status;
    uchar       note;
    uchar       instrument;
    uchar       volume;
    ushort      playtime;
    uchar       command;
    uchar       cmdvalue;
    signed char panning;
} TRACKDATA;

extern int moduleError;

#ifdef __cplusplus
extern "C" {
#endif

MODULE * cdecl  ampLoadModule( const char *name, long options );
MODULE * cdecl  ampLoadMOD( const char *name, long options );
MODULE * cdecl  ampLoadSTM( const char *name, long options );
MODULE * cdecl  ampLoadAMF( const char *name, long options );
MODULE * cdecl  ampLoadS3M( const char *name, long options );
MODULE * cdecl  ampLoad669( const char *name, long options );
MODULE * cdecl  ampLoadMTM( const char *name, long options );
MODULE * cdecl  ampLoadFAR( const char *name, long options );
void cdecl      ampFreeModule( MODULE *module );
int cdecl       ampInit( long options );
void cdecl      ampClose( void );
int cdecl       ampPlayModule( MODULE *mod, long opt );
int cdecl       ampPlayMultiplePatterns( MODULE *mod, long start, long end, long opt );
int cdecl       ampPlayPattern( MODULE *mod, long pat, long opt );
int cdecl       ampStopModule( void );
int cdecl       ampPauseModule( void );
int cdecl       ampResumeModule( void );
int cdecl       ampGetModuleStatus( void );
int cdecl       ampMuteTrack( long track );
int cdecl       ampUnmuteTrack( long track );
int cdecl       ampGetTrackStatus( long track );
TRACKDATA * cdecl ampGetTrackData( long track );
int cdecl       ampGetPattern( void );
int cdecl       ampGetTick( void );
int cdecl       ampGetRow( void );
int cdecl       ampGetSync( void );
unsigned int cdecl ampGetTempo( void );
void cdecl      ampSetTempo( ulong tempo );
void cdecl      ampSetPanning( long track, long panning );
void cdecl      ampSetMasterVolume( long track, long volume );
void cdecl      ampPlayRow( void );
void cdecl      ampBreakPattern( long direction );
ulong cdecl ampGetBufferDelta( void );

void cdecl      ampInterrupt( void );
void cdecl      ampPoll( void );

#ifdef __cplusplus
}
#endif

#endif
