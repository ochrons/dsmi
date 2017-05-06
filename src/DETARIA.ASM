;/************************************************************************
; *
; *     File        : DETARIA.ASM
; *
; *     Description : Hardware detection routine for Aria cards
; *
; *     Copyright (C) 1993 Otto Chrons
; *
; ***********************************************************************/

        IDEAL
        JUMPS
        P386N

        INCLUDE "MODEL.INC"
        INCLUDE "MCP.INC"

CSEGMENTS DETARIA

        DSP_DATA = 0
        DSP_STATUS = 2
        DSP_CONTROL = 2
        DSP_DMA_ADDRESS = 4
        DSP_DMA_DATA = 6

        INTPC_DSPRD     EQU  0001h      ; Interrupt PC on DSP read
        INTPC_DSPWR     EQU  0002h      ; Interrupt PC on DSP write
        INTDSP_PCRD     EQU  0004h      ; Interrupt DSP on PC read
        INTDSP_PCWR     EQU  0008h      ; Interrupt DSP on PC write
        INTPC_DMADONE   EQU  0010h      ; Interrupt PC on DMA completion
        SAMP_RATE       EQU  0060h      ; Sample rate mask
         SAMP_44K       EQU  0000h      ;    44.10 kHz
         SAMP_32K       EQU  0020h      ;    31.50 kHz
         SAMP_22K       EQU  0040h      ;    22.05 kHz
         SAMP_16K       EQU  0060h      ;    15.75 kHz
        C2MODE          EQU  0080h      ; Aria Wave Synthesis select
        DSP_RESET       EQU  0100h      ; Reset DSP
        DMA_DSPTOPC     EQU  0200h      ; DMA direction - DSP to PC
        DMA_XFR         EQU  0400h      ; Initiate DMA transfer
        ADC_SRC_AUX     EQU  0800h      ; ADC record source select
        ADC_STEREO      EQU  1000h      ; ADC mono/stereo select
        ADC_SRC_RIGHT   EQU  2000h      ; ADC monophonic source
        ADC_DISABLE     EQU  4000h      ; ADC enable/disable
        PORT0_BUSY      EQU  8000h      ; Data port busy flag

CDATASEG

        oldInt10        DD ?
        oldInt11        DD ?
        oldInt12        DD ?
        ioPort          DW ?
        dspIRQ          DB ?
ENDS

CCODESEG DETARIA

        CPUBLIC  detectAria

        Aria            CARDINFO <8,0,"Aria sound card",290h,10,5,4000,44100,1,1,2>

;/*************************************************************************
; *
; *     Function    :   AriaCMD
; *
; *     Description :   Sends a command to Aria's DSP
; *
; *     Input       :   AX = cmd to send
; *
; ************************************************************************/

PROC    AriaCMD NEAR

        push    cx
        push    ax
        mov     dx,[ioPort]
        add     dx,DSP_STATUS
        mov     cx,0
@@wait:
        in      ax,dx
        test    ax,8000h
        loopnz  @@wait

        mov     dx,[ioPort]
        pop     ax
        out     dx,ax
        pop     cx

        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   putMem16
; *
; *     Description :   Puts a word into DSP's memory
; *
; *     Input       :   BX = address, AX = value
; *
; ************************************************************************/

PROC    putMem16 NEAR

        push    ax
        mov     dx,[ioPort]
        add     dx,DSP_DMA_ADDRESS
        mov     ax,bx
        out     dx,ax
        mov     dx,[ioPort]
        add     dx,DSP_DMA_DATA
        pop     ax
        out     dx,ax

        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   getMem16
; *
; *     Description :   Gets a word into DSP's memory
; *
; *     Input       :   BX = address
; *
; *     Returns     :   AX = value
; *
; ************************************************************************/

PROC    getMem16 NEAR

        mov     dx,[ioPort]
        add     dx,DSP_DMA_ADDRESS
        mov     ax,bx
        out     dx,ax
        mov     dx,[ioPort]
        add     dx,DSP_DMA_DATA
        in      ax,dx

        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   int detectAria(SOUNDCARD *scard);
; *
; *     Description :   Detects the presence of Aria sound card
; *
; *     Input       :   Pointer to soundcard structure
; *
; *     Returns     :   0  if succesful
; *                     -1 on error (no card found)
; *
; ************************************************************************/

CPROC   detectAria @@scard

        ENTERPROC _si _di

        LESDI   [@@sCard]
        mov     ax,es
        or      ax,di                   ; Is sCard NULL?
        jz      @@error
        mov     si,offset Aria
        mov     cx,SIZE CARDINFO        ; Copy sound card info into buffer
        cld
        push    ds
        push    cs
        pop     ds
        rep     movsb
        pop     ds
        LESDI   [@@sCard]

        call    getPort                 ; Find base port address
        jc      @@error
        LESDI   [@@sCard]
        mov     [ESDI+CARDINFO.ioPort],ax

        call    getIRQ                  ; Detect IRQ
        jc      @@error
        LESDI   [@@sCard]
        mov     [ESDI+CARDINFO.DMAIRQ],al

        call    getDMA                  ; Find out DMA channel
        jc      @@error
        LESDI   [@@sCard]
        mov     [ESDI+CARDINFO.DMAChannel],al

        sub     ax,ax                   ; No error
        jmp     short @@exit
@@error:
        mov     ax,-1
@@exit:
        LEAVEPROC _si _di
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   getPort
; *
; *     Description :   Finds Aria card's base address
; *
; *     Returns     :   Carry = 0   --> AX = address
; *                     Carry = 1       error
; *
; ************************************************************************/

PROC    getPort NEAR

        mov     si,INTPC_DSPWR OR INTDSP_PCWR OR SAMP_22K OR C2MODE
        mov     cx,280h                 ; First base address
@@loop:
        mov     dx,cx
        add     dx,DSP_STATUS
        in      ax,dx
        cmp     ax,0FFFFh               ; Bus floating?
        je      @@not1
        mov     ax,si
        out     dx,ax                   ; Output to control register
        in      ax,dx
        and     ax,7FFFh
        cmp     ax,si                   ; Is it still the same?
        je      @@ready
@@not1:
        add     cx,10h
        cmp     cx,2C0h
        jne     @@loop
        stc                             ; Error
        ret
@@ready:
        mov     [ioPort],cx

        mov     dx,cx
        mov     ax,00C8h                ; Init Aria
        add     dx,DSP_CONTROL
        out     dx,ax

        mov     ax,0
        mov     bx,6102h                ; DSP init
        call    putMem16

        cli
        mov     ax,0                    ; System init
        call    AriaCMD
        mov     ax,0                    ; Add new task
        call    AriaCMD
        mov     ax,0                    ; Aria Synthesizer mode, ROM module
        call    AriaCMD
        mov     ax,0                    ; No address
        call    AriaCMD
        mov     ax,0FFFFh               ; End of command
        call    AriaCMD
        sti
        mov     cx,2000
@@wloop:
        mov     dx,[ioPort]
        add     dx,DSP_STATUS
        in      ax,dx                   ; Delay
        mov     bx,6102h
        call    getMem16                ; Get value from DSP's memory
        cmp     ax,1
        loopne  @@wloop

        mov     dx,[ioPort]
        add     dx,DSP_CONTROL
        mov     ax,00CAh                ; Init Aria mode..
        out     dx,ax

        clc                             ; No error, AX = address
        mov     ax,[ioPort]
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   getIRQ
; *
; *     Description :   Finds Aria card's IRQ
; *
; *     Returns     :   Carry = 0   --> AL = IRQ
; *                     Carry = 1       error
; *
; ************************************************************************/

PROC    getIRQ NEAR

        cli
        mov     ax,3572h                ; Save old interrupt vectors
        int     21h
        mov     [WORD HIGH oldInt10],es
        mov     [WORD LOW oldInt10],bx
        mov     ax,3573h
        int     21h
        mov     [WORD HIGH oldInt11],es
        mov     [WORD LOW oldInt11],bx
        mov     ax,3574h
        int     21h
        mov     [WORD HIGH oldInt12],es
        mov     [WORD LOW oldInt12],bx

        PUSHDS
        push    cs                      ; set new vectors
        pop     ds
        mov     ah,25h
        mov     al,72h
        mov     dx,offset int72
        int     21h
        mov     al,73h
        mov     dx,offset int73
        int     21h
        mov     al,74h
        mov     dx,offset int74
        int     21h
        pop     ds
        sti

        in      al,0A1h                 ; Enable interrupts
        mov     di,ax                   ; save old value
        and     al,NOT (4+8+16)         ; Enable 10,11,12
        out     0A1h,al

        mov     [dspIRQ],0

        cli
        mov     ax,0Ah
        call    AriaCMD
        mov     ax,0FFFFh
        call    AriaCMD
        sti

        mov     cx,10000
@@loop:
        jmp     short $+2               ; Delays
        jmp     short $+2
        mov     dx,[ioPort]
        add     dx,DSP_STATUS
        in      ax,dx                   ; Delay
        mov     al,[dspIRQ]
        or      al,al
        loopz   @@loop

        mov     ch,al                   ; Save IRQ

        mov     ax,di                   ; Restore IRQ mask
        out     0A1h,al
        PUSHDS                  ; Restore old interrupt vectors
        mov     dx,[WORD LOW oldInt10]
        mov     ds,[WORD HIGH oldInt10]
        mov     ax,2572h
        int     21h
        pop     ds
        PUSHDS
        mov     dx,[WORD LOW oldInt11]
        mov     ds,[WORD HIGH oldInt11]
        mov     ax,2573h
        int     21h
        pop     ds
        PUSHDS
        mov     dx,[WORD LOW oldInt12]
        mov     ds,[WORD HIGH oldInt12]
        mov     ax,2574h
        int     21h
        pop     ds

        or      ch,ch
        jz      @@error
        mov     al,ch
        sub     ah,ah
        clc                             ; No error, IRQ in AL
        ret
@@error:
        stc                             ; Error
        ret
ENDP

PROC    IRQhandlers FAR

int72:
        PUSHDS
        push    ax
        mov     ax,DGROUP
        mov     ds,ax
        mov     [dspIRQ],10               ; Set interrupt number
        jmp     short @@DMAdone
int73:
        PUSHDS
        push    ax
        mov     ax,DGROUP
        mov     ds,ax
        mov     [dspIRQ],11               ; Set interrupt number
        jmp     short @@DMAdone
int74:
        PUSHDS
        push    ax
        mov     ax,DGROUP
        mov     ds,ax
        mov     [dspIRQ],12               ; Set interrupt number
@@DMAdone:
        sti
        mov     al,20h
        out     20h,al
        out     0A0h,al
        pop     ax
        POPDS
        iret

ENDP

;/*************************************************************************
; *
; *     Function    :   getDMA
; *
; *     Description :   Finds Aria card's DMA channel
; *
; *     Returns     :   Carry = 0   --> AL = channel
; *                     Carry = 1       error
; *
; ************************************************************************/

PROC    getDMA NEAR

        mov     al,5
        clc

        ret
ENDP

ENDS

END
