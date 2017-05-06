// ************************************************************************
// *
// *    File        : 669LOAD.C
// *
// *    Description : 669 loader for DSMI
// *
// *    Copyright (C) 1993,1994 Otto Chrons
// *
// ************************************************************************
/*
        Revision history of 669LOAD.C

        1.0     7.5.93
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
    ushort      magic;
    char        message[108];
    uchar       ins,pats,loop,orders[128],tempos[128],breaks[128];
} HEADER669;

extern int      loadOptions;

void cdecl mcpConvertSample(void *sample,ulong length);

static uchar    *patUsed;
static MODULE   *module;
static FILE     *file;
static HEADER669 *hdr;
static int      lastChan;
static uchar    order8[8] = {PAN_LEFT,PAN_RIGHT,PAN_LEFT,PAN_RIGHT,PAN_LEFT,PAN_RIGHT,PAN_LEFT,PAN_RIGHT};

static int loadHeader(void)
{
    int         t,count,i;
    PATTERN     *pat;

    rewind(file);
    fread(hdr,sizeof(HEADER669),1,file);
    module->channelCount = 8;
    memcpy(&module->channelPanning,order8,8);
    module->tempo = 78;
    module->speed = 4;

    for( count = 0; count < 128 && hdr->orders[count] < 128; count++);
    module->patternCount = count;
    if((module->patterns = D_calloc(count,sizeof(PATTERN))) == NULL) return MERR_MEMORY;
    module->size += count*sizeof(PATTERN);

    for( t = 0; t < count; t++ )
    {
        patUsed[hdr->orders[t]] = 1;             // Indicate used
        pat = &module->patterns[t];
        pat->length = 64;
        for( i = 0; i < 8; i++)
        {
            pat->track[i] = (hdr->orders[t] == 0xFF) ? 0 : (void*)((int)hdr->orders[t]*8+1+i);
        }
    }
    return MERR_NONE;
}

typedef struct {
    char        name[13];
    ulong       length,loopstart,loopend;
} INS669;

static int loadInstruments(void)
{
    ushort      t;
    INSTRUMENT  *instr;
    INS669      ins;

    module->instrumentCount = hdr->ins;
    if((module->instruments = D_calloc(hdr->ins,sizeof(INSTRUMENT)))==NULL) return MERR_MEMORY;
    module->size += hdr->ins*sizeof(INSTRUMENT);
    for( t = 0; t < hdr->ins; t++)
    {
        if(!fread(&ins,sizeof(INS669),1,file)) return MERR_FILE;
        instr = &module->instruments[t];
        instr->type = 0;
        strcpy(instr->name,ins.name);
        instr->name[13] = 0;
        strcpy(instr->filename,ins.name);
        instr->filename[12] = 0;
        instr->rate = BASIC_FREQ;
        instr->volume = 64;
        instr->size = ins.length;
        instr->loopstart = ins.loopstart;
        instr->loopend = (ins.loopend > ins.length) ? 0 : ins.loopend;
        instr->sample = NULL;
    }
    return MERR_NONE;
}

typedef struct {
    uchar b1,b2,b3;
} ROW669;

#define insertNote(a,b) { *(temptrack+pos*3) = tick;\
                        *(temptrack+pos*3+1) = a;\
                        *(temptrack+pos*3+2) = b; pos++; }

#define insertCmd insertNote

static int loadPatterns(void)
{
    int         pos,t,j,i,tick,curTrack = 1;
    uchar       note,ins,volume,command,data,curins;
    ushort      count,tempo;
    TRACK       *track;
    uchar       *temptrack;
    ROW669      *buffer;
    ROW669      c;

    count = hdr->pats*8;
    temptrack = D_malloc(576);
    module->trackCount = count;
    if((module->tracks = D_calloc(count+4,sizeof(TRACK *)))==NULL) return MERR_MEMORY;
    module->size += (count+4)*sizeof(TRACK *);
    if((buffer = D_calloc(64*8,sizeof(ROW669))) == NULL) return MERR_MEMORY;
    for( t = 0; t < hdr->pats; t++ )
    {
        tempo = hdr->tempos[t];
        if(!fread(buffer,64*8*3,1,file)) return MERR_FILE;
        for( j = 0; j < 8; j++ )
        {
            memset(temptrack,0xFF,576);
            pos = 0;
            curins = 0xF0;
            for( tick = 0; tick < 64; tick++ )
            {
                if( tick == 0 && j == 0 && tempo != 0)
                {
                    insertCmd(cmdTempo,tempo);
                    insertCmd(cmdExtTempo,78);
                }
                if( tick == hdr->breaks[t] && j == 0 && tick != 63) insertCmd(cmdBreak,0);
                note = 0; volume = ins = 0xFF;
                c = buffer[tick*8+j];
                if( c.b1 < 0xFE )
                {
                    note = c.b1>>2;
                    ins = ((c.b1 & 0x3)<<4) | (c.b2>>4);
                    if( ins != curins )
                    {
                        curins = ins;
                        insertCmd(cmdInstr,ins);
                        module->instruments[ins].type = 1;
                    }
                }
                if( c.b1 < 0xFF )
                {
                    volume = c.b2 & 0xF;
                }
                command = c.b3 >> 4;
                data = c.b3 & 0xF;
                if( command == 2 )
                    insertCmd(cmdBenderTo,data);
                if( note )
                {
                    if( volume != 0xFF ) { insertNote(note+36,volume*4); }
                    else insertNote(note+36,255);
                }
                else if( volume != 0xFF ) insertCmd(cmdVolumeAbs,volume*4);

                switch(command)
                {
                    case 0 :
                        insertCmd(cmdBender,data);
                        break;
                    case 1 :
                        insertCmd(cmdBender,-data);
                        break;
                    case 3 :
                        insertCmd(cmdFinetune,-1);
                        break;
                    case 4 :
                        insertCmd(cmdVibrato,(data << 4)+1);
                        break;
                    case 5 :
                        insertCmd(cmdTempo,data);
                        break;
                    case 6 :
                        insertCmd(cmdSync,data);
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
                    else return MERR_MEMORY;
            }
            module->tracks[curTrack++] = track;
        }
    }
    D_free(buffer);
    D_free(temptrack);
    return MERR_NONE;
}

static int loadSamples(void)
{
    ushort      t,i;
    INSTRUMENT  *instr;
    ulong       length,a,b;
    char        *sample,c;
#ifdef _USE_EMS
    EMSH        handle;
#endif

    fseek(file,0x1F1+hdr->ins*sizeof(INS669)+hdr->pats*0x600,SEEK_SET);
    for( t = 0; t < hdr->ins; t++)
    {
        instr = &module->instruments[t];
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

int cdecl load669(FILE *f, MODULE *mod)
{
    int         a;

    file = f; module = mod;
    module->size = 0;
    lastChan = 0;
    hdr = D_malloc(sizeof(HEADER669));
    patUsed = D_malloc(256);
    if(( a = loadHeader()) == MERR_NONE )
        if(( a = loadInstruments()) == MERR_NONE )
            if(( a = loadPatterns()) == MERR_NONE )
                if(( a = loadSamples()) == MERR_NONE )
                    joinTracks2Patterns();
    D_free(hdr);
    D_free(patUsed);
    return a;
}

MODULE * cdecl ampLoad669(const char *name, long options)
{
    FILE        *file;
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
        D_free(module);
        return NULL;
    }
    module->type = MOD_NONE;
    fseek(file,0,SEEK_SET);
    fread(&b,2,1,file);
    if( b != 0x6669 ) // 669 magic
    {
        moduleError = MERR_TYPE;
        D_free(module);
        return NULL;
    }
    fread(module->name,32,1,file);
    module->name[31] = 0;
    moduleError = load669(file,module);
    if( moduleError == MERR_NONE )
    {
        module->type = MOD_669;
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
