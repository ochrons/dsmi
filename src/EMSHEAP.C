// ************************************************************************
// *
// *	File        : EMSHEAP.C
// *
// *	Description : EMS Heap Manager
// *
// *	Copyright (C) 1993 Otto Chrons
// *
// ************************************************************************

#include <alloc.h>
#include <dos.h>
#include <mem.h>
#include <stdlib.h>
#include <stdio.h>

#include "emhm.h"

// ษออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออป
// บ                                                                        บ
// บ	Internal structures                                                 บ
// บ                                                                        บ
// ศออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออผ

#define EMSMOVE_CONV 0
#define EMSMOVE_EMS 1

typedef unsigned char uchar;

typedef struct hh {
    EMSH	handle;
    long	start,size;
    struct hh	*next,*prev;
} HANDLE;

typedef HANDLE *PHANDLE;

typedef struct {			// Structure for memory moves
    long	size;			// to/from EMS
    uchar	srcType;
    unsigned	srcHandle;
    unsigned	srcOffset;
    unsigned	srcSegment;
    uchar	destType;
    unsigned	destHandle;
    unsigned	destOffset;
    unsigned	destSegment;
} EMSMOVE;

// ษออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออป
// บ                                                                        บ
// บ	Define external low-level functions                                 บ
// บ                                                                        บ
// ศออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออผ

int	_emsInit(void);
int	_emsAllocPages(int pages);
int	_emsReallocPages(int pages);
int	_emsMapPages(int lpage, int ppage);
void	_emsSaveState(void);
void	_emsRestoreState(void);
int	_emsQueryFree(void);
unsigned _emsGetFrame(void);
void	_emsMoveMem(EMSMOVE *move);
void	_emsClose(void);

// ษออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออป
// บ                                                                        บ
// บ	Internal variables                                                  บ
// บ                                                                        บ
// ศออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออผ

static long 	emsMAX = 0, emsMEM = 0;
static PHANDLE	first = NULL, last = NULL, locked = NULL;
static int	status = 0, physicalPages[4] = {0,0,0,0}, lowHandle;
static EMSH	nextHandle = 0;
static char far *frame;

static char	EMMname[9] = "EMMXXXX0";

// ษออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออป
// บ                                                                        บ
// บ	EMS Heap Manager internal functions                                 บ
// บ                                                                        บ
// ศออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออผ

static PHANDLE findHandle( EMSH which )
{
    PHANDLE	handle = first;

    if( !which ) return NULL;		// Zero is not a valid handle
    while( handle->next )
    {
	if( handle->handle == which ) return handle;	// Found!
	handle = handle->next;
    }
    return NULL;			// Not found...
}

// ษออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออป
// บ                                                                        บ
// บ	EMS Heap Manager interface functions                                บ
// บ                                                                        บ
// ศออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออผ

int emsInit( int minmem, int maxmem )		// Inits EMSHM
{
    unsigned	a;

    if( status != 0 ) return EMS_ERROR;		// Status must be 0!
    asm {
	mov	ax,3D00h
	mov	dx,offset EMMname
	int	21h
	jc	noems
	mov	bx,ax
	mov	ax,4400h		// Get ioctl
	int	21h
	pushf
	mov	ax,3E00h
	int	21h			// Close file
	popf
	jc	noems
	and	dx,80h
	jz	noems
	jmp	emsfound
    }
noems:
    return EMS_ERROR;
emsfound:
    if(_emsInit()) return EMS_ERROR;		// Low-level init
    emsMEM = maxmem*1024l;
    a = _emsQueryFree()*16l;
    if( a < minmem ) return EMS_MEMORY;
    if( a > maxmem )			// Allocate maximum amount of memory
    {
	if((lowHandle = _emsAllocPages((maxmem+15)/16))<0) return EMS_MEMORY;
    }
    else				// Allocate all free EMS memory
    {
	if((lowHandle = _emsAllocPages(a/16))<0) return EMS_MEMORY;
	emsMEM = a*1024l;
    }
    first = malloc(sizeof(HANDLE));
    last = malloc(sizeof(HANDLE));
    first->handle = 0;			// Setup first handle (NULL)
    first->start = first->size = 0;
    first->next = last;
    first->prev = NULL;
    memcpy(last,first,sizeof(HANDLE));	// Setup LAST handle
    last->next = NULL;
    last->prev = first;
    last->start = emsMEM;
    status = 1;
    frame = MK_FP(_emsGetFrame(),0);
    atexit(emsClose);			// Automatic shutdown
    return 0;
}

void emsClose( void )			// Closes EMSHM and frees EMS memory
{
    PHANDLE	handle = first, h;

    if( status != 1 ) return;
    _emsClose();			// low-level close
    status = 0;
    while( handle )			// Free handles
    {
	h = handle->next;
	free(handle);
	handle = h;
    }
}

EMSH emsAlloc( long size )		// Allocates EMS block
{
    PHANDLE	newHandle,handle = first, best = first;
    long	bestSize=33554432,	// VERY big... (32MB)
		a,b;
    int		align = 0;

    if( status != 1 ) return -1;

    size = (size+15) & ~15l;		// Align
    if( size >= 48*1024l ) align = 1;
    while( handle->next )
    {
	if( align )
	    a = handle->next->start-(((handle->start+16383l) & ~16383l)+handle->size);
	else
	    a = handle->next->start-(handle->start+handle->size);
	if( a > size && a < bestSize )	// Is it big enough?
	{
	    bestSize = a;		// New best fit..
	    best = handle;
	}
	handle = handle->next;		// Next handle
    }
    if( bestSize == 33554432 ) return EMS_MEMORY;
    if( !(newHandle = malloc(sizeof(HANDLE))) ) return EMS_MEMORY;
    newHandle->next = best->next;	// Add to the linked list
    best->next = newHandle;
    newHandle->prev = best;
    newHandle->next->prev = newHandle;
					// Size, start etc.
    newHandle->start = best->start+best->size;
    if( align ) newHandle->start = (newHandle->start+16383l) & ~16383l;
    newHandle->size = size;
    newHandle->handle = ++nextHandle;	// Handle number

    return nextHandle;			// Return new EMS handle
}

void emsFree( EMSH handle )		// Frees EMS block
{
    PHANDLE	h;

    if( status != 1 ) return;
    h = findHandle( handle );
    if( h == NULL ) return;		// Not valid handle

    h->prev->next = h->next;		// Remove from the list
    h->next->prev = h->prev;
    free(h);				// Free handle
}

void far *emsLock( EMSH handle, long start, unsigned length )
{
    PHANDLE	h;
    long	mapped = 0;
    int		page,pPage = 0;
    void far	*ptr;

    if( status != 1 ) return NULL;
    h = findHandle( handle );
    if( h == NULL ) return NULL;	// Not valid handle
    if( start > h->size ) return NULL;
    if( length + start > h->size ) length = h->size - start;
    page = (h->start+start)/16384;	// First logical page
    ptr = frame+(h->start+start-page*16384l);
    mapped = 16384l-h->start+start+page*16384l;
    _emsMapPages(page,pPage);		// Map it
    physicalPages[pPage] = page;
    while( length > mapped && pPage < 3)
    {
	page++; pPage++;
	_emsMapPages(page,pPage);	// Map rest of the pages if needed
	physicalPages[pPage] = page;
	mapped += 16384;
    }
    return ptr;
}

int emsCopyTo( EMSH handle, void far *ptr, long start, long length )
{
    PHANDLE	h;
    EMSMOVE	move;

    if( status != 1 ) return -1;
    if(( h = findHandle(handle)) == NULL) return -4;
    move.size = length;			// Build up the "move" structure
    move.srcType = EMSMOVE_CONV;
    move.srcHandle = 0;
    move.srcOffset = FP_OFF(ptr);
    move.srcSegment = FP_SEG(ptr);
    move.destType = EMSMOVE_EMS;
    move.destHandle = lowHandle;
    move.destOffset = (h->start+start) % 16384;		// Offset within page
    move.destSegment = (h->start+start) / 16384;	// Logical page
    _emsMoveMem(&move);			// Do the move
    return 0;
}

int emsCopyFrom( void far *ptr, EMSH handle, long start, long length )
{
    PHANDLE	h;
    EMSMOVE	move;

    if( status != 1 ) return -1;
    if(( h = findHandle(handle)) == NULL) return -4;
    move.size = length;			// Build up the "move" structure
    move.destType = EMSMOVE_CONV;
    move.destHandle = 0;
    move.destOffset = FP_OFF(ptr);
    move.destSegment = FP_SEG(ptr);
    move.srcType = EMSMOVE_EMS;
    move.srcHandle = lowHandle;
    move.srcOffset = (h->start+start) % 16384;	// Offset within page
    move.srcSegment = (h->start+start) / 16384;	// Logical page
    _emsMoveMem(&move);			// Do the move
    return 0;
}

int emsCopy( EMSH handleTo, EMSH handleFrom, long start1, long start2, long length )
{
    PHANDLE	h1,h2;
    EMSMOVE	move;

    if( status != 1 ) return -1;
    if(( h1 = findHandle(handleTo)) == NULL) return -4;
    if(( h2 = findHandle(handleFrom)) == NULL) return -4;
    move.size = length;			// Build up the "move" structure
    move.destType = EMSMOVE_EMS;
    move.destHandle = lowHandle;
    move.destOffset = (h1->start+start1) % 16384;	// Offset within page
    move.destSegment = (h1->start+start1) / 16384;	// Logical page
    move.srcType = EMSMOVE_EMS;
    move.srcHandle = lowHandle;
    move.srcOffset = (h2->start+start2) % 16384;	// Offset within page
    move.srcSegment = (h2->start+start2) / 16384;	// Logical page
    _emsMoveMem(&move);			// Do the move
    return 0;
}

void emsSaveState( void )
{
    if( status != 1 ) return;
    _emsSaveState();			// Save page map
}

void emsRestoreState( void )
{
    if( status != 1 ) return;
    _emsRestoreState();			// Restore page map
}

long emsHeapfree( void )
{
    if( status != 1 ) return 0;
    return _emsQueryFree()*16384l;	// Get number of free pages
}


void emsShowHeap( void )		// Debugging function
{
    PHANDLE	h = first;

    if( status != 1 ) return;
    puts("EMS Heap:");
    while(h->next)
    {
	printf("Start: %lu, size: %lu, end: %lu\n",h->start,h->size,h->start+h->size);
	h = h->next;
    }
}
