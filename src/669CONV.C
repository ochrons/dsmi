// ************************************************************************
// *
// *    File        : 669CONV.C
// *
// *    Description : Composer 669module converter for M2AMF
// *
// *    Copyright (C) 1993 Otto Chrons
// *
// ************************************************************************

#define CONVERSION

#include "669load.c"

int convert669(FILE *f, MODULE *mod)
{
    int         a;

    file = f; module = mod;
    module->size = 0;
    lastChan = 0;
    hdr = D_malloc(sizeof(HEADER669));
    patUsed = D_malloc(256);
    if(( a = loadHeader()) == MERR_NONE )
        if(( a = loadInstruments()) == MERR_NONE )
            if(( a = loadPatterns()) == MERR_NONE )
                if(( a = loadSamples()) == MERR_NONE );
    D_free(hdr);
    D_free(patUsed);
    return a;
}
