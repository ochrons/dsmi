// ************************************************************************
// *
// *    File        : DETPAS.H
// *
// *    Description : Detection routines for Media Vision cards
// *
// *    Copyright (C) 1993 Otto Chrons
// *
// ************************************************************************

#ifndef __DEF_DETECTPAS
#define __DEF_DETECTPAS

#ifndef __DEF_MCP
#include "mcp.h"
#endif

#ifdef __cplusplus
extern "C" {
#endif

int cdecl detectPAS( SOUNDCARD *sCard );

#ifdef __cplusplus
}
#endif

#endif
