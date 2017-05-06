// ************************************************************************
// *
// *    File        : DMPMT.C
// *
// *    Description : Dual Module Player for MultiTasking environments
// *
// *    Copyright (C) 1992 Otto Chrons
// *
// ************************************************************************

#include <conio.h>
#include <io.h>
#include <fcntl.h>
#include <dos.h>
#include <stdio.h>
#include <dir.h>
#include <stdlib.h>
#include <string.h>

#pragma hdrstop

#include "mcp.h"
#include "amp.h"
#include "sdi_sb.h"
#include "sdi_sb16.h"
#include "sdi_pas.h"
#include "detsb.h"
#include "detpas.h"
#include "mixer.h"
#include "dvcalls.h"
#include "ualloc.h"

int DMPMT_VERSION = 0;
#define MAX_MODS 256

int getCPUType();

long            startTime;
long far        *keyStatus = (long far *)0x00400017;
uchar           lines, oldMixer, multitasking = 0;

int             fileCount = 0;
char            *fileList[MAX_MODS];
MODULE          *module;
char            instrUsed[31];
char            *helpText[] = {
"",
"ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ",
"Command line options :                   ³ Keys :",
"ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ",
"  -?, -h     This help screen            ³ Scrl Lock Pause/resume module     ",
"  -o         Scramble module order       ³                                   ",
"  -ix        Use interrupt x             ³ N         Next module             ",
"  -pxxx      Use port xxx                ³ S         Stereo on/off (SBPro)   ",
"  -sxxxx     Sampling rate               ³ B         Break to next pattern   ",
"  -dx        DMA channel                 ³                                   ",
"  -cx        Specify sound card          ³ H         Show help screen        ",
"             1 = SB, 2 = SB Pro, 3 = PAS+³                                   ",
"             4 = PAS16, 5 = SB16         ³                                   ",
"  -q         Quality mode                ³                                   ",
"  -u         Don't use UMB               ³                                   ",
"  -m         Mono mode (PAS,SB16)        ³                                   ",
"  -l         Suppress looping            ³ ESC       Exit                    ",
"ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ",
"",0 },
                *contactText[] = {
"",
"Thank you for using DMP for Multitaskers!",
"",
"To contact the author you can either send NetMail to",
"2:222/348.10 (FidoNet) or to",
"Internet account c142092@cc.tut.fi",
"or write to",
"",
"Otto Chrons",
"Pyydyspolku 5",
"36200 KANGASALA",
"FINLAND",
"",
"To obtain the newest version of DMP, call these fine BBSs:",
"Express          +358-31-236069",
"R.A. LAW         +358-37-49007",
"Moonlight shadow +358-0-3882575",
"",
"Through Internet FTP-service:",
"ftp.uwp.edu",
"",
"Read DMPMT.DOC for information on DSMI Programming Interface!!"
"",0 };

void beginCritical()
{
    if( multitasking == 1 )
        {
        dvBeginCritical();
        }
    else
        {
        asm     mov     ax,1681h
        asm     int     2Fh
        }
}

void endCritical()
{
    if( multitasking == 1 )
        {
        dvEndCritical();
        }
    else
        {
        asm     mov     ax,1682h
        asm     int     2Fh
        }
}

void releaseSlice()
{
    if( multitasking == 1 )
        {
        dvPause();
        }
}

int getWindowsVersion()
{
    uchar       RAL;
    ushort      RAX;

    asm mov     ax,1600h
    asm int     2Fh
    asm mov     RAX,ax
    asm mov     RAL,al
    switch( RAL )
        {
        case 0x00 :
        case 0x80 :
            break;
        case 0x01 :
        case 0xFF :
            return 2;
        default :
            return RAX;
        }
    if(getenv("windir") || getenv("WINDIR")) return 1;
    return 0;
}

void resetMixer(void)
{
    setMixer( MIX_STEREO, oldMixer );
}

void showHelp()
{
    int         t;

    for( t = 0; helpText[t] != 0; t++)
        puts(helpText[t]);
}

void drawContact()
{
    int         t;

    for( t = 0; contactText[t] != 0; t++)
      puts(contactText[t]);
}

void errorexit(const char *str)
{
    drawContact();
    puts(str);
    exit(1);
}

int loader(char *name)
{
    char        *strptr, str[80], ch;

    if((module = ampLoadModule(name,LM_IML)) == NULL)
        {
        switch(moduleError)
            {
            case -1 :
                strptr = "Not enough memory to load %s\n";
                break;
            case -2 :
                strptr = "File error loading %s\n";
                break;
            case -3 :
                strptr = "%s is not a valid module file\n";
                break;
            default :
                strptr = "Couldn't load module %s\n";
                break;
            }
        printf(strptr,name);

        puts("Press <ENTER> to continue, <ESC> to quit");
        do {
            ch = getch();
        } while( ch != 13 && ch != 27 );
        if( ch == 27 ) errorexit("");
        }
    if( moduleError == MERR_CORRUPT )
        {
        printf("Module is corrupted. Play anyway? ");
        do {
            ch = toupper(getch());
        } while( ch != 13 && ch != 27 && ch != 'Y' && ch != 'N');
        puts("");
        if( ch == 27 ) errorexit("Corrupted module");
        if( ch != 'N' ) moduleError = MERR_NONE;
        }
    return moduleError;
}

int addExtension(char *name)
{
    struct ffblk ff;
    char        drive[MAXDRIVE],path[MAXDIR],file[MAXFILE],ext[MAXEXT];
    char        fName[MAXPATH],buffer[MAXPATH];
    int         a;

    strcpy(fName,name);
    a = findfirst(fName,&ff,0);
    if( a != 0 )
        {
        a = fnsplit(fName,drive,path,file,ext);
        if( (a & EXTENSION) == 0 )
            {
            fnmerge(fName,drive,path,file,".AMF");
            if( findfirst(fName,&ff,0) != 0)
                {
                fnmerge(fName,drive,path,file,".MOD");
                if( findfirst(fName,&ff,0) != 0)
                    {
                    fnmerge(fName,drive,path,file,".STM");
                    if( findfirst(fName,&ff,0) != 0)
                        {
                        fnmerge(fName,drive,path,file,".NST");
                        if( findfirst(fName,&ff,0) != 0) return -1;
                        }
                    }
                }
            }
        else return -1;
        }
    _fullpath(buffer,fName,255);
    strcpy(name,buffer);
    return 0;
}

void appendFileList(const char* name)
{
    char        drive[MAXDRIVE],path[MAXDIR],file[MAXFILE],ext[MAXEXT];
    char        fileName[255],*strptr;
    struct ffblk ffblk;
    int         error;

    if( strchr( name,'*' ) != NULL || strchr( name,'?' ) != NULL )
        {
        fnsplit( name,drive,path,file,ext );
        error = findfirst( name,&ffblk,0 );
        while( !error )
            {
            fnsplit( ffblk.ff_name,NULL,NULL,file,ext );
            fnmerge( fileName,drive,path,file,ext );
            addExtension( fileName );
            fileList[fileCount] = (char*)malloc( strlen(fileName)+1 );
            strupr( fileName );
            strcpy( fileList[fileCount],fileName );
            fileCount++;
            if( fileCount >= MAX_MODS ) errorexit("Too many modules");
            error = findnext(&ffblk);
            }
        }
    else
        {
        strcpy(fileName,name);
        if(addExtension(fileName) == 0)
            {
            fileList[fileCount] = (char*)malloc(strlen(fileName)+1);
            strupr( fileName );
            strcpy(fileList[fileCount],fileName);
            fileCount++;
            if( fileCount >= MAX_MODS ) errorexit("Too many modules");
            }
        }
}

void quit()
{
    drawContact();
    exit(0);
}

void traceOn(void)
{
    asm {
        mov     dx,3C0h
        mov     al,31h
        out     dx,al
        mov     al,1
        out     dx,al
        }
}

void traceOff(void)
{
    asm {
        mov     dx,3C0h
        mov     al,31h
        out     dx,al
        sub     al,al
        out     dx,al
        }
}


void waitRetrace()
{
    asm mov     dx,3DAh
testr:
    asm in      al,dx
    asm test    al,08h
    asm jz      testr                   // wait retrace
}

void dummy(void) {}

unsigned timerLatch(void)
{
    asm cli
    asm mov     al,0
    asm out     43h,al
    dummy();
    asm in      al,40h
    asm mov     bl,al
    dummy();
    asm in      al,40h
    asm mov     bh,al
    asm sti
    return _BX;
}

void main(int argc, char *argv[])
{
    int         t,i,b,stereo,ishelp = 0, currentFile, delta,
                option = 0, looping = 1, medcount = 0, sDevice = 0, doMono = 0;
    char        scrlLock, ch, *strptr, *ptr, fileName[MAXPATH], szName[10], szExt[5];
    ushort      a, rate = 21000, port = 0, intnum = 0, scramble = 0, timerd,
                timerc,dmach = 16;
    long        tempTime = 0, median = 0, l;
    FILE        *f;
    SOUNDCARD   scard;
    MCPSTRUCT   mcpstrc;
    void        *temp;
    long        rate50 = 23864,tempSeg;
    SDI_INIT    sdi;

    if(!(getCPUType() & 2)) errorexit("This program needs a 386/486 processor.");
    randomize();
    if(*(int*)&DMPMT_VERSION != 0 ) exit(1);
    printf("\nDual Module Player for Multitaskers version 2.%u\n",DMPMT_VERSION);
    puts("Copyright 1992,1993 Otto Chrons\n");
    if( argc < 2 )
        {
        puts("Syntax :    DMPMT modulename [modulename] [@listfile] [options]");
        puts("");
        puts("Use /h for more information");
        exit(0);
        }
    mcpstrc.options = 0;
    for( t = 1; t < argc; t++)
        {
        strptr = argv[t];
        if( strptr[0] == '/' || strptr[0] == '-' )
            {
            switch(toupper(strptr[1]))
                {
                case 'S' :
                    sscanf(&strptr[2],"%u",&a);
                    if( a >= 4000 && a <= 44100 ) rate = a;
                    if( a >=4 && a <= 44 ) rate = a*1000;
                    break;
                case 'H' :
                case '?' :
                    ishelp = 1;
                    break;
                case 'O' :
                    scramble = 1;
                    break;
                case 'I' :
                    sscanf(&strptr[2],"%u",&intnum);
                    break;
                case 'P' :
                    sscanf(&strptr[2],"%x",&port);
                    break;
                case 'D' :
                    sscanf(&strptr[2],"%u",&dmach);
                    break;
                case 'L' :
                    looping = 0;
                    break;
                case 'Q' :
                    mcpstrc.options |= MCP_QUALITY;
                    break;
                case 'C' :
                    sscanf(&strptr[2],"%u",&a);
                    if( a > 0 && a < 6 ) sDevice = a;
                    break;
                case 'M' :
                    doMono = 1;
                    break;
                case 'U' :
                    UMBok = 0;
                    break;
                }
            }
        else if( strptr[0] == '@' )
            {
            if((f = fopen(&strptr[1],"rt")) != NULL)
                do {
                    a = fscanf(f,"%s",fileName);
                    if( a == 1 ) appendFileList( fileName );
                } while( a == 1 );
            }
        else appendFileList( strptr );
        }
    if( fileCount > 1 && scramble )
        {
        for(i = 0; i < fileCount; i++)
            {
            a = random(fileCount);
            b = random(fileCount);
            if( a != b )
                {
                temp = fileList[a];
                fileList[a] = fileList[b];
                fileList[b] = temp;
                }
            }
        }
    if( ishelp )
        {
        showHelp();
        exit(0);
        }
    if( fileCount == 0 )
        {
        puts("Syntax :    DMP [options] modulename [modulename] [@listfile] [options]");
        exit(0);
        }
    if( intnum != 0 || port != 0 || dmach != 16 )
        {
        scard.dmaChannel = (dmach != 16 ) ? dmach : 1;
        scard.sampleSize = 1;
        scard.stereo = (doMono == 1) ? 0 : 1;
        switch(sDevice)
            {
            case 1 :
                scard.ID = ID_SB;
                break;
            case 2 :
                scard.ID = ID_SBPRO;
                break;
            case 3 :
                scard.ID = ID_PASPLUS;
                scard.stereo = (doMono == 1) ? 0 : 1;
                if( intnum==0 ) intnum = 7;
                if( port==0 ) port = 0x388;
                break;
            case 4 :
                scard.ID = ID_PAS16;
                scard.sampleSize = 2;
                scard.stereo = (doMono == 1) ? 0 : 1;
                if( intnum==0 ) intnum = 7;
                if( port==0 ) port = 0x388;
                break;
            case 5 :
                scard.ID = ID_SB16;
                scard.sampleSize = 2;
                scard.stereo = (doMono == 1) ? 0 : 1;
                if( intnum==0 ) intnum = 5;
                break;
            default :
                errorexit("You have to specify card type with -c parameter!");
                break;
            }
        if( intnum==0 ) intnum = 7;
        if( port==0 ) port = 0x220;
        scard.ioPort = port;
        scard.dmaIRQ = intnum;
        switch( scard.ID )
            {
            case ID_SB :
                sdi = SDI_SB;
                break;
            case ID_SBPRO :
                sdi = SDI_SBPro;
                break;
            case ID_PAS :
            case ID_PASPLUS :
            case ID_PAS16 :
                sdi = SDI_PAS;
                if(doMono) scard.stereo = 0;
                break;
            case ID_SB16 :
                sdi = SDI_SB16;
                if(doMono) scard.stereo = 0;
                break;
            default :
                errorexit("Invalid Sound Device Interface");
                break;
            }
        if(mcpInitSoundDevice(sdi,&scard)) errorexit("Unable to use the sound card");
        }
    else
        {
        if( sDevice == 0 || sDevice == 3 || sDevice == 4 ) a = detectPAS(&scard);
        if( a != 0 && (sDevice == 0 || sDevice == 5) ) a = detectSB16(&scard);
        if( a != 0 && (sDevice == 0 || sDevice == 2) ) a = detectSBPro(&scard);
        if( a != 0 && (sDevice == 0 || sDevice == 1) ) a = detectSB(&scard);
        if( a == 0 )
            {
            printf("%s has been detected at %Xh using IRQ %d on DMA channel %d\n",\
                scard.name,scard.ioPort,scard.dmaIRQ,scard.dmaChannel);
            printf("version is %d.%02d\n",scard.version>>8,scard.version&255);
            switch( scard.ID )
                {
                case ID_SB :
                    sdi = SDI_SB;
                    break;
                case ID_SBPRO :
                    sdi = SDI_SBPro;
                    break;
                case ID_PAS :
                case ID_PASPLUS :
                case ID_PAS16 :
                    sdi = SDI_PAS;
                    if(doMono) scard.stereo = 0;
                    break;
                case ID_SB16 :
                    sdi = SDI_SB16;
                    if(doMono) scard.stereo = 0;
                    break;
                default :
                    errorexit("Invalid Sound Device Interface");
                    break;
                }
            mcpInitSoundDevice(sdi,&scard);
            }
        else errorexit("Couldn't find sound card");
        }
    if(scard.ID == ID_SBPRO)
        {
        initMixer(MIX_SBPRO, scard.ioPort);
        oldMixer = getMixer( MIX_STEREO );
        setMixer(MIX_STEREO, stereo = 1);
        atexit(resetMixer);
        }
    a = MCP_TABLESIZE;
    if( mcpstrc.options & MCP_QUALITY ) a += MCP_QUALITYSIZE;
    if((temp = ualloc(a+16*1024+16)) == NULL) errorexit("Not enough memory");
    tempSeg = ((ulong)(FP_SEG(temp))*0x10+FP_OFF(temp)+0x10)/0x10;
    mcpstrc.bufferSeg = tempSeg;
    mcpstrc.bufferSize = 16*1024;
    mcpstrc.reqSize = 16*1024;
    mcpstrc.samplingRate = rate;
    if(mcpInit(&mcpstrc)) errorexit("Couldn't initialize MultiChannelPlayer");
    atexit((atexit_t)mcpClose);
    if(ampInit(AMP_MANUAL)) errorexit("Couldn't initialize AdvancedModulePlayer");
    atexit(ampClose);
    if((a = getDVVersion()) != 0)
        {
        printf("Detected DesqView %d.%02d\n",a/256,a & 255);
        puts("DesqView support enabled.");
        multitasking = 1;
        }
    else if((a = getWindowsVersion()) != 0)
        {
        if( a == 1 ) puts("Detected MS Windows 3.xx in Standard or Real mode");
        else if( a == 2 ) puts("Detected MS Windows/386 2.xx");
        else printf("Detected MS Windows %d.%02d in Enhanced mode\n",a & 255,a/256);
        if( a > 1 )
            {
            puts("MS Windows support enabled");
            multitasking = 2;
            }
        }
    rate = mcpGetSamplingRate();
    printf("Sampling rate is %u\n",rate);
    delta = rate/50;
    currentFile = -1;
    scrlLock = (*keyStatus) & 0x10;
    ch = 0; module = NULL;
    a = 0;
    for( t = 0; t < 100; t++ )
        {
        if( (timerLatch() & 1) != 0 )            // Test timer type
            {
            a = 1;
            break;
            }
        }
    if( a == 0 ) rate50 *= 2;
    do
        {
        if( fileCount > 1 && ampGetPattern() == module->patternCount - 1 )
            mcpSetMasterVolume(64-ampGetRow());
        if( (ampGetModuleStatus() & MD_PLAYING) == 0 )
            {
            do {
                mcpClearBuffer();
                ampFreeModule(module);
                currentFile++;
                if( currentFile >= fileCount )
                    {
                    if( looping == 0 ) quit();
                    currentFile = 0;
                    }
                fnsplit(fileList[currentFile],NULL,NULL,szName,szExt);
                printf("Loading %s%s . . .",szName,szExt);
                b = loader(fileList[currentFile]);
                memset(instrUsed,' ',31);
            } while( b < MERR_NONE );
            if( b == MERR_NONE )
                {
                printf("(%dk)\n",module->filesize/1024);
                mcpSetMasterVolume(64);
                mcpOpenChannels(module->channelCount,VOLUME_LINEAR,0);
                ampPlayModule(module,(fileCount == 1 && looping == 1) ? PM_LOOP : 0);
                printf("Playing %s (%dk)\n",module->name,module->size/1024);
                }
            }
        beginCritical();
        a = mcpGetBufferDelta()/delta;
        for(t = 0; t < a; t++)
            {
            timerc = timerLatch();
            ampPlayRow();
            mcpCalcBuffer(delta);
            timerd = timerLatch();
            median += (unsigned)(timerc-timerd);
            if(++medcount == 10 )
                {
                l = (long)median*100/(long)rate50;
                printf("Power : %2lu.%lu%%\r",
                       l/10,l % 10);
                median = 0;
                medcount = 0;
                }
            }
        endCritical();
        if( kbhit() )
            {
            ch = toupper(getch());
            switch( ch )
                {
                case 'H' :
                    showHelp();
                    break;
                case 'N' :
                    if( fileCount < 2 ) break;
                    ampStopModule();
                    break;
                case 'S' :
                    if(scard.stereo)
                        {
                        stereo = 1-stereo;
                        printf("Stereo %s\n",stereo == 1 ? "ON" : "OFF");
                        setMixer(MIX_STEREO,stereo);
                        }
                    break;
                case 'B' :
                    ampBreakPattern(1);
                    break;
                }
            }
        a = (*keyStatus) & 0x10;
        b = ampGetModuleStatus() & MD_PAUSED;
        if( !a && b )
            {
            puts("Module resumed");
            ampResumeModule();
            mcpResumeVoice();
            }
        if( a && !b )
            {
            puts("Module paused");
            ampPauseModule();
            mcpPauseVoice();
            }
        releaseSlice();
    } while ( ch != 27 );
    quit();
}
