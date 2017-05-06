// ************************************************************************
// *
// *    File        : CDI.H
// *
// *    Description : Channel Distributor header file
// *
// *    Copyright ( C) 1993 Otto Chrons
// *
// ************************************************************************

#ifndef __DEF_CDI
#define __DEF_CDI

#ifndef __DSMIDEF_H
#include "dsmidef.h"
#endif

typedef struct {
        void    *setsample,*playsample,*setvolume,*setfrequency,\
                *setlinearrate,*setposition,*setpanning,*setmastervolume,\
                *mutechannel,*unmutechannel,*stopchannel,*muteall,\
                *unmuteall,*poll,*getdelta,*download,*unload,*unloadall,\
                *getvoume,*getfrequency,*getposition,*getpan,*getsample,*setupch;
} CDIDEVICE;

#ifdef __cplusplus
extern "C" {
#endif

int cdecl cdiInit(void);
int cdecl cdiRegister( CDIDEVICE *cdi, long firstCh, long lastCh );
void cdecl  cdiClose(void);
int cdecl cdiSetInstrument( long channel, void *ins );
int cdecl cdiPlayNote( long channel, ulong rate, ulong volume );
int cdecl cdiStopNote( long channel );
int cdecl cdiSetVolume( long channel, ulong volume );
int cdecl cdiSetFrequency( long channel, ulong freq );
int cdecl cdiSetLinear( long channel, ulong linearRate );
int cdecl cdiSetPosition( long channel, ulong pos );
int cdecl cdiSetPanning( long channel, long pan );
ulong cdecl cdiGetVolume( long channel );
ulong cdecl cdiGetFrequency( long channel );
ulong cdecl cdiGetPosition( long channel );
int cdecl cdiGetPanning( long channel );
void * cdecl cdiGetInstrument( long channel );
int cdecl cdiGetChannelStatus( long channel );
int cdecl cdiMute( long channel );
int cdecl cdiUnmute( long channel );
int cdecl cdiMuteAll( long channel );
int cdecl cdiUnmuteAll( long channel );
ulong cdecl cdiPoll( long channel, ulong time );
ulong cdecl cdiGetDelta( long channel );
int cdecl cdiDownloadSample( long channel, void *sample, void *sampletag, ulong len );
int cdecl cdiUnloadSample( long channel, void *sampletag );
int cdecl cdiUnloadAll( long channel );
int cdecl cdiSetupChannels( long channel, long count, ushort *volTable );
void cdecl  cdiSetMasterVolume( long channel,ulong volume );

#ifdef __cplusplus
}
#endif

#endif
