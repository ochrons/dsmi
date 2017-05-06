/* SFXENG.C Sound effect engine
 *
 * Copyright 1994 Otto Chrons
 *
 * First revision 07-11-94 09:19:48pm
 *
 * Revision history:
 *
*/

#include <stdlib.h>
#include <string.h>
#include "dsmi.h"
#include "sfxeng.h"

#define MAX_SFX 40

typedef struct {
    SAMPLEINFO  *sinfo;
    int         handle;
} SFX;

static SAMPLEINFO   sfxs[MAX_SFX];
static SFX          sfxChannel[8];
static int          firstChannel,channelCount,lastSFX = 0, lastUse = 0;

int InitSFX(int firstCh, int chCount)
{
    if( chCount > 8 ) return -1;

    firstChannel = firstCh;
    channelCount = chCount;
    memset(sfxs,0,sizeof(sfxs));
    memset(sfxChannel,0,sizeof(sfxChannel));
    return 0;
}

int RegisterSFX(SAMPLEINFO *sinfo)
{
    if( lastSFX == MAX_SFX ) return -1;

    memcpy(&sfxs[lastSFX++],sinfo,sizeof(SAMPLEINFO));
    return lastSFX-1;
}

int PlaySFX(int handle, int volume, int rate, int panning)
{
    int         i,ch = -1;
    SAMPLEINFO  *s;
    static int  sfxHandle = 0;

    if( handle < 0 || handle >= lastSFX ) return -1;
    s = &sfxs[handle];
    for( i = 0; i < channelCount; i++ )
    {
        if( (cdiGetChannelStatus(i+firstChannel) & CH_PLAYING) == 0 )
        {
            ch = i;
            break;
        }
    }

    if( ch == -1 )
        for( i = 0; i < channelCount; i++ )
        {
            if( memcmp(sfxChannel[i].sinfo,s,sizeof(SAMPLEINFO)) == 0 )
            {
                ch = i;
                break;
            }
        }
    if( ch == -1 ) ch = (lastUse == channelCount-1) ? 0 : lastUse+1;
    lastUse = ch;

    memcpy(&sfxChannel[ch].sinfo,s,sizeof(SAMPLEINFO));
    sfxChannel[ch].handle = ++sfxHandle;

    cdiSetInstrument(ch+firstChannel,s);
    cdiPlayNote(ch+firstChannel,rate,volume);
    cdiSetPanning(ch+firstChannel,panning);

    return sfxHandle;
}

int StopSFX(int sfxhandle)
{
    int     i;

    for( i = 0; i < channelCount; i++ )
    {
        if( sfxChannel[i].handle == sfxhandle )
        {
            cdiStopNote(i+firstChannel);
            return 0;
        }
    }
    return -1;
}

int StopAllSFX(void)
{
    int     i;

    for( i = 0; i < channelCount; i++ )
    {
        cdiStopNote(i+firstChannel);
    }
    return 0;
}


