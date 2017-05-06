// ************************************************************************
// *
// *    File        : SETMIXER.C
// *
// *    Description : Test mixer functions
// *
// *    Copyright (C) 1992 Otto Chrons
// *
// ************************************************************************

#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#pragma hdrstop

#include "mixer.h"

void main(int argc, char *argv[])
{
    int         a,b,t;
    char        ch,str[80];

    puts("SETMIXER, SB Pro mixer's tester (C) 1992 Otto Chrons");

    initMixer(MIX_SBPRO,0x220);
    b = argc;
    a = atoi(argv[2]);
    switch(toupper(argv[1][0]))
        {
        case 'L' :
            setMixer(MIX_MASTERVOL | MIX_LEFT, a);
            setMixer(MIX_LINEVOL | MIX_LEFT, a);
            setMixer(MIX_DACVOL | MIX_LEFT, a);
            setMixer(MIX_CDVOL | MIX_LEFT, a);
            setMixer(MIX_FMVOL | MIX_LEFT, a);
            break;
        case 'R' :
            setMixer(MIX_MASTERVOL | MIX_RIGHT, a);
            setMixer(MIX_LINEVOL | MIX_RIGHT, a);
            setMixer(MIX_DACVOL | MIX_RIGHT, a);
            setMixer(MIX_CDVOL | MIX_RIGHT, a);
            setMixer(MIX_FMVOL | MIX_RIGHT, a);
            break;
        case 'B' :
            setMixer(MIX_MASTERVOL, a);
            setMixer(MIX_LINEVOL, a);
            setMixer(MIX_DACVOL, a);
            setMixer(MIX_CDVOL, a);
            setMixer(MIX_FMVOL, a);
            setMixer(MIX_MICVOL, a);
            break;
        case 'S' :
            setMixer(MIX_STEREO, a);
            break;
        case 'I' :
            setMixer(MIX_INPUTLINE, a);
            break;
        case 'M' :
            setMixer(MIX_FM_MODE, a);
            break;
        case 'F' :
            setMixer(MIX_FILTEROUT, a);
            setMixer(MIX_FILTERIN, a);
            break;
        }
}
