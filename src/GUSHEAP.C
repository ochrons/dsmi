// ************************************************************************
// *
// *    File        : GUSHEAP.C
// *
// *    Description : GUS Heap Manager
// *
// *    Copyright (C) 1993 Otto Chrons
// *
// ************************************************************************

#include <malloc.h>
#include <dos.h>
#include <mem.h>
#include <stdlib.h>
#include <stdio.h>

#include "gushm.h"
#include "gus.h"

// ษออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออป
// บ                                                                        บ
// บ    Internal structures                                                 บ
// บ                                                                        บ
// ศออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออผ

typedef unsigned char uchar;

typedef struct gushh {
    GUSH                handle;
    long                start,size;
    struct gushh        *next,*prev;
} GHANDLE;

typedef GHANDLE *PGHANDLE;

// ษออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออป
// บ                                                                        บ
// บ    Internal variables                                                  บ
// บ                                                                        บ
// ศออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออผ

static PGHANDLE first = NULL, last = NULL, handles;
static int      status = 0, handlesAllocated;

// ษออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออป
// บ                                                                        บ
// บ    GUS Heap Manager internal functions                                 บ
// บ                                                                        บ
// ศออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออผ

static PGHANDLE findHandle( GUSH which )
{
    PGHANDLE    handle = first;

    if( !which ) return NULL;           // Zero is not a valid handle
    while( handle->next )
    {
        if( handle->handle == which ) return handle;    // Found!
        handle = handle->next;
    }
    return NULL;                        // Not found...
}

static PGHANDLE createHandle( void )
{
    int         i;
    PGHANDLE     newHandle;

    for( i = 0; i < handlesAllocated; i++ )
    {
        if(handles[i].handle == 0) break;   // Find free handle
    }

    if( i == handlesAllocated )
    {
        newHandle = (GHANDLE*)calloc(handlesAllocated + 128,sizeof(GHANDLE));
        memcpy(newHandle,handles,handlesAllocated*sizeof(GHANDLE));
        handlesAllocated += 128;
        free(handles);
        handles = newHandle;
    }

    handles[i].handle = -1;
    return &handles[i];
}

static void destroyHandle( PGHANDLE handle )
{
    handle->handle = 0;
}

// ษออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออป
// บ                                                                        บ
// บ    GUS Heap Manager interface functions                                บ
// บ                                                                        บ
// ศออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออผ

int cdecl gushmInit( void )
{
    unsigned    a;

    handles = (GHANDLE*)calloc(handlesAllocated = 128,sizeof(GHANDLE));

    first = createHandle();
    last = createHandle();
    first->handle = 32;                 // Setup first handle
    first->start = 32;
    first->size = 32;
    first->next = last;
    first->prev = NULL;
    memcpy(last,first,sizeof(GHANDLE)); // Setup LAST handle
    last->next = NULL;
    last->prev = first;
    last->size = 0;
    gusPoke(257l*1024l,0x55);
    a = 256;
    if( gusPeek(257l*1024l) == 0x55 )
    {
        a = 512;
        gusPoke(513l*1024l,0x55);
        if( gusPeek(513l*1024l) == 0x55 )
        {
            a = 1024;
        }
    }
    last->start = last->handle = 1024l*(long)a;
    status = 1;
    return 0;
}

void cdecl gushmClose( void )                 // Closes GUSHM and frees GUS memory
{
    if( status != 1 ) return;
    status = 0;
    free(handles);
}

void cdecl gushmFreeAll( void )
{
    PGHANDLE    handle = first->next, h;

    if( status != 1 ) return;
    while( handle->next )                       // Free handles
    {
        h = handle->next;
        destroyHandle(handle);
        handle = h;
    }
    first->next = last;
    last->prev = first;
}

GUSH cdecl gushmAlloc( long size )            // Allocates GUS block
{
    PGHANDLE    newHandle,handle = first, best = first;
    long        bestSize=33554432,      // VERY big... (32MB)
                a;
    int         align = 0;

    if( status != 1 ) return -1;

    size = (size+64) & ~31l;            // Align
    while( handle->next )
    {
        a = handle->next->start-(handle->start+handle->size);
        if( (handle->start+handle->size)/262144l != (handle->start+handle->size+size)/262144l )
        {
            a = handle->next->start-((handle->start+handle->size+size) & ~262143l);
            if( a > size && a < bestSize )      // Is it big enough?
            {
                bestSize = a;           // New best fit..
                best = handle;
                align = 1;
            }
        } else
        if( a > size && a < bestSize )  // Is it big enough?
        {
            bestSize = a;               // New best fit..
            best = handle;
            align = 0;
        }
        handle = handle->next;          // Next handle
    }
    if( bestSize == 33554432 ) return (GUSH)0; // Not enough GUS memory

    newHandle = createHandle();
    newHandle->next = best->next;       // Add to the linked list
    best->next = newHandle;
    newHandle->prev = best;
    newHandle->next->prev = newHandle;
                                        // Size, start etc.
    if(align) newHandle->start = (best->start+best->size+size) & ~262143l;
    else newHandle->start = best->start+best->size;
    newHandle->size = size;
    newHandle->handle = newHandle->start;       // Handle number

    return newHandle->start;                    // Return new GUS handle
}

void cdecl gushmFree( GUSH handle )           // Frees GUS block
{
    PGHANDLE    h;

    if( status != 1 ) return;
    h = findHandle( handle );
    if( h == NULL ) return;             // Not valid handle

    if( h->prev ) h->prev->next = h->next;            // Remove from the list
    else first = h->next;
    if( h->next ) h->next->prev = h->prev;
    else last = h->prev;
    destroyHandle(h);                      // Free handle
}

void cdecl gushmShowHeap( void )              // Debugging function
{
    PGHANDLE    h = first;

    if( status != 1 ) return;
    puts("GUS Heap:");
    while(h->next)
    {
        printf("Start: %lu, size: %lu, end: %lu\n",h->start,h->size,h->start+h->size);
        h = h->next;
    }
}
