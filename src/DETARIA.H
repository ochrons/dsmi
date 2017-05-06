// ************************************************************************
// *
// *    File        : DETARIA.H
// *
// *    Description : Detection routine for Aria cards
// *
// *    Copyright (C) 1993 Otto Chrons
// *
// ************************************************************************

#ifndef __DEF_DETECTARIA
#define __DEF_DETECTARIA

#ifndef __DEF_MCP
#include "mcp.h"
#endif

#ifdef __cplusplus
extern "C" {
#endif

int cdecl detectAria( SOUNDCARD *sCard );

#ifdef __cplusplus
}
#endif

#endif
