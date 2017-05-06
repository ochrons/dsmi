// ************************************************************************
// *
// *    File        : STMLOAD.C
// *
// *    Description : Scream Tracker Module loader for AMP
// *
// *    Copyright (C) 1992 Otto Chrons
// *
// ************************************************************************
/*
        Revision history of STMLOAD.C

        1.0     16.4.93
                First version.


*/

#include <stdio.h>
#include <string.h>
#include <dos.h>

#include "amp.h"

#ifdef _USE_EMS
#include "emhm.h"
#endif

#define CORRECTFREQ 8368L/8448L


static int      curTrack;
static uchar    patUsed[255];
static ushort   instrOffs[32];
static uchar    order4[4] = {PAN_LEFT,PAN_RIGHT,PAN_RIGHT,PAN_LEFT};
extern int      loadOptions;
void cdecl mcpConvertSample(void *sample,ulong length);

typedef struct {
    char        name[13];
    char        disk;
    ushort      position;
    ushort      length;
    ushort      loopstart;
    ushort      loopend;
    char        volume;
    char        __a;
    ushort      rate;
    long        __b;
    ushort      __c;
} STMinst;

static int loadInstruments(FILE *file, MODULE* module)
{
    int         t,a;
    STMinst     STMi;
    INSTRUMENT  *instr;

    module->instrumentCount = 31;
    if((module->instruments = D_calloc(31,sizeof(INSTRUMENT)))==NULL) return MERR_MEMORY;
    module->size += 31*sizeof(INSTRUMENT);
    fseek(file,48,SEEK_SET);
    for(a = 1,t = 0; a == 1 && t < 31; t++)
    {
        a = fread(&STMi,sizeof(STMinst),1,file);
        instr = &module->instruments[t];
        instr->type = 0;
        strcpy(instr->name,STMi.name);
        strcpy(instr->filename,STMi.name);
        instr->sample = NULL;
        instrOffs[t] = STMi.position;
        instr->rate = STMi.rate*CORRECTFREQ;
        instr->volume = STMi.volume;
        instr->size = STMi.length;
        instr->loopstart = STMi.loopstart;
        instr->loopend = (STMi.loopend == 65535) ? 0 : STMi.loopend;
        if( instr->loopend != 0 && instr->loopend < instr->size ) instr->size = instr->loopend;
        if( instr->loopend > instr->size && instr->loopend != 0 )
            instr->loopend = instr->size;
        if( instr->loopstart > instr->loopend ) instr->loopend = 0;
        if( instr->loopend == 0 ) instr->loopstart = 0;
    }
    return (a != 1) ? MERR_FILE : 0;
}

static int loadPatterns(FILE *file, MODULE* module)
{
    char        orders[128];
    int         t,count;
    PATTERN     *pat;

    memset(patUsed,0,255);
    fseek(file,48+31*32,SEEK_SET);
    if(fread(orders,128,1,file) == 0) return MERR_FILE;
    for( count = 0; count < 128 && orders[count] != 99; count++ );
    module->patternCount = count;
    if((module->patterns = D_calloc(count,sizeof(PATTERN)))==NULL) return MERR_MEMORY;
    module->size += count*sizeof(PATTERN);
    for( t = 0; t < count; t++ )
    {
        patUsed[orders[t]] = 1;         // Indicate used
        pat = &module->patterns[t];
        pat->length = 64;
        pat->track[0] = (void*)(orders[t]*4u+1);
        pat->track[1] = (void*)(orders[t]*4u+2);
        pat->track[2] = (void*)(orders[t]*4u+3);
        pat->track[3] = (void*)(orders[t]*4u+4);
    }
    return MERR_NONE;
}

#define insertNote(a,b) { *(temptrack+pos*3) = tick;\
                        *(temptrack+pos*3+1) = a;\
                        *(temptrack+pos*3+2) = b; pos++; }

#define insertCmd insertNote

static TRACK * STM2AMF(uchar *buffer, int trk, MODULE *module)
{
    TRACK       *track;
    int         i,t,pos,tick;
    uchar       note,ins,volume,command,data,curins;
    uchar       *temptrack;

    pos = tick = 0;
    curins = 0xF0;
    buffer += trk*4;
    if((temptrack = D_malloc(576)) == NULL) return NULL;
    memset(temptrack,0xFF,576);
    for( t = 0; t < 64; t++ )
    {
        tick = t;
        note = buffer[t*16];
        command = (buffer[t*16+2] & 0xF)+64;
        data = buffer[t*16+3];
        if( command == 'G' )
        {
            insertCmd(cmdBenderTo,data);
            command = 0;
        }
        if( command == 'K' )
            insertCmd(cmdBenderTo,0);
        if((volume = (buffer[t*16+1] & 7) + (buffer[t*16+2] & 0xF0)/2) > 65) volume = 65;
        if( note != 0xFF )
        {
            ins = (buffer[t*16+1]>>3) - 1;
            if( ins != curins && ins != 0xFF )
            {
                insertCmd(cmdInstr,ins);
                module->instruments[ins].type = 1;   // Indicate used
                curins = ins;
            }
            if( ins != 0xFF && volume == 65 )
                volume = module->instruments[ins].volume;
            if( volume == 65 ) volume = 255;
            if( command == 'M' && (data >> 4) == 0xD )
            {
                insertCmd(cmdNoteDelay, data & 0xF);
                command = 0;
            }
            note = 36+(note & 0xF)+(note>>4)*12;
            insertNote(note,volume);
        }
        else if( volume < 65 )
        {
            insertCmd(cmdVolumeAbs,volume);
        }
        if( command != 64 )
        {
            switch(command)
            {
                case 'A' :
                    insertCmd(cmdTempo,data>>4);
                    break;
                case 'B' :
                    insertCmd(cmdGoto,data);
                    break;
                case 'C' :
                    insertCmd(cmdBreak,0);
                    break;
                case 'D' :
                    if( data >= 16 ) data = data/16;
                    else data = -data;
                    insertCmd(cmdVolume,data);
                    break;
                case 'E' :
                    if( data > 127 ) data = 127;
                    insertCmd(cmdBender,data);
                    break;
                case 'F' :
                    if( data > 127 ) data = 127;
                    insertCmd(cmdBender,-data);
                    break;
                case 'H' :
                    insertCmd(cmdVibrato,data);
                    break;
                case 'I' :
                    insertCmd(cmdTremolo,data);
                    break;
                case 'J' :
                    insertCmd(cmdArpeggio,data);
                    break;
                case 'K' :
                    if( data >= 16 ) data = data/16;
                    else data = -data;
                    insertCmd(cmdToneVol,data);
                    break;
                case 'L' :
                    if( data >= 16 ) data = data/16;
                    else data = -data;
                    insertCmd(cmdVibrVol,data);
                    break;
                case 'M' :
                    i = data >> 4;
                    data &= 0x0F;
                    switch(i)
                    {
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
                    }
                    break;
                case 'O' :
                    insertCmd(cmdSync,data);
                    break;
            }
        }
    }
    if( pos == 0 ) track = NULL;
    else
    {
        pos++;
        if( loadOptions & LM_IML )
        {
            for( i = 1; i < curTrack; i++)
            {
                if(module->tracks[i] != NULL)
                if(module->tracks[i]->size == pos &&
                   memcmp(&temptrack,(char*)module->tracks[i]+3,pos*3) == 0)
                {
                    return module->tracks[i];
                }
            }
        }
        if((track = (TRACK*)D_malloc(pos*3+3)) != NULL)
        {
            module->size += pos*3+3;
            track->size = pos;
            track->type = 0;
            memcpy((char*)(track)+3,temptrack,pos*3);
        }
    }
    return track;
}

static int loadTracks(FILE *file, MODULE* module)
{
    uchar       count;
    int         t,a;
    char        *buffer;

    fseek(file,33,SEEK_SET);
    fread(&count,1,1,file);
    module->trackCount = count*4;
    if((module->tracks = D_calloc(count*4+4,sizeof(TRACK *)))==NULL) return MERR_MEMORY;
    module->size += (count*4+4)*sizeof(TRACK *);
    fseek(file,48+32*31+128,SEEK_SET);
    module->tracks[0] = NULL;
    curTrack = 1;
    if((buffer = D_malloc(1024)) == NULL) return MERR_MEMORY;
    for( t = 0; t < count; t++)
    {
        if( (loadOptions & LM_IML) && (patUsed[t] == 0) )
        {
            module->tracks[curTrack++] = NULL;
            module->tracks[curTrack++] = NULL;
            module->tracks[curTrack++] = NULL;
            module->tracks[curTrack++] = NULL;
            fseek(file,1024,SEEK_CUR);
            continue;
        }
        a = fread(buffer,1024,1,file);          // Convert patterns into
        if( a != 0 )
        {
            module->tracks[curTrack++] = STM2AMF(buffer,0,module);
            module->tracks[curTrack++] = STM2AMF(buffer,1,module);
            module->tracks[curTrack++] = STM2AMF(buffer,2,module);
            module->tracks[curTrack++] = STM2AMF(buffer,3,module);
        }
        else
        {
            D_free(buffer);
            return MERR_FILE;
        }
    }
    D_free(buffer);
    return MERR_NONE;
}

static int loadSamples(FILE *file, MODULE *module)
{
    ulong       t,i,a,b;
    char        c;
    INSTRUMENT  *instr;
#ifdef _USE_EMS
    EMSH        handle;
#endif

    for( t = 0; t < module->instrumentCount; t++ )
    {
        instr = &module->instruments[t];
        if((loadOptions & LM_IML) && (instr->type == 0 )) instr->size = 0;
        if( instr->size > 0 )
        {
            fseek(file,instrOffs[t]*16L,SEEK_SET);
            if( instr->loopend != 0 && (a = instr->loopend - instr->loopstart) < CRIT_SIZE )
            {
                b = (CRIT_SIZE/a)*a;
                instr->loopend = instr->loopstart + b;
                if((instr->sample = D_malloc(instr->loopend+16)) == NULL)
                    return MERR_MEMORY;
                module->size += instr->loopend;
                if(fread(instr->sample,instr->size,1,file) == 0) return MERR_FILE;
                instr->size = instr->loopend;
                for( i = 1; i < CRIT_SIZE/a; i++)
                {
                    memcpy((char*)instr->sample+instr->loopstart+a*i,\
                           (char*)instr->sample+instr->loopstart,a);
                }
                mcpConvertSample(instr->sample,instr->size);
            }
            else
            {
                if((instr->sample = D_malloc(instr->size+16)) == NULL)
                    return MERR_MEMORY;
                module->size += instr->size;
                if(fread(instr->sample,instr->size,1,file) == 0) return MERR_FILE;
                mcpConvertSample(instr->sample,instr->size);
// Remove clicks
                c = (instr->loopend) ? *((char*)instr->sample+instr->loopstart) : 128;
                ((char*)(instr->sample))[instr->size-1] = c;
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
        else { instr->size = 0; instr->sample = NULL; }
    }
    return MERR_NONE;
}

#ifndef CONVERSION

static void joinTracks2Patterns(MODULE *module)
{
    unsigned    t,i;
    PATTERN     *pat;

    for( t = 0; t < module->patternCount; t++)
    {
        pat = &module->patterns[t];
        for( i = 0; i < 4; i++)
            pat->track[i] = ((unsigned)pat->track[i] <= module->trackCount)
                ? module->tracks[(unsigned)pat->track[i]] : NULL;
    }
}

int cdecl loadSTM(FILE *file, MODULE *module)
{
    int         a;

    module->tempo = 125;
    module->speed = 6;
    if((a = loadInstruments(file,module))!=0) return a;
    if((a = loadPatterns(file,module))!=0) return a;
    if((a = loadTracks(file,module))!=0) return a;
    if((a = loadSamples(file,module))!=0) return a;
    joinTracks2Patterns(module);
    return MERR_NONE;
}

MODULE * cdecl ampLoadSTM(const char *name, long options)
{
    FILE        *file;
    MODULE      *module;
    int         t,b;

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
    fseek(file,28,SEEK_SET);
    fread(&t,2,1,file);
    if( t == 0x021A )                   // is it STM?
    {
        module->type = MOD_STM;         // indicate type
        fseek(file,0,SEEK_SET);
        fread(module->name,20,1,file);  // Read module name
        module->name[20] = 0;
        module->channelCount = 4;
        memcpy(&module->channelPanning,&order4,4);
    }
    else
    {
        moduleError = MERR_TYPE;
        return NULL;
    }
    b = loadSTM(file,module);
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
