;/************************************************************************
; *
; *     File        :   TIMESERV.ASM
; *
; *     Description :   Timer Service routines
; *
; *     Copyright (C) 1992 Otto Chrons
; *
; ***********************************************************************
;
;       Revision history of TIMESERV.ASM
;
;       1.0     16.4.93
;               First version. Timer services work well.
;
;       1.1     7.5.93
;               Previous timer is now never busy. Corrects the problem
;               with some disk caches etc.
;
;       1.2     25.11.93
;               New macros to make compilation under Watcom/32 possible
;
;       1.5     14.2.94
;               Working under 32-bit...
;
; ***********************************************************************/

        IDEAL
        JUMPS
        P386N

        INCLUDE "MODEL.INC"
        INCLUDE "TIMESERV.INC"

MACRO   checkInit

        RETVAL  -1
        cmp     [TSinited],1
        jne     @@exit
ENDM

CSEGMENTS TIMESERV

CDATASEG
        TSroutines      TSROUTINE 16 dup(<>)
        lastTS          DW      ?
        TScount         DB      ?

IFDEF __PASCAL__
        EXTRN           TSinited:BYTE
ELSE
        TSinited        DB      0
ENDIF
        TStimerValue    DW      ?

ENDS

CCODESEG TIMESERV

        copyrightText DB "Timer Service v1.5 - (C) 1993,1994 Otto Chrons",0,1Ah

        CPUBLIC tsInit, tsClose
        CPUBLIC tsAddRoutine, tsRemoveRoutine, tsChangeRoutine
        CPUBLIC tsSetTimerRate, tsGetTimerRate

;/*************************************************************************
; *
; *     Function    :   setTimerRate
; *
; *     Description :   Set low-level timer rate
; *
; *     Input       :   AX = new timer rate
; *
; ************************************************************************/

PROC    setTimerRate NEAR

        pushf
        cli
        mov     bx,ax
        mov     al,00110110b            ; Set timer rate
        out     43h,al
        mov     ax,bx
        out     40h,al
        mov     al,ah
        out     40h,al
        popf

        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   timerCatch
; *
; *     Description :   TS's timer interrupt function which takes care of
; *                     calling the service functions.
; *
; ************************************************************************/

PROC    timerCatch

        push    _ax _bx _cx ds

        mov     al,20h                  ; EOI
        out     20h,al
	sti

        mov     ax,DGROUP
        mov     ds,ax

IF32    <sub    ecx,ecx>
        mov     cx,[lastTS]
        sub     _bx,_bx                 ; Offset to TSroutines
        inc     _cx
@@loop:
        cmp     [_bx+TSroutines.status],TS_ACTIVE
        mov     ax,[_bx+TSroutines.timerAdd]
        jne     @@over                  ; Is routine active
        add     [_bx+TSroutines.timerPassed],ax
        jnc     @@over
@@callRoutine:
IF16    pushf                           ; Make a fake interrupt call to
IF32    pushfd
        call    [_bx+TSroutines.routine] ; the service routine
@@over:
        add     _bx,SIZE TSROUTINE
        loop    @@loop
@@done:
        pop     ds _cx _bx _ax
IF16    iret
IF32    iretd
ENDP

;/*************************************************************************
; *
; *     Function    :   int tsInit();
; *
; *     Description :   Initializes TimerService and catches timer interrupt.
; *
; *     Returns     :   0 if succesful
; *                     -1 on error
; *
; ************************************************************************/

CPROC   tsInit

        push    _di

        mov     _ax,-1
        cmp     [TSinited],0
        jne     @@exit

        mov     [TScount],1
        mov     [lastTS],0
        PUSHDS
        POPES
        mov     _di,offset TSroutines    ; ES:DI = TSroutines
        sub     al,al                   ; AX = 0
        cld
        mov     _cx,(SIZE TSROUTINE)*16
        rep     stosb                   ; Reset TSroutines-structure

        mov     ax,65535                ; AX = timer rate
        mov     [TStimerValue],ax
        mov     [TSroutines.timerValue],ax
        mov     [TSroutines.timerAdd],ax        ; call every time
        call    setTimerRate

        push    es
        mov     ax,3508h                ; Get timer interrupt routine
        int     21h                     ; ESBX = address of routine
IFDEF __32__
        mov     [WORD 4+TSroutines.routine],es
        mov     [DWORD TSroutines.routine],ebx
ELSE
        mov     [WORD HIGH TSroutines.routine],es
        mov     [WORD LOW TSroutines.routine],bx
ENDIF
        mov     [TSroutines.status],TS_ACTIVE
        pop     es

        push    ds
        push    cs
        pop     ds
        mov     _dx,offset timerCatch    ; DS:DX = timerCatch
        mov     ax,2508h                ; Set our own timer handler
        int     21h
        pop     ds

        mov     [TSinited],1
        sub     _ax,_ax                   ; AX = 0, no error
@@exit:
        pop     _di
        ret
ENDP


;/*************************************************************************
; *
; *     Function    :   void tsClose();
; *
; *     Description :   Closes TimerService and returns timer interrupt.
; *
; ************************************************************************/

CPROC   tsClose

        cmp     [TSinited],1
        jne     @@exit

        cli
        mov     ax,[TSroutines.timerValue]
        call    setTimerRate            ; Reset timer rate
        mov     ax,[TSroutines.timerValue]
        call    setTimerRate            ; Reset timer rate

        push    ds
IFDEF __32__
        mov     edx,[DWORD TSroutines.routine]
        mov     ds,[WORD PTR 4+TSroutines.routine]
ELSE
        mov     dx,[WORD LOW TSroutines.routine]
        mov     ds,[WORD HIGH TSroutines.routine]
ENDIF
        mov     ax,2508h
        int     21h                     ; Reset timer interrupt handler
        pop     ds
        sti

        mov     [TSinited],0
@@exit:
        ret
ENDP


;/*************************************************************************
; *
; *     Function    :   int tsChangeRoutine(int tag,unsigned time);
; *
; *     Description :   Changes service routines time and resolution values.
; *
; *     Input       :   tag     =       indicates routine
; *                     time    =       new timer rate
; *                     (resolution =   new resolution for timer)
; *
; *     Returns     :   0       =       no error
; *                     -1      =       TimerService not initialized
; *                     -2      =       invalid tag
; *                     -3      =       invalid parameter
; *
; ************************************************************************/

CPROC   tsChangeRoutine  @@tag, @@timeValue

        ENTERPROC

        checkInit

        imul    ebx,[@@tag],SIZE TSROUTINE
        cmp     [_bx+TSroutines.status],TS_ACTIVE
        jne     @@exit
        mov     ax,[WORD @@timeValue]
        mov     [_bx+TSroutines.timerValue],ax
        cmp     ax,[TStimerValue]
        jae     @@slower
        mov     [TStimerValue],ax
        call    setTimerRate
@@slower:
IF32    <sub    ecx,ecx>
        mov     cx,[lastTS]
        inc     cx
        sub     _bx,_bx
@@TSloop:
        cmp     [_bx+TSroutines.status],TS_ACTIVE
        jne     @@next
        mov     dx,[TStimerValue]
        mov     ax,65535
        cmp     [_bx+TSroutines.timerValue],dx
        jbe     @@noDiv
        div     [_bx+TSroutines.timerValue]
@@noDiv:
        mov     [_bx+TSroutines.timerAdd],ax
        mov     [_bx+TSroutines.timerPassed],65535
@@next:
        add     _bx,SIZE TSROUTINE
        loop    @@TSloop
        sub     ax,ax
@@exit:
        LEAVEPROC
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   int tsAddRoutine(void (far *func)(),unsigned time);
; *
; *     Description :   Adds a new service routine
; *
; *     Input       :   func       =    pointer to timer function
; *                     time       =    timer rate, determines how often
; *                                     "func" is called
; *                     (resolution =   biggest allowable error in timing)
; *
; *     Returns     :   -1 = TimerService not initialized
; *                     -2 = too many service routines
; *                     -3 = error in parameter
; *                     1-15 = tag for inited routine
; *
; ************************************************************************/

CPROC   tsAddRoutine  @@func, @@timeValue
LOCALVAR        _byte @@tag

        ENTERPROC       _si _di

        checkInit

        RETVAL  -2
        cmp     [TScount],16            ; Are all tags used?
        jge     @@exit

        mov     _ax,1                    ; AL = tag
        mov     _cx,15                   ; CX = counter
@@loop:
        push    _ax
        imul    _ax,SIZE TSROUTINE
        mov     _bx,_ax                   ; BX = offset into array
        pop     _ax

        cmp     [_bx+TSroutines.status],TS_INACTIVE
        je      @@found
        inc     _ax                      ; Next tag
        loop    @@loop
        mov     _ax,-2                   ; No free tag was found
        jmp     @@exit
@@found:
        mov     [@@tag],al
        cmp     ax,[lastTS]
        jle     @@notLast
        mov     [lastTS],ax
@@notLast:
        mov     eax,[@@func]                ; Copy function pointer
        mov     [DWORD PTR _bx+TSroutines.routine],eax
IFDEF __C32__
        mov     ax,cs
        mov     [WORD ebx+4+TSroutines.routine],ax
ENDIF
        mov     [_bx+TSroutines.status],TS_ACTIVE
        mov     [_bx+TSroutines.busy],0
        mov     ax,[WORD @@timeValue]
        mov     [_bx+TSroutines.timerValue],ax
        push    _bx
        movzx   eax,[byte @@tag]                ; Initialize timer values
        ecall   tsChangeRoutine eax,[@@timeValue]
        pop     _bx
        or      ax,ax
        je      @@ok
        mov     [_bx+TSroutines.status],TS_INACTIVE
        jmp     @@exit
@@ok:
        inc     [TScount]
        movzx   eax,[byte @@tag]                ; Return tag
@@exit:
        LEAVEPROC       _si _di
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   int tsRemoveRoutine(int tag);
; *
; *     Description :   Removes the service routine indicated by the tag.
; *
; *     Input       :   tag     =       number that was returned when service
; *                                     routine was added.
; *
; *     Returns     :   0       =       routine removed normally
; *                     -1      =       TimerService not initialized
; *                     -2      =       invalid tag
; *
; ************************************************************************/

CPROC   tsRemoveRoutine  @@tag

        ENTERPROC

        checkInit

        mov     ax,-2
        mov     dx,[WORD @@tag]
        cmp     dx,1
        jl      @@exit
        cmp     dx,15
        jg      @@exit
        mov     al,dl
        mov     ah,SIZE TSROUTINE
        mul     ah
IF32    <sub    ebx,ebx>
        mov     bx,ax                   ; BX = offset into array

        mov     ax,-2                   ; Is tag active?
        cmp     [_bx+TSroutines.status],TS_ACTIVE
        jne     @@exit

        mov     [_bx+TSroutines.status],TS_INACTIVE
        dec     [TScount]
        mov     _cx,16
        sub     _bx,_bx
        sub     ax,ax
@@loop:
        cmp     [_bx+TSroutines.status],TS_ACTIVE
        jne     @@notActive
        mov     [lastTS],ax
@@notActive:
        inc     ax
        add     _bx,SIZE TSROUTINE
        loop    @@loop

        sub     ax,ax                   ; Inactivate tag
@@exit:
        LEAVEPROC
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   void tsSetTimerRate(ushort rate);
; *
; *     Description :   Sets a new hardware timer rate
; *
; *     Input       :   New rate
; *
; ************************************************************************/

CPROC   tsSetTimerRate @@timeValue

        ENTERPROC

        checkinit

        mov     ax,[WORD @@timeValue]
        mov     [TStimerValue],ax
        call    setTimerRate

IF32    <sub    ecx,ecx>
        mov     cx,[lastTS]
        inc     cx
        sub     _bx,_bx
@@TSloop:
        cmp     [_bx+TSroutines.status],TS_ACTIVE
        jne     @@next
        mov     dx,[TStimerValue]
        mov     ax,65535
        cmp     [_bx+TSroutines.timerValue],dx
        jbe     @@noDiv
        div     [_bx+TSroutines.timerValue]
@@noDiv:
        mov     [_bx+TSroutines.timerAdd],ax
        mov     [_bx+TSroutines.timerPassed],65535
@@next:
        add     _bx,SIZE TSROUTINE
        loop    @@TSloop
        sub     ax,ax
@@exit:
        LEAVEPROC
        ret
ENDP

;/************************************************************************
; *
; *     Function    :   ushort tsGetTimerRate(void);
; *
; *     Description :   Returns timer rate
; *
; ************************************************************************/

CPROC   tsGetTimerRate

        movzx   eax,[TStimerValue]
        ret
ENDP

ENDS

END

