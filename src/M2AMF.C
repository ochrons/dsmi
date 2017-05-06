// ************************************************************************
// *
// *    File        : M2AMF.C
// *
// *    Description : Converts STM,MOD,S3M,669 and MTM formats into AMF format
// *
// *    Copyright (C) 1992,1994 Otto Chrons
// *
// ************************************************************************


#include <stdio.h>
#include <dir.h>
#include <dos.h>
#include <alloc.h>
#include <stdlib.h>
#include <mem.h>

#pragma hdrstop

#include "amp.h"

#define VERSION "2.7"

typedef struct {
    uchar       type;
    char        name[32],filename[13];
    ulong       number;
    ulong       size;
    ushort      rate;
    uchar       volume;
    ulong       loopstart,loopend;
} AMFINS;

int loadOptions = LM_IML;

int convertSTM(FILE *f, MODULE *m);
int convertMOD(FILE *f, MODULE *m);
int convertS3M(FILE *f, MODULE *m);
int convert669(FILE *f, MODULE *m);
int convertMTM(FILE *f, MODULE *m);
int convertFAR(FILE *f, MODULE *m);

static uchar    order32[32] = {PAN_LEFT,PAN_RIGHT,PAN_RIGHT,PAN_LEFT,PAN_LEFT,PAN_RIGHT,PAN_RIGHT,PAN_LEFT,
                               PAN_LEFT,PAN_RIGHT,PAN_RIGHT,PAN_LEFT,PAN_LEFT,PAN_RIGHT,PAN_RIGHT,PAN_LEFT,
                               PAN_LEFT,PAN_RIGHT,PAN_RIGHT,PAN_LEFT,PAN_LEFT,PAN_RIGHT,PAN_RIGHT,PAN_LEFT,
                               PAN_LEFT,PAN_RIGHT,PAN_RIGHT,PAN_LEFT,PAN_LEFT,PAN_RIGHT,PAN_RIGHT,PAN_LEFT};

void mcpConvertSample(void *sample, ulong length)
{
    _ES = FP_SEG(sample);
    _SI = FP_OFF(sample);
    asm {
        mov     cx,[word ptr length]
        shr     cx,1
        jnc     l1
        xor     [byte ptr es:si],80h
        inc     si
    }
l1:
    asm {
        xor     [word ptr es:si],8080h
        inc     si
        inc     si
        loop    l1
    }
}

static int getType(FILE *file, MODULE* module)
{
    int         t = 0, c;
    long        l = 0;

    module->type = MOD_NONE;
    fseek(file,0,SEEK_SET);
    fread(&l,4,1,file);
    if( l == 0xFE524146 )                       // Is it FAR
    {
        module->type = MOD_FAR;
        rewind(file);
        return module->type;
    }
    if( (l & 0x00FFFFFF) == 0x004D544D )        // Is it MTM
    {
        module->type = MOD_MTM;
        rewind(file);
        return module->type;
    }
    if( (l & 0x00FFFFFF) == 0x00464D41 )        // Is it AMF
        {
        module->type = MOD_AMF;
        fread(module->name,20,1,file);
        module->name[20] = 0;
        if( l == 0x08464D41 || l == 0x01464D41 )
            {
            module->channelCount = 4;
            memcpy(&module->channelPanning,&order32,4);
            }
        }
    else
    {
        fseek(file,0x2C,SEEK_SET);
        fread(&l,4,1,file);
	if( l == 0x4D524353 ) // 'SCRM'
        {
            module->type = MOD_S3M;
            rewind(file);
            fread(module->name,28,1,file);
            module->name[28] = 0;
        }
        else
        {
            rewind(file);
            fread(&t,2,1,file);
            if( t == 0x6669 )
            {
                module->type = MOD_669;
                fseek(file,2,SEEK_SET);
                fread(module->name,32,1,file);
                module->name[31] = 0;
            }
            else
            {
                fseek(file,28,SEEK_SET);
                fread(&t,2,1,file);
                if( t == 0x021A )                       // is it STM?
                {
                    module->type = MOD_STM;             // indicate type
                    fseek(file,0,SEEK_SET);
                    fread(module->name,20,1,file);      // Read module name
                    module->name[20] = 0;
                    module->channelCount = 4;
                    memcpy(&module->channelPanning,&order32,4);
                }
                else
                {
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
                    else if( l == 0x38544C46 )
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
                }
            }
        }
    }
    return module->type;
}

int createAMF(MODULE *module, char *oldname)
{
    char        name[MAXFILE],ext[MAXEXT],dir[MAXDIR],drive[MAXDRIVE];
    char        newname[MAXPATH];
    void        *(*inslist)[];
    ushort      (*sample)[];
    void        *(*trcklist)[];
    void        *track;
    ulong       fpos;
    int         insPtr,trckPtr,a,t,i,isTrack;
    FILE        *amf;
    AMFINS      ins;
    static TRACK        nullTrack = {0,0};

    fnsplit(oldname,drive,dir,name,ext);
    fnmerge(newname,drive,dir,name,".AMF");

    if( (amf = fopen(newname,"wb")) == NULL ) return -1;
    setvbuf(amf,NULL,_IOFBF,4096);      // Buffered I/O

    if( fwrite("AMF\xE",4,1,amf) != 1)
        {
        printf("Error writing to file %s\n",newname);
        fclose(amf);
        remove(newname);
        return -1;
        }
    fwrite(module->name,32,1,amf);      // write module's name
    fwrite(&module->instrumentCount,1,1,amf);
    fwrite(&module->patternCount,1,1,amf);
    fwrite(&module->trackCount,2,1,amf);
    fwrite(&module->channelCount,1,1,amf);
    fwrite(&module->channelPanning,32,1,amf);
    fwrite(&module->tempo,1,1,amf);
    fwrite(&module->speed,1,1,amf);
    for(t = 0; t < module->patternCount; t++)
        {
        fwrite(&(module->patterns[t].length),2,1,amf);
        for( i = 0; i < module->channelCount; i++)
            fwrite(&(module->patterns[t].track[i]),2,1,amf);
        }
    inslist = calloc(module->instrumentCount,sizeof(void far *));
    sample = calloc(module->instrumentCount,sizeof(ushort));
    insPtr = trckPtr = 0;
    for( t = 0; t < module->instrumentCount; t++ )
        {
        memcpy(&ins,&module->instruments[t],sizeof(INSTRUMENT));
        for( i = 0; i < insPtr; i++ )
            {
            if( (void far *)ins.number == (*inslist)[i] )
                {
                ins.number = i+1;
                break;
                }
            }
        if( ins.number > 65536 )
            {
            (*inslist)[insPtr] = (void*)ins.number;
            (*sample)[insPtr] = ins.size;
            ins.number = ++insPtr;
            }
        fwrite(&ins,sizeof(AMFINS),1,amf);
        }
    trcklist = calloc(module->trackCount,sizeof(void far *));
    for( t = 1; t < (module->trackCount+1); t++ )
        {
        track = module->tracks[t];
        isTrack = 0;
        for( i = 0; i < trckPtr; i++ )
            {
            if( track == (*trcklist)[i] )
                {
                isTrack = 1;
                a = i+1;
                break;
                }
            }
        if( !isTrack )
            {
            (*trcklist)[trckPtr] = track;
            trckPtr++;
            a = trckPtr;
            }
        fwrite(&a,2,1,amf);
        }
    for( t = 0; t < trckPtr; t++ )
        {
        if( (*trcklist)[t] == NULL) fwrite(&nullTrack,3,1,amf);
        else fwrite((*trcklist)[t],((TRACK*)(*trcklist)[t])->size*3+3,1,amf);
        }
    for( t = 0; t < insPtr; t++ )
        {
        fpos = ftell(amf);
        a = fwrite((*inslist)[t],(*sample)[t],1,amf);
        }
    if( a == 0 )
        {
        printf("Error writing to file %s\n",newname);
        fclose(amf);
        remove(newname);
        return -1;
        }
    free(inslist);
    free(trcklist);
    fclose(amf);
    return 0;
}

void main(int argc, char *argv[])
{
    FILE        *file;
    MODULE      *module;
    int         a,tempo = 0;

    puts("Module converter version "VERSION);
    puts("Copyright (C) 1992,1994 Otto Chrons. All Rights Reserved.\n");
    if( argc < 2 )
        {
        printf("%s <modulename> [-e]\n",argv[0]);
        puts("\nwhere '-e' specifies old tempos.");
        exit(1);
        }
    if( (file = fopen(argv[1],"rb")) == NULL )
        {
        printf("Couldn't open file %s\n",argv[1]);
        exit(1);
        }
    if( (module = (MODULE*)malloc(sizeof(MODULE))) == NULL )
        {
        puts("Out of memory");
        exit(1);
        }
    memset(module,0,sizeof(MODULE));
    if( getType(file,module) == MOD_NONE )
        {
        puts("Invalid module type");
        puts("Use only valid formats");
        exit(1);
        }
    if( argc > 2 && argv[2][0] == '-' && toupper(argv[2][1]) == 'E') loadOptions |= LM_OLDTEMPO;
    printf("Loading %s . . .",argv[1]);
    switch(module->type)
    {
        case MOD_STM :
            a = convertSTM(file,module);
            break;
        case MOD_MOD :
        case MOD_15  :
        case MOD_TREK:
            a = convertMOD(file,module);
            break;
        case MOD_S3M :
            a = convertS3M(file,module);
            break;
        case MOD_669 :
            a = convert669(file,module);
            break;
        case MOD_MTM :
            a = convertMTM(file,module);
            break;
        case MOD_FAR :
            a = convertFAR(file,module);
            break;
    }
    puts("");
    if( a != 0 )
        {
        puts("Error in module file or out of memory");
        exit(1);
        }
    printf("Converting to AMF . . .");
    if( createAMF(module,argv[1]) )
        {
        puts("\nUnable to create AMF file");
        exit(1);
        }
    puts("\nFile conversion successful");
}

