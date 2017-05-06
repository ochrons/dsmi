// ************************************************************************
// *
// *    File        : INITDSMI.C
// *
// *    Description : Function initDSMI() for DSMI
// *
// *    Copyright (C) 1993 Otto Chrons
// *
// ************************************************************************
/*
        Revision history of INITDSMI.C

        1.0     16.4.93
                First version.

*/

#include <malloc.h>
#include <stdlib.h>
#include <dos.h>
#include "dsmi.h"
#include "timeserv.h"

int cdecl initDSMI(long rate, long buffer, long options, SOUNDCARD *scard)
{
    int         a;
    ushort      s;
    SDI_INIT    sdi;
    void        *temp;
    MCPSTRUCT   mcpstrc;

    a = detectGUS(scard);
    if( a != 0 ) a = detectPAS(scard);
    if( a != 0 ) a = detectAria(scard);
    if( a != 0 ) a = detectSB(scard);
    if( a == 0 )
    {
        switch( scard->ID )
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
                if(options & MCP_MONO) scard->stereo = 0;
                break;
            case ID_SB16 :
                sdi = SDI_SB16;
                if(options & MCP_MONO) scard->stereo = 0;
                break;
            case ID_ARIA :
                sdi = SDI_ARIA;
                if(options & MCP_MONO) scard->stereo = 0;
                break;
            case ID_GUS :
                break;
            default :
                return INVALID_SDI;
        }
        if(scard->ID != ID_GUS) mcpInitSoundDevice(sdi,scard);
    }
    else return NO_SOUNDCARD;

    tsInit();                                   // init Timer Service
    if( scard->ID != ID_GUS )
    {
        mcpstrc.options = 0;
        s = buffer+MCP_TABLESIZE+16;
        if( options & MCP_QUALITY )
        {
            mcpstrc.options |= MCP_QUALITY;
            s += MCP_QUALITYSIZE;
        }
        if((temp = D_malloc(s)) == NULL) return NO_MEMORY;
        mcpstrc.bufferSeg = ((ulong)(FP_SEG(temp))*0x10l+FP_OFF(temp)+0x10l)/0x10l;
        mcpstrc.bufferPhysical = (ulong)mcpstrc.bufferSeg<<4;
        mcpstrc.bufferSize = buffer;
        mcpstrc.reqSize = buffer;
        mcpstrc.samplingRate = rate;
        if(mcpInit(&mcpstrc)) return MCP_INITERROR;
        atexit((void(*)(void))mcpClose);
        cdiInit();
        cdiRegister(&CDI_MCP,0,31);
    }
    else
    {
        gusInit(scard);                 // Init GUS
        atexit((void(*)(void))gusClose);
        gushmInit();                            // Init GUS heap
        cdiInit();                              // Init CDI
        cdiRegister(&CDI_GUS,0,31);             // Register GUS into CDI
        tsAddRoutine(gusInterrupt,GUS_TIMER);
    }
    atexit((void(*)(void))tsClose);
    if(ampInit(0)) return AMP_INITERROR;        // Init AMP
    atexit((void(*)(void))ampClose);
    tsAddRoutine(ampInterrupt,AMP_TIMER);
    return 0;
}
