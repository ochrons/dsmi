#include <stdio.h>
#include <stdlib.h>
#include "dsmi.h"
#include "timeserv.h"

void errorexit(const char *str)
{
    puts(str);
    exit(1);
}

void main(void)
{
    SOUNDCARD   scard;
    MCPSTRUCT   mcpstrc;
    SDI_INIT    sdi;
    unsigned    a,t,i;
    void far    *temp;

/*
** It is always best to look for better cards first, so
** we try to find Pro Audio Spectrum first, then SB Pro
** and finally a normal SB.
*/
    a = detectPAS(&scard);
/*
** If a = 0, then the detection successed, any other
** value means failure
*/
    if( a != 0 ) a = detectSBPro(&scard);
    if( a != 0 ) a = detectSB(&scard);
    if( a != 0 ) errorexit("Couldn't detect any sound card!");
    switch( scard.ID )
        {
        case ID_SOUNDBLASTER :
            sdi = SDI_SB;
            break;
        case ID_SOUNDBLASTERPRO :
            sdi = SDI_SBPro;
            break;
        case ID_PAS :
        case ID_PASPLUS :
        case ID_PAS16 :
            sdi = SDI_PAS;
            break;
        default :
            errorexit("Invalid Sound Device Interface");
            break;
        }
    mcpInitSoundDevice(sdi,&scard);
    mcpstrc.options = MCP_QUALITY;
/*
** Quality mode gives better sound quality when using
** more than four channels.
*/
    a = MCP_TABLESIZE;
    if( mcpstrc.options & MCP_QUALITY ) a += MCP_QUALITYSIZE;
    if((temp = malloc(a+8192+16)) == NULL)
        errorexit("Not enough memory");
/*
** 'temp' is the buffer for volume tables and mixing
** Because we need a SEGMENT, not a pointer, we have
** to do some calculations.
*/
    mcpstrc.bufferSeg = ((long)(FP_SEG(temp))*0x10+FP_OFF(temp)+0x10)/0x10;
    mcpstrc.bufferSize = 8192;
/*
** We use different amounts of mixing buffer for
** different card types e.g. normal SB needs only
** a 1024 byte buffer, whereas PAS 16 in stereo
** mode requires four times that much.
*/
    mcpstrc.reqSize = 1024*(int)scard.sampleSize<<(int)scard.stereo;
    mcpstrc.samplingRate = 21000;
    if(mcpInit(&mcpstrc))
        errorexit(" Couldn't initialize MultiChannelPlayer");
/*
** Now we have to make sure we call mcpClose at the exit
*/
    atexit(mcpClose);
/*
** We will be using Timer Service for interrupt driven music
*/
    tsInit();                   // init Timer Service
    atexit(tsClose);
/*
** Next step is to initialize AMP
*/
    if(ampInit(AMP_INTERRUPT))
        errorexit(" Couldn't initialize AdvancedModulePlayer");
    atexit(ampClose);
}
