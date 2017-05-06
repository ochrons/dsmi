// ************************************************************************
// *
// *    File        : DETSB.C
// *
// *    Description : Detects SB, SB Pro and SB 16
// *
// *    Copyright (C) 1994 Otto Chrons
// *
// ************************************************************************

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <ctype.h>
#include "detsb.h"

int cdecl detectSB(SOUNDCARD *scard)
{
    char        *ptr;
    int         i,a,DMA,IRQ,IOaddr,stype;

    ptr = getenv("BLASTER");
    if (ptr == NULL)
    {
        a = detectSB16HW(scard);
#ifndef __C32__
        if( a != 0 ) a = detectSBProHW(scard);
        if( a != 0 ) a = detectSBHW(scard);
#endif
        return(a == 0 ? 0 : -1);
    }
    else
    {
        scard->dmaChannel = 1;
        scard->dmaIRQ = 7;
        scard->ioPort = 0x220;
        strcpy(scard->name,"Sound Blaster");
        scard->ID = ID_SB;
        scard->minRate = 4000;
        scard->maxRate = 44100;
        scard->stereo = 0;
        scard->mixer = 0;
        scard->sampleSize = 1;
        scard->version = 0x100;
        for( i = 0; ptr[i] != 0; i++)
        {
            if(isspace(ptr[i])) continue;
            switch(toupper(ptr[i]))
            {
                case 'A' :
                    sscanf(&ptr[i+1],"%x",&IOaddr);
                    scard->ioPort = IOaddr;
                    break;
                case 'I' :
                    sscanf(&ptr[i+1],"%d",&IRQ);
                    scard->dmaIRQ = IRQ;
                    break;
                case 'H' :
                case 'D' :
                    sscanf(&ptr[i+1],"%d",&DMA);
                    scard->dmaChannel = DMA;
                    break;
                case 'T' :
                    sscanf(&ptr[i+1],"%d",&stype);
                    switch(stype)
                    {
                        case 1 :
                            scard->maxRate = 22222;
                            break;
                        case 3 :
                            scard->version = 0x200;
                            break;
                        case 2 :
                        case 4 :
                        case 5 :
                            scard->ID = ID_SBPRO;
                            scard->stereo = 1;
                            scard->mixer = 1;
                            strcpy(scard->name,"Sound Blaster Pro");
                            break;
                        default :
                            scard->ID = ID_SB16;
                            scard->stereo = 1;
                            scard->mixer = 1;
                            scard->sampleSize = 2;
                            strcpy(scard->name,"Sound Blaster 16");
                            break;
                    }
                    break;
            }
            while(!isspace(ptr[i]) && ptr[i]) i++;
            i--;
        }
        return 0;
    }
}

