// ************************************************************************
// *
// *    File        : LOADM.C
// *
// *    Description : Module loader for AMP
// *
// *    Copyright (C) 1992,1994 Otto Chrons
// *
// ************************************************************************
/*
        Revision history of LOADM.C

        1.0     16.4.93
                First version. Loads AMF,MOD and STM files.
        2.0     Loads S3M,669,MTM,FAR and uses DSMI's own memory routines

*/

#include <stdio.h>
#include <malloc.h>
#include <string.h>

#include "amp.h"

extern int      loadOptions;

int cdecl loadSTM(FILE *f, MODULE *mod);
int cdecl loadMOD(FILE *f, MODULE *mod);
int cdecl loadAMF(FILE *f, MODULE *mod);
int cdecl loadS3M(FILE *f, MODULE *mod);
int cdecl load669(FILE *f, MODULE *mod);
int cdecl loadMTM(FILE *f, MODULE *mod);
int cdecl loadFAR(FILE *f, MODULE *mod);

static uchar    order32[32] = {PAN_LEFT,PAN_RIGHT,PAN_RIGHT,PAN_LEFT,PAN_LEFT,PAN_RIGHT,PAN_RIGHT,PAN_LEFT,
                               PAN_LEFT,PAN_RIGHT,PAN_RIGHT,PAN_LEFT,PAN_LEFT,PAN_RIGHT,PAN_RIGHT,PAN_LEFT,
                               PAN_LEFT,PAN_RIGHT,PAN_RIGHT,PAN_LEFT,PAN_LEFT,PAN_RIGHT,PAN_RIGHT,PAN_LEFT,
                               PAN_LEFT,PAN_RIGHT,PAN_RIGHT,PAN_LEFT,PAN_LEFT,PAN_RIGHT,PAN_RIGHT,PAN_LEFT};

static int getType(FILE *file, MODULE* module)
{
    int         t = 0,c;
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

MODULE * cdecl ampLoadModule(const char *name, long options)
{
    FILE        *file;
    int         a,b;
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
        return NULL;
    }
    a = getType(file,module);
    b = MERR_TYPE;
    switch(a)
    {
        case MOD_STM :
            b = loadSTM(file,module);
            break;
        case MOD_MOD :
        case MOD_15  :
        case MOD_TREK:
            b = loadMOD(file,module);
            break;
        case MOD_AMF :
            b = loadAMF(file,module);
            break;
        case MOD_S3M :
            b = loadS3M(file,module);
            break;
        case MOD_669 :
            b = load669(file,module);
            break;
        case MOD_MTM :
            b = loadMTM(file,module);
            break;
        case MOD_FAR :
            b = loadFAR(file,module);
            break;
    }
    moduleError = b;
    if( b >= MERR_NONE )
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
