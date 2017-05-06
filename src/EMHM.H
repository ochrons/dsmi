// ************************************************************************
// *
// *    File        : EMHM.H
// *
// *    Description : Header file for EMS Heap Manager
// *
// *    Copyright (C) 1993 Otto Chrons
// *
// ************************************************************************

#ifndef __EMSHM_H
#define __EMSHM_H

#define EMS_ERROR -1
#define EMS_MEMORY -2
#define EMS_PAGE -3
#define EMS_HANDLE -4

#ifdef __cplusplus
extern "C" {
#endif

typedef int EMSH;

int     emsInit( int minmem, int maxmem );
void    emsClose( void );
EMSH    emsAlloc( long size );
void    emsFree( EMSH handle );
void far *emsLock( EMSH handle, long start, unsigned length );
int     emsCopyTo( EMSH handle, void far *ptr, long start, long length );
int     emsCopyFrom( void far *ptr, EMSH handle, long start, long length );
int     emsCopy( EMSH handleTo, EMSH handleFrom, long start1, long start2, long length );
void    emsSaveState( void );
void    emsRestoreState( void );
long    emsHeapfree( void );

#ifdef __cplusplus
}
#endif

#endif
