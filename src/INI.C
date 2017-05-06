// ************************************************************************
// *
// *    File        : INI.C
// *
// *    Description : Config file routines
// *
// *    Copyright (C) 1993 Otto Chrons
// *
// ************************************************************************

#include <stdio.h>
#include <string.h>
#include <malloc.h>
#include <errno.h>
#include <ctype.h>
#include <stdlib.h>

#pragma hdrstop

#include "ini.h"

int CurrentConfigLine;

ConfigItemData  C_DATA;

static void trimSpace(char *str)
{
    char    *orgStr = str;

    while( isspace(*str) ) str++;
    strcpy(orgStr,str);
}

int ReadConfig(char const *fileName, ConfigFile *c_file)
{
    FILE        *file;
    ConfigClass *C_class = NULL;
    ConfigItem  *C_item = NULL;
    char        str[256],*str2 = NULL;
    int         t,i,a;

    CurrentConfigLine = 0;
    if( !c_file ) return -1;
    c_file->firstClass = NULL;
    c_file->currentClass = NULL;
    if(( file = fopen(fileName,"rt")) == NULL) return ENOENT;
    if((c_file->fileName = _fullpath(NULL,fileName,0)) == NULL)
    {
        fclose(file);
        return ENOMEM;
    }
    while( fgets(str,255,file) )
    {
        CurrentConfigLine++;            // Increase line counter, for error
                                        // tracking
        if( strlen(str) > 250 )         // is the line too long?
        {
            fclose(file);
            return -1;
        }
        trimSpace(str);
        strrev(str);
        trimSpace(str);
        strrev(str);
        if( strlen(str) < 3 ) continue;
        if( *str == ';' ) continue;     // Comment
        if( *str == '[' )               // New class
        {
            str2 = strchr(str+1,']');
            if( !str2 ) continue;       // Valid class?
            if( C_class )               // Is it the first?
            {
                                        // No, create a new class and link it
                if((C_class->nextClass = malloc(sizeof(ConfigClass))) == NULL)
                {
                    fclose(file);
                    return ENOMEM;
                }
                C_class = C_class->nextClass;
            } else                      // Yes, create and add to config file
            {
                if((C_class = malloc(sizeof(ConfigClass))) == NULL)
                {
                    fclose(file);
                    return ENOMEM;
                }
                c_file->firstClass = C_class;
            }
            C_item = NULL;
            C_class->nextClass = NULL;
            C_class->firstItem = NULL;
            a = ((str2-str-1 < 31) ? str2-str-1 : 31);
            if( a == 0 )
            {
                fclose(file);
                return -1;
            }
            strncpy(C_class->name,str+1,a);
            C_class->name[a] = 0;       // Terminate string
            trimSpace(C_class->name);
            strrev(C_class->name);
            trimSpace(C_class->name);
            strrev(C_class->name);
        }
        else
        {
            if( C_class == NULL ) continue;
            str2 = strchr(str,'=');     // Seek '='
            if( str2 == NULL ) continue;
            if( C_item )
            {
                if((C_item->nextItem = malloc(sizeof(ConfigItem))) == NULL)
                {
                    fclose(file);
                    return ENOMEM;
                }
                C_item = C_item->nextItem;
            } else
            {
                if((C_item = malloc(sizeof(ConfigItem))) == NULL)
                {
                    fclose(file);
                    return ENOMEM;
                }
                C_class->firstItem = C_item;
            }
            C_item->nextItem = NULL;
            if((C_item->data = malloc(strlen(str2+1)+1)) == NULL)
            {
                fclose(file);
                return ENOMEM;
            }
            strcpy(C_item->data,str2+1);
            trimSpace(C_item->data);
            *str2 = 0;                  // Strip the data part
            strncpy(C_item->name,str,31);
            C_item->name[31] = 0;
            strrev(C_item->name);
            trimSpace(C_item->name);
            strrev(C_item->name);
        }
    }
    fclose(file);
    return 0;
}

ConfigItemData *GetConfigItem(char const *itemName, enum ConfigDataType type, ConfigFile *c_file)
{
    ConfigClass *c = c_file->currentClass;
    ConfigItem  *i;

    if( c == NULL ) return NULL;    // Is there a current class selection?
    i = c->firstItem;
    while( i != NULL && stricmp(itemName,i->name) ) // Search for itemName
    {
        i = i->nextItem;
    }
    if( i == NULL ) return NULL;
    switch( type )
    {
        case T_STR :
            C_DATA.i_str = i->data;
            break;
        case T_BOOL :
            C_DATA.i_bool = FALSE;
            if( atol(i->data) == 1 ) C_DATA.i_bool = TRUE;
            if( stricmp(i->data,"yes") == 0 ||
                stricmp(i->data,"ok") == 0 ||
                stricmp(i->data,"y") == 0 ||
                stricmp(i->data,"true") == 0) C_DATA.i_bool = TRUE;
            break;
        case T_LONG :
            C_DATA.i_long = strtol(i->data,NULL,0);
            break;
        default:
            return NULL;
    }
    return &C_DATA;
}

int SelectConfigClass(char const *className, ConfigFile *c_file)
{
    ConfigClass *cPtr;

    if( !c_file ) return 0;
    if(( cPtr = GetConfigClass( className, c_file )) == NULL) return 0;
    c_file->currentClass = cPtr;
    return 1;
}

ConfigClass *GetConfigClass(char const *className, ConfigFile *c_file)
{
    ConfigClass *c = c_file->firstClass;

    if( !c_file ) return NULL;

    while( c != NULL && stricmp(className,c->name) )
    {
        c = c->nextClass;
    }
    return c;
}
