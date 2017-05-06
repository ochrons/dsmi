// ************************************************************************
// *
// *    File        : DMP.C
// *
// *    Description : Dual Module player that uses DSMI
// *
// *    Copyright (C) 1992,1994 Otto Chrons
// *
// ************************************************************************
/*
        Revision history of DMP.C

        2.33    16.4.93
                First recorded version.
        2.40    6.5.93
                Support for S3M format.
                DMP can now also display more channels and instruments.
                Support for 669 format also.
        2.41    8.5.93
                Fixed the blinking bug after DOS shell
                9.5.93
                Added amplifying control via mcpOpenChannel (option -a)
                S3M loader if now more compatible
        2.42    10.5.93
                S3M loader had troubles with non-used instruments.
                Same problem in 669 loader
                Filter on/off key for SB Pro
                Tempo keys, channel keys
        2.43    11.5.93
                Left/right/middle,channel selection
                No more channel orders
                Real volumebars
        2.44    12.5.93
                PC internal speaker support
                DAC works now with QEMM
        2.45    15.5.93
                Full panning
                Support for MDA (0xB000 screen)
        2.46    15.5.93
                Corrected the bug with all frequency commands...
                Aria sound card support
        2.50    25.5.93
                Autocalibration
                EMS support
        2.51    27.5.93
                EMS corrections
                New Quality mode
                Many bug fixes
        2.52    8.6.93
                Some bug fixes.. don't know what :)
        2.53    20.6.93
                WSS support
                Bugfixes with pause and SB
                Virtual DMA services support
        2.54    27.6.93
                Bug in VDS detection
                WSS didn't work, now fixed
        2.55    11.7.93
                Bugs with SB16 fixed (hopefully).
        2.60    8.8.93
                GUS support, sort of
        2.62    29.8.93
                GUS works now pretty well.
                Corrected a small bug in 669 loader
        2.65    18.9.93
                Surround sound for MCP
                GUS bugs fixed...
        2.66    26.9.93
                GUS DMA bugs fixed.. reset bugs, volume ramps, pause/resume
        2.67    2.10.93
                GUS IRQ bugs.
                New SB16 detection.
        2.68    3.10.93
                Portamento bug fixed
                Stereo DACs
        2.69    Stereo DACs are now stereo! :)
                GUS reset bugs fixed
        2.70    669 loader tempo bug fixed
                GUS reset bugs...
        2.71    GUS reset bugs again.. :(
                -W is immediate DOS shell
                GUS is now timed propely
                Samples are now loaded without DMA to the GUS
                (optimized routine)
        2.72    7.11.93
                Fixed a bug in CDI's CDIDEVICE
                S3M last instrument bug fixed
        2.74    20.11.93
                All calls use 32-bit parameters in DSMI
                28.11.93
                GUS,AMP,Timer Service and CDI use new Cstyle macros,
                not TASM language MODELs
                Had to skip 2.73 because of a fake 2.73b
        2.75    Changes in source for DSMI/32
                New reset routine for GUS
                Bug in S3M loader fixed
                Support for 32 channels
        2.76    DMP.INI support
                Archiver support
                MTM loader bug fixes
        2.77    Fixed a tiny bug in GUS heap (uninitialized pointer)
                New volume table for GUS, less clicks
                Mono screen support via DMP.INI
                Real volume bars for GUS
        2.78    Fixed a stack bug in AMPLAYER (CMDinstrument)
                Fixed plain instrument handling to MOD and MTM loaders
                Fixed a bug with archive expansion
        2.79    FAR loader
                MCPLAYER now uses macro library
                Fixed the CmdLine bug in DMP.INI
        2.80    GUS bugs fixed
                50/25-row switch
        2.81    S3M volume slide bug fixed
                Pitch bending bug fixed
                VGA hardware palette option
                Channel ID chars option
        2.82    Rewritten mixing routines are 25% faster on 486
                PAS DMA bugs fixed (hopefully)
        2.83    Internal DMA routines rewritten
                SB 2.0 44kHz support
                AudioTrix Pro support
                Fixed the amplifying bug
                Another S3M volume slide bug fixed
        2.85    SB16 initRate bug fixed (no ENTERPROC...)
                ampSetMasterVolume added
                Corrupted modules are now loaded
        2.86    Quality mode bug fixed
                Quiet mode, errorlevel support (68)
                Fixed MTM loader bug
        2.87    DMA bug with PAS cards (DMA was not stopped)
                GUS samples are downloaded with DMA
                GUS player bugs fixed
        2.88    GUS DMA works now
                MTM & FAR loaders fixed
        2.89    Module loaders now compatible with DSMI/32
                New detection routines for SB family
                Fixed a bug in WSS exit routine
                Optional non-DMA transfer mode for GUS
        2.90    Fixed S3M loader and FAR loader.
                AMF now supports >64 row patterns (FARandole)
                GUS now uses regular timer. Some bug fixes.
                Optimized mixing routines for 16-bit cards
        2.91    Memory optimizations
                Fixed a bug in delay note
                Retouched some header files
        2.92    New 16-bit quality mode introduced
        2.93    Fixed the 669 loader bug
                Fixed the SB Pro left-right bug
        2.94    Autoinit mode for SB cards
                Fixed some S3M loader bugs
                GUS panning did not work in 2.93
                Fixed a bad bug in ampPlayRow.
        2.95    Less Ultraclicks
                Fixed tremolo
                Optional GUS timer
                New DMA loading for GUS
                Checks for GUS memory allocations
                Less memory fragmentation
                Solo track feature
        3.00    Fixed bugs in GUS init code (IRQ & DMA setting probs)
                Digital Effects for MCP, reverb and filters
                Autogain for 16-bit Quality mode
                New help screens
        3.01    Autoinit bug fix in SB 2.00
                GUS player was way too slow
                WSS init bugs fixed
                The old Aria routine is back
*/


#include <io.h>
#include <fcntl.h>
#include <dos.h>
#include <stdio.h>
#include <dir.h>
#include <stdlib.h>
#include <string.h>
#include <bios.h>
#include <ctype.h>
#include <timeb.h>
#include <alloc.h>
#include <conio.h>
#include <process.h>
#include <time.h>

#include "mcp.h"
#include "gus.h"
#include "gushm.h"
#include "cdi.h"
#include "sdi_dac.h"
#include "sdi_sb.h"
#include "sdi_sb16.h"
#include "sdi_aria.h"
#include "sdi_pas.h"
#include "sdi_wss.h"
#include "detpas.h"
#include "detaria.h"
#include "detsb.h"
#include "detgus.h"
#include "amp.h"
#include "mixer.h"
#include "fastext.h"
#include "timeserv.h"
#include "dvcalls.h"
#include "vds.h"
#include "ini.h"
#include "queue.h"

#ifdef _USE_EMS
#include "emhm.h"
#endif

char    DMP_VERSION[5] = "3.01";

extern uchar quietMode;
extern ushort eventDiff;

int getCPUType(void);

#define V_REAL 1
#define V_NORMAL 0

typedef struct {
    char    fileName[MAXPATH];
    uchar   deleteIt;
} FileListItem;

typedef struct {
    char    ext[5];
    char    cmd[128];
} Unpacker;

typedef struct {
    ushort   r,g,b;
} RGB;

typedef struct {
    long    delay;
    long    gain;
} ECHO;

typedef struct {
    int     position;
    long    gain;
} REVERB;

enum { EFFECT_NONE, EFFECT_REVERB, EFFECT_REVERB_FAST, EFFECT_FILTER };

typedef struct {
    int     type;
    char    name[30];
    int     parmCount;
    long    parm[20];
} EFFECT;

int getCPUType();
long timer();

long            startTime;
volatile long   *timer2 = (long *)0x0000046C;
uchar           lines, oldStereo, volumeBar = V_REAL;
ushort          rate = 21000, multitasking = 0, cCount, thisChan = 0,
                isEMS = 0, vdsOK = 0, scrSize = 0, mono = 0, verLow1 = 0;
DDS             dds;
SOUNDCARD       scard;

int             fileCount = 0, verLow2 = 1,looping = 1, helpScr = 0,
                volume = 64, loadOpt = LM_IML, unpCount = 0,verHigh = 3,
                useAutoGain = 0, autoGain[32];

Queue           *fileList;
MODULE          *module;
char            instrUsed[127];
char            *tempDir = ".\\", *defaultDir = NULL;
Unpacker        unp[10];
char            *defaultExtensions = "MOD STM NST AMF S3M 669 MTM FAR";
char            channelID[33] = "123456789ABCDEFGHIJKLMNOPQRSTUVW";

EFFECT          dmpEffects[10];
int             currentEffect = 0;

#define VGACOLORCOUNT 16

int             setVGAColors = 0;

char            *vgaColorNames[VGACOLORCOUNT] = {
"BLACK",
"BLUE",
"GREEN",
"CYAN",
"RED",
"MAGENTA",
"BROWN",
"LIGHTGRAY",
"DARKGRAY",
"LIGHTBLUE",
"LIGHTGREEN",
"LIGHTCYAN",
"LIGHTRED",
"LIGHTMAGENTA",
"YELLOW",
"WHITE"};

RGB             vgaColors[VGACOLORCOUNT];
int             colorPointers[VGACOLORCOUNT];

#define COLORCOUNT 17
enum {          C_HEADER, C_INFO1, C_INFO2, C_3D1, C_3D2, C_3D3, C_TRACK,
                C_BAR1, C_BAR2, C_BAR3, C_INSTR1, C_INSTR2, C_INSTR3,
                C_CONTACT1, C_CONTACT2, C_HELP1, C_HELP2 };
ushort          colors[COLORCOUNT] = {
                0x4F,0x17,0x1E,0x7F,0x8F,0x78,0x78,0x7A,0x7E,
                0x7C,0x1E,0x1A,0x1D,0x07,0x0A,0x5F,0x5E };

ushort          monoColors[COLORCOUNT] = {
                0x7F,0x07,0x0F,0x7F,0x8F,0x78,0x78,0x7F,0x7F,
                0x7F,0x07,0x09,0x0F,0x07,0x0F,0x70,0x7F };

char            *colorNames[COLORCOUNT] = {
"Header",
"Info1",
"Info2",
"3D1",
"3D2",
"3D3",
"Track",
"VolumeBar1",
"VolumeBar2",
"VolumeBar3",
"Instr1",
"Instr2",
"Instr3",
"Contact1",
"Contact2",
"Help1",
"Help2"};

char            *helpCmdLine[] = {
" ~Command line options :~",
" ~ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ",
"   ~-?~, ~-h~     This help screen            ~-m~          Mono mode (PAS,SB16)",
"   ~-s~xxxx     Sampling rate               ~-q~          Quality mode",
"   ~-8~         Force 8-bit mode            ~-t~xxxx      Buffer = xxxx",
"   ~-p~xxx      Use port xxx (42 = PC spkr) ~-o~          Scramble module order",
"   ~-i~x        Use interrupt x             ~-x~          Quiet screen mode",
"   ~-d~x        DMA channel x               ~-n~xx        Set default panning",
"   ~-l~         No looping                  ~-g~          Non-DMA download (GUS)",
"   ~-a~xx       Amplify by xx (norm=31)     ~-w~[command] Immediate DOS shell",
"   ~-c~x        Sound device x              ~-f~xx        Select digital effect xx",
"              ~1~=SB, ~2~=SB Pro, ~3~=PAS+",
"              ~4~=PAS16, ~5~=SB16, ~6~=DAC",
"              ~7~=Aria, ~8~=WSS/AudioTrix Pro",
"              ~9~=GUS, ~10~=Spkr,",
"              ~11,12~=Stereo DAC",
"   ~-e~         Disable extended tempos",
"   ~-b~         Disable EMS usage",
"   ~-zxx~       Screen size 25/50",
"   ~-gt~        Don't use GUS timer",
"",
0 },

                *helpKeys[] = {

"            ~Keys :",
"            ~ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ",
"            ~P~           Pause/resume module",
"            ~1~-~9~,~0~       Turn track on/off",
"            ~S~           Solo/unsolo track",
"            ~N~           Next module",
"            ~F1~-~F10~,~+~,~-~  Set volume",
"            ~Left~/~Right~  Go to next/prev pattern",
"            ~F~           Filter on/off",
"            ~[~,~]~,~{~,~}~     Adjust speed/tempo",
"            ~, .~         Panning left/right",
"            ~L~,~M~,~R~,~U~     Left/mid/right/surround",
"            ~Up~/~down~     Select next/prev channel",
"            ~V~           Real/fake volume bars",
"            ~H~           This help screen",
"            ~Z~           Screen size (25/50)",
"            ~E~           Select Digital Effect",
"            ~D~           Shell to DOS",
"            ~ESC~         Exit",
"",
0 },

                *contactText[] = {
"",
"                         Thank you for using ~DMP~",
"",
"  DMP is ~cardware~, which means that if you like the program, you ~must~",
"  send me a ~postcard~. I want you to do this so that I can see how much DMP",
"  is actually used around the world. Send your postcard to following address.",
"  Please don't send e-mail as a substitute for a real post card!",
"",
"  To contact the author of ~DMP~, use following methods:",
"",
"  By mail:                    Internet:",
"  ~Otto Chrons~                 Mail: ~otto.chrons@cc.tut.fi",
"  ~Vaajakatu 5 K 199~           IRC : ~OC~",
"  ~FIN-33720 TAMPERE",
"  ~FINLAND",
"",
"  Read ~README~ for information on ~DSMI~ Programming Interface!!",
"",0 };

void beginCritical(void)
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

void endCritical(void)
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

void releaseSlice(void)
{
    if( multitasking == 1 )
    {
        dvPause();
    }
}

void update(void)
{

    if( multitasking == 0 ) return;
    beginCritical();
    ampPoll();
    endCritical();
}

EFFECT_ROUTINE  effRoutine = NULL;
signed short   *delayLineLeft = NULL, *delayLineRight = NULL, *delayLineMono = NULL;
int             delayLineSize = 0, delayLinePosition = 0;
int             reverbCount = 0;
REVERB          reverbs[8];
long            reverbFeedback = 0;
int             filterType = 0;

extern void reverbEffectsASM( void *buffer, long length, long dataType);

extern void filterEffectsASM( void *buffer, long length, long dataType);

void filterEffects( void *buffer, long length, long dataType)
{
    int     *intBuf;
    unsigned char *charBuf;
    static int prevval, prevvalR;

    switch( filterType )
    {
        case 1 :
            if( dataType & 0x2 )            // Stereo ??
            {
                if( dataType & 0x1 )        // Is it 16-bit?
                {
                    intBuf = buffer;
                    while(length--)
                    {
                        *intBuf++ = prevval = ((long)prevval+*intBuf)>>1;
                        *intBuf++ = prevvalR = ((long)prevvalR+*intBuf)>>1;
                    }
                }
                else
                {
                    charBuf = buffer;
                    while(length--)
                    {
                        *charBuf++ = prevval = (prevval+(unsigned int)*charBuf)>>1;
                        *charBuf++ = prevvalR = (prevvalR+(unsigned int)*charBuf)>>1;
                    }
                }

            }
            else                            // Mono
            {
                if( dataType & 0x1 )        // is it 16-bit
                {
                    intBuf = buffer;
                    while(length--)
                    {
                        *intBuf++ = prevval = ((long)prevval+*intBuf)>>1;
                    }
                }
                else
                {
                    charBuf = buffer;
                    while(length--)
                    {
                        *charBuf++ = prevval = (prevval+(unsigned int)*charBuf)>>1;
                    }
                }
            }
            break;
        case 2 :
            if( dataType & 0x2 )            // Stereo ??
            {
                if( dataType & 0x1 )        // Is it 16-bit?
                {
                    intBuf = buffer;
                    while(length--)
                    {
                        *intBuf++ = prevval = ((long)prevval+*intBuf+*intBuf+*intBuf)>>2;
                        *intBuf++ = prevvalR = ((long)prevvalR+*intBuf+*intBuf+*intBuf)>>2;
                    }
                }
                else
                {
                    charBuf = buffer;
                    while(length--)
                    {
                        *charBuf++ = prevval = (prevval+(unsigned int)*charBuf+(unsigned int)*charBuf+(unsigned int)*charBuf)>>2;
                        *charBuf++ = prevvalR = (prevvalR+(unsigned int)*charBuf+(unsigned int)*charBuf+(unsigned int)*charBuf)>>2;
                    }
                }

            }
            else                            // Mono
            {
                if( dataType & 0x1 )        // is it 16-bit
                {
                    intBuf = buffer;
                    while(length--)
                    {
                        *intBuf++ = prevval = ((long)prevval+*intBuf+*intBuf+*intBuf)>>2;
                    }
                }
                else
                {
                    charBuf = buffer;
                    while(length--)
                    {
                        *charBuf++ = prevval = (prevval+(unsigned int)*charBuf+(unsigned int)*charBuf+(unsigned int)*charBuf)>>2;
                    }
                }
            }
            break;
    }
}

void reverbEffects( void *buffer, long length, long dataType)
{
    int     i = length,mask,t;
    int     *intBuf;
    signed char *charBuf;
    long    revval,outval,tempval;
    static long prevval, prevvalRight;

    mask = delayLineSize - 1;       // Mask to prevent delay line overflow
    if( dataType & 0x2 )            // Do stereo reverb
    {
        if( dataType & 0x1 )            // 16-bit data
        {
            intBuf = buffer;
            while( i )
            {
                outval = *intBuf;   // Process left
                revval = 0;
                for( t = 0; t < reverbCount; t++ )
                {
                    revval += (reverbs[t].gain*delayLineLeft[reverbs[t].position = (reverbs[t].position + 1) & mask]);
                }
                revval = (prevval+(revval>>8))>>1;
                prevval = revval;
                tempval = outval+(revval*reverbFeedback>>8);
                revval += outval;
                if( revval > 32767 )
                {
                    revval = 32767;
                    if( tempval > 32767 ) tempval = 32767;
                }
                else if( revval < -32768 )
                {
                    revval = -32768;
                    if( tempval < -32768 ) tempval = -32768;
                }
                delayLineLeft[delayLinePosition = (delayLinePosition + 1) & mask] = tempval;
                *intBuf++ = (short)revval;

                outval = *intBuf;   // Process right
                revval = 0;
                for( t = 0; t < reverbCount; t++ )
                {
                    revval += (reverbs[t].gain*delayLineRight[reverbs[t].position]);
                }
                revval = (prevvalRight+(revval>>8))>>1;
                prevvalRight = revval;
                tempval = outval+(revval*reverbFeedback>>8);
                revval += outval;
                if( revval > 32767 )
                {
                    revval = 32767;
                    if( tempval > 32767 ) tempval = 32767;
                }
                else if( revval < -32768 )
                {
                    revval = -32768;
                    if( tempval < -32768 ) tempval = -32768;
                }
                delayLineRight[delayLinePosition] = tempval;
                *intBuf++ = (short)revval;
                i--;
            }
        }
        else                        // 8-bit stereo
        {
            charBuf = buffer;
            while( i )
            {
                outval = (((short)(*charBuf))<<(signed short)8)^(signed short)0x8000;   // Process left
                revval = 0;
                for( t = 0; t < reverbCount; t++ )
                {
                    revval += (reverbs[t].gain*delayLineLeft[reverbs[t].position = (reverbs[t].position + 1) & mask]);
                }
                revval = (prevval+(revval>>8))>>1;
                prevval = revval;
                tempval = outval+(revval*reverbFeedback>>8);
                revval += outval;
                if( revval > 32767 )
                {
                    revval = 32767;
                    if( tempval > 32767 ) tempval = 32767;
                }
                else if( revval < -32768 )
                {
                    revval = -32768;
                    if( tempval < -32768 ) tempval = -32768;
                }
                delayLineLeft[delayLinePosition = (delayLinePosition + 1) & mask] = tempval;
                *charBuf++ = ((short)revval^0x8000)>>8;

                outval = (((short)(*charBuf))<<(signed short)8)^(signed short)0x8000;   // Process right
                revval = 0;
                for( t = 0; t < reverbCount; t++ )
                {
                    revval += (reverbs[t].gain*delayLineRight[reverbs[t].position]);
                }
                revval = (prevvalRight+(revval>>8))>>1;
                prevvalRight = revval;
                tempval = outval+(revval*reverbFeedback>>8);
                revval += outval;
                if( revval > 32767 )
                {
                    revval = 32767;
                    if( tempval > 32767 ) tempval = 32767;
                }
                else if( revval < -32768 )
                {
                    revval = -32768;
                    if( tempval < -32768 ) tempval = -32768;
                }
                delayLineRight[delayLinePosition] = tempval;
                *charBuf++ = ((short)revval^0x8000)>>8;
                i--;
            }
        }
        return;
    }
    else                            // Mono reverb
    {
        if( dataType & 0x1 )            // 16-bit data
        {
            intBuf = buffer;
            while( i )
            {
                outval = *intBuf;
                revval = 0;
                for( t = 0; t < reverbCount; t++ )
                {
                    revval += (reverbs[t].gain*delayLineMono[reverbs[t].position = (reverbs[t].position + 1) & mask]);
                }
                revval = (prevval+(revval>>8))>>1;
                prevval = revval;
                tempval = outval+(revval*reverbFeedback>>8);
                revval += outval;
                if( revval > 32767 )
                {
                    revval = 32767;
                    if( tempval > 32767 ) tempval = 32767;
                }
                else if( revval < -32768 )
                {
                    revval = -32768;
                    if( tempval < -32768 ) tempval = -32768;
                }
                delayLineMono[delayLinePosition = (delayLinePosition + 1) & mask] = tempval;
                *intBuf++ = (short)revval;
                i--;
            }
        }
        else
        {
            charBuf = buffer;
            while( i )
            {
                outval = (((short)(*charBuf))<<(signed short)8)^(signed short)0x8000;   // Process left
                revval = 0;
                for( t = 0; t < reverbCount; t++ )
                {
                    revval += (reverbs[t].gain*delayLineMono[reverbs[t].position = (reverbs[t].position + 1) & mask]);
                }
                revval = (prevval+(revval>>8))>>1;
                prevval = revval;
                tempval = outval+(revval*reverbFeedback>>8);
                revval += outval;
                if( revval > 32767 )
                {
                    revval = 32767;
                    if( tempval > 32767 ) tempval = 32767;
                }
                else if( revval < -32768 )
                {
                    revval = -32768;
                    if( tempval < -32768 ) tempval = -32768;
                }
                delayLineMono[delayLinePosition = (delayLinePosition + 1) & mask] = tempval;
                *charBuf++ = ((short)revval^0x8000)>>8;
                i--;
            }
        }
    }
}

int initReverbEffects(int numofreverbs, long feedback, ECHO *newreverbs)
{
    int     i;
    long    l,maxDelay = 0;

    if( numofreverbs > 8 || numofreverbs < 1 ) return -1;

    for( i = 0; i < numofreverbs; i++ )     // Find max delay for delay line
    {
        if(newreverbs[i].delay > maxDelay ) maxDelay = newreverbs[i].delay;
    }

    reverbCount = numofreverbs;
    delayLinePosition = 0;
    reverbFeedback = feedback;

    l = rate*maxDelay/1000l;            // Calculate delay line size
    if( l > 16384 ) return -2;

    if( l > 8192 ) l = 16384;
    else if( l > 4096 ) l = 8192;
    else if( l > 2048 ) l = 4096;
    else l = 2048;

    if( l > delayLineSize )
    {
        delayLineLeft = delayLineMono = realloc(delayLineLeft,l*2);
        if(scard.stereo) delayLineRight = realloc(delayLineRight,l*2);
        delayLineSize = l;
    }
    memset(delayLineLeft,0,delayLineSize*2);        // Clear delay lines
    if(scard.stereo) memset(delayLineRight,0,delayLineSize*2);

    for( i = 0; i < numofreverbs; i++ )     // Adjust reverbs
    {
        reverbs[i].position = delayLineSize-(long)(rate)*newreverbs[i].delay/1000l-1;
        reverbs[i].gain = newreverbs[i].gain;
    }
    return 0;
}

void ActivateEffect( int eff )
{
    EFFECT      *e;

    if( scard.ID == ID_GUS ) return;         // Not for GUS

    if( !eff )
    {
        mcpSetEffectRoutine(NULL);
        return;
    }
    e = &dmpEffects[eff-1];
    switch( e->type )
    {
        case EFFECT_REVERB :
            mcpSetEffectRoutine(NULL);
            if(initReverbEffects((e->parmCount)/2,e->parm[0],(ECHO*)&e->parm[1])==0)
                mcpSetEffectRoutine(reverbEffectsASM);
            break;
        case EFFECT_FILTER :
            filterType = e->parm[0];
            mcpSetEffectRoutine(filterEffectsASM);
            break;
        case EFFECT_NONE :
        default :
            mcpSetEffectRoutine(NULL);
            break;
    }
}

void ParseEffect(int effectNum, char *str2parse)
{
    int         i,prmCnt;
    EFFECT      *e = &dmpEffects[effectNum];
    char        effType;

    prmCnt = sscanf(str2parse,"%s %c %li %li %li %li %li %li %li %li %li %li %li %li %li %li %li %li %li %li %li %li",
        e->name,&effType,&e->parm[0],&e->parm[1],&e->parm[2],&e->parm[3],&e->parm[4],
        &e->parm[5],&e->parm[6],&e->parm[7],&e->parm[8],&e->parm[9],
        &e->parm[10],&e->parm[11],&e->parm[12],&e->parm[13],&e->parm[14],
        &e->parm[15],&e->parm[16],&e->parm[17],&e->parm[18],&e->parm[19]);
    if( prmCnt < 2 ) return;
    for( i = 0; i < strlen(e->name); i++ ) if(e->name[i]=='_') e->name[i]=' ';
    switch( toupper(effType) )
    {
        case 'R' :
            if( prmCnt < 5 ) break;
            e->type = EFFECT_REVERB;
            e->parmCount = prmCnt-3;
            e->parm[0] = e->parm[0]*256/100;
            for(i = 0; i < e->parmCount/2; i++)
            {
                // Adjust gain values
                e->parm[i*2+2] = e->parm[i*2+2]*256/100;
            }
            break;
        case 'F' :
            if( e->parm[0] > 2 || e->parm[0] < 0 ) break;
            e->type = EFFECT_FILTER;
            e->parmCount = prmCnt-2;
            break;
        default :
            e->type = 0;
            break;
    }
}

#define FX_WIN_X 20
#define FX_WIN_Y 5

void drawEffectSelection(int selection)
{
    int     i;
    ushort      buf[80];
    char        *str,strbuf[80];

    writeStr("      Select Digital Effect to use      ",FX_WIN_X,FX_WIN_Y,colors[C_HEADER],40);
    for( i = 0; i < 11; i++ )
    {
        moveChar(buf,0,' ',colors[C_HELP1],40);
        if( i == selection )
            moveChar(buf,1,' ',colors[C_INFO1],38);
        if( i == 0 ) str = " ~X~. No effect";
        else str = (dmpEffects[i-1].name[0] == '\0') ? "~%2d~. No effect" : "~%2d~. %s";
        sprintf(strbuf,str,i,dmpEffects[i-1].name);
        if( i == selection )
            moveCStr(buf,1,strbuf,colors[C_INFO1],colors[C_INFO2]);
        else
            moveCStr(buf,1,strbuf,colors[C_HELP1],colors[C_HELP2]);
        writeBuf(buf,FX_WIN_X,FX_WIN_Y+i+1,40);
    }
}

void SelectEffect(void)
{
    int     sel = currentEffect,key, done = 0, oldsel;
    char    ch;

    drawEffectSelection(sel);
    while(!done)
    {
        update();
        releaseSlice();
        if(bioskey(1))
        {
            oldsel = sel;
            key = bioskey(0);           // Read keys
            ch = toupper(key);
            switch( ch )
            {
                case 0 :
                    switch(key>>8)
                    {
                        case 0x48 :
                            if( sel ) sel--;
                            break;
                        case 0x50 :
                            if( sel < 10 )
                                sel++;
                            break;
                    }
                    break;
                case 'X' :
                    sel = 0;
                    break;
                case 13:
                case 27:
                    done = 1;
                    break;
            }
            if( ch >= '0' && ch <= '9' )
            {
                sel = ch-'0';
                if( sel == 0 ) sel = 10;
            }
            if( sel != oldsel ) ActivateEffect(currentEffect = sel);
            drawEffectSelection(sel);
        }
    }
}

void dumpFreeHeap(void)
{
    struct heapinfo hinfo;

    cursorxy(0,1);
    hinfo.ptr = NULL;
    while(heapwalk(&hinfo) == _HEAPOK)
        if( hinfo.in_use != 1 ) printf("%p %ld\n", hinfo.ptr,hinfo.size);
}

void setTextmode(int mode)
{
    if(!quietMode) textmode(mode);
}

long timer(void)
{
    struct timeb curtime;

    ftime(&curtime);
    return curtime.time;
}

int realVolume(int track)
{
    int         t,orgvol;
    long        ave,vol;
    char huge   *hsample;
    char far    *sample;
    static char buf[128];

    if( (orgvol = cdiGetVolume(track)) == 0 ||
        !(cdiGetChannelStatus(track) & CH_PLAYING)) return 0;
    if( scard.ID == ID_GUS )
    {
        ave = (long)cdiGetInstrument(track);
        ave += cdiGetPosition(track);
        for( t = 0; t < 80; t++ )
        {
            buf[t] = (char)(gusPeek(ave++))^(char)0x80;
        }
        sample = buf;
    }
    else
    {
        hsample = (char huge *)cdiGetInstrument(track);
        hsample += cdiGetPosition(track);
        sample = (char far *)hsample;
    }
    vol = 0;
    for( t = 0; t < 80; t++ )
    {
        vol += abs(sample[t]^(char)0x80);
    }
    vol = vol*orgvol/8000;
    if( vol > 64 ) vol = 64;
    return vol;
}

void setBlink(int toggle)
{
    if( quietMode ) return;
    asm mov     ax,1003h
    asm mov     bx,toggle
    asm int     10h
}

void resetMixer(void)
{
    mixerSet( MIX_STEREO, oldStereo );
}

void drawHeader(void)
{
    ushort      buf[80];
    char        str[80];

    sprintf(str,"Dual Module Player version %s (C) 1992,1994 Otto Chrons. All Rights Reserved.",DMP_VERSION);
    moveChar(buf,0,' ',colors[C_HEADER],80);
    moveStr(buf,1,str,colors[C_HEADER]);
    writeBuf(buf,0,0,80);
}

void drawScreen(void)
{
    ushort      t, buf[80];

    drawHeader();
    moveChar(buf,0,' ',0x07,80);
    for( t = 1; t < lines; t++ ) writeBuf(buf,0,t,80);
}

void drawContact(void)
{
    ushort      t, buf[80];

    moveChar(buf,0,' ',0x07,80);
    for( t = 1; t < lines; t++ ) writeBuf(buf,0,t,80);
    for( t = 0; contactText[t] != 0; t++)
        writeCStr(contactText[t],0,t+1,colors[C_CONTACT1],colors[C_CONTACT2],80);
}

void showHelp(int line, int helptype)
{
    int         t;

    if( helptype == 1 )
    {
        for( t = 0; helpCmdLine[t] != 0; t++, line++)
            writeCStr(helpCmdLine[t],0,line,colors[C_HELP1],colors[C_HELP2],80);
    }
    else if( helptype == 2 )
    {
        for( t = 0; helpKeys[t] != 0; t++, line++)
            writeCStr(helpKeys[t],0,line,colors[C_HELP1],colors[C_HELP2],80);
    }
}

void drawTracks(void)
{
    static ushort       trackTime[32] = {65535,65535,65535,65535,65535,65535,65535,65535,
                                         65535,65535,65535,65535,65535,65535,65535,65535,
                                         65535,65535,65535,65535,65535,65535,65535,65535,
                                         65535,65535,65535,65535,65535,65535,65535,65535};
    static int          barSize[32] = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,\
                                       0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0}, oldRow = 255;
    static long         oldTimer;
    static char         *notes[12] = {"C-","C#","D-","D#","E-","F-","F#","G-","G#","A-","A#","B-"},
                        *cmds[] = {"","","VOLUME SLIDE","","","","PORTA TO NOTE",
                                   "TREMOR","ARPEGGIO","VIBRATO","TONE+VOL",
                                   "VIBRATO+VOL","","","","RETRIG","SAMPLE OFFSET",
                                   "FINE VOLUME","","DELAY NOTE","NOTE CUT","","","PAN"},
                        *modes[] = {"DOS","DesqView","Windows","Covox"},
                        noteTrack[33];
    int                 t,trck,i,s,a,x,y,cnt;
    TRACKDATA           *trackdata;
    TRACKDATA           tracks[32];
    ushort              buf[160],attr,ins;
    char                str[80], *strptr;
    uchar               note;

    if( *timer2 == oldTimer ) return;
    drawHeader();
    moveChar(buf,0,' ',colors[C_INFO1],80);
    sprintf(str,"Song: ~%s~",module->name);
    moveCStr(buf,1,str,colors[C_INFO1],colors[C_INFO2]);
    sprintf(str,"File size: ~%uK~",module->filesize/1024);
    moveCStr(buf,30,str,colors[C_INFO1],colors[C_INFO2]);
    sprintf(str,"Memory used: ~%uK~",module->size/1024);
    moveCStr(buf,46,str,colors[C_INFO1],colors[C_INFO2]);
    strptr = modes[multitasking];
    if( !multitasking && isEMS ) strptr = "DOS/EMS";
    sprintf(str,"Mode: ~%s~",strptr);
    moveCStr(buf,64,str,colors[C_INFO1],colors[C_INFO2]);
    writeBuf(buf,0,1,80);
    moveChar(buf,0,' ',colors[C_INFO1],80);
    sprintf(str,"Pattern: ~%d~/~%d~",ampGetPattern(),module->patternCount-1);
    moveCStr(buf,1,str,colors[C_INFO1],colors[C_INFO2]);
    sprintf(str,"Row: ~%02X~",oldRow = ampGetRow());
    moveCStr(buf,18,str,colors[C_INFO1],colors[C_INFO2]);
    sprintf(str,"Volume: ~%u~",volume);
    moveCStr(buf,39,str,colors[C_INFO1],colors[C_INFO2]);
    sprintf(str,"Rate: ~%u~",rate);
    moveCStr(buf,50,str,colors[C_INFO1],colors[C_INFO2]);
    sprintf(str,"Tempo: ~%u~/~%u~",ampGetTempo() & 255,ampGetTempo()>>8);
    moveCStr(buf,63,str,colors[C_INFO1],colors[C_INFO2]);
    if( ampGetModuleStatus() & MD_PAUSED ) strcpy(str,"Time: ~PAUSED~");
    else
    {
        a = (timer() - startTime);
        sprintf(str,"Time: ~%u:%02u~",a/60,a%60);
    }
    moveCStr(buf,26,str,colors[C_INFO1],colors[C_INFO2]);
    writeBuf(buf,0,2,80);
    oldTimer = *timer2;
    for( t = 0; t < cCount; t++)
    {
        if( barSize[t] > 18 ) barSize[t]--;
        else barSize[t] -= 2;
        if( barSize[t] < 0 ) barSize[t] = 0;
    }
    for( t = 0; t < cCount; t++)
    {
        trck = t;
        trackdata = ampGetTrackData( trck );
        memcpy(&tracks[t],trackdata,sizeof(TRACKDATA));
        moveChar(buf,0,' ',colors[C_TRACK],80);
        note = trackdata->note;
        moveStr(buf,0,"Ý                      Þ     Þ    Þ                Þ",colors[C_TRACK]);
        putAttr(buf,0,colors[C_3D1]);
        putAttr(buf,23,colors[C_3D2]);
        putAttr(buf,29,colors[C_3D2]);
        putAttr(buf,34,colors[C_3D2]);
        putAttr(buf,51,colors[C_3D2]);
        putAttr(buf,79,colors[C_3D3]);
        putChar(buf,79,'Þ');
        if( t == thisChan )
        {
            putChar(buf,0,'¯');
            putAttr(buf,0,colors[C_TRACK]);
        }
        moveChar(buf,53,'þ',colors[C_3D3],20);
        if( !(trackdata->status & TR_MUTED) )
        {
            if( note > 0 )
            {
                strncpy(str,module->instruments[trackdata->instrument].name,22);
                str[22] = 0;
                moveStr(buf,1,str,colors[C_TRACK]);
            }
            str[0] = 0;
            if( note > 0 )
                sprintf(str,"%2s%u",notes[note % 12],note/12 - ((module->type == MOD_S3M) ? 1 : 3));
            moveStr(buf,25,str,colors[C_TRACK]);
            sprintf(str,"%u",trackdata->volume);
            if( note > 0 ) moveStr(buf,31,str,colors[C_TRACK]);
            switch( trackdata->command )
            {
                case cmdBender :
                    strptr = (trackdata->cmdvalue > 127) ? "PORTA UP" : "PORTA DOWN";
                    break;
                case cmdFinetune :
                    strptr = (trackdata->cmdvalue > 127) ? "FINE PORTA UP" : "FINE PORTA DOWN";
                    break;
                case cmdExtraFineBender:
                    strptr = (trackdata->cmdvalue > 127) ? "EXTRA FINE UP" : "EXTRA FINE DOWN";
                    break;
                default :
                    strptr = cmds[trackdata->command & 0x7F];
                    break;
            }
            moveStr(buf,36,strptr,colors[C_TRACK]);
            if( trackdata->playtime < trackTime[trck] )
                barSize[t] = 20*trackdata->volume/64;
            if(volumeBar) barSize[t] = realVolume(t)*20/64;
            for( i = 0; i < barSize[t]; i++)
            {
                attr = ( i < 13 ) ? colors[C_BAR1] : ( i < 18 ) ? colors[C_BAR2] : colors[C_BAR3];
                putAttr(buf,53+i,attr);
            }
        }
        else moveStr(buf,60," MUTE ",colors[C_TRACK]);
        switch( trackdata->panning )
        {
            case PAN_LEFT :
                strptr = " LEFT";
                break;
            case PAN_RIGHT :
                strptr = "RIGHT";
                break;
            case PAN_MIDDLE :
                strptr = " MID ";
                break;
            case PAN_SURROUND :
                strptr = "SURND";
                break;
            default :
                sprintf(str,"%d",trackdata->panning);
                strptr = str;
                break;
        }
        moveStr(buf,74,strptr,colors[C_TRACK]);
        if( trackdata->playtime > 0 ) trackTime[trck] = trackdata->playtime;
        writeBuf(buf,0,3+t,80);
    }
    for( t = 0; t < (module->instrumentCount+1)/2*2; t++)
    {
        a = 0; cnt = cCount;
        memset(noteTrack,' ',cnt);
        noteTrack[cnt] = 0;
        if( t < module->instrumentCount )
            for( i = cnt-1; i >= 0; i--)
            {
                s = i;
                if( tracks[s].instrument == t && !(tracks[s].status & TR_MUTED) && (tracks[s].note > 0))
                {
                    a++;
                    noteTrack[--cnt] = channelID[s];
                }
            }
        ins = (module->instrumentCount+1)/2;
        attr = (a == 0) ? colors[C_INSTR1] : colors[C_INSTR2];
        if( a != 0 ) instrUsed[t] = '\x7';
        x = (t < ins) ? 0 : 40;
        y = (t < ins) ? t : t-ins;
        y += 3+cCount;
        moveChar(buf,0,' ',colors[C_INSTR1],40);
        if( t < module->instrumentCount )
        {
            moveStr(buf,8-cCount,noteTrack,colors[C_INSTR3]);
            putChar(buf,9,instrUsed[t]);
            moveStr(buf,10,module->instruments[t].name,attr);
            if( t < ins ) putChar(buf,39,'³');
        }
        writeBuf(buf,x,y,40);
    }
    moveChar(buf,0,' ',colors[C_INSTR1],80);
    for( t = 3+ins+cCount; t < 50; t++) writeBuf(buf,0,t,80);
}

void errorexit(const char *str)
{
    drawContact();
    writeStr(str,0,1,0x1C,80);
    cursorxy(0,23);
    setBlink(1);
    exit(1);
}

int loader(char *name)
{
    char        *strptr, str[80], ch;
    long        wait1;

    if((module = ampLoadModule(name,loadOpt)) == NULL)
    {
        switch(moduleError)
        {
            case -1 :
                strptr = " Not enough memory to load %s";
                break;
            case -2 :
                strptr = " File error loading %s";
                break;
            case -3 :
                strptr = " %s is not a valid module file";
                break;
            default :
                strptr = " Couldn't load module %s";
                break;
        }
        sprintf(str,strptr,name);
        drawScreen();
        writeStr(str,0,2,0x1C,80);
        writeStr("Press <ENTER> to continue, <ESC> to quit",0,3,0x1C,80);
        do {
            ch = bioskey(0);
        } while( ch != 13 && ch != 27 );
        drawScreen();
        if( ch == 27 ) errorexit(str);
    }
    if( moduleError == MERR_CORRUPT )
    {
        wait1 = *timer2;
        writeStr("Module is corrupted. Play anyway?",0,2,0x1C,80);
        while( *timer2 < wait1 + 18 && bioskey(1) == 0 );
        if(bioskey(1))
        {
            ch = toupper(bioskey(0));
            if( ch == 27 ) errorexit("Corrupted module");
            if( ch != 'N' ) moduleError = MERR_NONE;
        } else moduleError = MERR_NONE;
    }
    return moduleError;
}

char *searchAll(const char *name)
{
    struct ffblk ff;
    char        drive[MAXDRIVE],path[MAXDIR],file[MAXFILE],ext[MAXEXT];
    static char fName[MAXPATH],buffer[MAXPATH];

    fnsplit(name,drive,path,file,ext);
    fnsplit(_argv[0],drive,path,buffer,buffer);
    fnmerge(fName,drive,path,file,ext);
    if( findfirst(fName,&ff,0) != 0 )
    {
        return searchpath(name);
    }
    else return fName;
}

int addExtension(char *name)
{
    struct ffblk ff;
    char        drive[MAXDRIVE],path[MAXDIR],file[MAXFILE],ext[MAXEXT];
    char        fName[MAXPATH],buffer[MAXPATH];
    int         a;
    char        *extPtr = defaultExtensions;

    strcpy(fName,name);
    a = findfirst(fName,&ff,0);
    if( a != 0 )
    {
        a = fnsplit(fName,drive,path,file,ext);
        if( (a & EXTENSION) == 0 )
        {
            ext[0] = '.';
            do {
                a = 1; ext[1] = ext[2] = ext[3] = 0;
                while(*extPtr!=0 && *extPtr!=' ' && a < 4) ext[a++] = *extPtr++;
                if(*extPtr) extPtr++;
                ext[a] = 0;
                fnmerge(fName,drive,path,file,ext);
                if( findfirst(fName,&ff,0) == 0) break;
            } while( ext[1] );
            if( !ext[1] ) return -1;
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
    char        fileName[255];
    struct ffblk ffblk;
    int         error;
    FileListItem    *item;

    if( strchr( name,'*' ) != NULL || strchr( name,'?' ) != NULL )
    {
        fnsplit( name,drive,path,file,ext );
        error = findfirst( name,&ffblk,0 );
        while( !error )
        {
            fnsplit( ffblk.ff_name,NULL,NULL,file,ext );
            fnmerge( fileName,drive,path,file,ext );
            addExtension( fileName );
            item = malloc(sizeof(FileListItem));
            strupr( fileName );
            strcpy( item->fileName,fileName );
            item->deleteIt = 0;
            InsertQueueBottom(fileList, item);
            error = findnext(&ffblk);
            fileCount++;
        }
    }
    else
    {
        strcpy(fileName,name);
        if(addExtension(fileName) == 0)
        {
            item = malloc(sizeof(FileListItem));
            strupr( fileName );
            strcpy( item->fileName,fileName );
            item->deleteIt = 0;
            InsertQueueBottom(fileList, item);
            fileCount++;
        }
    }
}

void quit(int err)
{
    setTextmode(mono ? MONO : scrSize == 25 ? C80 : C4350);
    drawScreen();
    drawContact();
    cursorxy(0,23);
    setBlink(1);
    if( vdsOK == 2 )
    {
        vdsEnableDMATranslation(scard.dmaChannel);
        vdsUnlockDMA(&dds);
    }
    if(heapcheck() == _HEAPCORRUPT )
    {
        puts("Heap is corrupted!\n");
        exit(-1);
    }
    exit(err);
}

int getWindowsVersion(void)
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
    if(getenv("windir")) return 1;
    return 0;
}

Queue *ReadDir(const char *dir)
{
    char            drive[MAXDRIVE],path[MAXDIR],path1[MAXDIR],file[MAXFILE],ext[MAXEXT];
    char            fileName[MAXDIR];
    Queue           *q;
    struct ffblk    ff;
    int             error;
    FileListItem    *item;

    q = CreateQueue();
    strcpy(path1,dir);
    fnsplit( path1,drive,path,file,ext );
    strcat(path1,"*.*");
    error = findfirst( path1,&ff,0 );
    while( !error )
    {
        fnsplit( ff.ff_name,NULL,NULL,file,ext );
        fnmerge( fileName,drive,path,file,ext );
        item = calloc(1,sizeof(FileListItem));
        strupr( fileName );
        strcpy( item->fileName,fileName );
        InsertQueueBottom(q,item);
        error = findnext(&ff);
    }
    return q;
}

int DiffDir(Queue *q1, Queue *q2)
{
    FileListItem    *item;
    int             success = 0;

    item = GetQueueItem(q2);
    while( item )
    {
        if( !SearchQueueItem(q1,item,sizeof(FileListItem)))
        {
            item->deleteIt = 1;
            InsertQueueTop(fileList,item);
            success = 1;
        }
        else free(item);
        item = GetQueueItem(q2);
    }
    DestroyQueue(q1);
    DestroyQueue(q2);
    return success;
}

void AddUnpacker(const char *ext, const char *cmd)
{
    if( unpCount == 10 ) return;
    strncpy(unp[unpCount].ext,ext,5);
    unp[unpCount].ext[4] = 0;
    strncpy(unp[unpCount].cmd,cmd,128);
    unp[unpCount].cmd[127] = 0;
    unpCount++;
}

FileListItem *GetNextFile(void)
{
    FileListItem    *fileItem;
    int             t;
    Queue           *dir1,*dir2;
    char            cmdline[128];

    fileItem = GetQueueItem( fileList );
    if( fileItem == NULL ) quit(0);
    for( t = 0; t < unpCount; t++ )
        if(strstr(fileItem->fileName,unp[t].ext))
        {
            dir1 = ReadDir(tempDir);
            sprintf(cmdline,unp[t].cmd,fileItem->fileName,tempDir);
            cursorxy(0,1);
            setBlink(1);
            system(cmdline);
            setBlink(0);
            dir2 = ReadDir(tempDir);
            if(DiffDir(dir1,dir2) && looping )
            {
                InsertQueueBottom( fileList, fileItem );
            }
            return GetNextFile();
        }
    if( looping && !fileItem->deleteIt )
    {
        InsertQueueBottom( fileList, fileItem );
    }
    return fileItem;
}

#pragma option -2-

void check386(void)
{
    if(!(getCPUType() & 2))
    {
        puts("This program requires atleast a 386 processor.");
        exit(-1);
    }
}

#pragma option -3

#pragma startup check386

int getColorPointer(int color)
{
    int pointer;

    inp(0x3DA);
    outp(0x3C0,color);
    pointer = inp(0x3C1);
    inp(0x3DA);
    outp(0x3C0,0x20);
    return pointer;
}

void getRGB(int color, RGB *rgb)
{
    _ES = FP_SEG(rgb);
    _DI = FP_OFF(rgb);
    asm {
        mov     dx,3C7h
        mov     ax,color
        out     dx,al
        mov     dx,3C9h
        sub     ax,ax
        in      al,dx
        mov     [es:di],ax
        in      al,dx
        mov     [es:di+2],ax
        in      al,dx
        mov     [es:di+4],ax
    }
}

void setRGB(int color, RGB *rgb)
{
    _ES = FP_SEG(rgb);
    _DI = FP_OFF(rgb);
    asm {
        mov     dx,3C8h
        mov     ax,color
        out     dx,al
        mov     dx,3C9h
        mov     ax,[es:di]
        out     dx,al
        mov     ax,[es:di+2]
        out     dx,al
        mov     ax,[es:di+4]
        out     dx,al
    }
}

void updatePalette(void)
{
    int t;

    if(setVGAColors == 0) return;
    for( t = 0; t < VGACOLORCOUNT; t++ )
        setRGB(colorPointers[t],&vgaColors[t]);
}

int main(int argc, char *argv[])
{
    int         t,i,b,key,filter = 1,ishelp = 0,
                sDevice = 0, doMono = 0, dmach = 16, amp = 0, bit8 = 0,
                emsOK = 1, defpan = 64, dosshell = 0, gusDMA = 1, gusTimer = 1,
                solo = 0, soloChan = 0;
    char        ch, str[80], *strptr, fileName[MAXPATH], drive[MAXDRIVE];
    char        szName[10], szExt[5],*dmpenv = NULL,*dmpini,shellstr[80] = "";
    ushort      port = 0, intnum = 0, scramble = 0, a, bufsize = 0;
    ushort      voltable[32];
    long        tempTime, tempSeg;
    FILE        *f;
    MCPSTRUCT   mcpstrc;
    void        *temp;
    SDI_INIT    sdi;
    ConfigFile  iniFile;
    ConfigItemData  *itemData;
    FileListItem    *fileItem;
    QueueItem   *i1,*i2;
    ConfigClass *unpack;
    ConfigItem  *cItem;

    tempTime = 0;
    setBlink(0);
    randomize();
    lines = 50;
    sprintf(DMP_VERSION,"%d.%d%d",verHigh,verLow1,verLow2);
    if(initFastext() == 7)
    {
        mono = 1;
        memcpy(colors,monoColors,sizeof(colors));
    }
    dmpini = searchAll("DMP.INI");
    if( dmpini && ReadConfig(dmpini,&iniFile) == 0 )
    {
        if(SelectConfigClass("StartUp",&iniFile))
        {
            itemData = GetConfigItem("DefaultExt",T_STR,&iniFile);
            if( itemData != NULL  && itemData->i_str[0])
            {
                defaultExtensions = itemData->i_str;
            }
            itemData = GetConfigItem("Cmdline",T_STR,&iniFile);
            if( itemData != NULL && itemData->i_str[0] )
            {
                dmpenv = itemData->i_str;
            }
            itemData = GetConfigItem("DefaultDir",T_STR,&iniFile);
            if( itemData != NULL  && itemData->i_str[0] )
            {
                defaultDir = itemData->i_str;
            }
            itemData = GetConfigItem("ChannelID",T_STR,&iniFile);
            if( itemData != NULL  && itemData->i_str[0] )
            {
                for( a = 0; a < 32 && itemData->i_str[a] != 0; a++ )
                    channelID[a] = itemData->i_str[a];
            }
        }
        if(SelectConfigClass((mono) ? "MonoColors" : "Colors",&iniFile))
        {
            for( t = 0 ; t < COLORCOUNT; t++ )
            {
                itemData = GetConfigItem(colorNames[t],T_LONG,&iniFile);
                if( itemData != NULL )
                {
                    a = itemData->i_long;
                    if( a != 0 ) colors[t] = a;
                }
            }
        }
        if(SelectConfigClass("Unpack",&iniFile))
        {
            itemData = GetConfigItem("TempDir",T_STR,&iniFile);
            if( itemData != NULL )
            {
                tempDir = itemData->i_str;
            }
            unpack = GetConfigClass("Unpack",&iniFile);
            cItem = unpack->firstItem;
            while( cItem )
            {
                if( cItem->name[0] == '.' )
                {
                    AddUnpacker(cItem->name,cItem->data);
                }
                cItem = cItem->nextItem;
            }
        }
        if(SelectConfigClass("VGAColors",&iniFile))
        {
            setVGAColors = 1;
            scrSize = (peekb(0x40,0x84) < 25) ? 25 : 50;
            setTextmode(mono ? MONO : scrSize == 25 ? C80 : C4350);        // Load default palette
            for( t = 0; t < VGACOLORCOUNT; t++ )
                colorPointers[t] = getColorPointer(t);
            for( t = 0; t < VGACOLORCOUNT; t++ )
                getRGB(colorPointers[t],&vgaColors[t]);
            for( t = 0; t < VGACOLORCOUNT; t++ )
            {
                itemData = GetConfigItem(vgaColorNames[t],T_STR,&iniFile);
                if( itemData != NULL )
                {
                    sscanf(itemData->i_str,"%x %x %x",&vgaColors[t].r,&vgaColors[t].g,&vgaColors[t].b);
                }
            }
        }
        memset(dmpEffects,0,sizeof(dmpEffects));    // Process digital effects
        if(SelectConfigClass("DigitalEffects",&iniFile))
        {
            for( t = 1; t <= 10; t++ )
            {
                sprintf(str,"Effect%d",t);
                itemData = GetConfigItem(str,T_STR,&iniFile);
                if( itemData )
                {
                    ParseEffect(t-1,itemData->i_str);
                }
            }
            itemData = GetConfigItem("Default",T_LONG,&iniFile);
            if( itemData )
            {
                i = itemData->i_long;
                if( i != 0 && i > 0 && i < 11 )
                    if( dmpEffects[i-1].type ) currentEffect = i;
            }
        }
    }
    if( argc < 2 )
    {
        drawScreen();
        writeStr(" Syntax :    DMP modulename [options] [modulename] [@listfile] [options]",0,1,0x1F,80);
        writeStr("",0,2,0x1F,80);
        writeStr(" Use -H for more information",0,3,0x1F,80);
        cursorxy(0,4);
        exit(0);
    }
    mcpstrc.options = 0;
    fileList = CreateQueue();
    if(dmpenv == NULL) dmpenv = getenv("DMP");
    if( defaultDir )
    {
        fnsplit(defaultDir,drive,NULL,NULL,NULL);
        if(drive[0]) setdisk(toupper(drive[0])-'A');
        chdir(defaultDir);
    }
    if( dmpenv != NULL )
    {
        for( i = 0; dmpenv[i] != 0; i++ )
        {
            if( isspace(dmpenv[i]) ) continue;
            if( dmpenv[i] == '/' || dmpenv[i] == '-' )
            switch(toupper(dmpenv[i+1]))
            {
                case 'S' :
                    sscanf(&dmpenv[i+2],"%u",&a);
                    if( a >= 4 && a <= 64 ) a = rate = a*1000;
                    if( a < 4000 ) rate = 4000;
                    else rate = a;
                    break;
                case 'O' :
                    scramble = 1;
                    break;
                case 'I' :
                    sscanf(&dmpenv[i+2],"%u",&intnum);
                    break;
                case 'P' :
                    sscanf(&dmpenv[i+2],"%x",&port);
                    break;
                case 'C' :
                    sscanf(&dmpenv[i+2],"%u",&a);
                    if( a > 0 && a < 13 ) sDevice = a;
                    break;
                case 'L' :
                    looping = 0;
                    break;
                case 'Q' :
                    mcpstrc.options |= MCP_QUALITY;
                    break;
                case 'M' :
                    doMono = 1;
                    break;
                case 'D' :
                    sscanf(&dmpenv[i+2],"%u",&dmach);
                    break;
                case 'T' :
                    sscanf(&dmpenv[i+2],"%u",&bufsize);
                    if( bufsize > 32000 ) bufsize = 32000;
                    break;
                case 'E' :
                    loadOpt |= LM_OLDTEMPO;
                    break;
                case 'A' :
                    sscanf(&dmpenv[i+2],"%u",&amp);
                    if( amp > 1024 ) amp = 1024;
                    break;
                case '8' :                      // Use 8-bit sound
                    bit8 = 1;
                    break;
                case 'B' :
                    emsOK = 0;
                    break;
                case 'N' :
                    sscanf(&dmpenv[i+2],"%u",&defpan);
                    if( defpan != 100 && defpan > 63 ) defpan = 64;
                    break;
                case 'Z' :
                    sscanf(&dmpenv[i+2],"%u",&scrSize);
                    break;
                case 'G' :
                    if( toupper(dmpenv[i+2]) == 'T' ) gusTimer = 0;
                    else gusDMA = 0;
                    break;
                case 'F' :
                    sscanf(&dmpenv[i+2],"%u",&currentEffect);
                    break;
            }
        }
    }
    for( t = 1; t < argc; t++)
    {
        strptr = argv[t];
        if( strptr[0] == '/' || strptr[0] == '-' )
        {
            switch(toupper(strptr[1]))
            {
                case 'S' :
                    sscanf(&strptr[2],"%u",&a);
                    if( a >= 4 && a <= 64 ) a = rate = a*1000;
                    if( a < 4000 ) rate = 4000;
                    else rate = a;
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
                case 'C' :
                    sscanf(&strptr[2],"%u",&a);
                    if( a > 0 && a < 13 ) sDevice = a;
                    break;
                case 'L' :
                    looping = 0;
                    break;
                case 'Q' :
                    mcpstrc.options |= MCP_QUALITY;
                    break;
                case 'M' :
                    doMono = 1;
                    break;
                case 'D' :
                    sscanf(&strptr[2],"%u",&dmach);
                    break;
                case 'T' :
                    sscanf(&strptr[2],"%u",&bufsize);
                    if( bufsize > 32000 ) bufsize = 32000;
                    break;
                case 'E' :
                    loadOpt |= LM_OLDTEMPO;
                    break;
                case 'A' :
                    sscanf(&strptr[2],"%u",&amp);
                    if( amp > 1024 ) amp = 1024;
                    break;
                case '8' :
                    bit8 = 1;                   // Use 8-bit sound
                    break;
                case 'B' :
                    emsOK = 0;
                    break;
                case 'N' :
                    sscanf(&strptr[2],"%u",&defpan);
                    if( defpan != 100 && defpan > 63 ) defpan = 64;
                    break;
                case 'W' :
                    strcpy(shellstr,&strptr[2]);
                    dosshell = 1;
                    break;
                case 'Z' :
                    sscanf(&strptr[2],"%u",&scrSize);
                    break;
                case 'X' :
                    quietMode = 1;
                    break;
                case 'G' :
                    if( toupper(strptr[2]) == 'T' ) gusTimer = 0;
                    else gusDMA = 0;
                    break;
                case 'F' :
                    sscanf(&strptr[2],"%u",&currentEffect);
                    break;
            }
        }
        else if( strptr[0] == '@' )
        {
            if((f = fopen(&strptr[1],"rt")) != NULL)
            {
                do {
                    a = fscanf(f,"%s",fileName);
                    if( a == 1 ) appendFileList( fileName );
                } while( a == 1 );
                fclose(f);
            }
        }
        else appendFileList( strptr );
    }
#ifdef _USE_EMS
    if( emsOK ) isEMS = (emsInit(128,1024) == 0);
#endif
    drawScreen();
    updatePalette();
    cursorxy(0,1);
    if( fileCount > 1 && scramble )
    {
        for(i = 0; i < fileCount; i++)
        {
            b = random(fileCount);
            if( i != b )
            {
                for( a = 0,i1 = fileList->firstItem; a < i; a++,i1 = i1->next );
                for( a = 0,i2 = fileList->firstItem; a < b; a++,i2 = i2->next );
                temp = i1->data;
                i1->data = i2->data;
                i2->data = temp;
            }
        }
    }
    if( ishelp )
    {
        showHelp(1,1);
        cursorxy(0,23);
        exit(0);
    }
    if( scrSize == 25 || scrSize == 50 )
    {
        setTextmode(mono ? MONO : scrSize == 25 ? C80 : C4350);
        updatePalette();
        setBlink(0);
    }
    scrSize = (peekb(0x40,0x84) < 25) ? 25 : 50;
    if( fileCount == 0 )
    {
        writeStr(" Syntax :    DMP [options] modulename [modulename] [@listfile] [options]",0,1,0x1F,80);
        cursorxy(0,2);
        exit(0);
    }
    if( !multitasking || (scard.ID == ID_GUS && gusTimer == 0))
    {
        tsInit();               // init Timer Service
        atexit(tsClose);
    }
    if( intnum != 0 || port != 0 || dmach != 16 || sDevice == 10 || sDevice == 11 || sDevice == 12)
    {
        memset(&scard,0,sizeof(SOUNDCARD));
        scard.dmaChannel = (dmach != 16 ) ? dmach : 1;
        scard.sampleSize = 1;
        scard.minRate = 4000;
        scard.maxRate = 22050;
        if( intnum == 0 ) intnum = 7;
        switch(sDevice)
        {
            case 1 :
                scard.ID = ID_SB;
                break;
            case 2 :
                scard.ID = ID_SBPRO;
                scard.maxRate = 44100;
                scard.stereo = (doMono == 1) ? 0 : 1;
                scard.mixer = 1;
                break;
            case 3 :
                scard.ID = ID_PASPLUS;
                scard.stereo = (doMono == 1) ? 0 : 1;
                if( intnum==0 ) intnum = 7;
                if( port==0 ) port = 0x388;
                scard.maxRate = 44100;
                break;
            case 4 :
                scard.ID = ID_PAS16;
                scard.sampleSize = (bit8) ? 1 : 2;
                scard.stereo = (doMono == 1) ? 0 : 1;
                if( intnum==0 ) intnum = 7;
                if( port==0 ) port = 0x388;
                scard.maxRate = 44100;
                break;
            case 5 :
                scard.ID = ID_SB16;
                scard.sampleSize = (bit8) ? 1 : 2;
                scard.stereo = (doMono == 1) ? 0 : 1;
                if( intnum==0 ) intnum = 5;
                scard.maxRate = 44100;
                break;
            case 6 :
                scard.ID = ID_DAC;
                scard.sampleSize = 1;
                scard.stereo = 0;
                scard.dmaChannel = 0;
                if( port == 0 ) port = 0x378;
                scard.maxRate = 60000;
                break;
            case 7 :
                scard.ID = ID_ARIA;
                scard.sampleSize = (bit8) ? 1 : 2;
                scard.stereo = 1;
                if( port == 0 ) port = 0x290;
                scard.maxRate = 44100;
                break;
            case 8 :
                scard.ID = ID_WSS;
                scard.sampleSize = (bit8) ? 1 : 2;
                scard.stereo = 1;
                if( port == 0 ) port = 0x530;
                scard.maxRate = 44100;
                break;
            case 9 :
                detectGUS(&scard);
                scard.ID = ID_GUS;
                scard.sampleSize = 0;
                if( port == 0 ) port = 0x220;
                scard.stereo = 1;
                scard.extraField[2] = gusDMA;
                scard.extraField[3] = gusTimer;
                break;
            case 10 :
                scard.ID = ID_DAC;
                scard.sampleSize = 1;
                scard.stereo = 0;
                scard.dmaChannel = 0;
                port = 0x42;
                scard.maxRate = 44100;
                break;
            case 11 :
                scard.ID = ID_DAC;
                scard.sampleSize = 1;
                scard.stereo = 1;
                scard.dmaChannel = 1;
                scard.maxRate = 60000;
                break;
            case 12 :
                scard.ID = ID_DAC;
                scard.sampleSize = 1;
                scard.stereo = 1;
                scard.dmaChannel = 2;
                if( port == 0 ) port = 0x378;
                scard.maxRate = 60000;
                break;
            default :
                errorexit("You have to specify card type with -c parameter!");
                break;
        }
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
            case ID_ARIA :
                sdi = SDI_ARIA;
                if(doMono) scard.stereo = 0;
                break;
            case ID_WSS :
                sdi = SDI_WSS;
                if(doMono) scard.stereo = 0;
                break;
            case ID_DAC :
                sdi = SDI_DAC;
                break;
            case ID_GUS :
                break;
            default :
                errorexit("Invalid Sound Device Interface");
                break;
        }
        if( scard.ID != ID_GUS )
            if(mcpInitSoundDevice(sdi,&scard)) errorexit("Unable to use the sound card");
    }
    else
    {
        if( sDevice == 0 || sDevice == 9 ) a = detectGUS(&scard);
        if( a != 0 && (sDevice == 0 || sDevice == 3 || sDevice == 4) ) a = detectPAS(&scard);
        if( a != 0 && (sDevice == 0 || sDevice == 7) ) a = detectAria(&scard);
        if( a != 0 && (sDevice == 0 || sDevice == 1 || sDevice == 2 || sDevice == 5) ) a = detectSB(&scard);
        if( a == 0 )
        {
            sprintf(str,"%s has been detected at %Xh using IRQ %d on DMA channel %d",\
                scard.name,scard.ioPort,scard.dmaIRQ,scard.dmaChannel);
            writeStr(str,0,1,0x1E,80);
            sprintf(str,"version is %d.%02d",scard.version>>8,scard.version&255);
            writeStr(str,0,2,0x1E,80);
            delay(500);
            switch( scard.ID )
            {
                case ID_SB :
                    sdi = SDI_SB;
                    break;
                case ID_SBPRO :
                    sdi = SDI_SBPro;
                    scard.stereo = (doMono) ? 0 : 1;
                    break;
                case ID_PAS :
                case ID_PASPLUS :
                case ID_PAS16 :
                    sdi = SDI_PAS;
                    scard.sampleSize = (bit8) ? 1 : 2;
                    scard.stereo = (doMono) ? 0 : 1;
                    break;
                case ID_SB16 :
                    scard.sampleSize = (bit8) ? 1 : 2;
                    sdi = SDI_SB16;
                    scard.stereo = (doMono) ? 0 : 1;
                    break;
                case ID_ARIA :
                    scard.sampleSize = (bit8) ? 1 : 2;
                    sdi = SDI_ARIA;
                    scard.stereo = (doMono) ? 0 : 1;
                    break;
                case ID_GUS :
                    scard.extraField[2] = gusDMA;
                    scard.extraField[3] = gusTimer;
                    break;
                default :
                    errorexit("Invalid Sound Device Interface");
                    break;
            }
            if(scard.ID != ID_GUS) if(mcpInitSoundDevice(sdi,&scard))
                errorexit("Unable to use the sound card");
        }
        else errorexit("Couldn't find sound card");
    }
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
    vdsOK = vdsInit() == 0;
    if(scard.ID == ID_SBPRO)
    {
        mixerInit(MIX_SBPRO, scard.ioPort);
        mixerSet(MIX_FILTEROUT, filter = 0);
        atexit(resetMixer);
    }
    if( scard.ID != ID_GUS )
    {
        a = MCP_TABLESIZE;
        mcpstrc.reqSize = 0;
        if( bufsize == 0 )
        {
            bufsize = (2500*(int)scard.sampleSize<<(int)scard.stereo)*(long)rate/22000l;
            mcpstrc.reqSize = 0;
            if( multitasking )
            {
                if( bufsize < 16384 ) bufsize = 16384;
            }
        }

        // Is quality mode on?
        if( mcpstrc.options & MCP_QUALITY )
        {
            // 8-bit or 16-bit sound card?
            if( scard.sampleSize == 1 ) a += MCP_QUALITYSIZE;
            else
            {
                a = MCP_TABLESIZE16+MCP_QUALITYSIZE16;
                useAutoGain = 1;
                if( amp == 0 ) amp = 32;
                for( t = 0; t < 32; t++ ) autoGain[t] = amp*(t+1)/4;
            }
        }
        if( (long)bufsize+(long)a > 65500 ) bufsize = 65500-a;
        if((temp = malloc(a+bufsize)) == NULL) errorexit("Not enough memory");
        tempSeg = ((long)(FP_SEG(temp))*0x10+FP_OFF(temp)+0x10)/0x10;
        if( getCPUType() & 4 ) mcpstrc.options |= MCP_486;
        mcpstrc.bufferSeg = tempSeg;
        if( vdsOK && scard.ID != ID_DAC )
        {
            dds.size = bufsize;
            dds.segment = tempSeg;
            dds.offset = 0;
            if(vdsLockDMA(&dds)==0)
            {
                mcpstrc.bufferPhysical = dds.address;
                vdsDisableDMATranslation(scard.dmaChannel);
                vdsOK = 2;
            }
            else mcpstrc.bufferPhysical = (ulong)tempSeg<<4;
        }
        else mcpstrc.bufferPhysical = (ulong)tempSeg<<4;
        mcpstrc.bufferSize = bufsize;
        mcpstrc.samplingRate = rate;
        if(mcpInit(&mcpstrc)) errorexit(" Couldn't initialize MultiChannelPlayer");
        atexit(mcpClose);
        cdiInit();
        cdiRegister(&CDI_MCP,0,31);
    }
    else
    {
        gusInit(&scard);
        atexit(gusClose);
        gushmInit();
        cdiInit();
        cdiRegister(&CDI_GUS,0,31);
        if(!gusTimer) tsAddRoutine(gusInterrupt,GUS_TIMER);
    }
    if(ampInit(0)) errorexit(" Couldn't initialize AdvancedModulePlayer");
    atexit(ampClose);
    if( !multitasking )
    {
        tsAddRoutine(ampInterrupt,AMP_TIMER);
        if( scard.ID == ID_DAC ) setDACTimer(tsGetTimerRate());
    }
    if( scard.ID != ID_GUS )
    {
        mcpStartVoice();                // Start voice output
        rate = mcpGetSamplingRate();
    }
    else
    {
        gusStartVoice();
        rate = gusGetSamplingRate();
    }
    drawScreen();
    cursorxy(0,lines+1);
    startTime = timer();
    ch = 0; module = NULL;
    ActivateEffect( currentEffect );
    do
    {
        if( fileList->firstItem->next && ampGetPattern() == module->patternCount - 1 )
            ampSetMasterVolume(-1,(ampGetRow() < 64 ) ? volume-ampGetRow()*volume/64 : 0);
        if( (ampGetModuleStatus() & MD_PLAYING) == 0 )
        {
            do
            {
                drawScreen();
                mcpClearBuffer();
                ampFreeModule(module);
                if(heapcheck() == _HEAPCORRUPT )
                {
                    puts("Heap is corrupted!\n");
                    exit(-1);
                }
                fileItem = GetNextFile();
                fnsplit(fileItem->fileName,NULL,NULL,szName,szExt);
                sprintf(str,"Loading %s%s . . .",szName,szExt);
                writeStr(str,0,1,0x1F,80);
                cursorxy(0,2);
                if(heapcheck() == _HEAPCORRUPT )
                {
                    puts("Heap is corrupted!\n");
                    exit(-1);
                }
                b = loader(fileItem->fileName);
                if( fileItem->deleteIt )
                {
                    remove(fileItem->fileName);
                    free(fileItem);
                }
                if(heapcheck() == _HEAPCORRUPT )
                {
                    puts("Heap is corrupted!\n");
                    exit(-1);
                }
                memset(instrUsed,' ',31);
                cursorxy(0,lines+1);
            } while( b < MERR_NONE );
            if( b == MERR_NONE )
            {
                startTime = timer();
                ampSetMasterVolume(-1,volume);
                cCount = module->channelCount;
                if( useAutoGain )
                {
                    for( i = 1; i < 33; i++ ) voltable[i-1] = i*autoGain[cCount-1]/32;
                    cdiSetupChannels(0,cCount,voltable);
                }
                else if( amp )
                {
                    for( i = 1; i < 33; i++ ) voltable[i-1] = i*amp/32;
                    cdiSetupChannels(0,cCount,voltable);
                }
                else cdiSetupChannels(0,cCount,0);
                thisChan = 0;
                if(ampPlayModule(module,(fileCount == 1 && looping == 1) ? PM_LOOP : 0) == -2 )
                {
                    writeStr("Not enough GUS memory to play the module (ESC to quit, ENTER to continue)",0,2,0x1C,80);
                    key = bioskey(0);
                    ch = toupper(key);
                    if( ch == 27 ) errorexit("Not enough GUS memory to play the module");
                    ampStopModule();
                }

                if( defpan != 64 )
                {
                    for( i = 0; i < module->channelCount; i++ )
                    {
                        if( defpan == 100 ) a = defpan;
                        else
                        {
                            b = module->channelPanning[i];
                            if( b == PAN_MIDDLE ) a = PAN_MIDDLE;
                            else if( b > PAN_MIDDLE ) a = defpan;
                            else a = -defpan;
                        }
                        ampSetPanning(i,a);
                    }
                }
                if( scard.ID != ID_GUS )
                {
                    rate = mcpGetSamplingRate();
                }
                else
                {
                    rate = gusGetSamplingRate();
                }
            }
            while(bioskey(1)) bioskey(0);       // Empty the keyboard buffer
            }
        drawTracks();
        update();
        releaseSlice();
        if( dosshell )
        {
            if( !multitasking )
            {
                drawScreen();
                writeStr("Type EXIT to return to DMP . . .",0,1,0x1F,80);
                cursorxy(0,2);
                setBlink(1);
                if( shellstr[0] == 0 ) a = spawnlp(P_WAIT,getenv("COMSPEC"),NULL,NULL);
                else a = spawnlp(P_WAIT,getenv("COMSPEC"),"","/C",shellstr,NULL);
                if( a == 68 ) quit(68);         // Errorlevel == 68?
                setTextmode(mono ? MONO : scrSize == 25 ? C80 : C4350);
                updatePalette();
                shellstr[0] = 0;                // Erase string
                setBlink(0);
                drawScreen();
                cursorxy(0,lines+1);
            }
            dosshell = 0;
        }
        if( bioskey(1) )
        {
            key = bioskey(0);
            ch = toupper(key);
            if( ampGetModuleStatus() & MD_PAUSED )
            {
                ampResumeModule();
                mcpResumeVoice();
                startTime += timer() - tempTime;
                while(bioskey(1)) bioskey(0);   // Empty the keyboard buffer
            }
            else
            {
                switch( ch )
                {
                    case 0 :
                        a = key>>8;
                        if( a >= 0x3B && a <= 0x44 )
                            ampSetMasterVolume(-1, volume = (a - 0x3A)*64/10 );
                        switch(a)
                        {
                            case 0x4B :
                                ampBreakPattern(-1);
                                ampSetMasterVolume(-1, volume );
                                break;
                            case 0x4D :
                                ampBreakPattern(1);
                                break;
                            case 0x48 :
                                if( thisChan ) thisChan--;
                                break;
                            case 0x50 :
                                if( thisChan < module->channelCount-1 )
                                    thisChan++;
                                break;
                        }
                        break;
                    case '+':
                        volume +=2 ;
                    case '-' :
                        volume--;
                        if( volume < 0 ) volume = 0;
                        if( volume > 64 ) volume = 64;
                        ampSetMasterVolume(-1, volume );
                        break;
                    case 'P' :
                        if( !(ampGetModuleStatus() & MD_PAUSED) )
                        {
                            ampPauseModule();
                            mcpPauseVoice();
                            tempTime = timer();
                        }
                        break;
                    case 'D' :
                        if( multitasking ) break;
                        drawScreen();
                        writeStr("Type EXIT to return to DMP . . .",0,1,0x1F,80);
                        cursorxy(0,2);
                        setBlink(1);
                        system("");
                        setTextmode(mono ? MONO : scrSize == 25 ? C80 : C4350);
                        updatePalette();
                        setBlink(0);
                        drawScreen();
                        cursorxy(0,lines+1);
                        break;
                    case 'H' :
                        showHelp(1,2);
                        while(!bioskey(1))
                        {
                            update();
                            releaseSlice();
                        }
                        while(bioskey(1)) bioskey(0);           // Read keys
                        break;
                    case 'N' :
                        ampStopModule();
                        break;
                    case 'S' :
                        if( solo )          // Solo mode on?
                        {
                            if( thisChan == soloChan )
                            {
                                for( i = 0; i < module->channelCount; i++ )
                                    ampUnmuteTrack(i);
                                solo = 0;
                            }
                            else
                            {
                                for( i = 0; i < module->channelCount; i++ )
                                    ampMuteTrack(i);
                                ampUnmuteTrack(soloChan = thisChan);
                            }
                        }
                        else
                        {
                            for( i = 0; i < module->channelCount; i++ )
                                ampMuteTrack(i);
                            ampUnmuteTrack(soloChan = thisChan);
                            solo = 1;
                        }
                        break;
                    case 'F' :
                        if( scard.ID != ID_SBPRO ) break;
                        filter = 1-filter;
                        mixerSet(MIX_FILTEROUT,filter);
                        break;
                    case '[' :
                        a = ampGetTempo();
                        if( (a & 0xFF) > 1 ) ampSetTempo(a-1);
                        break;
                    case ']' :
                        a = ampGetTempo();
                        if( (a & 0xFF) < 32 ) ampSetTempo(a+1);
                        break;
                    case '{' :
                        a = ampGetTempo();
                        if( (a & 0xFF00) > 32*256 ) ampSetTempo(a-256);
                        break;
                    case '}' :
                        a = ampGetTempo();
                        if( (ushort)(a & 0xFF00) < 255u*256 ) ampSetTempo(a+256);
                        break;
                    case 'M' :
                        ampSetPanning(thisChan,PAN_MIDDLE);
                        break;
                    case 'L' :
                        ampSetPanning(thisChan,PAN_LEFT);
                        break;
                    case 'R' :
                        ampSetPanning(thisChan,PAN_RIGHT);
                        break;
                    case 'U' :
                        ampSetPanning(thisChan,PAN_SURROUND);
                        break;
                    case 'V' :
                        volumeBar ^= 1;
                        break;
                    case '0' :
                        if( ampGetTrackStatus(thisChan) & TR_MUTED ) ampUnmuteTrack( thisChan );
                        else ampMuteTrack( thisChan );
                        break;
                    case ',' :
                        b = ampGetTrackData( thisChan )->panning;
                        if( b == PAN_SURROUND ) break;
                        if( b >= PAN_LEFT + 3 ) ampSetPanning(thisChan,b-3);
                        break;
                    case '.' :
                        b = ampGetTrackData( thisChan )->panning;
                        if( b == PAN_SURROUND ) break;
                        if( b <= PAN_RIGHT - 3 ) ampSetPanning(thisChan,b+3);
                        break;
                    case 'Z' :
                        scrSize = (peekb(0x40,0x84) < 25) ? 50 : 25;
                        setTextmode(mono ? MONO : scrSize == 25 ? C80 : C4350);
                        updatePalette();
                        setBlink(0);
                        drawScreen();
                        cursorxy(0,lines+1);
                        break;
                    case 'A' :
                        cursorxy(0,1);
                        printf("%2x",inp(scard.ioPort+6));
                        getch();
                        break;
                    case '!' :
                        dumpFreeHeap();
                        getch();
                        break;
                    case '|' :
                        cursorxy(0,1);
                        gushmShowHeap();
                        getch();
                        break;
                    case 'E' :
                        if( scard.ID == ID_GUS ) break;
                        SelectEffect();
                        drawTracks();
                        break;
                    case '#' :
                        while(!bioskey(1))
                        {
                            cursorxy(0,0);
                            cprintf("DMA pos : %5ld",65536L-(unsigned)dmaGetPos());
                        }
                        bioskey(0);
                        break;
                }
                if( ch >= '1' && ch <= module->channelCount+'0' && ch <= '9' )
                {
                    a = ch - '1';
                    if( ampGetTrackStatus(a) & TR_MUTED ) ampUnmuteTrack( a );
                    else ampMuteTrack( a );
                }
            }
        }
    } while ( ch != 27 );
    quit(1);
    return 0;
}
