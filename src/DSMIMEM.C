// ************************************************************************
// *
// *    File        : DSMIMEM.C
// *
// *    Description : DSMI memory handling routines
// *
// *    Copyright (C) 1994 Otto Chrons
// *
// ************************************************************************

#include <malloc.h>
#include "dsmidef.h"

#ifdef __C32__

void* cdecl D_malloc(ulong size)
{
    return malloc(size);
}

void* cdecl D_calloc(ulong count, ulong size)
{
    return calloc(count, size);
}

void cdecl D_free(void *ptr)
{
    free(ptr);
}

#else

void* cdecl D_malloc(ulong size)
{
    return farmalloc(size);
}

void* cdecl D_calloc(ulong count, ulong size)
{
    return farcalloc(count, size);
}

void cdecl D_free(void *ptr)
{
    farfree(ptr);
}

#endif
