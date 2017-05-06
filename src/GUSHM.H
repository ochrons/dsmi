// ************************************************************************
// *
// *    File        : GUSHM.H
// *
// *    Description : Header file for GUS Heap Manager
// *
// *    Copyright (C) 1993 Otto Chrons
// *
// ************************************************************************

#ifndef __GUSHM_H
#define __GUSHM_H

#ifdef __cplusplus
extern "C" {
#endif

#define GUS_MEMORY -1

typedef long GUSH;

int  cdecl gushmInit( void );
void cdecl gushmClose( void );
void cdecl gushmFreeAll( void );
GUSH cdecl gushmAlloc( long size );
void cdecl gushmFree( GUSH handle );
void cdecl gushmShowHeap( void );

#ifdef __cplusplus
}
#endif

#endif
