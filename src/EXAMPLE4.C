// This is EXAMPLE4.C
//
// Tutorial example for DSMI
//
// (C) 1993 Otto Chrons

#include <malloc.h>
#include <stdio.h>
#include "dsmi.h"

void main()
{
    MODULE      *module;
    FILE        *f;
    SAMPLEINFO  sample;
    SOUNDCARD   scard;

    if( initDSMI(22000,2048,0,&scard) ) return;   // Error
    if( scard.ID != ID_GUS ) mcpStartVoice();
    else gusStartVoice();
    module = ampLoadAMF("EXAMPLE.AMF",0);
    f = fopen("CHORUS","rb");

    cdiSetupChannels(0,8,0);
    ampPlayModule(module,PM_LOOP);   // Play looping
    sample.sample = malloc(16300);
    fread(sample.sample,16300,1,f);
    fclose(f);
    sample.length = 16300;	// Length of sample
    sample.loopstart = 300;
    sample.loopend = 16300;    // Looping sample
    sample.mode = sample.sampleID = 0;
    cdiDownloadSample(0,sample.sample,sample.sample,sample.length);
    cdiSetInstrument(6,&sample);
    cdiSetInstrument(7,&sample);
    cdiPlayNote(6,8368,64);
    cdiPlayNote(7,8368,64);
    getch();
    ampStopModule();
}
