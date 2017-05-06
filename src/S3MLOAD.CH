Comparing files S3MLOAD.C and D:\S3MLOAD.C
***** S3MLOAD.C
                added
        1.11    9.5.93
                Fixed bugs in the loader.. note 254 now turns note off
                'Q' is retrig
*/
***** D:\S3MLOAD.C
                added
*/
*****

***** S3MLOAD.C
static int      lastChan;
static char     order16[16];

static int loadHeader(void)
{
    uchar       orders[256];
    void        *ptr;
    int         a,t,i,count = 0;
    PATTERN     *pat;
***** D:\S3MLOAD.C
static int      lastChan;
static char     order16[16] = {0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15};

static void joinTracks2Patterns(void)
{
    int         t,i;
    PATTERN     *pat;
*****

***** S3MLOAD.C

    rewind(file);
***** D:\S3MLOAD.C

    for( t = 0; t < module->patternCount; t++)
        {
        pat = &(*module->patterns)[t];
        for( i = 0; i < module->channelCount; i++ )
            pat->track[i] = (*module->tracks)[(unsigned)pat->track[i]];
        }
}

static int loadHeader(void)
{
    uchar       orders[256];
    void        *ptr;
    int         a,t,i,count = 0;
    PATTERN     *pat;

    rewind(file);
*****

***** S3MLOAD.C
    module->channelCount = 0;
    for( t = 0; t < 16; t++ )
    {
        if( hdr.channels[t] != 0xFF )
        {
            module->channelCount++;
            module->channelPanning[t] = (hdr.channels[t] > 7) ? PAN_RIGHT : PAN_LEFT;
        }
        else
            module->channelPanning[t] = PAN_MIDDLE;
    }
    if((module->patterns = calloc(count,sizeof(PATTERN))) == NULL) return MERR_MEMORY;
***** D:\S3MLOAD.C
    module->channelCount = 0;
    for( t = 0; t < 32; t++ )
        if( hdr.channels[t] != 0xFF ) module->channelCount++;
    if((module->patterns = calloc(count,sizeof(PATTERN))) == NULL) return MERR_MEMORY;
*****

***** S3MLOAD.C
    module->size += count*sizeof(PATTERN);
    memset(patUsed,0,256);
***** D:\S3MLOAD.C
    module->size += count*sizeof(PATTERN);
    memcpy(&module->channelOrder,order16,16);
    memset(patUsed,0,256);
*****

***** S3MLOAD.C
    for( t = 0; t < count; t++ )
    {
        patUsed[orders[t]] = 1;         // Indicate used
***** D:\S3MLOAD.C
    for( t = 0; t < count; t++ )
        {
        patUsed[orders[t]] = 1;         // Indicate used
*****

***** S3MLOAD.C
        for( i = 0; i < module->channelCount; i++)
        {
            pat->track[i] = (orders[t] == 0xFF) ? 0 : (void*)((int)orders[t]*module->channelCount+1+i);
        }
    }
    return MERR_NONE;
***** D:\S3MLOAD.C
        for( i = 0; i < module->channelCount; i++)
            {
            pat->track[module->channelOrder[i]] = (orders[t] == 0xFF) ? 0 : (void*)((int)orders[t]*module->channelCount+1+i);
            }
        }
    return MERR_NONE;
*****

***** S3MLOAD.C
                            note = buffer[i++];
                            if( note != 254 )
                                note = (((note & 0xF0)>>4)-4)*12 + (note & 0x0F)+60;
                            ins = buffer[i++];
***** D:\S3MLOAD.C
                            note = buffer[i++];
                            note = (((note & 0xF0)>>4)-4)*12 + (note & 0x0F)+60;
                            ins = buffer[i++];
*****

***** S3MLOAD.C
                                insertCmd(cmdBenderTo,data);
                                }
***** D:\S3MLOAD.C
                                insertCmd(cmdBenderTo,data);
                                command = 0;
                                }
*****

***** S3MLOAD.C
                            }
                            if(!(c & 0x40) && note != 0 && note != 254) // no volume
                                insertNote(note,(ins) ? (*module->instruments)[ins-1].volume : 255);
                            if( note == 254 )
                                insertNote(note = 0,0);
                        }
***** D:\S3MLOAD.C
                            }
                            if(!(c & 0x40)) // no volume
                                insertNote(note,(ins) ? (*module->instruments)[ins-1].volume : 255);
                        }
*****

***** S3MLOAD.C
                                    if(data) volsld = data; else data = volsld;
                                    if( (data & 0xF0) == 0xF0 )
                                    {
                                        if( data == 0xF0 ) data = volsld;
                                        insertCmd(cmdFinevol,-(data & 0x0F));
***** D:\S3MLOAD.C
                                    if(data) volsld = data; else data = volsld;
                                    if( data > 0xF0 )
                                    {
                                        insertCmd(cmdFinevol,-(data & 0x0F));
*****

***** S3MLOAD.C
                                    }
                                    else if( (data & 0x0F) == 0x0F)
                                    {
                                        if( data == 0x0F ) data = volsld;
                                        insertCmd(cmdFinevol,data >> 4);
***** D:\S3MLOAD.C
                                    }
                                    else if( (data & 0x0F) == 0x0F && data > 0x0F)
                                    {
                                        insertCmd(cmdFinevol,data >> 4);
*****

***** S3MLOAD.C
                                    break;
                                case 'Q' :
                                    insertCmd(cmdRetrig,data & 0xF);
                                    break;
//                              case 'Z' :
//                                  insertCmd(cmdNoteCut,data);
//                                  break;
                            }
***** D:\S3MLOAD.C
                                    break;
                                default :
//                                  cprintf("Command %c data %X\t",command,(ushort)data);
                                    break;
                            }
*****

***** S3MLOAD.C
                    {
                        i += ((c & 0x20)>>4) + ((c & 0xC0)>>6); // skip note
                    }
***** D:\S3MLOAD.C
                    {
                        if(c & 0x20) i+=2;
                        if(c & 0x40) i++;
                        if(c & 0x80) i+=2;
                    }
*****

***** S3MLOAD.C
        {
            if( instr->loopend != 0 && (a = instr->loopend - instr->loopstart) < CRIT_SIZE )
***** D:\S3MLOAD.C
        {
            module->size += length;
            if( instr->loopend != 0 && (a = instr->loopend - instr->loopstart) < CRIT_SIZE )
*****

***** S3MLOAD.C
                if((sample = instr->sample = farmalloc(length)) == NULL) return MERR_MEMORY;
                module->size += length;
                while( length > 65535 )
***** D:\S3MLOAD.C
                if((sample = instr->sample = farmalloc(length)) == NULL) return MERR_MEMORY;
                while( length > 65535 )
*****

***** S3MLOAD.C
        }
        else
        {
            instr->size = 0;
            instr->sample = NULL;
        }
    }
***** D:\S3MLOAD.C
        }
    }
*****

***** S3MLOAD.C

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
***** D:\S3MLOAD.C

int loadS3M(FILE *f, MODULE *mod)
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
    if(module->channelCount > lastChan+1) module->channelCount = lastChan+1;
    return a;
}
*****

***** S3MLOAD.C

int loadS3M(FILE *f, MODULE *mod)
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
    if(module->channelCount > lastChan+1) module->channelCount = lastChan+1;
    return a;
}

MODULE far *ampLoadS3M(const char far *name, short options)
***** D:\S3MLOAD.C

MODULE far *ampLoadS3M(const char far *name, short options)
*****

***** S3MLOAD.C

#endif
***** D:\S3MLOAD.C
*****


