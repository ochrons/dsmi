// ************************************************************************
// *
// *    File        : FARCONV.C
// *
// *    Description : Module converter for M2AMF
// *
// *    Copyright (C) 1993 Otto Chrons
// *
// ************************************************************************

#define CONVERSION

#include "farload.c"

int convertFAR(FILE *f, MODULE *mod)
{
    int         a;

    file = f; module = mod;
    module->size = 0;
    hdr = D_malloc(sizeof(HEADERFAR));
    hdr2 = D_malloc(sizeof(HEADERFAR2));
    patUsed = D_malloc(256);
    if(( a = loadHeader()) == MERR_NONE )
        if(( a = loadPatterns()) == MERR_NONE )
            if(( a = loadSamples()) == MERR_NONE );
    D_free(hdr);
    D_free(hdr2);
    D_free(patUsed);
    return a;
}
