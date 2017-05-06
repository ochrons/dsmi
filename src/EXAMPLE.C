/* EXAMPLE.C An example program for DSMI
 *
 * Copyright 1994 Otto Chrons
 *
 * First revision 05-19-94 11:39:18am
 *
 * Revision history:
 *
*/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <conio.h>
#include <ctype.h>
#include <dos.h>
#include "dsmi.h"
#include "emhm.h"
#include "sfxeng.h"

typedef struct {
    char    *name;
    int     ID;
} SC_TYPE;

SC_TYPE  soundcards[] = {"Sound Blaster",1,
                         "Sound Blaster Pro",2,
                         "Sound Blaster 16",6,
                         "Pro Audio Spectrum",3,
                         "Pro Audio Spectrum+",4,
                         "Pro Audio Spectrum 16",5,
                         "Aria sound card",8,
                         "Windows Sound System (or compatible)",9,
                         "Gravis Ultrasound",10,
                         "DAC on LPT",7,
                         "Stereo DACs on LPT1 and LPT2",7,
                         "Stereo-on-1 DAC on LPT",7,
                         "PC speaker",7,
                         NULL,0};

int     emsOK;

#define MAX_EFFECT 16

typedef struct {
    char    *name;
    long    loopStart,loopEnd;
} SEFFECT;


SEFFECT effects[] = {   "EFFECT1.RAW",0,0,
                        "EFFECT2.RAW",0,0,
                        "EFFECT3.RAW",0,0,
                        "EFFECT4.RAW",32823,50887,
                        "EFFECT5.RAW",0,0,
                        NULL,0,0};

/****************************************************************************\
*
* Function:     void getSoundHardware(SOUNDCARD *scard)
*
* Description:  Detects the sound card and asks the user to confirm information
*
* Input:        SOUNDCARD *scard
*
\****************************************************************************/

int getSoundHardware(SOUNDCARD *scard)
{
    int         sc,i,autosel,select;
    char        answer[80],ch;

    memset(scard,0,sizeof(SOUNDCARD));
again:
    sc = detectGUS(scard);
    if( sc != 0 ) sc = detectPAS(scard);
    if( sc != 0 ) sc = detectAria(scard);
    if( sc != 0 ) sc = detectSB(scard);

    // If no sound card found, zero scard
    if( sc != 0 ) memset(scard,0,sizeof(SOUNDCARD));

    autosel = -1;
    if( sc == 0 )        // Found a sound card
    {
        for( i = 0; soundcards[i].name != NULL; i++ )
        {
            if( scard->ID == soundcards[i].ID )
            {
                // Set auto selection mark
                autosel = i+1;
                break;
            }
        }
    }

    // Print the list of sound cards
    for( i = 0; soundcards[i].name != NULL; i++ )
        printf("(%d) %s\n",i+1,soundcards[i].name);

    if( autosel != -1 ) printf("\nSelect (%d): ",autosel);
    else printf("\nSelect : ");

    // Read user input
    gets(answer);
    select = atoi(answer);

    // Default entry?
    if( select == 0 ) select = autosel;
    if( select != autosel )     // Is selection different from what we found?
    {
        // Clear all assumptions
        sc = -1;
        memset(scard,0,sizeof(SOUNDCARD));
        scard->ID = soundcards[select-1].ID; // Set correct ID
    }

    // Query I/O address
    if( scard->ID == ID_DAC ) scard->ioPort = 0x378;
    if( sc == 0 ) printf("Enter sound card's base I/O address (0x%X): ",scard->ioPort);
    else printf("Enter sound card's base I/O address: ");

    // Read user input
    gets(answer);
    i = strtol(answer,NULL,16);

    if( i != 0 ) scard->ioPort = i;

    if( sc != 1 ) // Not autodetected
    {
        switch( scard->ID )
        {
            case ID_SB16 :
            case ID_PAS16 :
            case ID_WSS :
            case ID_ARIA :
            case ID_GUS :
                scard->sampleSize = 2;      // 16-bit card
            case ID_SBPRO :
            case ID_PAS :
            case ID_PASPLUS :
                scard->stereo = 1;      // Enable stereo
                break;
            default :
                scard->sampleSize = 1;
                scard->stereo = 0;
                break;
        }
    }

    if( scard->ID != ID_DAC )
    {
        // Query IRQ number
        if( sc == 0 ) printf("Enter sound card's IRQ number (%d): ",scard->dmaIRQ);
        else printf("Enter sound card's IRQ number: ");

        // Read user input
        gets(answer);
        i = atoi(answer);

        if( i != 0 ) scard->dmaIRQ = i;

        // Query DMA channel
        if( sc == 0 ) printf("Enter sound card's DMA channel (%d): ",scard->dmaChannel);
        else printf("Enter sound card's DMA channel: ");

        // Read user input
        gets(answer);
        i = atoi(answer);

        if( i != 0 ) scard->dmaChannel = i;
    } else
    {
        // Select correct DAC
        scard->maxRate = 44100;
        if(strcmp("Stereo DACs on LPT1 and LPT2",soundcards[select-1].name) == 0)
        {
            scard->stereo = 1;
            scard->dmaChannel = 1;      // Special 'mark'
            scard->maxRate = 60000;
        } else
        if(strcmp("Stereo-on-1 DAC on LPT",soundcards[select-1].name) == 0)
        {
            scard->stereo = 1;
            scard->dmaChannel = 2;      // Special 'mark'
            scard->maxRate = 60000;
            if( scard->ioPort == 0 ) scard->ioPort = 0x378;
        } else
        if(strcmp("PC speaker",soundcards[select-1].name) == 0)
        {
            scard->dmaChannel = 0;
            scard->ioPort = 0x42;       // Special 'mark'
            scard->maxRate = 44100;
        }
    }

    if( scard->ID != ID_DAC )
    {
        printf("Your selection: %s at 0x%x using IRQ %d and DMA channel %d\n", \
               soundcards[select-1].name,scard->ioPort,scard->dmaIRQ,scard->dmaChannel);
    } else
    {
        printf("Your selection: %s at 0x%x\n",soundcards[select-1].name,scard->ioPort);
    }
    printf("Is this correct (Y/n)? ");
    ch = getche();
    puts("");
    if( toupper(ch) == 'N' ) goto again;
    return 0;
}

/****************************************************************************\
*
* Function:     int loadSample(const char *fname, SAMPLEINFO *sinfo)
*
* Description:  Loads a raw sample and fills 'sinfo'
*
* Input:        const char *fname       File name
*               SAMPLEINFO *sinfo       Pointer to sample info structure
*
* Returns:      handle                  if OK
*               -1                      error
*
\****************************************************************************/

int loadSample(SEFFECT *sef, int *handle)
{
    FILE        *f;
    int         a;
    long        l;
    EMSH        e;
    SAMPLEINFO  sinfo;

    // Clear sinfo
    memset(&sinfo,0,sizeof(SAMPLEINFO));

    // Open sample file
    if((f = fopen(sef->name,"rb")) == NULL) return -1;

    // Get the length of the file
    fseek(f,0,SEEK_END);
    l = ftell(f);
    fseek(f,0,SEEK_SET);

    if( l > 65520 ) l = 65520;      // Limit the size

    // Can we use EMS?
    if( emsOK && (e = emsAlloc(l)) > 0)
    {
        // Map into page frame
        sinfo.sample = emsLock(e,0,l);
        sinfo.sampleID = e;
    }
    else if((sinfo.sample = D_malloc(l)) == NULL) return -1;

    // Read sample data
    fread(sinfo.sample,l,1,f);

    // Fill other fields in sinfo
    sinfo.length = l;
    sinfo.loopstart = sef->loopStart;
    sinfo.loopend = sef->loopEnd;

    // Was it loaded into EMS
    if( sinfo.sampleID )
    {
        // Download with sampleID
        cdiDownloadSample(0,sinfo.sample,(void*)sinfo.sampleID,l);
        sinfo.sample = (void*)sinfo.sampleID;
    }
    else
    {
        // Download with pointer
        cdiDownloadSample(0,sinfo.sample,sinfo.sample,l);
    }

    fclose(f);
    *handle = RegisterSFX(&sinfo);
    return 0;
}

int main()
{
    SOUNDCARD   scard;
    MCPSTRUCT   mcpstrc;
    DDS         dds;
    MODULE      *module;
    SDI_INIT    sdi;
    int         t,ch,vdsOK,curCh,moduleVolume;
    unsigned    bufsize;
    ulong       a,rate,tempSeg;
    char        answer[80];
    void        *temp;
    ushort      volTable[32];
    int         sfxHandles[MAX_EFFECT];

    // Read sound card information
    if(getSoundHardware(&scard) == -1) return 1;

    // Initialize EMS Heap Manager with 256kB
    a = emsInit(256,256);
    if( a == 0 )
    {
        emsOK = 1;
        puts("Using 256kB of EMS memory");
    }
    else emsOK = 0;

    // Initialize Timer Service
    tsInit();
    atexit(tsClose);
    if( scard.ID == ID_GUS )
    {
        // Initialize GUS player
        scard.extraField[2] = 1;    // Use DMA downloading
        scard.extraField[3] = 0;    // Don't use GUS timer
        gusInit(&scard);
        atexit(gusClose);

        // Initialize GUS heap manager
        gushmInit();

        // Init CDI
        cdiInit();

        // Register GUS into CDI
        cdiRegister(&CDI_GUS,0,31);

        // Add GUS event playing engine into Timer Service
        tsAddRoutine(gusInterrupt,GUS_TIMER);
    }
    else
    {
        // Initialize Virtual DMA Specification
        vdsOK = (vdsInit() == 0);

        memset(&mcpstrc,0,sizeof(MCPSTRUCT));

        // Query for sampling rate
        printf("Enter the sampling rate (21000) : ");
        gets(answer);
        a = atol(answer);
        if( a > 4000 ) rate = a;
        else rate = 21000;

        // Query for quality mode
        printf("Use quality mode (Y/n)? ");
        ch = getche();
        if( toupper(ch) != 'N' ) mcpstrc.options = MCP_QUALITY;

        puts("");
        switch( scard.ID )
        {
            case ID_SB :
                sdi = SDI_SB;
                scard.maxRate = 22000;
                break;
            case ID_SBPRO :
                sdi = SDI_SBPro;
                scard.maxRate = 22000;
                break;
            case ID_PAS :
            case ID_PASPLUS :
            case ID_PAS16 :
                sdi = SDI_PAS;
                scard.maxRate = 44100;
                break;
            case ID_SB16 :
                sdi = SDI_SB16;
                scard.maxRate = 44100;
                break;
            case ID_ARIA :
                sdi = SDI_ARIA;
                scard.maxRate = 44100;
                break;
            case ID_WSS :
                sdi = SDI_WSS;
                scard.maxRate = 48000;
                break;
            case ID_DAC :
                sdi = SDI_DAC;
                break;
        }
        mcpInitSoundDevice(sdi,&scard);
        a = MCP_TABLESIZE;
        mcpstrc.reqSize = 0;

        // Calculate mixing buffer size
        bufsize = (2800*(int)scard.sampleSize<<(int)scard.stereo)*(long)rate/22000l;
        mcpstrc.reqSize = 0;
        if( mcpstrc.options & MCP_QUALITY )
        {
            // 8-bit or 16-bit sound card?
            if( scard.sampleSize == 1 ) a += MCP_QUALITYSIZE;
            else a = MCP_TABLESIZE16+MCP_QUALITYSIZE16;

        }
        if( (long)bufsize+(long)a > 65500L ) bufsize = 65500L-a;

        // Allocate volume table + mixing buffer
        if((temp = D_malloc(a+bufsize)) == NULL) return 2;
        tempSeg = ((long)(FP_SEG(temp))*0x10+FP_OFF(temp)+0x10)/0x10;
        mcpstrc.bufferSeg = tempSeg;
        if( vdsOK && scard.ID != ID_DAC )
        {
            dds.size = bufsize;
            dds.segment = tempSeg;
            dds.offset = 0;

            // Lock DMA buffer if VDS present
            if(vdsLockDMA(&dds)==0)
            {
                mcpstrc.bufferPhysical = dds.address;
            }
            else mcpstrc.bufferPhysical = (ulong)tempSeg<<4;
        }
        else mcpstrc.bufferPhysical = (ulong)tempSeg<<4;
        mcpstrc.bufferSize = bufsize;
        mcpstrc.samplingRate = rate;

        // Initialize Multi Channel Player
        if(mcpInit(&mcpstrc)) return 3;
        atexit(mcpClose);

        // Initialize Channel Distributor
        cdiInit();

        // Register MCP into CDI
        cdiRegister(&CDI_MCP,0,31);
    }

    // Try to initialize AMP
    if(ampInit(0)) return 3;
    atexit(ampClose);

    // Hook AMP player routine into Timer Service
    tsAddRoutine(ampInterrupt,AMP_TIMER);

    // If using DAC, then adjust DAC timer
    if( scard.ID == ID_DAC ) setDACTimer(tsGetTimerRate());

    if( scard.ID != ID_GUS ) mcpStartVoice(); // Start voice output
    else gusStartVoice();

    // Load an example AMF
    puts("Loading EXAMPLE.AMF");
    if( (module = ampLoadAMF("EXAMPLE.AMF",0)) == NULL ) return 4;

    // Is it MCP & Quality mode & 16-bit card?
    if( scard.ID != ID_GUS && (mcpstrc.options & MCP_QUALITY) && scard.sampleSize == 2)
    {
        // Open module+3 channels with amplified volumetable (4.7 gain)
        for( a = 1; a < 33; a++ ) volTable[a-1] = a*150/32;
        cdiSetupChannels(0,module->channelCount+3,volTable);
    }
    else
    {
        // Open module+2 channels with regular volumetable
        cdiSetupChannels(0,module->channelCount+3,NULL);
    }
    moduleVolume = 64;

    // Load effects
    puts("Loading effects...");

    InitSFX(module->channelCount,3);
    for( t = 0; effects[t].name; t++ )
        if(loadSample(&effects[t],&sfxHandles[t]) == -1 ) return 4;

    // Play module
    ampPlayModule(module,PM_LOOP);
    puts("Playing EXAMPLE.AMF\n\n");
    puts("Press + or - to adjust the volume of module");
    puts("Press 1-5 to play an effect");
    puts("Press 0 to stop all effects");

    do {
        ch = getch();
        switch( ch )
        {
            case '+' :
                if( moduleVolume < 64 ) moduleVolume++;
                ampSetMasterVolume(-1,moduleVolume);
                break;
            case '-' :
                if( moduleVolume > 0 ) moduleVolume--;
                ampSetMasterVolume(-1,moduleVolume);
                break;
        }
        t = ch - '1';
        if( t >= 0 && t <= 4 )
        {
            PlaySFX(sfxHandles[t],64,11025,PAN_MIDDLE);
        }
        if( t == -1 )
        {
            StopAllSFX();
        }
    } while( ch != 27 );        // Wait for ESCAPE
    ampStopModule();
    return 0;
}
