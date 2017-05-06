/* F_STDIO.C General File System functions using STDIO file functions
 *
 * Copyright 1994 Otto Chrons
 *
 * First revision 06-23-94 00:13:43am
 *
 * Revision history:
 *
*/

#include <stdio.h>
#include <malloc.h>

#ifndef __C32__
  #include <dos.h>
#endif

#include "gfilelow.h"

static FILE     **fileTable;             // Table of pointers to FILE
static int      maxFiles;

static char     *filemodes[16] = {"rb","rt","rb","rt","wb","wt","r+b","r+t",
                                  "ab","at","ab","at","a+b","a+t","a+b","a+t"};

int _CDECL InitGeneralFileLow(int maxF)
{
    // Check for valid parameters
    if( maxF == 0 ) maxF = 20;

    // Allocate fileTable and ZERO it...
    fileTable = calloc(maxFiles = maxF,sizeof(FILE*));

    // Succesful?
    if( fileTable == NULL ) return -1;

    return 0;
}

GFILE _CDECL OpenFileLow(const char *name, int modeflags)
{
    int     t;
    FILE    *f;

    // Find a free entry in fileTable
    for( t = 0; t < maxFiles; t++ )
        if( fileTable[t] == NULL ) break;

    // No free handles...
    if( t == maxFiles ) return -1;

    // Open file with correct mode flags
    if((f = fopen(name,filemodes[modeflags & 0xF])) == NULL )
        return -1;

    // Save FILE pointer to table
    fileTable[t] = f;

    // Return handle
    return t;
}

int _CDECL CloseFileLow(GFILE gfile)
{
    // Is it opened?
    if( gfile < 0 ) return -1;
    if( fileTable[gfile] == NULL) return -1;

    // Flush the file
    fflush(fileTable[gfile]);

    // Close the file
    fclose(fileTable[gfile]);

    // Remove the entry from table
    fileTable[gfile] = NULL;
    return 0;
}

long _CDECL ReadFileLow(GFILE gfile, void *buffer, long size)
{
    long    readSize = 0;
    FILE    *file;

    // Check for valid file handle
    if( gfile < 0 ) return -1;
    if( fileTable[gfile] == NULL ) return 0;

    file = fileTable[gfile];
#ifndef __C32__
    // If it's BIG then read 65520 chunks first, only for 16-bit implementation
    while( size > 65520 )
    {
        if(fread(buffer,65520,1,file) != 1) return readSize;
        size -= 65520;
        readSize += 65520;
        buffer = MK_FP(FP_SEG(buffer)+4095,FP_OFF(buffer));
    }
#endif

    // Read the rest
    if(size) if(fread(buffer,size,1,file) != 1) return readSize;

    return size;
}

long _CDECL WriteFileLow(GFILE gfile, void *buffer, long size)
{
    long    writeSize = 0;
    FILE    *file;

    // Check for valid file handle
    if( gfile < 0 ) return -1;
    if( fileTable[gfile] == NULL) return 0;

    file = fileTable[gfile];
#ifndef __C32__
    // If it's BIG then write 65520 chunks first, only for 16-bit implementation
    while( size > 65520 )
    {
        if(fwrite(buffer,65520,1,file) != 1) return writeSize;
        size -= 65520;
        writeSize += 65520;
        buffer = MK_FP(FP_SEG(buffer)+4095,FP_OFF(buffer));
    }
#endif

    // Read the rest
    if(size) if(fwrite(buffer,size,1,file) != 1) return writeSize;

    return size;
}

int _CDECL SeekFileLow(GFILE gfile, long position, int whence)
{
    // Check for valid file handle
    if( gfile < 0 ) return -1;
    if( fileTable[gfile] == NULL) return -1;

    // Do the seek
    return fseek(fileTable[gfile],position,whence);
}

long _CDECL TellFilePositionLow(GFILE gfile)
{
    // Check for valid file handle
    if( gfile < 0 ) return -1;
    if( fileTable[gfile] == NULL) return -1;

    // Return current position
    return ftell(fileTable[gfile]);
}

int _CDECL FlushFileLow(GFILE gfile)
{
    // Check for valid file handle
    if( gfile < 0 ) return -1;
    if( fileTable[gfile] == NULL) return -1;

    // Flush the file
    return fflush(fileTable[gfile]);
}

int _CDECL FileEOFLow(GFILE gfile)
{
    // Check for valid file handle
    if( gfile < 0 ) return -1;
    if( fileTable[gfile] == NULL) return -1;

    // Flush the file
    return feof(fileTable[gfile]);
}
