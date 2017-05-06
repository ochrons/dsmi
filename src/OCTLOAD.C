// ************************************************************************
// *
// *    File        : OCTLOAD.C
// *
// *    Description : Octalyzer loader for AMP
// *
// *    Copyright (C) 1992 Otto Chrons
// *
// ************************************************************************

#include <stdio.h>
#include <alloc.h>
#include <string.h>
#include <stdlib.h>

#pragma hdrstop

#include "amp.h"

#define BASIC_FREQ 8448L

void far mcpConvertSample(void far *, ushort);

static int      curTrack;
static uchar    patUsed[255];
static ushort   instrRates[16] = { 856,850,844,838,832,826,820,814,
                                   907,900,894,887,881,875,868,862 };

extern int      loadOptions;

typedef struct {
    char        name[22];
    unsigned    length;
    char        finetune;
    char        volume;
    unsigned    loopstart;
    unsigned    looplength;
} OCTinst;

static ushort swapb(ushort a)
{
    asm mov     ax,a
    asm xchg    ah,al

    return _AX;
}

static int loadInstruments(FILE *file, MODULE* module)
{
    int         t,a;
    ushort      b;
    MODinst     MODi;
    INSTRUMENT  *instr;

    module->instrumentCount = 31;
    if((module->instruments = calloc(31,sizeof(INSTRUMENT)))==NULL) return -1;
    module->size += 31*sizeof(INSTRUMENT);
    fseek(file,20,SEEK_SET);
    for(a = 0,t = 0; a != -1 && t < 31; t++)
        {
        a = fread(&MODi,sizeof(MODinst),1,file);
        instr = &(*module->instruments)[t];
        instr->type = 0;
        MODi.name[21] = 0;
        strcpy(instr->name,MODi.name);
        strncpy(instr->filename,MODi.name,12);
        instr->filename[12] = 0;
        instr->sample = NULL;
        instr->rate = 856*BASIC_FREQ/instrRates[MODi.finetune & 0x0F];
        if((instr->volume = MODi.volume) > 64) instr->volume = 64;
        instr->size = swapb(MODi.length)*2;
        instr->loopstart = swapb(MODi.loopstart)*2;
        b = swapb(MODi.looplength)*2;
        if( b == 2 || b == 0 ) b = 65535;
        else b += instr->loopstart;
        instr->loopend = b;
        if( instr->loopend > instr->size && instr->loopend < 65535 )
            instr->loopend = instr->size;
        }
    return (a == -1) ? -2 : 0;
}

static int loadPatterns(FILE *file, MODULE* module)
{
    char        orders[128];
    void        *ptr;
    int         a,t,i,count = 0,lastPattern = 0;
    PATTERN     *pat;

    memset(patUsed,0,255);
    fseek(file,20+31*30,SEEK_SET);
    fread(&count,1,1,file);
    fread(orders,1,1,file);
    fread(orders,128,1,file);
    for( t = 0; t < 128; t++) if(lastPattern < orders[t]) lastPattern = orders[t];
    lastPattern++;
    module->patternCount = count;
    module->trackCount = lastPattern*module->channelCount;
    if((module->patterns = calloc(count,sizeof(PATTERN)))==NULL) return -1;
    module->size += count*sizeof(PATTERN);
    for( t = 0; t < count; t++ )
        {
        patUsed[orders[t]] = 1;         // Indicate used
        pat = &(*module->patterns)[t];
        pat->length = 64;
        for( i = 0; i < module->channelCount; i++)
            {
            pat->track[module->channelOrder[i]] = (void*)(orders[t]*4u+1+i);
            }
        }
    return 0;
}

ushort modNotes[61] = { 1712,1616,1524,1440,1356,1280,1208,1140,1076,1016,960,912,
                        856,808,762,720,678,640,604,570,538,508,480,453,
                        428,404,381,360,339,320,302,285,269,254,240,226,
                        214,202,190,180,170,160,151,143,135,127,120,113,
                        107,101,95,90,85,80,75,71,67,63,60,56,0 };


#define insertNote(a,b) { *(temptrack+pos*3) = tick;\
                        *(temptrack+pos*3+1) = a;\
                        *(temptrack+pos*3+2) = b; pos++; }

#define insertCmd insertNote

static TRACK far* STM2AMF(uchar far *buffer, int trk, MODULE *module)
{
    TRACK       *track;
    int         i,t,pos,tick,a;
    uchar       note,noNote,oldnote,ins,volume,command,data,curins,curvolume;
    ushort      nvalue;
    static uchar temptrack[576];

    pos = tick = ins = 0;
    oldnote = 0;
    curins = 0xF0;
    buffer += trk*4;
    memset(temptrack,0xFF,576);
    for( t = 0; t < 64; t++ )
        {
        tick = t;
        note = 0xFF; noNote = 0;
        nvalue = (buffer[t*16] & 0xF)*256 + buffer[t*16+1];
        if( nvalue != 0 )
            for( i = 0; i < 61; i++)
                if(nvalue >= modNotes[i])
                    {
                    note = i + 36;
                    break;
                    }
        command = buffer[t*16+2] & 0xF;
        if( command == 3 )
            {
            insertCmd(cmdBenderTo,buffer[t*16+3]);
            command = 0xFF;
            }
        volume = 255;
        if( command == 0xC )
            if((volume = buffer[t*16+3]) > 64) volume = 64;
        ins = ((buffer[t*16+2]>>4) | (buffer[t*16] & 0x10));
        if( ins != 0 && nvalue == 0 )
            {
            ins--;
            if( ins == curins )
                insertCmd(cmdVolumeAbs,(*module->instruments)[ins].volume)
            else
                {
                insertCmd(cmdInstr,ins);
                (*module->instruments)[ins].type = 1;   // Indicate used
                }
            curins = ins;
            ins++;
            }
        if( note != 0xFF )
            {
            ins--;
            if(ins != curins && ins != 0xFF )
                {
                insertCmd(cmdInstr,ins);
                (*module->instruments)[ins].type = 1;   // Indicate used
                curins = ins;
                }
            if( ins != 0xFF && command != 0xC )
                volume = (*module->instruments)[ins].volume;
            insertNote(note,volume)
            }
        else
            {
            if( ins != 0 ) volume = (*module->instruments)[ins].volume;
            if( volume < 65 ) insertCmd(cmdVolumeAbs,volume);
            }
        data = buffer[t*16+3];
        switch(command)
            {
            case 0xF :
                if( data > 0 && data < 32 ) insertCmd(cmdTempo,data);
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
                if( data > 127 ) data = 127;
                insertCmd(cmdBender,data);
                break;
            case 1 :
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
            case 0xE :
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
                if((*module->tracks)[i]->size == pos &&
                   memcmp(&temptrack,(char*)(*module->tracks)[i]+3,pos*3) == 0)
                    {
                    return (*module->tracks)[i];
                    }
                }
            }
        if((track = (TRACK*)malloc(pos*3+3)) != NULL)
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
    int         t,i,a;
    char        buffer[1024];

    a = module->channelCount;
    count = module->trackCount/a;
    if((module->tracks = calloc(count*a+4,sizeof(TRACK far *)))==NULL) return -1;
    module->size += (count*a+4)*sizeof(TRACK far *);
    fseek(file,20+30*31+128+2+4,SEEK_SET);
    (*module->tracks)[0] = NULL;
    curTrack = 1;
    for( t = 0; t < count; t++)
        {
        if( (loadOptions & LM_IML) && (patUsed[t] == 0) )
            {
            for( i = 0; i < module->channelCount; i++ )
                (*module->tracks)[curTrack++] = NULL;
            fseek(file,256*module->channelCount,SEEK_CUR);
            continue;
            }
        if( module->channelCount == 4 )
            {
            a = fread(buffer,1024,1,file);              // Convert patterns into
            if( a != 0 )
                {
                (*module->tracks)[curTrack++] = STM2AMF(buffer,0,module);
                (*module->tracks)[curTrack++] = STM2AMF(buffer,1,module);
                (*module->tracks)[curTrack++] = STM2AMF(buffer,2,module);
                (*module->tracks)[curTrack++] = STM2AMF(buffer,3,module);
                }
            else return -2;
            }
        else if( module->channelCount = 8 )
            {
            a = fread(buffer,1024,1,file);              // Convert patterns into
            if( a != 0 )
                {
                (*module->tracks)[curTrack++] = STM2AMF(buffer,0,module);
                (*module->tracks)[curTrack++] = STM2AMF(buffer,1,module);
                (*module->tracks)[curTrack++] = STM2AMF(buffer,2,module);
                (*module->tracks)[curTrack++] = STM2AMF(buffer,3,module);
                }
            else return -2;
            a = fread(buffer,1024,1,file);              // Convert patterns into
            if( a != 0 )
                {
                (*module->tracks)[curTrack++] = STM2AMF(buffer,0,module);
                (*module->tracks)[curTrack++] = STM2AMF(buffer,1,module);
                (*module->tracks)[curTrack++] = STM2AMF(buffer,2,module);
                (*module->tracks)[curTrack++] = STM2AMF(buffer,3,module);
                }
            else return -2;
            }
        }
    return 0;
}

static int loadSamples(FILE *file, MODULE *module)
{
    ushort      t,i,a,b;
    long        c;
    INSTRUMENT  *instr;
    char        temp[32];

    fseek(file,20+30*31+128+2+4+(long)module->trackCount*256L,SEEK_SET);
    for( t = 0; t < module->instrumentCount; t++ )
        {
        instr = &(*module->instruments)[t];
        if((loadOptions & LM_IML) && (instr->type == 0 ))
            {
            fseek(file,instr->size,SEEK_CUR);
            instr->size = 0;
            }
        if( instr->size >= 8 )
            {
            if( (a = instr->loopend - instr->loopstart) < CRIT_SIZE )
                {
                b = (CRIT_SIZE/a)*a;
                instr->loopend = instr->loopstart + b;
                if((instr->sample = malloc(instr->loopend)) == NULL) return -1;
                module->size += instr->loopend;
                if(fread(instr->sample,instr->size,1,file) == 0) return -2;
                instr->size = instr->loopend;
                for( i = 1; i < CRIT_SIZE/a; i++)
                    {
                    memcpy((char*)instr->sample+instr->loopstart+a*i,\
                           (char*)instr->sample+instr->loopstart,a);
                    }
                }
            else
                {
                a = (instr->size > 65520) ? 65520 : instr->size;
                if((instr->sample = malloc(a)) == NULL) return -1;
                module->size += a;
                if( fread(instr->sample,a,1,file ) == 0) return -2;
                if( a < instr->size )
                    {
                    fread(temp,instr->size - a,1,file);
                    instr->size = a;
                    }
                }
            mcpConvertSample(instr->sample,instr->size);
            if( loadOptions & LM_IML )
                {
                a = instr->size;
                for( i = 0; i < t; i++)
                    if((*module->instruments)[i].size == a &&
                       memcmp(instr->sample,(*module->instruments)[i].sample,instr->size) == 0)
                        {
                        free(instr->sample);
                        module->size -= instr->size;
                        instr->sample = (*module->instruments)[i].sample;
                        break;
                        }
                }
            }
        else { instr->size = 0; instr->sample = 0; }
        }
    return 0;
}

#ifndef CONVERSION

static void joinTracks2Patterns(FILE *file,MODULE *module)
{
    int         t,i;
    PATTERN     *pat;

    for( t = 0; t < module->patternCount; t++)
        {
        pat = &(*module->patterns)[t];
        for( i = 0; i < module->channelCount; i++ )
        pat->track[i] = (*module->tracks)[(unsigned)pat->track[i]];
        }
}

int loadMOD(FILE *file, MODULE *module)
{
    int         a;

    if((a = loadInstruments(file,module)) != 0) return a;
    if((a = loadPatterns(file,module)) != 0) return a;
    if((a = loadTracks(file,module)) != 0) return a;
    if((a = loadSamples(file,module)) != 0) return a;
    joinTracks2Patterns(file,module);

    return 0;
}

#endif
