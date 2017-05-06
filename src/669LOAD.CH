Comparing files 669LOAD.C and D:\669LOAD.C
***** 669LOAD.C
static int      lastChan;
static uchar    order8[8] = {PAN_LEFT,PAN_RIGHT,PAN_LEFT,PAN_RIGHT,PAN_LEFT,PAN_RIGHT,PAN_LEFT,PAN_RIGHT};

static int loadHeader(void)
{
    int         t,count,i;
    PATTERN     *pat;
***** D:\669LOAD.C
static int      lastChan;
static char     order8[8] = {0,1,2,3,4,5,6,7};

static void joinTracks2Patterns(void)
{
    int         t,i;
    PATTERN     *pat;
*****

***** 669LOAD.C

    rewind(file);
***** D:\669LOAD.C

    for( t = 0; t < module->patternCount; t++)
        {
        pat = &(*module->patterns)[t];
        for( i = 0; i < module->channelCount; i++ )
            pat->track[i] = (*module->tracks)[(unsigned)pat->track[i]];
        }
}

static int loadHeader(void)
{
    int         t,count,i;
    PATTERN     *pat;

    rewind(file);
*****

***** 669LOAD.C
    module->channelCount = 8;
    memcpy(&module->channelPanning,order8,8);
    module->tempo = 80;
***** D:\669LOAD.C
    module->channelCount = 8;
    memcpy(&module->channelOrder,order8,8);
    module->tempo = 80;
*****

***** 669LOAD.C
            {
            pat->track[i] = (hdr.orders[t] == 0xFF) ? 0 : (void*)((int)hdr.orders[t]*8+1+i);
            }
***** D:\669LOAD.C
            {
            pat->track[module->channelOrder[i]] = (hdr.orders[t] == 0xFF) ? 0 : (void*)((int)hdr.orders[t]*8+1+i);
            }
*****

***** 669LOAD.C
        }
    return MERR_NONE;
***** D:\669LOAD.C
        }

    return MERR_NONE;
*****

***** 669LOAD.C
        strcpy(instr->name,ins.name);
        instr->name[13] = 0;
        strcpy(instr->filename,ins.name);
        instr->filename[13] = 0;
        instr->rate = BASIC_FREQ;
***** D:\669LOAD.C
        strcpy(instr->name,ins.name);
        strcpy(instr->filename,ins.name);
        instr->rate = BASIC_FREQ;
*****

***** 669LOAD.C
            {
                if( tick == 0 && j == 0 )
                {
                    insertCmd(cmdTempo,tempo);
                    insertCmd(cmdExtTempo,80);
                }
                if( tick == hdr.breaks[t] && j == 0 && tick != 63) insertCmd(cmdBreak,0);
***** D:\669LOAD.C
            {
                if( tick == 0 && j == 0 ) insertCmd(cmdTempo,tempo);
                if( tick == hdr.breaks[t] && j == 0 && tick != 63) insertCmd(cmdBreak,0);
*****

***** 669LOAD.C
        length = instr->size;
        if( length > 0 && instr->type == 1 )
        {
            if( instr->loopend != 0 && (a = instr->loopend - instr->loopstart) < CRIT_SIZE )
***** D:\669LOAD.C
        length = instr->size;
        if( length > 0 )
        {
            if( instr->type == 1 ) module->size += length;
            if( instr->loopend != 0 && (a = instr->loopend - instr->loopstart) < CRIT_SIZE )
*****

***** 669LOAD.C
                }
                module->size += length;
                if((sample = instr->sample = farmalloc(length)) == NULL) return MERR_MEMORY;
***** D:\669LOAD.C
                }
                if((sample = instr->sample = farmalloc(length)) == NULL) return MERR_MEMORY;
*****

***** 669LOAD.C
        }
        else
        {
            fseek(file,instr->size,SEEK_CUR);
            instr->sample = NULL;
            instr->size = 0;
        }
    }
***** D:\669LOAD.C
        }
    }
*****

***** 669LOAD.C

#ifndef CONVERSION

static void joinTracks2Patterns(void)
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
***** D:\669LOAD.C

int load669(FILE *f, MODULE *mod)
{
    int         a;

    file = f; module = mod;
    module->size = 0;
    lastChan = 0;
    if(( a = loadHeader()) < MERR_NONE ) return a;
    if(( a = loadInstruments()) < MERR_NONE ) return a;
    if(( a = loadPatterns()) < MERR_NONE ) return a;
    if(( a = loadSamples()) < MERR_NONE ) return a;
    joinTracks2Patterns();
    return a;
}
*****

***** 669LOAD.C

int load669(FILE *f, MODULE *mod)
{
    int         a;

    file = f; module = mod;
    module->size = 0;
    lastChan = 0;
    if(( a = loadHeader()) < MERR_NONE ) return a;
    if(( a = loadInstruments()) < MERR_NONE ) return a;
    if(( a = loadPatterns()) < MERR_NONE ) return a;
    if(( a = loadSamples()) < MERR_NONE ) return a;
    joinTracks2Patterns();
    return a;
}

MODULE far *ampLoad669(const char far *name, short options)
***** D:\669LOAD.C

MODULE far *ampLoad669(const char far *name, short options)
*****

***** 669LOAD.C
    module->name[31] = 0;
    moduleError = load669(file,module);
    if( moduleError == MERR_NONE )
***** D:\669LOAD.C
    module->name[31] = 0;
    moduleError = loadS3M(file,module);
    if( moduleError == MERR_NONE )
*****

***** 669LOAD.C

#endif
***** D:\669LOAD.C
*****


