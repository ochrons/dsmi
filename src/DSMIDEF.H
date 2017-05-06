// ************************************************************************
// *
// *    File        : DSMIDEF.H
// *
// *    Description : Common definitions for DSMI
// *
// *    Copyright (C) 1993,1994 Otto Chrons
// *
// ************************************************************************

#ifndef __DSMIDEF_H
#define __DSMIDEF_H

typedef unsigned char uchar;
typedef unsigned short ushort;
typedef unsigned long ulong;

#ifdef __cplusplus
extern "C" {
#endif

void* cdecl D_malloc(ulong size);
void* cdecl D_calloc(ulong count, ulong size);
void  cdecl D_free(void *ptr);

#ifdef __cplusplus
}
#endif

#endif
