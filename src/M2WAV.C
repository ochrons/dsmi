// This is EXAMPLE3.C
//
// Tutorial example for DSMI
//
// (C) 1993 Otto Chrons

#include "dsmi.h"

void main()
{
    MODULE    	*module;
    SOUNDCARD	scard;

    if( initDSMI(22000,2048,0,&scard) ) return;   // Error
    module = ampLoadAMF("EXAMPLE.AMF",0);
    if( scard.ID != ID_GUS ) mcpStartVoice();
    else gusStartVoice();

    cdiSetupChannels(0,module->channelCount,0);

    ampPlayModule(module,PM_LOOP);   // Play looping
    getch();
    ampStopModule();
}
