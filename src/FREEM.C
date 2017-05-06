// ************************************************************************
// *
// *    File        : FREEM.C
// *
// *    Description : Frees module
// *
// *    Copyright (C) 1992,1994 Otto Chrons
// *
// ************************************************************************

#include <malloc.h>
#include "amp.h"

#ifdef _USE_EMS
#include "emhm.h"
#endif

int     loadOptions;

int     moduleError;

void cdecl ampFreeModule(MODULE *module)
{
    int         t,i;
    void        *ptr;

    if( module == NULL ) return;
    if( module->type != 0 )
    {
        if( module->patterns != NULL) D_free(module->patterns);
        if( module->instruments != NULL)
        {
            for( t = 0; t < module->instrumentCount; t++ )
            {
                if((ptr = module->instruments[t].sample) == NULL) continue;
                for( i = 0; i < t; i++)
                    if( ptr == module->instruments[i].sample )
                    {
                        ptr = NULL;
                        break;
                    }
#ifdef _USE_EMS
                if( ((long)ptr & 0xFFFF0000) == 0xFFFF0000 )
                    emsFree((long)ptr & 0xFFFF);
                else
#endif
                if( ptr != NULL ) D_free(ptr);
            }
            D_free(module->instruments);
        }
        if( module->tracks != NULL )
        {
            for( t = 1; t < module->trackCount+1; t++ )
            {
                ptr = module->tracks[t];
                for( i = 1; i < t; i++)
                    if( ptr == module->tracks[i] )
                    {
                        ptr = NULL;
                        break;
                    }
                if( ptr != NULL ) D_free(ptr);
            }
            D_free(module->tracks);
        }
    }
}
