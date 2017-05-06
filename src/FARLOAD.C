// ************************************************************************
// *
// *    File        : FARLOAD.C
// *
// *    Description : FAR loader for DSMI
// *
// *    Copyright (C) 1993,1994 Otto Chrons
// *
// ************************************************************************
/*
        Revision history of FARLOAD.C

        1.0     19.12.93
                First version.

*/

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <dos.h>

#include "amp.h"

#ifdef _USE_EMS
#include "emhm.h"
#endif

#define BASIC_FREQ 8368L

typedef struct {
    ulong       magic;
    char        songname[40];
    char        dummy1[3];
    ushort      hdrlen;
    uchar       version;
    uchar       channelmap[16];
    uchar       dummy2[9];
    uchar       tempo;
    uchar       pan[16];
    uchar       dummy3[4];
    ushort      songtextlen;
} HEADERFAR;

typedef struct {
    uchar       order[256];
    uchar       patcount,orderlen,loopto;
    ushort      patsize[256];
} HEADERFAR2;

typedef struct {
    char        name[32];
    ulong       length;
    uchar       finetune;
    uchar       volume;
    ulong       loopStart, loopEnd;
    uchar       sampleType, loopMode;
} INSFAR;

typedef struct {
    uchar note,ins,vol,eff;
} ROWFAR;

extern int      loadOptions;

void cdecl mcpConvertSample(void *sample, ulong len);

static uchar    *patUsed;
static MODULE   *module;
static FILE     *file;
static HEADERFAR *hdr;
static HEADERFAR2 *hdr2;

static int getTempo(int tempo)
{
    long        a,b;

    a = 5000*tempo/32;
    b = a/100;
    if( a > 1500 ) a = 1500;
    return 125-(125-125*b/(b+1))*(a % 100)/100;
}

static int getSpeed(int tempo)
{
    return 50*tempo/32;
}

static int loadHeader(void)
{
    int         t,count,i,a;
    PATTERN     *pat;

    rewind(file);
    if(1 != fread(hdr,sizeof(HEADERFAR),1,file)) return MERR_FILE;
    fseek(file,hdr->songtextlen,SEEK_CUR);
    if(1 != fread(hdr2,sizeof(HEADERFAR2),1,file)) return MERR_FILE;
    memcpy(module->name, hdr->songname,32);
    module->name[31] = 0;
    module->tempo = getTempo(hdr->tempo);
    module->speed = getSpeed(hdr->tempo);
    for( t = 0; t < 16; t++ )
    {
        a = hdr->pan[t];
        module->channelPanning[t] = (a == 7 || a == 8 ) ? 0 : ( a < 7 ) ? (a-7)*9 : (a-8)*9;
        if(hdr->channelmap[t]) module->channelCount = t+1;
    }
    count = module->patternCount = hdr2->orderlen;
    if((module->patterns = D_calloc(count,sizeof(PATTERN))) == NULL) return MERR_MEMORY;
    module->size += count*sizeof(PATTERN);

    for( t = 0; t < count; t++ )
    {
        patUsed[hdr2->order[t]] = 1;             // Indicate used
        pat = &module->patterns[t];
        pat->length = 256;
        for( i = 0; i < 16; i++)
        {
            pat->track[i] = (hdr2->order[t] == 0xFF) ? 0 : (void*)((int)hdr2->order[t]*16+1+i);
        }
    }
    if(( module->instruments = D_calloc(64,sizeof(INSTRUMENT))) == NULL) return MERR_MEMORY;
    return MERR_NONE;
}

#define insertNote(a,b) { *(temptrack+pos*3) = tick;\
                        *(temptrack+pos*3+1) = a;\
                        *(temptrack+pos*3+2) = b; pos++; }

#define insertCmd insertNote

static int loadPatterns(void)
{
    int         pos,row,t,j,i,tick,curTrack = 1;
    uchar       note,ins,volume,command,data,curins;
    ushort      count, buffersize;
    TRACK       *track;
    uchar       *temptrack;
    ROWFAR      *buffer;
    ROWFAR      c;

    buffersize = 64*16*sizeof(ROWFAR);
    if(( buffer = D_calloc(64*16,sizeof(ROWFAR))) == NULL) return MERR_MEMORY;
    for( count = t = 0; t < 256; t++) if(hdr2->patsize[t]) count = t+1;
    count *= 16;
    module->trackCount = count;
    if((module->tracks = D_calloc(count+4,sizeof(TRACK *)))==NULL) return MERR_MEMORY;
    module->size += (count+4)*sizeof(TRACK *);
    module->tracks[0] = NULL;
    temptrack = D_malloc(576);
    for( t = 0; t < 256; t++ )
    if(hdr2->patsize[t] > 0)
    {
        fread(&data,1,1,file);
        row = data+1;
        fseek(file,1,SEEK_CUR);
        if( hdr2->patsize[t] > buffersize )
        {
            D_free(buffer);
            if((buffer = D_malloc(buffersize = hdr2->patsize[t])) == NULL) return MERR_MEMORY;
        }
        if(!fread(buffer,hdr2->patsize[t]-2,1,file)) return MERR_FILE;
        for( j = 0; j < 16; j++ )
        {
            memset(temptrack,0xFF,576);
            pos = 0;
            curins = 0xF0;
            for( tick = 0; tick < row+1; tick++ )
            {
                if( tick == row && j == 0 && tick != 255) insertCmd(cmdBreak,0);
                note = 0; volume = ins = 0xFF;
                c = buffer[tick*16+j];
                if( c.note != 0 )
                {
                    note = c.note;
                    ins = c.ins;
                    if( ins != curins )
                    {
                        curins = ins;
                        insertCmd(cmdInstr,ins);
                        module->instruments[ins].type = 1;
                    }
                }
                if((volume = c.vol) == 0) volume = 0xFF;
                command = c.eff>>4;
                data = c.eff & 0xF;
                if( command == 3 )
                    insertCmd(cmdBenderTo,data);
                if( note )
                {
                    if( volume != 0xFF ) { insertNote(note+47,volume*4); }
                    else insertNote(note+47,255);
                }
                else if( volume != 0xFF ) insertCmd(cmdVolumeAbs,volume*4);

                switch(command)
                {
                    case 1 :
                        insertCmd(cmdBender,-data);
                        break;
                    case 2 :
                        insertCmd(cmdBender,data);
                        break;
                    case 4 :
                        insertCmd(cmdRetrig,data);
                        break;
                    case 0xB :
                        insertCmd(cmdPan,(data == 7 || data == 8 ) ? 0 : ( data < 7 ) ? (data-7)*9 : (data-8)*9);
                        break;
                    case 0xF :
                        insertCmd(cmdExtTempo,getTempo(data));
                        insertCmd(cmdTempo,getSpeed(data));
                        break;
                }
            }
            if( pos == 0 ) track = NULL;
            else
            {
                pos++;
                if( loadOptions & LM_IML )
                {
                    for( i = 1; i < curTrack-1; i++)
                    {
                        if(module->tracks[i] != NULL)
                        if(module->tracks[i]->size == pos &&
                           memcmp(temptrack,(char*)module->tracks[i]+3,pos*3) == 0)
                        {
                            track = module->tracks[i];
                            pos = 0;
                            break;
                        }
                    }
                }
                if(pos)
            if((track = (TRACK*)D_malloc(pos*3+3)) != NULL)
                    {
                        module->size += pos*3+3;
                        track->size = pos;
                        track->type = 0;
                        memcpy((char*)(track)+3,temptrack,pos*3);
                    }
                    else
                    {
                        D_free(temptrack);
                        return MERR_MEMORY;
                    }
            }
            module->tracks[curTrack++] = track;
        }
    }
    else if( t < module->trackCount/16 )
    {
	for( j = 0; j < 16; j++ ) module->tracks[curTrack++] = NULL;
    }
    D_free(buffer);
    D_free(temptrack);
    return MERR_NONE;
}

static int loadSamples(void)
{
    ushort      t,i,lastins = 0;
    INSTRUMENT  *instr;
    INSFAR      ins;
    ulong       length,a,b;
    char        *sample,c;
    uchar       sampleMap[8];
#ifdef _USE_EMS
    EMSH        handle;
#endif

    module->instrumentCount = 0;
    fread(sampleMap,8,1,file);
    for( t = 0; t < 64; t++)
    {
        instr = &module->instruments[t];
        if(sampleMap[t/8] & (1<<t%8))
        {
            lastins = t;
	    if(1 != fread(&ins,sizeof(ins),1,file)) return MERR_FILE;
            memcpy(instr->name,ins.name,32);
            instr->size = ins.length;
            instr->loopstart = (ins.loopMode) ? ins.loopStart : 0;
            instr->loopend = (ins.loopMode) ? ins.loopEnd : 0;
            instr->volume = 64;
            instr->rate = BASIC_FREQ;
            length = instr->size;
            if( length > 0 && instr->type == 1 )
            {
                if( instr->loopend != 0 && (a = instr->loopend - instr->loopstart) < CRIT_SIZE )
                {
                    b = (CRIT_SIZE/a)*a;
                    instr->loopend = instr->loopstart + b;
                    if((instr->sample = D_malloc(instr->loopend+16)) == NULL) return MERR_MEMORY;
                    module->size += instr->loopend;
                    if( instr->size > instr->loopend )
		    {
                        if(fread(instr->sample,instr->loopend,1,file) == 0) return MERR_FILE;
                        fseek(file,instr->size - instr->loopend,SEEK_CUR);
                    }
                    else
                        if(fread(instr->sample,instr->size,1,file) == 0) return MERR_FILE;
                    instr->size = instr->loopend;
                    mcpConvertSample(instr->sample,length);
                    for( i = 1; i < CRIT_SIZE/a; i++)
                    {
                        memcpy((char*)instr->sample+instr->loopstart+a*i,\
                               (char*)instr->sample+instr->loopstart,a);
                    }
                }
                else
                {
                    if( instr->type != 1 )
                    {
                        fseek(file,length,SEEK_CUR);
                        continue;
                    }
                    module->size += length;
                    if((sample = instr->sample = D_malloc(length+16)) == NULL) return MERR_MEMORY;
#ifdef __C32__
                    if(fread(sample,length,1,file) != 1) return MERR_FILE;
#else
                    while( length > 65520 )
                    {
                        if(fread(sample,65520,1,file) != 1) return MERR_FILE;
                        length -= 65520;
                        sample = MK_FP(FP_SEG(sample)+4095,FP_OFF(sample));
                    }
                    if(length) if(fread(sample,length,1,file) != 1) return MERR_FILE;
#endif
                    mcpConvertSample(instr->sample,length);
// Remove clicks
                    c = (instr->loopend) ? *((char*)instr->sample+instr->loopstart) : 128;
                    sample[length-1] = c;
#ifdef _USE_EMS
                    handle = 0;
                    if( instr->size > 2048 )
                    {
                        if((handle = emsAlloc(instr->size+16)) > 0)
                        {
                            emsCopyTo(handle,instr->sample,0,instr->size);
                            D_free(instr->sample);
                            instr->sample = MK_FP(0xFFFF,handle);
			}
                    }
#endif
                }
            }
            else
            {
                fseek(file,instr->size,SEEK_CUR);
                instr->sample = NULL;
                instr->size = 0;
            }
        }
        else
        {
            instr->sample = NULL;
            instr->size = 0;
        }
    }
    module->instrumentCount = lastins+1;
    return MERR_NONE;
}

#ifndef CONVERSION

static void joinTracks2Patterns(void)
{
    int         t,i;
    PATTERN     *pat;

    for( t = 0; t < module->patternCount; t++)
        {
        pat = &module->patterns[t];
        for( i = 0; i < module->channelCount; i++ )
            pat->track[i] = module->tracks[(unsigned)pat->track[i]];
        }
}

int cdecl loadFAR(FILE *f, MODULE *mod)
{
    int         a;

    file = f; module = mod;
    module->size = 0;
    hdr = D_malloc(sizeof(HEADERFAR));
    hdr2 = D_malloc(sizeof(HEADERFAR2));
    patUsed = D_malloc(256);
    if(( a = loadHeader()) == MERR_NONE )
        if(( a = loadPatterns()) == MERR_NONE )
            if(( a = loadSamples()) == MERR_NONE )
                joinTracks2Patterns();
    D_free(hdr);
    D_free(hdr2);
    D_free(patUsed);
    return a;
}

MODULE * cdecl ampLoadFAR(const char *name, long options)
{
    FILE        *file;
    ulong       l;
    MODULE      *module;

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
        D_free(module);
        return NULL;
    }
    module->type = MOD_NONE;
    fseek(file,0,SEEK_SET);
    fread(&l,4,1,file);
    if( l != 0xFE524146 ) // FSMþ magic
    {
        moduleError = MERR_TYPE;
    D_free(module);
        return NULL;
    }
    fread(module->name,32,1,file);
    module->name[31] = 0;
    moduleError = loadFAR(file,module);
    if( moduleError == MERR_NONE )
    {
        module->type = MOD_FAR;
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

#endif
