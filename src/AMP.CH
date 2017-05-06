Comparing files AMP.H and D:\AMP.H
***** AMP.H

#ifndef PAN_LEFT

#define PAN_LEFT -63
#define PAN_RIGHT 63
#define PAN_MIDDLE 0

#endif

***** D:\AMP.H

typedef struct {
    uchar       timesig;
    uchar       note;
    uchar       velocity;
} NOTE;

*****

***** AMP.H
    uchar       timesig;
    uchar       note;
    uchar       velocity;
} NOTE;

***** D:\AMP.H
    uchar       timesig;
    uchar       command;
    uchar       value;
} COMMAND;

*****

***** AMP.H
typedef struct {
    uchar       timesig;
    uchar       command;
    uchar       value;
} COMMAND;

***** D:\AMP.H
typedef struct {
    ushort      size;
    uchar       type;
    NOTE        note[];
} TRACK;

*****

***** AMP.H
typedef struct {
    ushort      size;
    uchar       type;
    NOTE        note[];
} TRACK;

***** D:\AMP.H
typedef struct {
    short       length;
    TRACK far   *track[MAX_TRACKS];
} PATTERN;

*****

***** AMP.H
typedef struct {
    short       length;
    TRACK far   *track[MAX_TRACKS];
} PATTERN;

typedef struct {
    uchar       type;
***** D:\AMP.H
typedef struct {
    uchar       type;
*****

***** AMP.H
    uchar               channelCount;
    uchar               channelPanning[MAX_TRACKS];
    uchar               instrumentCount;
***** D:\AMP.H
    uchar               channelCount;
    uchar               channelOrder[MAX_TRACKS];
    uchar               instrumentCount;
*****

***** AMP.H
    uchar       cmdvalue;
    char        panning;
} TRACKDATA;
***** D:\AMP.H
    uchar       cmdvalue;
} TRACKDATA;
*****

***** AMP.H
MODULE far *    ampLoadS3M( const char far *name, short options );
MODULE far *    ampLoad669( const char far *name, short options );
void    ampFreeModule( MODULE far *module );
***** D:\AMP.H
MODULE far *    ampLoadS3M( const char far *name, short options );
void    ampFreeModule( MODULE far *module );
*****

***** AMP.H
void    far ampSetTempo( ushort tempo );
void    far ampSetPanning( short track, short panning );
void    far ampPlayRow( void );
***** D:\AMP.H
void    far ampSetTempo( ushort tempo );
void    far ampPlayRow( void );
*****


