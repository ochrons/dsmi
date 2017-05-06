// ************************************************************************
// *
// *    File        :   AMPTEST.C
// *
// *    Description :   Test AMP's routines
// *
// *    Copyright (C) 1992 Otto Chrons
// *
// ************************************************************************
#include <stdlib.h>
#include <conio.h>
#include <stdio.h>
#include "mcp.h"
#include "amp.h"

void main(int argc, char *argv[])
{
    void        *ptr;
    int         a,t,rate,options = 0;
    char        ch,track[4];
    SAMPLEINFO  sinfo;
    INSTRUMENT  *instr;
    TRACKDATA   *trData;

    puts("Advanced Module Player  ver 0.8     (C) 1992 Otto Chrons");
    puts("Do not distribute!");
    if(argc < 2)
        {
        puts("\nUsage : AMP modulename [sampling rate] [/I-]\n");
        puts("/I-  disable Intelligent Module Loader\n");
        exit(0);
        }
    rate = 16000;
    options = LM_IML;
    if( argc > 2 ) for( t = 1; t < argc; t++)
        {
        if( argv[t][0] == '/' && toupper(argv[t][1]) == 'I' && argv[t][2] == '-')
            options &= !LM_IML;
        if( isdigit(argv[t][0]) ) rate = atoi(argv[t]);
        }
    if( rate < 4000 || rate > 23000 ) rate = 16000;
    a = initAMP(rate);
    atexit(closeAMP);
    if( a == -1 )
        {
        puts("Error initializing AMP");
        exit(1);
        }
    a = loadModule(argv[1],options);
    if( a != 0 )
        {
        printf("Error loading %s\n",argv[1]);
        exit(1);
        }
    clrscr();
    gotoxy(1,7);
    cprintf("Memory used : %uK\n\r",curModule.size/1024);
    cputs("ESC = stop     SPACE = DOS shell\n\r");
    cputs("P = pause      R = resume        1-4 pause/resume track\n\r");
    playModule(PM_LOOP);
    do  {
        for( t = 0; t < 4 ; t++)
            track[t] = (getTrackStatus(t) & TR_PAUSED) ? ' ' : t + '1';
        a = getRow();
        while(!kbhit())
            {
            if( a != getRow() )
                {
                gotoxy(1,1);
                cprintf("Pattern : %3u   Row : %2X    Active : %c %c %c %c\r\n",
                        getPattern(),a=getRow(),track[0],track[1],track[2],track[3]);
                for( t = 0; t < 4; t++)
                    {
                    trData = getTrackData(t);
                    cprintf("Track %u : NOTE:%3u  VOL:%2u  INS:%2u    CMD:%2X  VALUE:%2X  \r\n",\
                            t,trData->note,trData->volume,trData->instrument,trData->command,trData->cmdvalue);
                    }
                }
            }
        ch = toupper(getch());
        switch(ch)
            {
            case ' ' :
                puts("\nType EXIT to return to AMP");
                if(system("") == -1) puts("Couldn't shell to DOS");
                break;
            case 'P' : pauseModule();break;
            case 'R' : resumeModule();break;
            case '1' :
            case '2' :
            case '3' :
            case '4' :
                if( getTrackStatus(ch - '1') & TR_PAUSED )
                    resumeTrack(ch - '1');
                else pauseTrack(ch - '1');
                break;
            }
        } while( ch != 27 );
}
