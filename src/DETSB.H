// ************************************************************************
// *
// *    File        : DETSB.H
// *
// *    Description : Detection routines for SB & SB Pro
// *
// *    Copyright (C) 1993 Otto Chrons
// *
// ************************************************************************

#ifndef __DEF_DETECTSB
#define __DEF_DETECTSB

#ifndef __DEF_MCP
#include "mcp.h"
#endif

#ifdef __cplusplus
extern "C" {
#endif

int cdecl detectSB( SOUNDCARD *sCard );

#ifndef __C32__
int cdecl detectSBHW( SOUNDCARD *sCard );
int cdecl detectSBProHW( SOUNDCARD *sCard );
#endif

int cdecl detectSB16HW( SOUNDCARD *sCard );

#ifdef __cplusplus
}
#endif

#endif
