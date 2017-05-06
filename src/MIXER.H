// ************************************************************************
// *
// *    File        : MIXER.H
// *
// *    Description : Definitions for sound mixer interface
// *
// *    Copyright (C) 1992 Otto Chrons
// *
// ************************************************************************

#ifndef __MIXER_H
#define __MIXER_H

#ifndef __DSMIDEF_H
#include "dsmidef.h"
#endif

enum
{
    MIX_RESET, MIX_MASTERVOL, MIX_DACVOL, MIX_FMVOL, MIX_CDVOL,\
    MIX_MICVOL, MIX_LINEVOL, MIX_STEREO, MIX_FILTEROUT, MIX_FILTERIN,\
    MIX_INPUTLINE, MIX_FM_MODE
};

#define MIX_LEFT 0x40
#define MIX_RIGHT 0x80
#define MIX_BOTH 0xC0

#define MIX_IN_MIC 1
#define MIX_IN_CD 2
#define MIX_IN_LINE 3
#define MIX_FILTERHIGH 0x40

#define MIX_FM_NORMAL 0
#define MIX_FM_LEFT 1
#define MIX_FM_RIGHT 2
#define MIX_FM_MUTE 3

#define MIX_STEREO_ON 1
#define MIX_STEREO_OFF 0
#define MIX_MONO 0

#define MIX_SBPRO 1

#ifdef __cplusplus
extern "C" {
#endif

void cdecl mixerInit(uchar type, unsigned iobase);
void cdecl mixerSet(uchar function, uchar value);
uchar cdecl mixerGet(uchar function);

#ifdef __cplusplus
}
#endif

#endif
