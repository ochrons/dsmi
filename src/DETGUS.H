// ************************************************************************
// *
// *    File        : DETGUS.H
// *
// *    Description : Detection routines for GUS
// *
// *    Copyright (C) 1993 Otto Chrons
// *
// ************************************************************************

#ifndef __DEF_DETECTGUS
#define __DEF_DETECTGUS

#ifndef __DEF_MCP
#include "mcp.h"
#endif

#ifdef __cplusplus
extern "C" {
#endif

int cdecl detectGUS( SOUNDCARD *sCard );

#ifdef __cplusplus
}
#endif

#endif
