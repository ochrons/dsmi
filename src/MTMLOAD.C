// ************************************************************************
// *
// *    File        : MTMLOAD.C
// *
// *    Description : Module loader for AMP
// *
// *    Copyright (C) 1993,1994 Otto Chrons
// *
// ************************************************************************
/*
        Revision history of MTMLOAD.C

        1.0     28.11.93
                First version.
                3.12.93
                Support for 32 channels. Module name is now copied.
                5.12.93
                Fixed the missing pattern bug.
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

static ushort   instrRates[16] = { 856,850,844,838,832,826,820,814,
                                   907,900,894,887,881,875,868,862 };
static int      curTrack;
static uchar    patUsed[255];
static uchar    insc;
extern int      loadOptions;
void cdecl mcpConvertSample(void *sample,ulong length);

typedef struct {
    char        ID[3];
    char        version;
    char        songname[20];
    ushort      trackCount;
    uchar       patCount;
    uchar       orderCount;
    ushort      commentLength;
    uchar       sampleCount;
    uchar       attribute;
    uchar       bpt;
    uchar       channelCount;
    char        pan[32];
} MTMHEADER;

typedef struct {
    char        sampleName[22];
    long        sampleLength;
    long        loopStart, loopEnd;
    uchar       finetune;
    uchar       volume;
    uchar       attribute;
} MTMINSTRUMENT;

MTMHEADER       MTMhdr;

static int loadInstruments(FILE *file, MODULE* module)
{
    int         t,a;
    ushort      b;
    MTMINSTRUMENT MTMi;
    INSTRUMENT  *instr;

    fread(&MTMhdr,sizeof(MTMHEADER),1,file);    // Read header
    memcpy(module->name,MTMhdr.songname,20);
    module->name[20] = 0;
    module->channelCount = MTMhdr.channelCount;
    for( t = 0; t < 32; t++ )
    {
        a = MTMhdr.pan[t];
        module->channelPanning[t] = (a == 7 || a == 8 ) ? 0 : ( a < 7 ) ? (a-7)*9 : (a-8)*9;
    }
    insc = module->instrumentCount = MTMhdr.sampleCount;
    if((module->instruments = D_calloc(MTMhdr.sampleCount,sizeof(INSTRUMENT)))==NULL) return MERR_MEMORY;
    module->size += insc*sizeof(INSTRUMENT);
    for( t = 0; t < MTMhdr.sampleCount; t++ )
    {
        if(1 != fread(&MTMi,sizeof(MTMINSTRUMENT),1,file)) return MERR_FILE;
        instr = &module->instruments[t];
        instr->type = 0;
        strncpy(instr->name,MTMi.sampleName,22);
        instr->name[22] = 0;
        strncpy(instr->filename,MTMi.sampleName,12);
        instr->filename[12] = 0;
        instr->sample = NULL;
        instr->rate = 856*BASIC_FREQ/instrRates[MTMi.finetune & 0x0F];
        if((instr->volume = MTMi.volume) > 64) instr->volume = 64;
        instr->size = MTMi.sampleLength;
        instr->loopstart = MTMi.loopStart;
        b = MTMi.loopEnd;
        if( b < 3 ) b = 0;
        instr->loopend = b;
        if( instr->loopend > instr->size ) instr->loopend = instr->size;
        if( instr->loopstart > instr->loopend ) instr->loopend = 0;
        if( instr->loopend == 0 ) instr->loopstart = 0;
    }
    return MERR_NONE;
}

static int loadPatterns(FILE *file, MODULE* module)
{
    uchar       *orders;
    int         t,i,count;
    PATTERN     *pat;
    ushort      *trackptrs;

    if((orders = D_malloc(128)) == NULL) return MERR_MEMORY;
    if(1 != fread(orders,128,1,file)) return MERR_FILE;
    count = MTMhdr.orderCount+1;
    module->patternCount = count;
    module->trackCount = MTMhdr.trackCount;
    if((module->patterns = D_calloc(count,sizeof(PATTERN)))==NULL) return MERR_MEMORY;
    module->size += count*sizeof(PATTERN);
    for( t = 0; t < count; t++ )
    {
        patUsed[orders[t]] = 1;         // Indicate used
    }
    fseek(file,sizeof(MTMHEADER)+MTMhdr.sampleCount*sizeof(MTMINSTRUMENT)+128+MTMhdr.trackCount*192l,SEEK_SET);
    if((trackptrs = D_malloc(32*2*(MTMhdr.patCount+1))) == NULL) return MERR_MEMORY;
    if(1 != fread(trackptrs,32*2*(MTMhdr.patCount+1),1,file)) return MERR_FILE;
    for( t = 0; t < module->patternCount; t++ )
    {
        pat = &module->patterns[t];
        pat->length = 64;
        for( i = 0; i < 32; i++ )
        {
            pat->track[i] = (void*)(trackptrs[orders[t]*32+i]);
        }
    }
    D_free(trackptrs);
    D_free(orders);
    return MERR_NONE;
}

#define insertNote(a,b) { *(temptrack+pos*3) = tick;\
                        *(temptrack+pos*3+1) = a;\
                        *(temptrack+pos*3+2) = b; pos++; }

#define insertCmd insertNote

static TRACK *MTM2AMF(uchar *buffer, MODULE *module)
{
    TRACK       *track;
    int         i,t,pos,tick;
    uchar       note,ins,volume,command,data,curins;
    ushort      nvalue;
    uchar       *temptrack;

    pos = tick = ins = 0;
    curins = 0xF0;
    if((temptrack = D_malloc(576)) == NULL) return NULL;
    memset(temptrack,0xFF,576);
    for( t = 0; t < 64; t++ )
    {
        tick = t;
        note = 0xFF;
        nvalue = (buffer[t*3] >> 2);
        if( nvalue ) note = nvalue+36;
        command = buffer[t*3+1] & 0xF;
        data = buffer[t*3+2];
        volume = 255;
        if( command == 0xC )
            if((volume = data) > 64) volume = 64;
        ins = (((buffer[t*3+1] & 0xF0) >> 4) | ((buffer[t*3] & 0x3) << 4));
        if( ins != 0 )
        {
            ins--;
            if( ins != curins )
            {
                insertCmd(cmdInstr,ins);
                module->instruments[ins].type = 1;   // Indicate used
            }
            else
            {
                if( note == 0xFF && volume > 64 )
                {
                    insertCmd(cmdVolumeAbs,module->instruments[ins].volume);
                }
            }
            curins = ins;
            ins++;
        }
        if( command == 0xE && (data >> 4) == 0xD && (data & 0xF) != 0 && note != 0xFF )
        {
            insertCmd(cmdNoteDelay, data & 0xF);
            command = 0xFF;
        }
        if( command == 3 )
        {
            insertCmd(cmdBenderTo,data);
            command = 0xFF;
        }
        if( note != 0xFF )
        {
            ins--;
            if( ins != 0xFF && command != 0xC )
                volume = module->instruments[ins].volume;
            insertNote(note,volume)
        }
        else
        {
            if( volume < 65 ) insertCmd(cmdVolumeAbs,volume);
        }
        switch(command)
        {
            case 0xF :
                if( (data > 0 && data < 32) || (loadOptions & LM_OLDTEMPO))
                { insertCmd(cmdTempo,data); }
                else
                { insertCmd(cmdExtTempo,data); }
                break;
            case 0xB :
                insertCmd(cmdGoto,data);
                break;
            case 0xD :
                insertCmd(cmdBreak,0);
                break;
            case 0xA :
                if( data >= 16 ) data /= 16;
                else data = -data;
                insertCmd(cmdVolume,data);
                break;
            case 2 :
                if( !data ) break;
                if( data > 127 ) data = 127;
                insertCmd(cmdBender,data);
                break;
            case 1 :
                if( !data ) break;
                if( data > 127 ) data = 127;
                insertCmd(cmdBender,-data);
                break;
            case 4 :
                insertCmd(cmdVibrato,data);
                break;
            case 5 :
                if( data >= 16 ) data /= 16;
                else data = -data;
                insertCmd(cmdToneVol,data);
                break;
            case 6 :
                if( data >= 16 ) data /= 16;
                else data = -data;
                insertCmd(cmdVibrVol,data);
                break;
            case 7 :
                insertCmd(cmdTremolo,data);
                break;
            case 0 :
                if( data != 0 ) insertCmd(cmdArpeggio,data);
                break;
            case 9 :
                insertCmd(cmdOffset,data);
                break;
            case 8 :
                insertCmd(cmdPan,data-64);
                break;
            case 0xE :
                i = data >> 4;
                data &= 0x0F;
                switch(i)
                {
                    case 0 :
                        insertCmd(cmdSync,data);
                        break;
                    case 9 :
                        insertCmd(cmdRetrig,data);
                        break;
                    case 1 :
                        insertCmd(cmdFinetune,-data);
                        break;
                    case 2 :
                        insertCmd(cmdFinetune,data);
                        break;
                    case 0xA :
                        insertCmd(cmdFinevol,data);
                        break;
                    case 0xB :
                        insertCmd(cmdFinevol,-data);
                        break;
                    case 0xC :
                        insertCmd(cmdNoteCut,data);
                        break;
                    case 0xD :
                        insertCmd(cmdNoteDelay,data);
                        break;
                    case 8 :
                        insertCmd(cmdPan,(data == 7 || data == 8 ) ? 0 : ( data < 7 ) ? (data-7)*9 : (data-8)*9);
                        break;
                }
                break;
        }
    }
    if( pos == 0 ) track = NULL;
    else
    {
        pos++;
    if((track = (TRACK*)D_malloc(pos*3+3)) != NULL)
        {
            module->size += pos*3+3;
            track->size = pos;
            track->type = 0;
            memcpy((char*)(track)+3,temptrack,pos*3);
        }
    }
    D_free(temptrack);
    return track;
}

static int loadTracks(FILE *file, MODULE* module)
{
    int         count;
    int         t;
    char        *buffer;

    count = module->trackCount;
    if((module->tracks = D_calloc(count+4,sizeof(TRACK *)))==NULL) return MERR_MEMORY;
    module->size += (count+4)*sizeof(TRACK *);
    module->tracks[0] = NULL;
    curTrack = 1;
    fseek(file,sizeof(MTMHEADER)+MTMhdr.sampleCount*sizeof(MTMINSTRUMENT)+128,SEEK_SET);
    buffer = D_malloc(192);
    for( t = 0; t < MTMhdr.trackCount; t++ )
    {
        fread(buffer,192,1,file);               // Can't fail!
        module->tracks[curTrack++] = MTM2AMF(buffer,module);
    }
    D_free(buffer);
    return MERR_NONE;
}

static int loadSamples(FILE *file, MODULE *module)
{
    ushort      t,i,b;
    ulong       a,length;
    INSTRUMENT  *instr;
    uchar       *sample,c;

#ifdef _USE_EMS
    EMSH        handle;
#endif


    fseek(file,sizeof(MTMHEADER)+MTMhdr.sampleCount*sizeof(MTMINSTRUMENT)+128+\
               MTMhdr.trackCount*192l+(MTMhdr.patCount+1)*32*2l+MTMhdr.commentLength,SEEK_SET);
    for( t = 0; t < module->instrumentCount; t++ )
    {
        instr = &module->instruments[t];
        if((loadOptions & LM_IML) && (instr->type == 0 ))
        {
            fseek(file,instr->size,SEEK_CUR);
            instr->size = 0;
            instr->sample = NULL;
            continue;
        }
        if( instr->size > 4 )
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
                length = instr->size;
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
                if( instr->size > 1024 )
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
        else { instr->size = 0; instr->sample = 0; }
    }
    return MERR_NONE;
}

#ifndef CONVERSION

static void joinTracks2Patterns(MODULE *module)
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

int cdecl loadMTM(FILE *file, MODULE *module)
{
    int         a;

    module->tempo = 125;
    module->speed = 6;
    if((a = loadInstruments(file,module)) < MERR_NONE) return a;
    if((a = loadPatterns(file,module)) < MERR_NONE) return a;
    if((a = loadTracks(file,module)) < MERR_NONE) return a;
    if((a = loadSamples(file,module)) < MERR_NONE) return a;
    joinTracks2Patterns(module);
    return a;
}

MODULE * cdecl ampLoadMTM(const char *name, long options)
{
    FILE        *file;
    MODULE      *module;
    int         b;
    char        ID[4];

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
    fread(ID,3,1,file);
    ID[3] = 0;
    if( strcmp(ID,"MTM") == 0 ) module->type = MOD_MTM;
    if( module->type == MOD_NONE )
    {
        moduleError = MERR_TYPE;
        return NULL;
    }
    b = loadMTM(file,module);
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
#endif
