// This is EXAMPLE1.C
//
// Tutorial example for DSMI
//
// (C) 1993 Otto Chrons

#include "dsmi.h"

void main()
{
    SAMPLEINFO  sample;
    SOUNDCARD   scard;

    if( initDSMI(22000,2048,0,&scard) ) return;   // Error
    if( scard.ID != ID_GUS )
        mcpStartVoice();
    else
        gusStartVoice();

    cdiSetupChannels(0,2,0);

    sample.sample = 1;         // Pointer to sampledata
    sample.length = 5500;      // Length of sample
    sample.loopstart = 0;
    sample.loopend = 5500;     // Looping
    sample.mode = sample.sampleID = 0;
    cdiDownloadSample(0,sample.sample,sample.sample,sample.length);
    cdiSetInstrument(0,&sample);
    cdiPlayNote(0,8800,32);  // Play at 8800Hz with
                               // half volume
    getch();                   // Wait for keypress
    cdiStopNote(0);         // Stop voice
}

