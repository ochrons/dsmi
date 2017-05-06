Comparing files AMFLOAD.C and D:\AMFLOAD.C
***** AMFLOAD.C

#include "mcp.h"
#include "amp.h"
***** D:\AMFLOAD.C

#include "amp.h"
*****

***** AMFLOAD.C

extern int      loadOptions;
***** D:\AMFLOAD.C

static uchar    order4[4] = {0,1,3,2};
extern int      loadOptions;
*****

***** AMFLOAD.C

static uchar    order16[16] = { PAN_LEFT,PAN_RIGHT,PAN_RIGHT,PAN_LEFT,PAN_LEFT,PAN_RIGHT,PAN_RIGHT,PAN_LEFT,
                                PAN_LEFT,PAN_RIGHT,PAN_RIGHT,PAN_LEFT,PAN_LEFT,PAN_RIGHT,PAN_RIGHT,PAN_LEFT};

static void joinTracks2Patterns(MODULE *module)
***** D:\AMFLOAD.C

static void joinTracks2Patterns(MODULE *module)
*****

***** AMFLOAD.C
{
    int         a,t,i,insPtr = 0,size = 0, oldIns = 1, pan = 0;
    ushort      (*sample)[];
    ushort      (*tracks)[],trckPtr = 0,lastIns = 0;
    long        l,fpos;
    TRACK       *track;
***** D:\AMFLOAD.C
{
    int         a,t,i,insPtr = 0,size = 0, oldIns = 1;
    ushort      (*sample)[];
    ushort      (*tracks)[],trckPtr = 0;
    long        l;
    TRACK       *track;
*****

***** AMFLOAD.C
    if( l == 0x01464D41 ) size = 3;
    else if( l >= 0x0A464D41 ) oldIns = 0;
    else if( l >= 0x0B464D41 ) pan = 1;
    else if( l!= 0x08464D41 && l != 0x09464D41) return MERR_TYPE;
***** D:\AMFLOAD.C
    if( l == 0x01464D41 ) size = 3;
    else if( l == 0x0A464D41 ) oldIns = 0;
    else if( l!= 0x08464D41 && l != 0x09464D41) return MERR_TYPE;
*****

***** AMFLOAD.C
    if( l >= 0x09464D41 )
    {
        fread(&module->channelCount,1,1,file);
        fread(&module->channelPanning,16,1,file);
        if( l < 0x0B464D41 )
        {
            memcpy(&module->channelPanning,order16,16);
        }
    }
    if((module->patterns = calloc(module->patternCount,sizeof(PATTERN))) == NULL ) return MERR_MEMORY;
***** D:\AMFLOAD.C
    if( l >= 0x09464D41 )
        {
        fread(&module->channelCount,1,1,file);
        fread(&module->channelOrder,16,1,file);
        }
    if((module->patterns = calloc(module->patternCount,sizeof(PATTERN))) == NULL ) return MERR_MEMORY;
*****

***** AMFLOAD.C
    for( t = 0; t < module->patternCount; t++ )
    {
        for( i = 0; i < module->channelCount; i++ )
***** D:\AMFLOAD.C
    for( t = 0; t < module->patternCount; t++ )
        {
        for( i = 0; i < module->channelCount; i++ )
*****

***** AMFLOAD.C
        fread(&((*module->patterns)[t].track[i]),2,1,file);
    }
    sample = calloc(module->instrumentCount,sizeof(ushort));
***** D:\AMFLOAD.C
        fread(&((*module->patterns)[t].track[i]),2,1,file);
        }
    sample = calloc(module->instrumentCount,sizeof(ushort));
*****

***** AMFLOAD.C
    for( t = 0; t < module->instrumentCount; t++ )
    {
        if( oldIns )
        {
            fread(&oi,sizeof(OLDINSTRUMENT),1,file);
***** D:\AMFLOAD.C
    for( t = 0; t < module->instrumentCount; t++ )
        {
        if( oldIns )
            {
            fread(&oi,sizeof(OLDINSTRUMENT),1,file);
*****

***** AMFLOAD.C
                instr->loopend = instr->loopstart = 0;
        }
        else
        {
            fread(&(*module->instruments)[t],sizeof(INSTRUMENT),1,file);
        }
        if((int)(*module->instruments)[t].sample > lastIns )
            lastIns = (int)(*module->instruments)[t].sample;
        if((int)(*module->instruments)[t].sample > insPtr)
        {
            (*sample)[insPtr] = (*module->instruments)[t].size;
***** D:\AMFLOAD.C
                instr->loopend = instr->loopstart = 0;
            }
        else
            {
            fread(&(*module->instruments)[t],sizeof(INSTRUMENT),1,file);
            }
        if((int)(*module->instruments)[t].sample > insPtr)
            {
            (*sample)[insPtr] = (*module->instruments)[t].size;
*****

***** AMFLOAD.C
            insPtr++;
        }
    }
    insPtr = lastIns;
    tracks = calloc(module->trackCount,sizeof(ushort));
***** D:\AMFLOAD.C
            insPtr++;
            }
        }
    tracks = calloc(module->trackCount,sizeof(ushort));
*****

***** AMFLOAD.C
        module->size += (*sample)[t];
        fpos = ftell(file);
        if(fread(smp,(*sample)[t],1,file) == 0) return MERR_FILE;
***** D:\AMFLOAD.C
        module->size += (*sample)[t];
        if(fread(smp,(*sample)[t],1,file) == 0) return MERR_FILE;
*****

***** AMFLOAD.C
    fread(&l,4,1,file);
    if( (l & 0x00FFFFFF) == 0x00464D41 )
        {
***** D:\AMFLOAD.C
    fread(&l,4,1,file);
    if( l == 0x08464D41 || l == 0x01464D41 || l == 0x09464D41 || l == 0x0A464D41 )
        {
*****

***** AMFLOAD.C
            module->channelCount = 4;
            memcpy(&module->channelPanning,&order16,4);
            }
***** D:\AMFLOAD.C
            module->channelCount = 4;
            memcpy(&module->channelOrder,&order4,4);
            }
*****


