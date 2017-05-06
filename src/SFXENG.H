/* SFXENG.H Sound effect engine header file
 *
 * Copyright 1994 Otto Chrons
 *
 * First revision 07-11-94 09:20:49pm
 *
 * Revision history:
 *
*/

#ifndef __DEF_SFXENG
#define __DEF_SFXENG

#ifndef __DEF_DSMI
#include "dsmi.h"
#endif

#ifdef __cplusplus
extern "C" {
#endif

int InitSFX(int firstchannel, int channelcount);
int RegisterSFX(SAMPLEINFO *sinfo);
int PlaySFX(int handle, int volume, int rate, int panning);
int StopSFX(int sfxhandle);
int StopAllSFX(void);

#ifdef __cplusplus
}
#endif

#endif
