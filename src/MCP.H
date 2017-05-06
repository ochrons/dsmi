// ************************************************************************
// *
// *    File        : MCP.H
// *
// *    Description : Multi Channel Player- header file
// *
// *    Copyright ( C) 1992 Otto Chrons
// *
// ************************************************************************

#ifndef __DEF_MCP
#define __DEF_MCP

#ifndef __DSMIDEF_H
#include "dsmidef.h"
#endif

#include "cdi.h"

typedef struct {
    void        *sample;
    ulong       length;
    ulong       loopstart,loopend;
    uchar       mode;
    ushort      sampleID;
} SAMPLEINFO;

typedef struct {
    char        ID;
    ushort      version;
    char        name[32];
    ushort      ioPort;
    char        dmaIRQ;
    char        dmaChannel;
    ushort      minRate;
    ushort      maxRate;
    char        stereo;
    char        mixer;
    char        sampleSize;
    uchar       extraField[8];
} SOUNDCARD;

typedef struct {
    void     *initDevice;
    void     *initOutput;
    void     *initRate;
    void     *closeDevice;
    void     *closeOutput;
    void     *startOutput;
    void     *stopOutput;
    void     *pauseOutput;
    void     *resumeOutput;
    void     *getBufferPos;
    void     *speakerOn;
    void     *speakerOff;
} SOUNDDEVICE;

typedef struct {
    ushort      samplingRate;
    ushort      options;
    ushort      bufferSeg;
#ifdef __C32__
    ulong       bufferBase;
#endif
    ulong       bufferPhysical;
    ushort      bufferSize;
    ushort      reqSize;
} MCPSTRUCT;

typedef struct {
    ushort      position;
    void        *start;
    ushort      length;
} MCPOUTPUT;

extern SOUNDCARD SoundCard;
extern CDIDEVICE CDI_MCP;

typedef void cdecl (*SDI_INIT)(void);
typedef void cdecl (*EFFECT_ROUTINE)(void *buffer, long length, long dataType);

#define ID_SB 1
#define ID_SBPRO 2
#define ID_PAS 3
#define ID_PASPLUS 4
#define ID_PAS16 5
#define ID_SB16 6
#define ID_DAC 7
#define ID_ARIA 8
#define ID_WSS 9
#define ID_GUS 10

#define MCP_QUALITY 1
#define MCP_486 2
#define MCP_MONO 4

#define MCP_TABLESIZE (32*256*2+32)
#define MCP_QUALITYSIZE (2048*2+8192)
#define MCP_TABLESIZE16 (32*256*4+32)
#define MCP_QUALITYSIZE16 (2048*4+64*4)
#define VOLUME_LINEAR 1
#define VOLUME_ANY 255

#define SAMPLE_CONTINUE 1

#define CH_PLAYING      1
#define CH_LOOPING      2
#define CH_MUTED        4
#define CH_VALID        8

#define PAN_LEFT -63
#define PAN_RIGHT 63
#define PAN_MIDDLE 0
#define PAN_SURROUND 100

#ifdef __cplusplus
extern "C" {
#endif

int cdecl       mcpInit( MCPSTRUCT  *mcpstruc );
int cdecl       mcpInitSoundDevice( SDI_INIT sdi, SOUNDCARD  *sCard );
void cdecl      mcpClose( void );
void cdecl      mcpOpenSpeaker( void );
void cdecl      mcpCloseSpeaker( void );
int cdecl       mcpSetupChannels( long channels, ushort *volTable );
int cdecl       mcpStartVoice( void );
int cdecl       mcpStopVoice( void );
int cdecl       mcpPauseVoice( void );
int cdecl       mcpResumeVoice( void );
ulong cdecl     mcpGetDelta(void);
void cdecl      mcpPoll(ulong time);
void cdecl      mcpClearBuffer( void );
void * cdecl    mcpSampleRealAddress( ulong sampleID, ulong pos );
void cdecl      mcpEnableVirtualSamples( void );
void cdecl      mcpDisableVirtualSamples( void );
int cdecl       mcpMuteChannel( long channel );
int cdecl       mcpUnmuteChannel( long channel );
int cdecl       mcpStopChannel( long channel );
int cdecl       mcpMuteAll( void );
int cdecl       mcpUnmuteAll( void );
int cdecl       mcpGetChannelStatus( long channel );
int cdecl       mcpGetChannelCount( void );
int cdecl       mcpSetSample( long channel, SAMPLEINFO  *s );
int cdecl       mcpPlaySample( long channel, ulong rate, ulong volume );
int cdecl       mcpSetVolume( long channel,long volume );
int cdecl       mcpSetRate( long channel, long rate );
int cdecl       mcpSetPosition( long channel, ulong position );
int cdecl       mcpSetPanning( long channel, long panning );
int cdecl       mcpGetVolume( long channel );
ulong cdecl     mcpGetPosition( long channel );
void *  cdecl   mcpGetSample( long channel );
ulong cdecl     mcpGetRate( long channel );
int cdecl       mcpSetSamplingRate( ulong sampling_rate );
ulong cdecl     mcpGetSamplingRate( void );
int cdecl       mcpSetMasterVolume( long volume );
void cdecl      mcpConvertSample( void  *sample, ulong length );
MCPOUTPUT * cdecl mcpGetOutput( void );
void cdecl      mcpSetEffectRoutine(EFFECT_ROUTINE newRoutine);

#ifdef __cplusplus
}
#endif

#endif
