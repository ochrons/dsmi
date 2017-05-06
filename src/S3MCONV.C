// ************************************************************************
// *
// *    File        : S3MCONV.C
// *
// *    Description : Scream Tracker 3.0 module converter for M2AMF
// *
// *    Copyright (C) 1993 Otto Chrons
// *
// ************************************************************************

#define CONVERSION

#include "s3mload.c"

int convertS3M(FILE *f, MODULE *mod)
{
    int         a;

    patUsed = D_malloc(256);
    insPtr = D_malloc(512);
    patPtr = D_malloc(512);
    file = f; module = mod;
    module->size = 0;
    lastChan = 0;
    if(( a = loadHeader()) < MERR_NONE ) goto done;
    if(( a = loadInstruments()) < MERR_NONE ) goto done;
    if(( a = loadPatterns()) < MERR_NONE ) goto done;
    if(( a = loadSamples()) < MERR_NONE ) goto done;
    if(module->channelCount > lastChan+1) module->channelCount = lastChan+1;
done:
    D_free(patUsed);
    D_free(insPtr);
    D_free(patPtr);
    return a;
}
