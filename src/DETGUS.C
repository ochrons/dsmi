// ************************************************************************
// *
// *    File        : DETGUS.C
// *
// *    Description : Detects GUS
// *
// *    Copyright (C) 1993 Otto Chrons
// *
// ************************************************************************

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include "detgus.h"

int cdecl detectGUS(SOUNDCARD *scard)
{
    char        *ptr;
    short       DMA,DMA2,IRQ,IRQ2;

    ptr = getenv("ULTRASND");
    if (ptr == NULL)
    {
        return(-1);
    }
    else
    {
        sscanf(ptr,"%x,%d,%d,%d,%d",    &scard->ioPort,
                                        &DMA,
                                        &DMA2,
                                        &IRQ,
                                        &IRQ2);
        scard->dmaChannel = DMA;
        scard->dmaIRQ = IRQ;
        strcpy(scard->name,"Gravis Ultrasound");
        scard->ID = ID_GUS;
        scard->minRate = 19293;
        scard->maxRate = 44100;
        scard->stereo = 1;
        scard->mixer = 1;
        scard->sampleSize = 1;
        scard->version = 0x100;
        scard->extraField[0] = (uchar)DMA2;
        scard->extraField[1] = (uchar)IRQ2;
        return 0;
    }
}

