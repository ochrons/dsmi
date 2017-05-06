// ************************************************************************
// *
// *    File        : MCPTEST.C
// *
// *    Description : Testing Multi Channel Player
// *
// *    Copyright (C) 1992 Otto Chrons
// *
// ************************************************************************

#include <stdio.h>
#include <conio.h>
#include <io.h>
#include <fcntl.h>
#include <alloc.h>
#include <dos.h>
#include <mem.h>
#include <math.h>
#include <time.h>
#include "mcp.h"

typedef struct {
    char        name[13];
    char        disk;
    unsigned    position;
    unsigned    length;
    unsigned    loopstart;
    unsigned    loopend;
    char        volume;
    char        __a;
    unsigned    rate;
    long        __b;
    unsigned    __c;
} STMSAMPLE;

typedef struct {
    unsigned char       note;
    unsigned char       insvol;
    unsigned char       volcmd;
    unsigned char       cmd_data;
} NOTE;

typedef struct {
    NOTE        channel[4];
} ROW;

typedef struct {
    ROW         row[64];
} PATTERN;

void main(int argc, char *argv[])
{
    int         order,curpat,currow,t,patnum,file,channel[4],len,a;
    int         cmd,cmdData,ins,vol,dtime = 125;
    int         err,port,dmaInt,isBreak;
    unsigned    rate;
    long        time1,time2,time3;
    float       freq = 1.059463094;
    char        c,ch,dummy[128],pats[128];
    void        *sample;
    SAMPLEINFO  sInfo[31];
    SAMPLEINFO  temp;
    STMSAMPLE   stm_sample;
    PATTERN     *pattern[64];
    NOTE        curnote;

    err = checkSB(&port,&dmaInt);
    if( err == -1 )
        {
        printf("Sound Blaster not found!\n");
        return;
        }
    else printf("Sound Blaster found on %Xh, DMA interrupt is %u, "\
                "version %u.%02u \n",port,dmaInt,err/256,err & 255);
    file = open(argv[1],O_BINARY | O_RDONLY);
    if(file == -1)
        {
        printf("File \"%s\" not found.\n",argv[1]);
        return;
        }
    read(file,dummy,29);                // This part is not needed
    read(file,&c,1);                    // File type
    if( c == 2 )
        {
        read(file,dummy,2);
        read(file,&c,1);                // Default tempo
        dtime = 117*c/96;
        patnum = 0;
        read(file,&patnum,1);           // patterns saved
        read(file,dummy,14);
        for( t = 0; t < 31; t++)
            {
            read(file,&stm_sample,sizeof(STMSAMPLE));
            sInfo[t].sample = 0;
            if( stm_sample.length > 16 )
                {
                puts(stm_sample.name);
                (unsigned)sInfo[t].sample = stm_sample.position;
                sInfo[t].length = stm_sample.length;
                sInfo[t].loopstart = stm_sample.loopstart;
                sInfo[t].loopend = stm_sample.loopend;
                sInfo[t].volume = stm_sample.volume;
                sInfo[t].rate = stm_sample.rate;
                }
            }
        read(file,pats,128);
        for( t = 0; t < patnum; t++)
            {
            printf("Pattern %u  \r",t);
            pattern[t] = (PATTERN*)malloc(sizeof(PATTERN));
            if(pattern[t] == 0)
                {
                printf("Error reading pattern %u\n",t);
                return;
                }
            read(file,pattern[t],sizeof(PATTERN));
            }
        for( t = 0; t < 31; t++)
            {
            if( sInfo[t].sample != 0 )
                {
                sample = malloc(sInfo[t].length);
                if( sample )
                    {
                    printf("Sample %u   \r",t);
                    lseek(file,((unsigned)(sInfo[t].sample))*16L,SEEK_SET);
                    read(file,sample,sInfo[t].length);
                    convertSample(sample,sInfo[t].length);
                    sInfo[t].sample = sample;
                    }
                }
            }
        }
    close(file);
    puts("");
    curpat = 0; currow = 0;
    order = 0;
    rate = atoi(argv[2]);
    if(rate < 4000) rate = 16000;
    err = initMCP(rate);
    if( err == -1 )
        {
        puts("Error initializing MCP!");
        return;
        }
    openChannels(4);
    startVoice();
    curpat = pats[order++];
    asm {
        mov     al,00110110b
        out     43h,al
        mov     ax,1193                 // 1000/sec
        out     40h,al
        mov     al,ah
        out     40h,al
        }
    time2 = clock();
    while( !kbhit() )
        {
        for( currow = 0; currow < 64; currow++)
            {
            if(kbhit()) break;
            time1 = clock();
            isBreak = 0;
            for( t = 0; t < 4; t++)
                {
                memcpy(&curnote,&pattern[curpat]->row[currow].channel[t],sizeof(NOTE));
                c = curnote.note;
                cmd = curnote.volcmd & 0xF;
                cmdData = (unsigned)curnote.cmd_data;
                if( cmd == 1 ) dtime = 117*cmdData/96;
                if( cmd == 3 ) isBreak = 1;
                if( (unsigned char)c < 250 )
                    {
                    ins = (unsigned char)(curnote.insvol)>>3;
                    vol = (curnote.insvol&7) + (curnote.volcmd&0xF0)/2;
                    rate = (float)(sInfo[ins-1].rate)*pow(2.0,(float)(c/16-2))*pow(freq,(float)(c & 15));
                    memcpy(&temp,&sInfo[ins-1],sizeof(SAMPLEINFO));
                    if(rate > 1000) temp.rate = rate;
                    temp.volume = (vol == 65) ? temp.volume : vol;
                    putSample(t,&temp);
                    }
                }
            time3 = clock() - time2;
            cprintf("Pattern %02u row %02u playing time %2u:%02u  \r",\
                curpat,currow,(unsigned)(time3/60000u),(unsigned)(time3/1000u % 60));
            if( isBreak ) currow = 64;
            while(clock()-time1 < dtime);
            }
        if( pats[order] == 99 ) order = 0;
        curpat = pats[order++];
        }
    puts("");
    asm {
        mov     al,00110110b
        out     43h,al
        mov     ax,65535                // 18.2
        out     40h,al
        mov     al,ah
        out     40h,al
        }
    closeMCP();
}
