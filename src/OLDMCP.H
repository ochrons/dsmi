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

#if !defined(__LARGE__) && !defined(__HUGE__)
#error You have to use LARGE or HUGE models!
#endif

typedef struct {
    void far    *sample;
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
} SOUNDCARD;

typedef struct {
    void far    *initDevice;
    void far    *initOutput;
    void far    *initRate;
    void far    *closeDevice;
    void far    *closeOutput;
    void far    *startOutput;
    void far    *stopOutput;
    void far    *pauseOutput;
    void far    *resumeOutput;
    void far    *getBufferPos;
    void far    *speakerOn;
    void far    *speakerOff;
} SOUNDDEVICE;

typedef struct {
    ushort      samplingRate;
    ushort      options;
    ushort      bufferSeg;
    ulong       bufferLinear;
    ushort      bufferSize;
    ushort      reqSize;
} MCPSTRUCT;

typedef struct {
    ushort	position;
    void far	*start;
    ushort	length;
} MCPOUTPUT;

extern SOUNDCARD SoundCard;

typedef void (far *SDI_INIT)();

#define ID_SB 1
#define ID_SBPRO 2
#define ID_PAS 3
#define ID_PASPLUS 4
#define ID_PAS16 5
#define ID_SB16 6
#define ID_DAC 7
#define ID_ARIA 8
#define ID_WSS 9

#define MCP_QUALITY 1
#define MCP_486 2
#define MCP_MONO 4

#define MCP_TABLESIZE (33*256*2+16)
#define MCP_QUALITYSIZE (2048*2+4096)
#define VOLUME_LINEAR 1
#define VOLUME_ANY 255

#define SAMPLE_CONTINUE 1

#define	CH_PLAYING 	1
#define	CH_LOOPING 	2
#define	CH_PAUSED 	4
#define	CH_VALID	8

#define PAN_LEFT -63
#define PAN_RIGHT 63
#define PAN_MIDDLE 0

#ifdef __cplusplus
extern "C" {
#endif

short  mcpInit( MCPSTRUCT  *mcpstruc );
short  mcpInitSoundDevice( SDI_INIT sdi, SOUNDCARD  *sCard );
void   mcpClose( void );
void   mcpOpenSpeaker( void );
void   mcpCloseSpeaker( void );
short  mcpOpenChannels( short channels, short volumemode, ushort  *volTable );
short  mcpStartVoice( void );
short  mcpStopVoice( void );
short  mcpPauseVoice( void );
short  mcpResumeVoice( void );
ushort  mcpGetBufferDelta(void);
void   mcpCalcBuffer(short amount);
void   mcpClearBuffer( void );
void   *  mcpSampleRealAddress( ushort sampleID, ulong pos );
void   mcpEnableVirtualSamples( void );
void   mcpDisableVirtualSamples( void );
short  mcpPauseChannel( short channel );
short  mcpResumeChannel( short channel );
short  mcpStopChannel( short channel );
short  mcpPauseAll( void );
short  mcpResumeAll( void );
short  mcpGetChannelStatus( short channel );
short  mcpGetChannelCount( void );
short  mcpSetSample( short channel, SAMPLEINFO  *s );
short  mcpPlaySample( short channel, ulong rate, ushort volume );
short  mcpSetVolume( short channel,short volume );
ushort  mcpGetChannelVolume( short channel );
ulong  mcpGetChannelPosition( short channel );
void  *  mcpGetChannelSample( short channel );
ulong  mcpGetChannelRate( short channel );
short  mcpSetRate( short channel, long rate );
short  mcpSetPosition( short channel, ulong position );
short  mcpSetPanning( short channel, short panning );
short  mcpSetSamplingRate( ushort sampling_rate );
ushort  mcpGetSamplingRate( void );
short  mcpSetMasterVolume( short volume );
void   mcpConvertSample( void  *sample, ulong length );
MCPOUTPUT  *mcpGetOutput( void );

void far interrupt mcpCalibrate( void );
int far mcpCalibrateInit( short delta, short accuracy );
void far mcpCalibrateClose( void );

#ifdef __cplusplus
}
#endif

#endif
