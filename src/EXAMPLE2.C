// This is EXAMPLE2.C
//
// Tutorial example for DSMI
//
// (C) 1993 Otto Chrons

#include <malloc.h>
#include <stdio.h>
#include "dsmi.h"

void main()
{
    SAMPLEINFO   sample;
    FILE         *f;
    SOUNDCARD    scard;

    if( initDSMI(22000,2048,MCP_MONO,&scard) ) return;   // Error
    if( scard.ID != ID_GUS )
        mcpStartVoice();
    else
        gusStartVoice();

    cdiSetupChannels(0,3,0);

    f = fopen("CHORUS","rb");
    if((sample.sample = malloc(16300)) == NULL) return;
    fread(sample.sample,16300,1,f);
    fclose(f);
    sample.length = 16300;	// Length of sample
    sample.loopstart = 0;
    sample.loopend = 0;    // Indicate no looping
    sample.mode = sample.sampleID = 0;
    cdiDownloadSample(0,sample.sample,sample.sample,sample.length);
    cdiSetInstrument(0,&sample);
    cdiSetInstrument(1,&sample);
    cdiSetInstrument(2,&sample);
    cdiPlayNote(0,8800,32);  // Play at 8800Hz
    cdiPlayNote(1,11087,32);
    cdiPlayNote(2,13185,32);
    getch();                   // Wait for keypress
    cdiStopNote(0);         // Stop voice
    cdiStopNote(1);         // Stop voice
    cdiStopNote(2);         // Stop voice
}
