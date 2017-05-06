// ************************************************************************
// *
// *    File        : S3MLOAD.C
// *
// *    Description : Module loader for Scream Tracker 3.0 files
// *
// *    Copyright (C) 1993 Otto Chrons
// *
// ************************************************************************
/*
        Revision history of S3MLOAD.C

        1.0     4.5.93
                First version.
        1.1     7.5.93
                Commands are now more accurate. Special ExtraFineBender
                added
        1.11    9.5.93
                Fixed bugs in the loader.. note 254 now turns note off
                'Q' is retrig
*/


#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <dos.h>

#include "amp.h"

#ifdef _USE_EMS
#include "emhm.h"
#endif

typedef struct {
    char        name[28];
    uchar       end,type,d1[2];
    ushort      orders,ins,pats,flags,cwt,ffv;
    char        magic[4];
    uchar       mv,is,it,mm;
    char        d2[12];
    uchar       channels[32];
} S3Mheader;

extern int      loadOptions;

void cdecl mcpConvertSample(void *sample,ulong length);

static uchar    *patUsed;
static MODULE   *module;
static FILE     *file;
static ushort   *insPtr;
static ushort   *patPtr;
static S3Mheader hdr;
static int      lastChan;

static int loadHeader(void)
{
    uchar       *orders;
    int         a,t,i,count = 0;
    PATTERN     *pat;

    orders = D_malloc(256);
    rewind(file);
    fread(&hdr,sizeof(hdr),1,file);
    module->tempo = hdr.it;
    module->speed = hdr.is;
    module->instrumentCount = hdr.ins;
    module->channelCount = 0;
    for( t = 0; t < 16; t++ )
    {
        if( hdr.channels[t] != 0xFF )
        {
            module->channelCount++;
            a = hdr.channels[t];
            module->channelPanning[t] = (a > 7) ? PAN_RIGHT : PAN_LEFT;
        }
        else
            module->channelPanning[t] = PAN_MIDDLE;
    }
    fread(orders,hdr.orders,1,file);
    fread(insPtr,hdr.ins,2,file);
    fread(patPtr,hdr.pats,2,file);
    for( t = i = 0; t < hdr.orders; t++ )
    {
        if( orders[t] >= 0xFE ) continue;   // Skip this pattern
        orders[i++] = orders[t];
    }
    count = module->patternCount = i;
    if((module->patterns = calloc(count,sizeof(PATTERN))) == NULL)
    {
        D_free(orders);
        return MERR_MEMORY;
    }
    module->size += count*sizeof(PATTERN);
    memset(patUsed,0,256);
    for( t = 0; t < count; t++ )
    {
        patUsed[orders[t]] = 1;         // Indicate used
        pat = &module->patterns[t];
        pat->length = 64;
        for( i = 0; i < module->channelCount; i++)
        {
            pat->track[i] = (void*)((int)orders[t]*module->channelCount+1+i);
        }
    }
    D_free(orders);
    return MERR_NONE;
}

typedef struct {
    uchar       type;
    char        dosname[13];
    ushort      memseg;
    ulong       length,loopstart,loopend;
    uchar       volume,dsk,pack,flag;
    ulong       c2spd,d1;
    ushort      d2,d3;
    ulong       d4;
    char        name[28];
    ulong       magic;
} S3Minstr;

static int loadInstruments(void)
{
    ushort      t;
    INSTRUMENT  *instr;
    S3Minstr    sins;

    module->instrumentCount = hdr.ins;
    if((module->instruments = calloc(hdr.ins,sizeof(INSTRUMENT)))==NULL) return MERR_MEMORY;
    module->size += hdr.ins*sizeof(INSTRUMENT);
    for( t = 0; t < hdr.ins; t++)
    {
        fseek(file,(long)insPtr[t]*16,SEEK_SET);
        fread(&sins,sizeof(sins),1,file);
        if( sins.magic != 0x53524353 && sins.magic != 0 ) return MERR_TYPE;
        instr = &module->instruments[t];
        instr->type = 0;
        strcpy(instr->name,sins.name);
        strcpy(instr->filename,sins.dosname);
        instr->rate = sins.c2spd;
        instr->volume = sins.volume;
        instr->size = sins.length;
        instr->loopstart = sins.loopstart;
        instr->loopend = (sins.loopend > 0) ? sins.loopend : 0;
        if( (sins.flag & 1) == 0) instr->loopstart = instr->loopend = 0;
        instr->sample = (void*)sins.memseg;
    }
    return MERR_NONE;
}

#define insertNote(a,b) { *(temptrack+pos*3) = tick;\
                        *(temptrack+pos*3+1) = a;\
                        *(temptrack+pos*3+2) = b; pos++; }

#define insertCmd insertNote

static int loadPatterns(void)
{
    int         pos,row,t,j,a,i,tick,curTrack = 1;
    static int  bufSize = 1024;
    static uchar *buffer = NULL;
    uchar       c;
    ushort      patSize;
    uchar       note,ins,volume,command,data,curins,olddata;
    ushort      count,volsld;
    TRACK       *track;
    static uchar *temptrack;

    count = hdr.pats*module->channelCount;
    module->trackCount = count;
    if((module->tracks = calloc(count+4,sizeof(TRACK *)))==NULL) return MERR_MEMORY;
    module->tracks[0] = NULL;
    module->size += (count+4)*sizeof(TRACK *);
    if(temptrack == NULL) if((temptrack = D_malloc(1200)) == NULL) return MERR_MEMORY;
    if( buffer == NULL ) buffer = malloc(bufSize);
    for( t = 0; t < hdr.pats; t++ )
    {
        if(!patUsed[t])
        {
            for( j = 0; j < module->channelCount; j++ )
                module->tracks[curTrack++] = NULL;
            continue;
        }
        fseek(file,(long)patPtr[t]*16l,SEEK_SET);
        fread(&patSize,2,1,file);
        if( patSize > bufSize )
        {
            bufSize = patSize;
            if((buffer = realloc(buffer,bufSize)) == NULL) return MERR_MEMORY;
        }
        if(!fread(buffer,patSize,1,file)) return MERR_FILE;
        for( j = 0; j < module->channelCount; j++ )
        {
            memset(temptrack,0xFF,1200);
            pos = ins = 0;
            curins = 0xF0;
            i = row = 0;
            volsld = 0;
            olddata = 0;
            while( row < 64 )
            {
                c = buffer[i++];
                if( pos*3 > 1200 )
                    exit(-1);
                tick = row;
                if( c == 0 ) row++;
                else
                {
                    a = c & 0x1F;
                    if( a > lastChan) lastChan = a;
                    if((c & 0x1F) == j)
                    {
                        note = ins = volume = command = data = 0;
                        if(c & 0x20)
                        {
                            note = buffer[i++];
                            if( note != 254 && note != 0 && note != 255 )
                                note = (note>>4)*12 + (note & 0x0F)+12;
                            ins = buffer[i++];
                        }
                        if(c & 0x40) volume = buffer[i++];  // Volume
                        if(c & 0x80)
                        {
                            command = buffer[i++]+'A'-1;
                            data = buffer[i++];
                            if( data == 0 ) data = olddata; else olddata = data;
                            if( command == 'G' )
                                {
                                if( data > 127 ) data = 127;
                                insertCmd(cmdBenderTo,data);
                                }
                        }
                        if( command == 'S' && (data >> 4) == 0xD && (data & 0xF) != 0 && note != 0xFF )
                        {
                            insertCmd(cmdNoteDelay, data & 0xF);
                        }
                        if(c & 0x20)            // note & ins
                        {
                            if( ins != 0 && ins != curins && ins <= hdr.ins)
                            {
                                curins = ins;
                                insertCmd(cmdInstr,ins-1);
                                module->instruments[ins-1].type = 1; // Indicate used
                            }
                            if(!(c & 0x40) && note != 0 && note != 254) // no volume
                                insertNote(note,(ins) ? module->instruments[ins-1].volume : 255);
                            if( note == 255 )
                            {
                                if( ins < module->instrumentCount && module->instruments[ins-1].size != 0 )
                                    insertCmd(cmdVolumeAbs,module->instruments[ins-1].volume);
                            }
                            if( note == 254 )
                                insertNote(note = 0,0);
                        }
                        if(c & 0x40)
                        {
                            if( note == 0 ) // no note
                            {
                                insertCmd(cmdVolumeAbs,volume);
                            }
                            else insertNote(note,volume);
                        }
                        if(c & 0x80)
                        {
                            switch(command)
                            {
                                case 'A' :
                                    insertCmd(cmdTempo,data);
                                    break;
                                case 'B' :
                                    insertCmd(cmdGoto,data);
                                    break;
                                case 'C' :
                                    insertCmd(cmdBreak,0);
                                    break;
                                case 'D' :
//                                    if(data) volsld = data; else data = volsld;
                                    if( (data & 0xF0) == 0xF0 )
                                    {
                                        if( data == 0xF0 )
                                        {
                                            insertCmd(cmdVolume,0xF);
                                        } else
                                        {
                                            insertCmd(cmdFinevol,-(data & 0x0F));
                                        }
                                    }
                                    else if( (data & 0x0F) == 0x0F)
                                    {
                                        if( data == 0x0F )
                                        {
                                            insertCmd(cmdVolume,(unsigned char)(-0xF));
                                        } else
                                        {
                                            insertCmd(cmdFinevol,data >> 4);
                                        }
                                    }
                                    else
                                    {
                                        if( data & 0x0F ) data = -(data & 0x0F);
                                        else data >>= 4;
                                        insertCmd(cmdVolume,data);
                                    }
                                    break;
                                case 'E' :
//                                  if( data == 0 ) data = oldtune; else oldtune = data;
                                    if( (data & 0xF0) == 0xF0 )
                                    {
                                        insertCmd(cmdFinetune,data & 0x0F);
                                    }
                                    else
                                    if( (data & 0xE0) == 0xE0 )
                                    {
                                        insertCmd(cmdExtraFineBender,(data & 0x0F)*4);
                                    }
                                    else
                                    {
                                        if( data > 127 ) data = 127;
                                        if( data == 0 )
                                        {
                                            insertCmd(cmdBender,0);
                                        }
                                        else
                                        {
                                            insertCmd(cmdBender,data);
                                        }
                                    }
                                    break;
                                case 'F' :
//                                  if( data == 0 ) data = oldtune; else oldtune = data;
                                    if( (data & 0xF0) == 0xF0 )
                                    {
                                        insertCmd(cmdFinetune,-(data & 0x0F));
                                    }
                                    else
                                    if( (data & 0xE0) == 0xE0 )
                                    {
                                        insertCmd(cmdExtraFineBender,-(data & 0x0F)*4);
                                    }
                                    else
                                    {
                                        if( data > 127 ) data = 127;
                                        if( data == 0 )
                                        {
                                            insertCmd(cmdBender,(unsigned char)(-128));
                                        }
                                        else
                                        {
                                            insertCmd(cmdBender,-data);
                                        }
                                    }
                                    break;
                                case 'H' :
                                    insertCmd(cmdVibrato,data);
                                    break;
                                case 'I' :
                                case 'R' :
                                    insertCmd(cmdTremolo,data);
                                    break;
                                case 'J' :
                                    insertCmd(cmdArpeggio,data);
                                    break;
                                case 'L' :
                                    if( data >= 16 ) data >>= 4;
                                    else data = -data;
                                    if(data) volsld = data;
                                    else data = volsld;
                                    insertCmd(cmdToneVol,data);
                                    break;
                                case 'K' :
                                    if( data >= 16 ) data >>= 4;
                                    else data = -data;
                                    if(data) volsld = data;
                                    else data = volsld;
                                    insertCmd(cmdVibrVol,data);
                                    break;
                                case 'T' :
                                    insertCmd(cmdExtTempo,data);
                                    break;
                                case 'O' :
                                    insertCmd(cmdOffset,data);
                                    break;
                                case 'Q' :
                                    insertCmd(cmdRetrig,data & 0xF);
                                    break;
                                case 'Z' :
                                    insertCmd(cmdSync,data);
                                    break;
                                case 'X' :
                                    insertCmd(cmdPan,data-64);
                                    break;
                                case 'G' :
                                    break;
                                case 'S' :
                                    command = data >> 4;
                                    data &= 0x0F;
                                    switch(command)
                                    {
                                        case 0x8 :
                                            insertCmd(cmdPan,(data == 7 || data == 8 ) ? 0 : (data < 7) ? (data-7)*9 : (data-8)*9);
                                            break;
                                        case 0xC :
                                            insertCmd(cmdNoteCut,data);
                                            break;
                                        case 0xD :
                                            insertCmd(cmdNoteDelay,data);
                                            break;
                                        default :
//                                          cprintf("Cmd S%X data %d ",command,data);
                                            break;
                                    }
                                default :
//                                  cprintf("Cmd %d data %d ",command,data);
                                    break;
                            }
                        }
                    }
                    else
                    {
                        i += ((c & 0x20)>>4) + ((c & 0xC0)>>6); // skip note
                    }
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

    for( t = 0; t < hdr.ins; t++)
    {
        instr = &module->instruments[t];
        fseek(file,(long)instr->sample*16l,SEEK_SET);
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
                if((sample = instr->sample = D_malloc(length+16)) == NULL) return MERR_MEMORY;
                module->size += length;
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
            instr->size = 0;
            instr->sample = NULL;
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

int cdecl loadS3M(FILE *f, MODULE *mod)
{
    int         a;

    patUsed = D_malloc(256);
    insPtr = D_malloc(512);
    patPtr = D_malloc(512);
    file = f; module = mod;
    module->size = 0;
    lastChan = 0;
    if(( a = loadHeader()) < MERR_NONE ) goto done;
    if(( a = loadInstruments()) < MERR_NONE ) goto done;
    if(( a = loadPatterns()) < MERR_NONE ) goto done;
    if(( a = loadSamples()) < MERR_NONE ) goto done;
    joinTracks2Patterns();
    if(module->channelCount > lastChan+1) module->channelCount = lastChan+1;
done:
    D_free(patUsed);
    D_free(insPtr);
    D_free(patPtr);
    return a;
}

MODULE * cdecl ampLoadS3M(const char *name, long options)
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
    fseek(file,0x2C,SEEK_SET);
    fread(&l,4,1,file);
    if( l != 0x4D524353 ) // 'SCRM'
    {
        moduleError = MERR_TYPE;
        D_free(module);
        return NULL;
    }
    rewind(file);
    fread(module->name,28,1,file);
    module->name[28] = 0;
    moduleError = loadS3M(file,module);
    if( moduleError == MERR_NONE )
    {
        module->type = MOD_S3M;
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
