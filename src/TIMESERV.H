// ************************************************************************
// *
// *    File        : TIMESERV.H
// *
// *    Description : Header file for Timer Service
// *
// *    Copyright (C) 1992-1994 Otto Chrons
// *
// ************************************************************************

#ifndef __DSMIDEF_H
#include "dsmidef.h"
#endif

#ifdef __cplusplus
extern "C" {
#endif

int cdecl tsInit( void );
void cdecl tsClose( void );

int cdecl tsAddRoutine( void (*func)(void), ulong time );
int cdecl tsRemoveRoutine( long tag );
int cdecl tsChangeRoutine( long tag, ulong time );
int cdecl tsSetTimerRate( ulong time );
unsigned int cdecl tsGetTimerRate( void );

#ifdef __cplusplus
}
#endif
