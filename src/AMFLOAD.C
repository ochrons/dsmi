// ************************************************************************
// *
// *    File        : AMFLOAD.C
// *
// *    Description : Loads an AMF format module file
// *
// *    Copyright (C) 1992,1994 Otto Chrons
// *
// ************************************************************************
/*
        Revision history of AMFLOAD.C

        1.0     16.4.93
                First version.


*/

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <dos.h>

#include "mcp.h"
#include "amp.h"

#ifdef _USE_EMS
#include "emhm.h"
#endif

extern int      loadOptions;

static uchar    order16[16] = { PAN_LEFT,PAN_RIGHT,PAN_RIGHT,PAN_LEFT,PAN_LEFT,PAN_RIGHT,PAN_RIGHT,PAN_LEFT,
                                PAN_LEFT,PAN_RIGHT,PAN_RIGHT,PAN_LEFT,PAN_LEFT,PAN_RIGHT,PAN_RIGHT,PAN_LEFT};

static void joinTracks2Patterns(MODULE *module)
{
    int         t,i;
    PATTERN     *pat;

    for( t = 0; t < module->patternCount; t++)
        {
        pat = &module->patterns[t];
        for( i = 0; i < module->channelCount; i++ )
            pat->track[i] = module->tracks[(ushort)pat->track[i]];
        }
}

typedef struct {
    uchar       type;
    char        name[32],filename[13];
    void        *sample;
    ushort      size;
    ushort      rate;
    uchar       volume;
    ushort      loopstart,loopend;
} OLDINSTRUMENT;

int cdecl loadAMF(FILE *file, MODULE *module)
{
    ushort      a,t,i,insPtr = 0,size = 0, oldIns = 1,pan;
    ushort      (*sample)[];
    ushort      (*tracks)[],trckPtr = 0,lastIns = 0;
    long        l;
    TRACK       *track;
    void        *smp;
    OLDINSTRUMENT oi;
    INSTRUMENT  *instr;
#ifdef _USE_EMS
    EMSH        handle;
#endif

    module->tempo = 125;
    module->speed = 6;
    fseek(file,0,SEEK_SET);
    fread(&l,4,1,file);
    fread(&module->name,32,1,file);
    if( l >= 0x0C464D41 ) pan = 32; else pan = 16;
    if( l == 0x01464D41 ) size = 3;
    else if( l >= 0x0A464D41 ) oldIns = 0;
    else if( l!= 0x08464D41 && l != 0x09464D41) return MERR_TYPE;
    fread(&module->instrumentCount,1,1,file);
    fread(&module->patternCount,1,1,file);
    fread(&module->trackCount,2,1,file);
    if( l >= 0x09464D41 )
    {
        fread(&module->channelCount,1,1,file);
        fread(&module->channelPanning,pan,1,file);
        if( l < 0x0B464D41 )
        {
            memcpy(&module->channelPanning,order16,16);
        }
    }
    if( l >= 0x0D464D41 )
    {
        fread(&module->tempo,1,1,file);
        fread(&module->speed,1,1,file);
    }
    if((module->patterns = D_calloc(module->patternCount,sizeof(PATTERN))) == NULL ) return MERR_MEMORY;
    if((module->instruments = D_calloc(module->instrumentCount,sizeof(INSTRUMENT))) == NULL ) return MERR_MEMORY;
    if((module->tracks = D_calloc(module->trackCount+4,sizeof(void *))) == NULL) return MERR_MEMORY;
    module->size += module->patternCount*sizeof(PATTERN)+
                    module->instrumentCount*sizeof(INSTRUMENT)+
                    (module->trackCount+4)*sizeof(void *);
    for( t = 0; t < module->patternCount; t++ )
    {
        if( l >= 0x0E464D41 ) fread(&(module->patterns[t].length),2,1,file);
        else module->patterns[t].length = 64;
        for( i = 0; i < module->channelCount; i++ )
        fread(&(module->patterns[t].track[i]),2,1,file);
    }
    sample = D_calloc(module->instrumentCount,sizeof(ushort));
    for( t = 0; t < module->instrumentCount; t++ )
    {
        if( oldIns )
        {
            fread(&oi,sizeof(OLDINSTRUMENT),1,file);
            memcpy(instr = &module->instruments[t],&oi,sizeof(OLDINSTRUMENT));
            instr->size = oi.size;
            instr->rate = oi.rate;
            instr->volume = oi.volume;
            instr->loopstart = oi.loopstart;
            instr->loopend = oi.loopend;
            if(instr->loopend == 65535)
                instr->loopend = instr->loopstart = 0;
        }
        else
        {
            fread(&module->instruments[t],sizeof(INSTRUMENT),1,file);
        }
        if((int)module->instruments[t].sample > lastIns )
            lastIns = (int)module->instruments[t].sample;
        if((int)module->instruments[t].sample > insPtr)
        {
            (*sample)[insPtr] = module->instruments[t].size;
            insPtr++;
        }
    }
    insPtr = lastIns;
    tracks = D_calloc(module->trackCount,sizeof(ushort));
    for( t = 0; t < module->trackCount; t++ )
    {
        fread(&(*tracks)[t],2,1,file);
        if((*tracks)[t] > trckPtr) trckPtr = (*tracks)[t];
    }
    for( i = 1; i < module->trackCount+1; i++ )
        module->tracks[i] = NULL;
    for( t = 0; t < trckPtr; t++)
    {
        fread(&a,2,1,file);
        fread(&i,1,1,file);
        if( a == 0 ) track = NULL;
        else
        {
            if((track = D_malloc(3*a+6)) == NULL) return MERR_MEMORY;
            module->size += 3*a+3;
            track->type = 0;
            track->size = a;
            fread(&track->note,a*3+size,1,file);
        }
        for( i = 0; i < module->trackCount; i++ )
        {
            if( (*tracks)[i] == t+1 )
                module->tracks[i+1] = track;
        }
    }
    for( t = 0; t < insPtr; t++ )
    if( (*sample)[t] > 0 )
    {
        if((smp = D_malloc((*sample)[t]+16)) == NULL) return MERR_MEMORY;
        module->size += (*sample)[t]+16;
        if(fread(smp,(*sample)[t],1,file) == 0) return MERR_FILE;
#ifdef _USE_EMS
        if( (*sample)[t] > 2048 )
        {
            if((handle = emsAlloc((*sample)[t])) > 0)
            {
                emsCopyTo(handle,smp,0,(*sample)[t]);
                D_free(smp);
                smp = MK_FP(0xFFFF,handle);
            }
        }
#endif
        for( i = 0; i < module->instrumentCount; i++ )
        {
            if((ushort)module->instruments[i].sample == t+1 &&\
               ((ulong)module->instruments[i].sample & 0xFFFF0000) == 0)
            {
                module->instruments[i].sample = smp;
            }
        }
    }
    for( i = 0; i < module->instrumentCount; i++ )
        if(((ulong)module->instruments[i].sample & 0xFFFF0000) == 0)
           module->instruments[i].sample = NULL;
    joinTracks2Patterns(module);
    D_free(sample);
    D_free(tracks);
    return 0;
}

MODULE * cdecl ampLoadAMF(const char *name, long options)
{
    FILE        *file;
    ulong       l;
    MODULE      *module;
    int         b;

    loadOptions = options;
    if((module = (MODULE*)D_malloc(sizeof(MODULE)))==NULL)
    {
        moduleError = MERR_MEMORY;
        return NULL;
    }
    memset(module,0,sizeof(MODULE));
    if((file = fopen(name,"rb")) == NULL)
    {
        moduleError = MERR_FILE;
        return NULL;
    }
    module->type = MOD_NONE;
    fseek(file,0,SEEK_SET);
    fread(&l,4,1,file);
    if( (l & 0x00FFFFFF) == 0x00464D41 )
    {
        module->type = MOD_AMF;
        fread(module->name,20,1,file);
        module->name[20] = 0;
        if( l == 0x08464D41 || l == 0x01464D41 )
        {
            module->channelCount = 4;
            memcpy(&module->channelPanning,&order16,4);
        }
    }
    else
    {
        moduleError = MERR_TYPE;
        return NULL;
    }
    b = loadAMF(file,module);
    moduleError = b;
    if( b == MERR_NONE )
    {
        fseek(file,0,SEEK_END);
        module->filesize = ftell( file );
    }
    else
    {
        ampFreeModule(module);
        D_free(module);
        module = NULL;
    }
    fclose(file);
    return module;
}
