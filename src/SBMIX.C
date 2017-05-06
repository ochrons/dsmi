// ************************************************************************
// *
// *    File        : SBMIX.C
// *
// *    Description : Test program for SB Pro's mixer
// *
// *    Copyright (C) 1992 Otto Chrons
// *
// ************************************************************************

#include <stdio.h>

typedef unsigned char uchar;

void setMix(uchar port,uchar value);
int getMix(uchar port);

int     sbPort = 0x220;

void main()
{
    int         t;

    puts("Mixer testing program (C) 1992 Otto Chrons\n");
    puts("Mixer values:\n");
    printf("MASTER volume :   %02X\n",getMix(0x22));
    printf("VOC volume    :   %02X\n",getMix(0x04));
    printf("LINE volume   :   %02X\n",getMix(0x2E));
    printf("MIC volume    :   %02X\n",getMix(0x0A));
    printf("FM volume     :   %02X\n",getMix(0x26));
    printf("CD volume     :   %02X\n\n",getMix(0x08));
    printf("Input line    :   %02X\n",getMix(0x0C));
    printf("Mode          :   %02X\n\n",getMix(0x0E));
    printf("Others :\t");
    for(t = 0; t < 64; t++) printf("%02X:%02X\t",t,getMix(t));
    puts("");
}

void setMix(uchar port,uchar value)
{
    asm {
        mov     dx,sbPort
        add     dx,4
        mov     al,port
        out     dx,al
        inc     dx
        mov     al,value
        out     dx,al
    }
}

int getMix(uchar port)
{
    asm {
        mov     dx,sbPort
        add     dx,4
        mov     al,port
        out     dx,al
        inc     dx
        in      al,dx
        sub     ah,ah
    }
    return _AX;
}
