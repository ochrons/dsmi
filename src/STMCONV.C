// ************************************************************************
// *
// *    File        : STMCONV.C
// *
// *    Description : Scream Tracker module converter for M2AMF
// *
// *    Copyright (C) 1992 Otto Chrons
// *
// ************************************************************************

#define CONVERSION

#include "stmload.c"

int convertSTM(FILE *file, MODULE *module)
{
    int         a;

    loadOptions = LM_IML;
    module->tempo = 125;
    module->speed = 6;
    if((a = loadInstruments(file,module))!=0) return a;
    if((a = loadPatterns(file,module))!=0) return a;
    if((a = loadTracks(file,module))!=0) return a;
    if((a = loadSamples(file,module))!=0) return a;
    return 0;
}
