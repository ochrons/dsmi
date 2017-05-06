// ************************************************************************
// *
// *    File        : MODLOAD.C
// *
// *    Description : Module loader for AMP
// *
// *    Copyright (C) 1992 Otto Chrons
// *
// ************************************************************************
/*
        Revision history of MODLOAD.C

        1.0     16.4.93
                First version. Loads also FastTracker MODs.

                11.5.93
                Panning replaced channel orders
                In corrupted modules the last sample is now converted into
                unsigned form.

                10.5.94
                Support for 'n' channel MODs

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

static int      curTrack;
static uchar    patUsed[255];
static ushort   instrRates[16] = { 856,850,844,838,832,826,820,814,
                                   907,900,894,887,881,875,868,862 };
static uchar    order32[32] = {PAN_LEFT,PAN_RIGHT,PAN_RIGHT,PAN_LEFT,PAN_LEFT,PAN_RIGHT,PAN_RIGHT,PAN_LEFT,
                               PAN_LEFT,PAN_RIGHT,PAN_RIGHT,PAN_LEFT,PAN_LEFT,PAN_RIGHT,PAN_RIGHT,PAN_LEFT,
                               PAN_LEFT,PAN_RIGHT,PAN_RIGHT,PAN_LEFT,PAN_LEFT,PAN_RIGHT,PAN_RIGHT,PAN_LEFT,
                               PAN_LEFT,PAN_RIGHT,PAN_RIGHT,PAN_LEFT,PAN_LEFT,PAN_RIGHT,PAN_RIGHT,PAN_LEFT};

static uchar    insc;
extern int      loadOptions;

void cdecl mcpConvertSample(void *sample,ulong length);

typedef struct {
    char        name[22];
    ushort      length;
    char        finetune;
    char        volume;
    ushort      loopstart;
    ushort      looplength;
} MODinst;

static ushort swapb(ushort a)
{
    return (a>>8) + ((a & 0xFF) << 8);
}

static int loadInstruments(FILE *file, MODULE* module)
{
    int         t,a;
    ushort      b;
    MODinst     MODi;
    INSTRUMENT  *instr;

    insc = (module->type == MOD_15) ? 15 : 31;
    module->instrumentCount = insc;
    if((module->instruments = D_calloc(insc,sizeof(INSTRUMENT)))==NULL) return MERR_MEMORY;
    module->size += insc*sizeof(INSTRUMENT);
    fseek(file,20,SEEK_SET);
    for(a = 1,t = 0; a == 1 && t < insc; t++)
    {
        a = fread(&MODi,sizeof(MODinst),1,file);
        instr = &module->instruments[t];
        instr->type = 0;
        strncpy(instr->name,MODi.name,22);
        instr->name[22] = 0;
        strncpy(instr->filename,MODi.name,12);
        instr->filename[12] = 0;
        instr->sample = NULL;
        instr->rate = 856*BASIC_FREQ/instrRates[MODi.finetune & 0x0F];
        if((instr->volume = MODi.volume) > 64) instr->volume = 64;
        instr->size = swapb(MODi.length)*2;
        instr->loopstart = swapb(MODi.loopstart)*2;
        b = swapb(MODi.looplength)*2;
        if( b < 3 ) b = 0;
        else b += instr->loopstart;
        instr->loopend = b;
        if( instr->loopend > instr->size && instr->loopend != 0 )
            instr->loopend = instr->size;
        if( instr->loopstart > instr->loopend ) instr->loopend = 0;
        if( instr->loopend == 0 ) instr->loopstart = 0;
    }
    return (a != 1) ? MERR_FILE : 0;
}

static int loadPatterns(FILE *file, MODULE* module)
{
    uchar       orders[128];
    ushort      t,i,count = 0,lastPattern = 0;
    PATTERN     *pat;

    memset(patUsed,0,255);
    fseek(file,20+insc*30,SEEK_SET);
    fread(&count,1,1,file);
    fread(orders,1,1,file);
    fread(orders,128,1,file);
    for( t = 0; t < 128; t++) if(lastPattern < orders[t]) lastPattern = orders[t];
    lastPattern++;
    module->patternCount = count;
    module->trackCount = lastPattern*module->channelCount;
    if((module->patterns = D_calloc(count,sizeof(PATTERN)))==NULL) return MERR_MEMORY;
    module->size += count*sizeof(PATTERN);
    for( t = 0; t < count; t++ )
    {
        patUsed[orders[t]] = 1;         // Indicate used
        pat = &module->patterns[t];
        pat->length = 64;
        for( i = 0; i < module->channelCount; i++)
        {
            pat->track[i] = (void*)(orders[t]*module->channelCount+1+i);
        }
    }
    return MERR_NONE;
}

static ushort modNotes[61] = { 1712,1616,1524,1440,1356,1280,1208,1140,1076,1016,960,912,
                        856,808,762,720,678,640,604,570,538,508,480,453,
                        428,404,381,360,339,320,302,285,269,254,240,226,
                        214,202,190,180,170,160,151,143,135,127,120,113,
                        107,101,95,90,85,80,75,71,67,63,60,56,0 };


#define insertNote(a,b) { *(temptrack+pos*3) = tick;\
                        *(temptrack+pos*3+1) = a;\
                        *(temptrack+pos*3+2) = b; pos++; }

#define insertCmd insertNote

static TRACK * MOD2AMF(uchar *buffer, int trk, MODULE *module)
{
    TRACK       *track;
    ushort      i,t,pos,tick,rowadd;
    uchar       note,ins,volume,command,data,curins;
    ushort      nvalue;
    static uchar *temptrack = NULL;

    pos = tick = ins = 0;
    curins = 0xF0;
    buffer += trk*4;
    rowadd = 4*module->channelCount;
    if( temptrack == NULL ) if((temptrack = D_malloc(576)) == NULL) return NULL;
    memset(temptrack,0xFF,576);
    for( t = 0; t < 64; t++ )
    {
        tick = t;
        note = 0xFF;
        nvalue = (buffer[t*rowadd] & 0xF)*256 + buffer[t*rowadd+1];
        if( nvalue != 0 )
            for( i = 0; i < 61; i++)
                if(modNotes[i] <= nvalue)
                {
                    note = i + 36;
                    break;
                }
        command = buffer[t*rowadd+2] & 0xF;
        data = buffer[t*rowadd+3];
        volume = 255;
        if( command == 0xC )
            if((volume = data) > 64) volume = 64;
        ins = ((buffer[t*rowadd+2]>>4) | (buffer[t*rowadd] & 0x10));
        if( ins != 0 )
        {
            ins--;
            if( ins != curins )
            {
                insertCmd(cmdInstr,ins);
                module->instruments[ins].type = 1;   // Indicate used
                if( note == 0xFF )
                {
                    insertNote(127,255);                // Retrig
                }
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
                    case 8 :
                        insertCmd(cmdSync,data);
                        break;
                }
                break;
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
                    free(temptrack);
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
    ushort      t,i,a,c;
    char        *buffer;

    a = c = module->channelCount;
    count = module->trackCount/a;
    if((buffer = D_malloc(2048)) == NULL) return MERR_MEMORY;
    if((module->tracks = D_calloc(count*a+4,sizeof(TRACK  *)))==NULL) return MERR_MEMORY;
    module->size += (count*a+4)*sizeof(TRACK  *);
    fseek(file,20+30*insc+128+2+((insc == 15) ? 0 : 4),SEEK_SET);
    module->tracks[0] = NULL;
    curTrack = 1;
    for( t = 0; t < count; t++)
    {
        if( (loadOptions & LM_IML) && (patUsed[t] == 0) )
        {
            for( i = 0; i < c; i++ )
                module->tracks[curTrack++] = NULL;
            fseek(file,256*c,SEEK_CUR);
            continue;
        }
        if( module->type == MOD_MOD || module->type == MOD_15 )
        {
            a = fread(buffer,256*c,1,file);             // Convert patterns into
            if( a != 0 )
            {
                for( i = 0; i < c; i++ )
                   module->tracks[curTrack++] = MOD2AMF(buffer,i,module);
            }
            else return MERR_FILE;
        }
        else if( c == 8 && module->type == MOD_TREK )
        {
            a = fread(buffer,1024,1,file);              // Convert patterns into
            if( a != 0 )
            {
                module->tracks[curTrack++] = MOD2AMF(buffer,0,module);
                module->tracks[curTrack++] = MOD2AMF(buffer,1,module);
                module->tracks[curTrack++] = MOD2AMF(buffer,2,module);
                module->tracks[curTrack++] = MOD2AMF(buffer,3,module);
            }
            else return MERR_FILE;
            a = fread(buffer,1024,1,file);              // Convert patterns into
            if( a != 0 )
            {
                module->tracks[curTrack++] = MOD2AMF(buffer,0,module);
                module->tracks[curTrack++] = MOD2AMF(buffer,1,module);
                module->tracks[curTrack++] = MOD2AMF(buffer,2,module);
                module->tracks[curTrack++] = MOD2AMF(buffer,3,module);
            }
            else return MERR_FILE;
        }
    }
    D_free(buffer);
    return MERR_NONE;
}

static int loadSamples(FILE *file, MODULE *module)
{
    ushort      t,i,a,b;
    INSTRUMENT  *instr;
    char        temp[32],c;
#ifdef _USE_EMS
    EMSH        handle;
#endif


    fseek(file,20+30*insc+128+2+((insc == 15) ? 0 : 4)+(long)module->trackCount*256L,SEEK_SET);
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
                mcpConvertSample(instr->sample,instr->size);
            }
            else
            {
                a = (instr->size > 65510) ? 65510 : instr->size;
                if((instr->sample = D_malloc(a+16)) == NULL) return MERR_MEMORY;
                module->size += a;
                memset(instr->sample,0,a+16);
                if( fread(instr->sample,a,1,file ) == 0)
                {
                    mcpConvertSample(instr->sample,instr->size);
                    return MERR_CORRUPT;
                }
                if( a < instr->size )
                {
                    fread(temp,instr->size - a,1,file);
                    instr->size = a;
                }
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

int cdecl loadMOD(FILE *file, MODULE *module)
{
    int         a;

    module->tempo = 125;
    module->speed = 6;
    if((a = loadInstruments(file,module)) < MERR_NONE) return a;
    if((a = loadPatterns(file,module)) < MERR_NONE) return a;
    if((a = loadTracks(file,module)) < MERR_NONE) return a;
    if((a = loadSamples(file,module)) < MERR_NONE) return a;
    joinTracks2Patterns(module);
    if( module->type == MOD_15 ) module->type = MOD_MOD;
    return a;
}

MODULE  * cdecl ampLoadMOD(const char  *name, long options)
{
    FILE        *file;
    ulong       l;
    MODULE      *module;
    int         b,c;

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
    fseek(file,1080,SEEK_SET);  // Check if file is MOD
    fread(&l,4,1,file);
    if( l == 0x2E4B2E4D || l == 0x34544C46 || l == 0x214B214D ) // Is it MOD?
    {
        module->type = MOD_MOD; // indicate module type
        fseek(file,0,SEEK_SET);
        fread(module->name,20,1,file);  // Read module name
        module->name[20] = 0;
        module->channelCount = 4;
        memcpy(&module->channelPanning,&order32,4);
    }
    else if( l == 0x38544C46 )          // StarTrekker 8 channel
    {
        module->type = MOD_TREK;        // indicate module type
        fseek(file,0,SEEK_SET);
        fread(module->name,20,1,file);  // Read module name
        module->name[20] = 0;
        module->channelCount = 8;
        memcpy(&module->channelPanning,&order32,8);
    }
    else if( (l & 0xFFFFFF00) == 0x4E484300 ) // FastTracker 1-9 channel
    {
        module->type = MOD_MOD; // indicate module type
        fseek(file,0,SEEK_SET);
        fread(module->name,20,1,file);  // Read module name
        module->name[20] = 0;
	module->channelCount = c = (l & 0xFF)-'0';
        memcpy(&module->channelPanning,&order32,c);
    }
    else if( (l & 0xFFFF0000) == 0x4E480000 )  // FastTracker 10-32 channel
    {
        module->type = MOD_MOD; // indicate module type
        fseek(file,0,SEEK_SET);
        fread(module->name,20,1,file);  // Read module name
        module->name[20] = 0;
        c = (((l & 0xFF00) >> 8)-'0')*10+(l & 0xFF)-'0';
        if( c > 32 ) c = 32;
        module->channelCount = c;
        memcpy(&module->channelPanning,&order32,c);
    }
    else                                // Assume 15-channel MOD
    {
        module->type = MOD_15;
        fseek(file,0,SEEK_SET);
        fread(module->name,20,1,file);  // Read module name
        module->name[20] = 0;
        module->channelCount = 4;
        memcpy(&module->channelPanning,&order32,4);
    }
    if( module->type == MOD_NONE )
    {
        moduleError = MERR_TYPE;
        return NULL;
    }
    b = loadMOD(file,module);
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
