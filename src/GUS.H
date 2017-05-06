// ************************************************************************
// *
// *    File        : GUS.H
// *
// *    Description : Header file for GUS interface
// *
// *    Copyright (C) 1992 Otto Chrons
// *
// ************************************************************************

#ifndef __GUS_H
#define __GUS_H

#ifndef __DSMIDEF_H
#include "dsmidef.h"
#endif

#include "mcp.h"
#include "cdi.h"


#define ID_GUS 10

#define GUS_TIMER (1193180/101)

#ifdef __cplusplus
extern "C" {
#endif
extern CDIDEVICE CDI_GUS;
extern ulong gusDeltaTime;

int cdecl gusInit( SOUNDCARD *scard );
void cdecl gusClose( void );
int cdecl gusStartVoice( void );
int cdecl gusStopVoice( void );
uchar cdecl gusPeek( long addr );
void  cdecl gusPoke( long addr, ulong value );
ulong cdecl gusGetSamplingRate( void );
int cdecl gusSetSample( long channel, void *sample );
int cdecl gusPlaySample( long channel, ulong freq, ulong volume );
int cdecl gusStopChannel( long channel );
int cdecl gusSetVolume( long channel, ulong volume );
int cdecl gusSetRate( long channel, ulong rate );
int cdecl gusSetPosition( long channel, ulong pos );
int cdecl gusSetPanning( long channel, long pan );
int cdecl   gusGetVolume( long channel );
ulong cdecl gusGetRate( long channel );
ulong cdecl gusGetPosition( long channel );
void * cdecl gusGetSample( long channel );
int cdecl gusGetPanning( long channel );
int cdecl gusGetChannelStatus( long channel );
int cdecl gusMuteChannel( long channel );
int cdecl gusUnmuteChannel( long channel );
int cdecl gusMuteAll( void );
int cdecl gusUnmuteAll( void );
int cdecl  gusDownloadSample( void *sample, ulong sampletag, ulong len );
void cdecl  gusUnloadSample( void *sample );
void cdecl  gusUnloadAll( void );
int cdecl gusSetupChannels( long count, ushort *volTable);
int cdecl gusSetMasterVolume( ulong volume );
void cdecl  gusPoll( ulong time );
ulong cdecl gusGetDelta( void );

void cdecl gusInterrupt(void);

#ifdef __cplusplus
}
#endif

#endif


