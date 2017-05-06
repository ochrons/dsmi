;/************************************************************************
; *
; *     File        :   GUS.ASM
; *
; *     Description :   Interface for Gravis Ultrasound
; *
; *     Copyright (C) 1993,1994 Otto Chrons
; *
; ***********************************************************************
;
;       Revision history of GUS.ASM
;
;       1.0     31.7.93
;               Well, maybe it works
;       2.0     11.11.93
;               Now it seems to be working pretty well... Some probs with
;               IRQs from wavetable and volume ramps.. odd.. Corrected...
;	2.1	DMA download routines
;	2.5	Changed GUS timer to regular timer. saveIRQ now inhibits
;		all interrupts, not just GUS'.
;
; ***********************************************************************/

	IDEAL
	JUMPS
	P386

        INCLUDE "MODEL.INC"
        INCLUDE "MCP.INC"
        INCLUDE "GUS.INC"
        INCLUDE "CDI.INC"

CSEGMENTS GUS
        INCLUDE "DSMIMEM.INC"
IFDEF __32__
        INCLUDE "DSMI32.INC"
ENDIF

STRUC   GUSEVENT
    time        DD ?
IFDEF __32__
    func        DD ?
ELSE
    func        DW ?                    ; Pointer to function
ENDIF
    p1          DD ?                    ; Parameters
    p2          DD ?
    p3          DD ?
ENDS

STRUC   SAMPLELINK
    origSample  DD ?
    gusSample   DD ?
ENDS

IFDEF __PASCAL__
	EXTRN   gushmAlloc:_FAR, gushmFreeAll:_FAR, gushmFree:_FAR
ELSE
	EXTRN   _gushmAlloc:_FAR, _gushmFreeAll:_FAR, _gushmFree:_FAR
ENDIF

STRUC   DMAPORT

	addr    DW ?
	count   DW ?
	page    DW ?
	wcntrl  DW ?
	wreq    DW ?
	wrsmr   DW ?
	wrmode  DW ?
	clear   DW ?
	wrclr   DW ?
	clrmask DW ?
	wrall   DW ?
ENDS

MACRO   checkMute

	movzx   ebx,[WORD @@channel]
	cmp     [_bx+chMuted],1
	je      @@exit
ENDM

MACRO   selectChannel x

        mov     al,x
        mov     dx,[gusChannelAddr]
        out     dx,al
ENDM

MACRO   WWAIT
        jmp     short $+2
ENDM

CDATASEG

        MAXEVENT        = 250
	MAXSAMPLE       = 128
	TIME_DELTA      = 30000                 ; 30msec
        GUS_TIMER       = 9920                  ; 10msec

        eventQueue              DD ?
        sampleList              DD ?
	sampleListLength        DW ?
	firstEvent              DW ?
	lastEvent               DW ?
	staticEvent             GUSEVENT <>
        staticEventOut          GUSEVENT <>
        curTime                 DQ ?
        pseudoTime              DQ ?
	deltaTime               DD ?
	gusVoices               DB ?
	gusBaseAddr             DW ?
	gusCmdAddr              DW ?
	gusChannelAddr          DW ?
	gusIRQ                  DB ?
	gusDMA                  DB ?
        savePIC                 DW ?
        chBase                  DD 32 dup(?)
	chMode			DB 32 dup(?)
	chFreq                  DD 32 dup(?)
	chVolume                DW 32 dup(?)
	chMuted                 DB 32 dup(?)
	oldSS                   DW ?
	oldSP                   DW ?
	gusBUSY                 DW ?
	masterVol               DW ?
	curDMA                  DMAPORT <>
	dmaActive               DB ?
	irqStatus               DB ?
	testIRQ                 DB ?
        mixReg                  DB ?
        useDMAdownload          DB ?
        useGUStimer             DB ?
        gusStatus               DW ?
        gusDMAbuffer            DD ?
        gusDMAbufferPtr         DD ?
        gusDMAbufferPhys        DD ?
IFDEF __32__
        gusDMAbufferSel         DW ?
        gusDMAbufferSize        DD ?
ELSE
        gusDMAbufferSize        DW ?
ENDIF

IFDEF __32__
        oldIRQ                  DF ?
ELSE
        oldIRQ                  DD ?
ENDIF

struc DDS
    size	DD ?
    offset	DD ?
    segm	DW ?
    ID		DW ?
    address	DD ?
ENDS

	dmaDDS	DDS <>


IFDEF __PASCAL__
	EXTRN	gusDeltaTime:DWORD
ELSE
	CPUBLIC		gusDeltaTime

	_gusDeltaTime		DD ?

	gusDeltaTime EQU _gusDeltaTime
ENDIF

IFDEF __PASCAL__

	EXTRN CDI_GUS:CDIDEVICE

ELSE
	CPUBLIC CDI_GUS

	_CDI_GUS        CDIDEVICE <\
	_far ptr _gusSetSample,\
	_far ptr _gusPlaySample,\
	_far ptr _gusSetVolume,\
	_far ptr _gusSetRate,\
	0,\
	_far ptr _gusSetPosition,\
	_far ptr _gusSetPanning,\
	_far ptr _gusSetMasterVolume,\
	_far ptr _gusMuteChannel,\
	_far ptr _gusUnmuteChannel,\
        _far ptr _gusStopChannel,\
	_far ptr _gusMuteAll,\
	_far ptr _gusUnmuteAll,\
        _far ptr _gusPoll,\
        _far ptr _gusGetDelta,\
        _far ptr _gusDownloadSample,\
        _far ptr _gusUnloadSample,\
        _far ptr _gusUnloadAll,\
        _far ptr _gusGetVolume,\
        _far ptr _gusGetRate,\
        _far ptr _gusGetPosition,\
        _far ptr _gusGetPanning,\
        _far ptr _gusGetSample,\
        _far ptr _gusSetupChannels,\
        _far ptr _gusGetChannelStatus>
ENDIF

ENDS

CCODESEG GUS

	CPUBLIC gusInit, gusClose, gusStartVoice, gusStopVoice
        CPUBLIC gusSetSample, gusPlaySample, gusStopChannel, gusSetVolume, gusSetRate
        CPUBLIC gusSetPosition, gusSetPanning, gusSetMasterVolume, gusGetSamplingRate
	CPUBLIC gusMuteChannel, gusUnmuteChannel, gusMuteAll, gusUnmuteAll
        CPUBLIC gusPoll, gusGetDelta, gusDownloadSample, gusUnloadSample, gusUnloadAll
	CPUBLIC gusGetVolume, gusGetRate, gusGetPosition, gusGetPanning
        CPUBLIC gusGetSample, gusSetupChannels, gusGetChannelStatus

	CPUBLIC gusPoke, gusPeek

	CPUBLIC gusInterrupt

	LABEL DMAports  DMAPORT

	    DMAPORT <0,1,87h,8,9,0Ah,0Bh,0Ch,0Dh,0Eh,0Fh>
	    DMAPORT <2,3,83h,8,9,0Ah,0Bh,0Ch,0Dh,0Eh,0Fh>
	    DMAPORT <4,5,81h,8,9,0Ah,0Bh,0Ch,0Dh,0Eh,0Fh>
	    DMAPORT <6,7,82h,8,9,0Ah,0Bh,0Ch,0Dh,0Eh,0Fh>
	    DMAPORT <0,0,0,0,0,0,0,0,0,0,0>
	    DMAPORT <0C4h,0C6h,8Bh,0D0h,0D2h,0D4h,0D6h,0D8h,0DAh,0DCH,0DEh>
	    DMAPORT <0C8h,0CAh,89h,0D0h,0D2h,0D4h,0D6h,0D8h,0DAh,0DCH,0DEh>
	    DMAPORT <0CCh,0CEh,8Ah,0D0h,0D2h,0D4h,0D6h,0D8h,0DAh,0DCH,0DEh>

PROC    nullFunc NEAR
	ret
ENDP

MACRO   saveIRQ
        call    _saveIRQ
ENDM

MACRO   restoreIRQ
        call    _restoreIRQ
ENDM


PROC    _saveIRQ NEAR
        push    cx
        mov     cl,[gusIRQ]
        mov     ah,1
        test    cl,8
        jnz     ll1
        shl     ah,cl
        in      al,21h
        or      al,ah
        out     21h,al
        jmp     short ll2
ll1:
        and     cl,7
        shl     ah,cl
        in      al,0A1h
        or      al,ah
        out     0A1h,al
ll2:
        pop     cx
        ret
ENDP

PROC    _restoreIRQ NEAR
        push    cx
        mov     cl,[gusIRQ]
        mov     ah,1
        test    cl,8
        jnz     @@ll1
        shl     ah,cl
        not     ah
        in      al,21h
        and     al,ah
        out     21h,al
        jmp     short @@ll2
@@ll1:
        and     cl,7
        shl     ah,cl
        not     ah
        in      al,0A1h
        and     al,ah
        out     0A1h,al
@@ll2:
        pop     cx
        ret
ENDP

PROC    gusDelay NEAR
	push    ax dx
	mov     dx,[gusBaseAddr]
	add     dx,107h
	in      al,dx
	in      al,dx
	in      al,dx
	in      al,dx
	in      al,dx
	in      al,dx
	in      al,dx
	pop     dx ax
	ret
ENDP

;/***************************************************************************\
;*
;* Function:    setGUSTimer @@timer:DWORD
;*
;* Description: Sets GUS timer to @@timer
;*
;\***************************************************************************/

CPROC   setGUSTimer @@timer

        ENTERPROC
        cmp     [useGUStimer],0
        je      @@nogustimer

        cli

        mov     al,[gusIRQ]
	test	al,8			; Is IRQ > 7
	jz	@@01
	add	al,60h			; Yes, base is 70h
@@01:
	push    es
        add     al,8                    ; AL = GUS interrupt number
	push	ax
	mov	ah,35h			; Get interrupt vector
	int	21h
IFDEF __32__
        mov     [WORD 4+oldIRQ],es
        mov     [DWORD oldIRQ],ebx
ELSE
        mov     [WORD HIGH oldIRQ],es
        mov     [WORD LOW oldIRQ],bx
ENDIF
	pop	ax			; Replace vector with the address
        pop     es
	mov	ah,25h			; of own interrupt routine
	push    ds
        push    cs
        pop     ds
IFDEF __PASCAL__
        mov     _dx,offset gusInterrupt ; Set interrupt vector
ELSE
        mov     _dx,offset _gusInterrupt ; Set interrupt vector
ENDIF
	int	21h
        pop     ds

        mov     cl,[gusIRQ]             ; Enable GUS interrupt
	mov	ah,1
	test	cl,8
	jnz	@@10
	shl	ah,cl
	not	ah
	in	al,21h
	and	al,ah
	out	21h,al
	jmp	@@20
@@10:
	and	cl,7
	shl	ah,cl
	not	ah
	in	al,0A1h
	and	al,ah
	out	0A1h,al
@@20:
        mov     dx,[gusCmdAddr]
        mov     al,47h
        out     dx,al
        mov     eax,[DWORD @@timer]     ; Set Timer 2 counter
        sub     edx,edx
        mov     ebx,320
        div     ebx                     ; Divide by 320usec
        neg     al                      ; AL = 256-AL
        mov     dx,[gusCmdAddr]
        add     dx,2
        out     dx,al

        mov     dx,[gusCmdAddr]
        mov     al,45h                  ; Enable timer IRQ
        out     dx,al
        add     dx,2
        mov     al,8
        out     dx,al

        mov     dx,[gusBaseAddr]
        add     dx,8
        mov     al,4
        out     dx,al

        mov     dx,[gusBaseAddr]
        add     dx,9
        mov     al,2
        out     dx,al
@@nogusTimer:
        sti
        LEAVEPROC
        ret
ENDP

;/***************************************************************************\
;*
;* Function:    stopGUSTimer
;*
;* Description: Stops GUS timer
;*
;\***************************************************************************/

CPROC   stopGUSTimer

        cmp     [useGUStimer],0
        je      @@nogustimer
        cli

        mov     dx,[gusCmdAddr]
        mov     al,45h                  ; Disable timer
        out     dx,al
        add     dx,2
        mov     al,0
        out     dx,al

        mov     dx,[gusBaseAddr]
        add     dx,9
        mov     al,80h
        out     dx,al                   ; Clear IRQ

        push    ds
        mov     al,[gusIRQ]
	test	al,8			; Is IRQ > 7
	jz	@@01
	add	al,60h			; Yes, base is 70h
@@01:
	add	al,8
        lds     _dx,[oldIRQ]
        mov     ah,25h
	int	21h			; Restore DMA vector
	pop	ds
        sti
@@nogustimer:
        ret
ENDP

;/***************************************************************************\
;*
;* Function:    allocateGUSDMAbuffer
;*
;* Description: Allocates a 8K buffer for DMA transfers
;*
;\***************************************************************************/

CPROC   allocateGUSDMAbuffer

IFDEF __32__

        mov     [gusDMAbufferSize],8192
        mov     eax,8192+32
        ecall   D_DOSAlloc eax          ; Allocate DOS memory

        mov     ebx,eax
        shr     ebx,16                  ; BX = selector
        mov     [gusDMAbufferSel],bx
        and     eax,0FFFFh
        shl     eax,4                   ; EAX = linear pointer to allocated memory
        mov     [gusDMAbuffer],eax
        mov     [gusDMAbufferPtr],eax

        cmp     ax,0E000h               ; Is it valid buffer?
        jb      @@bufok

        neg     ax                      ; AX = 65536-AX
        mov     [gusDMAbufferSize],_ax
        cmp     ax,4096                 ; Is it at least half buffer?
        jae     @@bufok

        neg     ax
        add     eax,10000h
        and     eax,NOT 0FFFFh
        mov     [gusDMAbuffer],eax      ; New buffer position

        sub     eax,[gusDMAbufferPtr]
        neg     eax
        add     eax,8192                ; New size
        mov     [gusDMAbufferSize],_ax
@@bufok:
        and     [gusDMAbufferSize],NOT 31 ; Align the size to 32 bytes

        mov     eax,[gusDMAbuffer]
        mov     [gusDMAbufferPhys],eax

ELSE

        mov     [gusDMAbufferSize],8192

        mov     eax,8192+32
        ecall   D_malloc eax            ; Allocate heap memory

        mov     [WORD LOW gusDMAbufferPtr],ax   ; Save real pointer
        mov     [WORD HIGH gusDMAbufferPtr],dx

        sub     ecx,ecx
        mov     cx,dx
        shl     ecx,4
        and     eax,0FFFFh
        add     ecx,eax                 ; ECX = "physical" address
        mov     eax,ecx

        mov     [gusDMAbuffer],eax

        cmp     ax,0E000h               ; Is it valid buffer?
        jb      @@bufok

        neg     ax                      ; AX = 65536-AX
        mov     [gusDMAbufferSize],ax
        cmp     ax,4096                 ; Is it at least half buffer?
        jae     @@bufok

        neg     ax
        add     eax,10000h
        and     eax,NOT 0FFFFh
        mov     [gusDMAbuffer],eax      ; New buffer position

        sub     eax,ecx
        neg     eax
        add     eax,8192                ; New size
        mov     [gusDMAbufferSize],ax
@@bufok:
        and     [gusDMAbufferSize],NOT 31 ; Align the size to 32 bytes

        mov     eax,[gusDMAbuffer]      ; Convert to seg:ofs
        mov     [gusDMAbufferPhys],eax  ; Save physical address first
        mov     ebx,eax
        and     eax,0FFFFh
        and     ebx,0F0000h
        shr     ebx,4
        mov     [WORD LOW gusDMAbuffer],ax
        mov     [WORD HIGH gusDMAbuffer],bx
ENDIF
        ret
ENDP

;/***************************************************************************\
;*
;* Function:    freeGUSDMAbuffer
;*
;* Description: Frees the allocated DMA buffer
;*
;\***************************************************************************/

CPROC   freeGUSDMAbuffer

IFDEF __32__
        mov     ax,[gusDMAbufferSel]    ; Get selector
        shl     eax,16

        mov     edx,[gusDMAbufferPtr]   ; Get pointer
        shr     edx,4
        mov     ax,dx

        ecall   D_DOSFree eax
ELSE
        les     bx,[gusDMAbufferPtr]
        ecall   D_free <es bx>
ENDIF
        ret
ENDP

;/*************************************************************************
; *
; *     Function    : initEventQueue();
; *
; *     Description : Initializes event queue
; *
; ************************************************************************/

PROC    initEventQueue NEAR

        ecall   D_malloc <LARGE (SIZE GUSEVENT)*(MAXEVENT+2)>
        PUSHES
        push    _di                     ; Allocate event queue
IFDEF __32__
        mov     edi,eax
        mov	[eventQueue],eax
ELSE
        mov     es,dx
	mov     di,ax
	mov	[WORD LOW eventQueue],ax
	mov	[WORD HIGH eventQueue],dx
ENDIF
        cld
        mov     _cx,(SIZE GUSEVENT)*(MAXEVENT)
	mov     al,0FFh
	rep     stosb                   ; Clear events
	mov     [firstEvent],0
	mov     [lastEvent],0
        mov     [DWORD HIGH curTime],0
        mov     [DWORD LOW curTime],0FFFF0000h
        mov     [DWORD HIGH pseudoTime],0
        mov     [DWORD LOW pseudoTime],0FFFF0000h
        mov     [deltaTime],GUS_TIMER  ; 10msec
	pop     _di
        POPES
	ret
ENDP

;/*************************************************************************
; *
; *     Function    : insertEvent();
; *
; *     Description : Inserts an event to GUS' event queue (static structure)
; *
; ************************************************************************/

PROC    insertEvent NEAR

	push    _di _si

        saveIRQ

        LESDI   [eventQueue]
        movzx   ebx,[lastEvent]
        inc     [lastEvent]
        cmp     [lastEvent],MAXEVENT
	jb      @@ok
        mov     [lastEvent],0
@@ok:
	mov	eax,[gusDeltaTime]
        shr     eax,8
	add     [staticEvent.time],eax
        imul    _bx,SIZE GUSEVENT
        add     _di,_bx
        mov     _si,offset staticEvent  ; DS:SI points to the event to be inserted
	mov     _cx,SIZE GUSEVENT
        cld
        rep     movsb

        restoreIRQ

	pop     _si _di

        ret
ENDP

;/*************************************************************************
; *
; *     Function    : getEvent();
; *
; *     Description : Gets an event from GUS' event queue
; *
; ************************************************************************/

PROC    getEvent NEAR

        push    _di _si
	mov     _ax,-1                  ; -1 = no event
	movzx   ebx,[firstEvent]
	cmp     bx,[lastEvent]
	je      @@exit
@@ok:
	imul    _bx,SIZE GUSEVENT
	PUSHDS
	POPES
	PUSHDS
	LDSSI   [eventQueue]		; DS:(E)SI points to event queue
	add     _si,_bx
        mov     _di,offset staticEventOut ; ES:(E)DI points to the event to be fetched
	mov     _cx,SIZE GUSEVENT
	cld
	rep     movsb
	POPDS
	sub     _ax,_ax                 ; Event is loaded into the static buffer
@@exit:
	pop     _si _di
	ret
ENDP

;/*************************************************************************
; *
; *     Function    : processEvent();
; *
; *     Description : Processes current event in queue
; *
; ************************************************************************/

PROC    processEvent NEAR

	mov     _ax,-1                  ; -1 = not processed
        mov     edx,[DWORD LOW curTime]
        mov     ecx,[DWORD HIGH curTime]
        shrd    edx,ecx,8
        cmp     [staticEventOut.time],edx  ; Is it time?
	ja      @@exit
        mov     eax,[staticEventOut.p1] ; Pass parametres
        mov     ebx,[staticEventOut.p2]
        mov     ecx,[staticEventOut.p3]
        cmp     [staticEventOut.func],0 ; Is pointer NULL?
	je	@@nocall
        call    [staticEventOut.func]   ; Call function
@@nocall:
        inc     [firstEvent]            ; Purge event
        cmp     [firstEvent],MAXEVENT
        jb      @@ok
        mov     [firstEvent],0
@@ok:
        sub     _ax,_ax                 ; 0 = processed
@@exit:
	ret
ENDP

;/*************************************************************************
; *
; *     Function    :   handleIRQ
; *
; *     Description :   Handles GUS' volume and wave interrupts
; *
; ************************************************************************/

PROC    handleIRQ NEAR

	sti
@@loop:
        cli
        mov     dx,[gusCmdAddr]
	mov     al,8Fh
	out	dx,al
	add	dx,2
	in	al,dx
        sti

        mov     bl,al
        and     al,11000000b
        cmp     al,11000000b            ; Are high bits 1?
        je      @@done
        and     bl,00111111b

        selectChannel bl

        cli
        mov     dx,[gusCmdAddr]
        mov     al,0
        out     dx,al
        add     dx,2
        mov     al,3
        out     dx,al
        DELAY
        out     dx,al

        mov     dx,[gusCmdAddr]
        mov     al,0Dh
        out     dx,al
        add     dx,2
        mov     al,3
        out     dx,al
        DELAY
        out     dx,al
        sti

        jmp     @@loop
@@done:
	ret
ENDP

;/*************************************************************************
; *
; *     Function    :   interruptHandler
; *
; *     Description :   Handles GUS' interrupts
; *
; ************************************************************************/

PROC    interruptHandler NEAR

	mov     eax,[deltaTime]
        add     [DWORD LOW curTime],eax
        adc     [DWORD HIGH curTime],0

	cmp     [gusBUSY],0
	jne     @@busy

	mov     [gusBUSY],1
	PUSHDS
	POPES
@@loop:
	call    getEvent
	or      ax,ax
	jnz     @@exit
	call    processEvent
	or      ax,ax
	jz      @@loop
@@exit:
	mov     [gusBUSY],0
@@busy:
	ret
ENDP

;/*************************************************************************
; *
; *     Function    : interruptGUS();
; *
; *     Description : Interrupt service routine for handling events
; *
; ************************************************************************/

CPROC   gusInterrupt

        pushad
        push    es ds

        mov     ax,DGROUP
        mov     ds,ax
	mov     es,ax

        mov     al,20h
        out     20h,al
        out     0A0h,al

        cmp     [useGUStimer],0
        je      @@nogustimer

        mov     dx,[gusBaseAddr]
        add     dx,6
        in      al,dx

        mov     dx,[gusCmdAddr]
        mov     al,45h                  ; Disable timer
        out     dx,al
        add     dx,2
        mov     al,0
        out     dx,al

        mov     dx,[gusCmdAddr]
        mov     al,45h                  ; Enable timer
        out     dx,al
        add     dx,2
        mov     al,8
        out     dx,al

        call    handleIRQ
@@nogustimer:
        sti
        call    near interruptHandler

        pop     ds es
        popad

        nop
IFDEF __32__
        iretd
ELSE
	iret
ENDIF
ENDP

;/*************************************************************************
; *
; *     Function    :   long(eax) findSample(void *ptr);
; *
; *     Description :   Returns the offset of the sample in GUS' memory
; *
; *     Returns     :   EAX = offset
; *                     BX = offset to sample list
; *
; ************************************************************************/

CPROC   findSample @@pptr

        ENTERPROC

        sub     eax,eax
        movzx   ecx,[sampleListLength]
        jcxz    @@exit
	LESBX   [sampleList]
@@loop:
        mov     edx,[ESBX+SAMPLELINK.origSample]
	cmp     edx,[@@pptr]
        je      @@found
        add     _bx,SIZE SAMPLELINK
	loop    @@loop
	mov	_bx,-1
	jmp	@@exit
@@found:
        mov     eax,[ESBX+SAMPLELINK.gusSample]
@@exit:
	LEAVEPROC
	ret
ENDP

;/*************************************************************************
; *
; *     Function    :   void insertSample(void *ptr, long offset);
; *
; *     Description :   Inserts a sample to sample list
; *
; ************************************************************************/

CPROC   insertSample @@pptr,@@gusoffset

	ENTERPROC
	mov     _cx,MAXSAMPLE
	sub     _dx,_dx
	LESBX   [sampleList]
@@loop:
	cmp     [ESBX+SAMPLELINK.origSample],0
	je      @@found
	add     _bx,SIZE SAMPLELINK
	inc     _dx
	loop    @@loop
	jmp     @@exit
@@found:
	inc	_dx
	mov     eax,[@@pptr]
	mov     [ESBX+SAMPLELINK.origSample],eax
	mov     eax,[@@gusoffset]
	mov     [ESBX+SAMPLELINK.gusSample],eax
	cmp     dx,[sampleListLength]
	jle     @@exit
	mov     [sampleListLength],dx
@@exit:
	LEAVEPROC
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   short gusStartVoice(void);
; *
; *     Description :   Starts output
; *
; ************************************************************************/

CPROC   gusStartVoice

        cmp     [gusStatus],0BEEFh
        jne     @@exit
        mov     _cx,32
	sub     eax,eax
@@closeLoop:
	push    eax _cx
	ecall   gusStopChannel eax
	pop     _cx eax
	inc     eax
	loop    @@closeloop

        ecall   setGUSTimer [deltaTime]
@@exit:
	ret
ENDP

;/*************************************************************************
; *
; *     Function    :   short gusStopVoice(void);
; *
; *     Description :   Stops output
; *
; ************************************************************************/

CPROC   gusStopVoice

        cmp     [gusStatus],0BEEFh
        jne     @@exit

        ecall   stopGUSTimer

        mov     _cx,32
	sub     eax,eax
@@closeLoop:
	push    eax _cx
	ecall   gusStopChannel eax
	pop     _cx eax
	inc     eax
	loop    @@closeloop

	mov     ax,14
        mov     bx,[gusBaseAddr]
        call    NEAR _gusReset
@@exit:
        ret
ENDP

u_IRQLatch      db      2,2,1,3,2,2,2,4,2,2,2,5,6,2,2,7
u_DMALatch      db      1,1,1,2,1,3,4,5

;/*************************************************************************
; *
; *     Function    :   short gusInit(CARDINFO *scard);
; *
; *     Description :   Inits GUS
; *
; ************************************************************************/

CPROC   gusInit @@scard

	ENTERPROC esi edi
        LESSI   [@@scard]

        mov     [mixReg],00001000b

	mov     al,[ESSI+CARDINFO.DMAIRQ]
	mov     [gusIRQ],al
	mov     al,[ESSI+CARDINFO.DMAchannel]
	mov     [gusDMA],al
	mov     al,[ESSI+2+CARDINFO.extraField]
	mov     [useDMAdownload],al
        mov     al,[ESSI+3+CARDINFO.extraField]
        mov     [useGUSTimer],al

	cli
	sub     _bx,_bx
	mov     bl,[ESSI+1+CARDINFO.extraField]
	mov     cl,[_bx+u_IRQLatch]
	shl     cl,3
	mov     bl,[ESSI+CARDINFO.DMAIRQ]
	cmp     bl,[ESSI+1+CARDINFO.extraField]
	jne     @@JustStore
        mov     cl,40h
@@JustStore:
	or	cl,[_bx+u_IRQLatch]
@@10:
	push    cx
        mov     bl,[ESSI+CARDINFO.extraField]
	mov     cl,[_bx+u_DMALatch]
        shl     cl,3
        mov     bl,[ESSI+CARDINFO.DMAchannel]
        cmp     bl,[ESSI+CARDINFO.extraField]
	jne     @@JustStore2
        mov     cl,40h                  ; Same IRQ...
        or      [mixReg],10h
@@JustStore2:
        or      cl,[_bx+u_DMALatch]
@@20:
	mov     bl,cl
	pop     cx

        ; Set up for Digital ASIC
	mov     dx,[ESSI+CARDINFO.ioPort]
        add     dl,0fh
        mov     al,5
        out     dx,al
	mov     dx,[ESSI+CARDINFO.ioPort]
        mov     al,[mixReg]
        out     dx,al
        add     dl,0Bh
        out     dx,al
        add     dl,4
        out     dx,al
        sub     dl,0Fh

        ; First do DMA control register
        mov     al,[mixReg]
        out     dx,al
        add     dl,0Bh
        mov     al,bl
        or      al,80h
        out     dx,al
        sub     dl,0Bh

        ; IRQ CONTROL REG
        mov     al,[mixReg]
        or      al,40h
        out     dx,al
	add     dl,0Bh
        mov     al,cl
        out     dx,al
	sub     dl,0Bh

        ; First do DMA control register
        mov     al,[mixReg]
        out     dx,al
	add     dl,0Bh
	mov     al,bl
	out     dx,al
	sub     dl,0Bh

	; IRQ CONTROL REG
        mov     al,[mixReg]
        or      al,40h
	out     dx,al
	add     dl,0Bh
	mov     al,cl
	out     dx,al
	sub     dl,0Bh

	; IRQ CONTROL, ENABLE IRQ
	; just to Lock out writes to irq\dma register ...
        mov     dx,[ESSI+CARDINFO.ioPort]
        add     dx,102h
        mov     al,0
        out     dx,al

	; enable output & irq, disable line & mic input
	mov     dx,[ESSI+CARDINFO.ioPort]
        mov     al,[mixReg]
	out     dx,al

	; IRQ CONTROL, ENABLE IRQ
	; just to Lock out writes to irq\dma register ...
        mov     dx,[ESSI+CARDINFO.ioPort]
        add     dx,102h
        mov     al,0
        out     dx,al
        sti
@@Exit:
        cld
        PUSHES
        push    _si
        movzx   _bx,[ESSI+CARDINFO.DMAchannel]
        imul    _bx,_bx,SIZE DMAPORT
        lea     _si,[_bx+DMAports]      ; SI = DMAports[DMAchannel]
        PUSHDS
        POPES
	mov     _di,offset curDMA       ; ESDI = curDMA
        mov     _cx,SIZE DMAPORT
	cli
        _segcs
        rep     movsb                   ; Copy structure
	sti
        pop     _si
        POPES

        mov     dx,[ESSI+CARDINFO.ioPort]         ; Close outputs/inputs
        mov     [gusBaseAddr],dx
        mov     al,00001011b
        out     dx,al

        call    initEventQueue          ; Allocate and clear the event queue
	mov     ax,[gusBaseAddr]
	sub     ebx,ebx
	mov     cl,0
        call    __gusPoke               ; Clear first two bytes of GUS memory
	mov     ax,[gusBaseAddr]
	mov     ebx,1
	mov     cl,0
	call    __gusPoke

	mov     [sampleListLength],0
        mov     [masterVol],256
	mov     [dmaActive],0
	mov     [gusBUSY],0
	mov     [irqStatus],0
	mov	[gusDeltaTime],TIME_DELTA
        mov     [gusStatus],0BEEFh

        cmp     [gusDMA],0
        je      @@nodma
        ecall   allocateGUSDMAbuffer
@@nodma:

        ecall   D_malloc <LARGE ((SIZE SAMPLELINK)*MAXSAMPLE)>
        push    _di                     ; Allocate samplelink table
IFDEF __32__
        mov     edi,eax
        mov     [sampleList],eax
ELSE
        mov     es,dx
        mov     di,ax
        mov     [WORD LOW sampleList],ax
        mov     [WORD HIGH sampleList],dx
ENDIF
        sub     _ax,_ax                 ; Clear it
        mov     _cx,(SIZE SAMPLELINK)*MAXSAMPLE
        rep     stosb
        pop     _di

        PUSHDS                          ; Prepare for clearing tables
	POPES

	memSet	chBase,32*4
	memSet	chMuted,32
	memSet	chFreq,32*4
	memSet	chVolume,32*2
	memSet	chMode,32

        LESSI   [@@scard]
        mov     ax,16
	mov     bx,[ESSI+CARDINFO.ioPort]
	call    _gusReset

	LEAVEPROC esi edi
	ret
ENDP

;/*************************************************************************
; *
; *     Function    :   void gusClose(void);
; *
; *     Description :   Closes GUS
; *
; ************************************************************************/

CPROC   gusClose

	ecall   gusStopVoice
        cmp     [gusDMA],0
        je      @@nodma
        ecall   freeGUSDMAbuffer
@@nodma:
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   short gusSetSample(short channel, SAMPLEINFO *sinfo);
; *
; *     Description :   Sets a new sample on a channel
; *
; ************************************************************************/

CPROC   gusSetSample @@channel,@@sinfo

        ENTERPROC
        mov     eax,[DWORD LOW pseudoTime]
        mov     edx,[DWORD HIGH pseudoTime]
        shrd    eax,edx,8                      ; DIV by 256
        mov     [staticEvent.time],eax
        mov     [staticEvent.func],offset __gusPrimeVoice
        LESBX   [@@sinfo]
        mov     eax,[@@channel]
        mov     edx,[ESBX+SAMPLEINFO.loopStart]
        shl     edx,8
        or      eax,edx
        mov     [staticEvent.p1],eax
        mov     eax,[ESBX+SAMPLEINFO.voiceData]
        mov     [staticEvent.p2],eax
        mov     eax,[ESBX+SAMPLEINFO.loopEnd]
	mov     edx,[ESBX+SAMPLEINFO.length]
        shl     edx,16
        or      eax,edx
	mov     [staticEvent.p3],eax

	call    insertEvent
	LEAVEPROC
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   short gusPlaySample(short @@channel, long freq, short volume);
; *
; *     Description :   Plays the sample
; *
; ************************************************************************/

CPROC   gusPlaySample @@channel,@@freq,@@volume

        ENTERPROC
        mov     eax,[DWORD LOW pseudoTime]
        mov     edx,[DWORD HIGH pseudoTime]
        shrd    eax,edx,8                      ; DIV by 256
        mov     [staticEvent.time],eax
        mov     [staticEvent.func],offset __gusGoVoice
        mov     eax,[@@channel]
        mov     [staticEvent.p1],eax
        mov     eax,[@@freq]
	mov     [staticEvent.p2],eax
        mov     eax,[@@volume]
        mov     [staticEvent.p3],eax
        call    insertEvent
        LEAVEPROC
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   short gusSetVolume(short @@channel, short volume);
; *
; *     Description :   Sets new volume on a @@channel
; *
; ************************************************************************/

CPROC   gusSetVolume @@channel,@@volume

        ENTERPROC
        mov     eax,[DWORD LOW pseudoTime]
        mov     edx,[DWORD HIGH pseudoTime]
        shrd    eax,edx,8                      ; DIV by 256
        mov     [staticEvent.time],eax
	mov     [staticEvent.func],offset __gusSetVolume
        mov     eax,[@@channel]
	mov     [staticEvent.p1],eax
	mov     eax,[@@volume]
        mov     [staticEvent.p2],eax
        call    insertEvent
        LEAVEPROC
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   short gusSetRate(short @@channel, long freq);
; *
; *     Description :   Sets new playing frequency
; *
; ************************************************************************/

CPROC   gusSetRate @@channel,@@freq

        ENTERPROC
        mov     eax,[DWORD LOW pseudoTime]
        mov     edx,[DWORD HIGH pseudoTime]
        shrd    eax,edx,8                      ; DIV by 256
        mov     [staticEvent.time],eax
        mov     [staticEvent.func],offset __gusSetRate
	mov     eax,[@@channel]
        mov     [staticEvent.p1],eax
        mov     eax,[@@freq]
        mov     [staticEvent.p2],eax
        call    insertEvent
        LEAVEPROC

        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   short gusSetPosition(short @@channel, long position);
; *
; *     Description :   Resets sample to a new playing position
; *
; ************************************************************************/

CPROC   gusSetPosition @@channel,@@position

        ENTERPROC
        mov     eax,[DWORD LOW pseudoTime]
        mov     edx,[DWORD HIGH pseudoTime]
        shrd    eax,edx,8                      ; DIV by 256
        mov     [staticEvent.time],eax
	mov     [staticEvent.func],offset __gusSetPosition
	mov     eax,[@@channel]
        mov     [staticEvent.p1],eax
        mov     eax,[@@position]
        mov     [staticEvent.p2],eax
        call    insertEvent
        LEAVEPROC
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   short gusSetPanning(short @@channel, short panning);
; *
; *     Description :   Sets voice's panning position
; *
; ************************************************************************/

CPROC   gusSetPanning @@channel,@@panning

        ENTERPROC
        mov     eax,[DWORD LOW pseudoTime]
        mov     edx,[DWORD HIGH pseudoTime]
        shrd    eax,edx,8                      ; DIV by 256
        mov     [staticEvent.time],eax
        mov     [staticEvent.func],offset __gusSetPan
        mov     eax,[@@channel]
        mov     [staticEvent.p1],eax
        mov     eax,[@@panning]
        cmp     eax,PAN_SURROUND
        jne     @@noSurround
        mov     eax,PAN_MIDDLE
@@noSurround:
        mov     [staticEvent.p2],eax
        call    insertEvent
        LEAVEPROC
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   short gusSetMasterVolume(short volume);
; *
; *     Description :   Sets new master volume
; *
; ************************************************************************/

CPROC   gusSetMasterVolume @@volume

        ENTERPROC
        mov     eax,[@@volume]
        shl     ax,2
        mov     [masterVol],ax

        movzx   ecx,[gusVoices]
        sub     _dx,_dx
@@loop:
        mov     _ax,_dx
        mov     _bx,_dx
        shl     _bx,1
	mov     bx,[chVolume+_bx]
        push    _cx _dx
	call    __gusSetVolume
	pop     _dx _cx
        inc     _dx
        loop    @@loop
        LEAVEPROC
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   short gusMuteChannel(short @@channel);
; *
; *     Description :   Mutes the voice
; *
; ************************************************************************/

CPROC   gusMuteChannel @@channel

        ENTERPROC
        saveIRQ

	mov     ebx,[@@channel]
	mov     [_bx+chMuted],1

	selectChannel bl

	mov     ax,0
	call    rampVolume

	restoreIRQ
	LEAVEPROC
	ret
ENDP

;/*************************************************************************
; *
; *     Function    :   short gusUnmuteChannel(short @@channel);
; *
; *     Description :   Unmutes the voice
; *
; ************************************************************************/

CPROC   gusUnmuteChannel @@channel

	ENTERPROC
	saveIRQ

	mov     ebx,[@@channel]
	mov     [_bx+chMuted],0

	selectChannel bl

	mov     ebx,[@@channel]
	shl     _bx,1
	mov     ax,[chVolume+_bx]
	call    rampVolume

        restoreIRQ
        LEAVEPROC
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   short gusMuteAll(void);
; *
; *     Description :   Mutes all channels
; *
; ************************************************************************/

CPROC   gusMuteAll

        movzx   ecx,[gusVoices]
@@loop:
        push    ecx
        dec     ecx
	ecall   gusMuteChannel ecx
        pop     ecx
        loop    @@loop

        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   short gusUnmuteAll(void);
; *
; *     Description :   Unmutes all channels
; *
; ************************************************************************/

CPROC   gusUnmuteAll

        movzx   ecx,[gusVoices]
@@loop:
        push    ecx
        dec     ecx
	ecall   gusUnmuteChannel ecx
	pop     ecx
        loop    @@loop
	ret
ENDP

;/*************************************************************************
; *
; *     Function    :   short gusPoll(long time);
; *
; *     Description :   "Plays buffer"
; *
; ************************************************************************/

CPROC   gusPoll @@time

	ENTERPROC

        mov     eax,[@@time]
        add     [DWORD LOW pseudoTime],eax
        adc     [DWORD HIGH pseudoTime],0
        LEAVEPROC
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   long gusGetDelta(void);
; *
; *     Description :   Gets "delta" time
; *
; ************************************************************************/

CPROC   gusGetDelta

        mov     eax,[DWORD LOW pseudoTime]
        mov     edx,[DWORD HIGH pseudoTime]
        sub     eax,[DWORD LOW curTime]
        sbb     edx,[DWORD HIGH curTime]
        js      @@ok
        sub     eax,eax
@@ok:
        neg     eax
IFDEF __16__
        shld    edx,eax,16
ENDIF
        ret
ENDP

LABEL	gusVolumes	WORD
        DW 1500h
	DW 40004,42600,44752,45648,46544,47624,48448,49232
	DW 50048,50584,51112,51656,52184,52584,52976,53376
	DW 53752,54016,54280,54520,54768,55024,55280,55544
	DW 55776,56048,56288,56536,56784,56992,57184,57384
	DW 57616,57752,57888,58000,58112,58248,58368,58480
	DW 58600,58720,58840,58960,59088,59208,59336,59464
	DW 59584,59720,59816,59944,60072,60176,60312,60408
	DW 60544,60648,60784,60888,60992,61064,61176,61248

LABEL   freqs WORD
	DW 44100,41160,38587,36317,34300,32494,30870,29400,28063,26843,25725
	DW 24696,23746,22866,22050,21289,20580,19916,19293

;/*************************************************************************
; *
; *     Function    :   rampVolume
; *
; *     Description :   Ramps the volume to AX
; *
; *     Input       :   AX = end volume
; *
; ************************************************************************/

PROC    rampVolume NEAR

	cmp     ax,64
	jbe     @@volok
	mov     ax,64
@@volok:
	imul    [masterVol]
	shr     ax,8
	movzx   ebx,ax
	shl     ebx,1
	mov	cx,[gusVolumes+_bx]

	mov     dx,[gusCmdAddr]
	mov     al,89h
	out     dx,al
	inc     dx
	in      ax,dx
	push    cx
	push    ax
	shr     ax,8
	shr     cx,8
	cmp     ax,cx
	je      @@Done2
	jb      @@OK
	xchg    cx,ax
@@OK:
	push    ax
	mov     dx,[gusCmdAddr]
	mov     al,0Dh			; Stop old ramp
	out     dx,al
        WWAIT
	add	dx,2
	mov	al,00000011b
	out	dx,al

        WWAIT
	mov     dx,[gusCmdAddr]
	mov     al,7			; Set ramp start
	out     dx,al
        WWAIT
	add     dx,2
	pop     ax
	out     dx,al

        WWAIT
	mov     dx,[gusCmdAddr]
	mov     al,8			; Set ramp end
	out     dx,al
        WWAIT
	add     dx,2
	mov     ax,cx
	out     dx,al

        WWAIT
	mov     dx,[gusCmdAddr]
	mov     al,6
	out     dx,al
        WWAIT
	add     dx,2
        mov     al,00111111b
	out     dx,al
	mov     bl,00000000b
	pop     ax
	pop     cx
	cmp     ax,cx
	jb      @@OK2
	or      bl,01000000b
@@OK2:
	REPT 2
	mov     dx,[gusCmdAddr]
	mov     al,0Dh
	out     dx,al
	add     dx,2
	mov     al,bl
	out     dx,al
	DELAY
	ENDM
	jmp     @@Done
@@Done2:
	pop     ax ax
@@Done:

	ret
ENDP

;/*************************************************************************
; *
; *     Description : Sets up ('primes') a sample to be played in the @@channel
; *
; *     Input       :   ax      = @@channel
; *
; ************************************************************************/

PROC    __gusPrimeVoice NEAR
locs = 0
procargs = 0
LOCALVAR        _word @@channel
LOCALVAR        _dword @@sample
LOCALVAR        _dword @@loopStart
LOCALVAR        _dword @@loopEnd
LOCALVAR        _dword @@voicegus
LOCALVAR        _dword @@slength

        ENTERPROC _si
        mov     [@@channel],ax
        and     [word @@channel],7Fh
        shr     eax,8
        mov     [@@loopStart],eax
        mov     [@@sample],ebx
        mov     [@@loopEnd],ecx
        and     [dword @@loopEnd],0FFFFh
	shr     ecx,16
	mov     [@@slength],ecx

	saveIRQ

	PUSHES
	ecall   findSample <[dword @@sample]>
	POPES
	mov     [@@voicegus],eax

	selectChannel <[byte @@channel]>

	sub     al,al
	cmp     [DWORD @@loopEnd],0
	jz      @@noloop
	or      al,8
@@noloop:
	movzx   ebx,[word @@channel]
	mov	[_bx+chMode],al		; Save mode
	shl     ebx,2
	mov	eax,[@@voicegus]
	cmp	eax,[_bx+chBase]
	je	@@nostop
	mov     [_bx+chBase],eax

        sub     ax,ax
        call    rampVolume

        sti
        mov     _cx,200
@@waitramp:
        mov     dx,[gusCmdAddr]         ; Wait ramp to stop
        mov     al,8Dh
        cli
        out     dx,al
        add     dx,2
        in      al,dx
        sti
        test    al,1
        loopz   @@waitramp

        cli
        mov     dx,[gusCmdAddr]         ; Stop old voice
	mov     al,0
	out     dx,al
        WWAIT
	add     dx,2
	mov	al,3
	out     dx,al
	sub     dx,2
	DELAY
	mov     al,0
	out     dx,al
        WWAIT
	add     dx,2
	mov	al,3
	out     dx,al
	sub     dx,2
@@nostop:
	mov     dx,[gusCmdAddr]
	mov     al,0ah
	out     dx,al                   ; Set beginning of data
	inc     dx
	mov     eax,[@@voicegus]
	shr     eax,7
	and     ax,1fffh
	out     dx,ax
        WWAIT
	dec     dx
	mov     al,0bh
	out     dx,al
	inc     dx
	mov     ax,[WORD @@voicegus]
	and     ax,07fh
	shl     ax,9
	out     dx,ax

	mov     dx,[gusCmdAddr]
	mov     ebx,[@@voicegus]
	cmp     [DWORD @@loopEnd],0
	je      @@noloopings
	add     ebx,[@@loopStart]
        cmp     [DWORD @@loopStart],2
        jle     @@noloopings
        sub     ebx,1
@@noloopings:
	mov     al,02h
	out     dx,al                   ; Set start of loop
	inc     dx
	mov     eax,ebx
	shr     eax,7
	and     ax,1fffh
	out     dx,ax
        WWAIT
	dec     dx
	mov     al,03h
	out     dx,al
	inc     dx
	mov     ax,bx
	and     ax,07fh
	shl     ax,9
	out     dx,ax

	mov     dx,[gusCmdAddr]
	mov     ebx,[@@voicegus]
	mov     eax,[@@loopEnd]
	or      eax,eax
	jne     @@looping
	mov     eax,[@@slength]
        sub     eax,1
@@looping:
        sub     eax,1
        add     ebx,eax
	mov     al,04h
	out     dx,al                   ; Set end of loop
	inc     dx
	mov     eax,ebx
	shr     eax,7
	and     ax,1fffh
	out     dx,ax
        WWAIT
	dec     dx
	mov     al,05h
	out     dx,al
        WWAIT
	inc     dx
	mov     ax,bx
	and     ax,07fh
	shl     ax,9
	out     dx,ax

@@done:
	restoreIRQ
@@exit:
	sub     _ax,_ax
	LEAVEPROC _si
	ret
ENDP

;/*************************************************************************
; *
; *     Description : Plays a sample that has been primed beforehand
; *
; *     Input       :   ax      = @@channel number
; *                     ebx     = rate
; *                     cx      = volume
; *
; ************************************************************************/

PROC    __gusGoVoice NEAR
locs = 0
procargs = 0
LOCALVAR        _word @@channel
LOCALVAR        _dword @@rate
LOCALVAR        _word @@vol
LOCALVAR        _dword @@base

	ENTERPROC
	mov     [@@channel],ax
	mov     [@@rate],ebx
	mov     [@@vol],cx

	saveIRQ

        movzx   ebx,[WORD @@channel]
	shl     ebx,1
	mov     ax,[@@vol]
	mov     [_bx+chVolume],ax
	shl     ebx,1
	mov     eax,[_bx+chBase]
	mov     [@@base],eax

	selectChannel <[byte @@channel]>

        sub     ax,ax
        call    rampVolume

        mov     _cx,200
@@waitramp:
        mov     dx,[gusCmdAddr]         ; Wait ramp to stop
        mov     al,8Dh
        cli
        out     dx,al
        add     dx,2
        in      al,dx
        sti
        test    al,1
        loopz   @@waitramp

        cli
	mov     dx,[gusCmdAddr]         ; Stop old voice
	mov     al,0
	out     dx,al
        WWAIT
	add     dx,2
	mov	al,3
	out     dx,al
	sub     dx,2
	DELAY
	mov     al,0
	out     dx,al
        WWAIT
	add     dx,2
	mov	al,3
	out     dx,al
	sub     dx,2

	mov     dx,[gusCmdAddr]
	mov     al,0ah
	out     dx,al                   ; Set beginning of data
	inc     dx
	mov     eax,[@@base]
	shr     eax,7
	and     ax,1fffh
	out     dx,ax
        WWAIT
	dec     dx
	mov     al,0bh
	out     dx,al
	inc     dx
	mov     ax,[WORD @@base]
	and     ax,07fh
	shl     ax,9
	out     dx,ax

	movzx   ebx,[gusVoices]
	sub     ebx,14
	shl     ebx,1
	movzx   eax,[freqs+_bx]         ; Set playing frequency
	mov     ecx,eax
	mov     ebx,[@@rate]
	shl     ebx,9
	shr     eax,1
	add     eax,ebx
	sub     edx,edx
	idiv    ecx
	shl     eax,1
	mov     cx,ax

	mov     dx,[gusCmdAddr]
	mov     al,1
	out     dx,al
        WWAIT
        inc     dx
	mov     ax,cx
	out     dx,ax

	movzx   ebx,[WORD @@channel]
	shl     ebx,2
	mov     eax,[@@rate]
	mov     [_bx+chFreq],eax

	mov     dx,[gusCmdAddr]
	mov     al,9
	out     dx,al
        WWAIT
        inc     dx
        mov     ax,[gusVolumes]         ; Volume = 0
	out     dx,ax
	DELAY
	out	dx,ax

	movzx   ebx,[WORD @@channel]
	mov	cl,[_bx+chMode]		; Get mode

	mov     dx,[gusCmdAddr]
	mov	al,0
	out	dx,al
        WWAIT
        add     dx,2
	mov	al,cl
	out	dx,al			; Start voice 2 times
	DELAY
	sub	dx,2
	mov	al,0
	out	dx,al
        WWAIT
        add     dx,2
	mov	al,cl
	out	dx,al

	movzx   ebx,[WORD @@channel]
	cmp     [_bx+chMuted],1
	je      @@novol

	mov     ax,[@@vol]
	call    rampVolume

@@novol:

	restoreIRQ
@@exit:
	sub     _ax,_ax
	LEAVEPROC
	ret
ENDP

;/*************************************************************************
; *
; *     Function    : int gusSetVolume(int @@channel,unsigned volume);
; *
; *     Description : Changes the volume of a @@channel
; *
; *     Input       :   ax = @@channel nr.
; *                     bx = volume
; *
; ************************************************************************/

PROC    __gusSetVolume NEAR
locs = 0
procargs = 0
LOCALVAR        _word @@channel
LOCALVAR        _word @@vol

        ENTERPROC
        mov     [@@channel],ax
        mov     [@@vol],bx

	checkMute

	movzx   ebx,[WORD @@channel]
	shl     ebx,1
	mov     ax,[@@vol]
	mov     [_bx+chVolume],ax

	saveIRQ

	selectChannel <[byte @@channel]>

	mov     ax,[@@vol]
	call    rampVolume

        restoreIRQ
@@exit:
	LEAVEPROC
	ret
ENDP

;/*************************************************************************
; *
; *     Function    : int gusStopChannel(int @@channel);
; *
; *     Description : Stops the voice on @@channel
; *
; *     Input       :   ax = @@channel nr.
; *
; ************************************************************************/

CPROC   gusStopChannel @@channel

	ENTERPROC _si
	saveIRQ

	selectChannel <[byte @@channel]>

	mov     ebx,[@@channel]
	shl     ebx,1
	mov     [_bx+chVolume],0
	shl     ebx,1
	mov     [_bx+chFreq],0
	mov     [_bx+chBase],-1

	mov     ax,0
	call    rampVolume

        mov     _cx,200
@@waitramp:
        mov     dx,[gusCmdAddr]         ; Wait ramp to stop
        mov     al,8Dh
        cli
        out     dx,al
        add     dx,2
        in      al,dx
        sti
        test    al,1
        loopz   @@waitramp

	mov     dx,[gusCmdAddr]
	mov     al,0
	out     dx,al
        WWAIT
        add     dx,2
	mov     al,3                    ; Stop voice
	out     dx,al
	sub     dx,2
	DELAY
	mov     al,0
	out     dx,al
        WWAIT
        add     dx,2
	mov     al,3                    ; Stop voice second time
	out     dx,al
	sub     dx,2

	DELAY

	mov     dx,[gusCmdAddr]
	mov     al,9
	out     dx,al
        WWAIT
        inc     dx
        mov     ax,[gusVolumes]         ; Volume = 0
	out     dx,ax

	mov     dx,[gusCmdAddr]
	mov     al,0ah                  ; Current position
	out     dx,al
        WWAIT
        inc     dx
	mov     ax,0
	out     dx,ax
        WWAIT
        dec     dx
	mov     al,0bh
	out     dx,al
        WWAIT
        inc     dx
	mov     ax,0
	out     dx,ax
	dec     dx

	mov     al,02h                  ; Loop start
	out     dx,al
        WWAIT
        inc     dx
	mov     ax,0
	out     dx,ax
        WWAIT
        dec     dx
	mov     al,03h
	out     dx,al
        WWAIT
        inc     dx
	mov     ax,0
	out     dx,ax
        WWAIT
        dec     dx

	mov     al,04h                  ; Loop end
	out     dx,al
        WWAIT
        inc     dx
	mov     ax,0
	out     dx,ax
        WWAIT
        dec     dx
	mov     al,05h
	out     dx,al
        WWAIT
        inc     dx
	mov     ax,0
	out     dx,ax
	dec     dx

        mov     _cx,MAXEVENT
        LESSI   [eventQueue]
        mov     dl,[byte @@channel]
@@clearChannelEvents:
        cmp     dl,[byte ESSI+GUSEVENT.p1] ; Is channel the same?
	jne	@@next
        mov     [ESSI+GUSEVENT.func],0 ; Don't call it
@@next:
	add	_si,SIZE GUSEVENT
	loop	@@clearChannelEvents

        restoreIRQ

        LEAVEPROC _si
	ret
ENDP

;/*************************************************************************
; *
; *     Function    : int gusSetRate(int @@channel,unsigned long rate);
; *
; *     Description : Changes the rate (frequency) of a @@channel
; *
; *     Input       :   ax  = @@channel
; *                     ebx = rate
; *
; ************************************************************************/

PROC    __gusSetRate NEAR
locs = 0
procargs = 0
LOCALVAR        _word @@channel
LOCALVAR        _dword @@rate

        ENTERPROC
	mov     [@@channel],ax
        mov     [@@rate],ebx
        mov     ecx,[@@rate]

	checkMute

	movzx   _bx,[gusVoices]
	sub     _bx,14
	shl     _bx,1
	movzx   eax,[freqs+_bx]
	mov     ecx,eax
	mov     ebx,[@@rate]
	shl     ebx,9
	shr     eax,1
	add     eax,ebx
	sub     edx,edx
	idiv    ecx
	shl     eax,1
	mov     cx,ax

	saveIRQ

	selectChannel <[byte @@channel]>

	DELAY

	mov     dx,[gusCmdAddr]
	mov     al,1
	out     dx,al
        WWAIT
        inc     dx
	mov     ax,cx
	out     dx,ax

	restoreIRQ
@@exit:
	LEAVEPROC
	ret
ENDP



;/*************************************************************************
; *
; *     Description : Sets the sample position to an absolute location
; *
; *     Input       : ax = @@channel
; *                   ebx = pos
; *
; ************************************************************************/

PROC    __gusSetPosition NEAR
locs = 0
procargs = 0
LOCALVAR        _word @@channel
LOCALVAR        _dword @@pos

	ENTERPROC
	mov     [@@channel],ax
	mov     [@@pos],ebx

	checkMute

	saveIRQ

	movzx   ebx,[WORD @@channel]
	shl     ebx,2
	mov     eax,[_bx+chBase]
	add     [@@pos],eax

	selectChannel <[byte @@channel]>

        REPT 2
	mov     dx,[gusCmdAddr]
	mov     al,0ah
	out     dx,al
        WWAIT
        inc     dx
	mov     eax,[@@pos]
	shr     eax,7
	out     dx,ax
        WWAIT
        dec     dx
	mov     al,0bh
	out     dx,al
        WWAIT
        inc     dx
	mov     ax,[WORD @@pos]
	shl     ax,9
	out     dx,ax
	DELAY
	ENDM

	restoreIRQ
@@exit:
	LEAVEPROC
	ret
ENDP

;/*************************************************************************
; *
; *     Description : Sets the panning position
; *
; *     Input       : ax = @@channel
; *                   ebx = panning value (-63 - 63)
; *
; ************************************************************************/

PROC    __gusSetPan NEAR

	mov     dl,al

	saveIRQ

	selectChannel dl

	cmp     bl,-63
	jge     @@1
	mov     bl,-63
@@1:
	cmp     bl,63
	jle     @@2
	mov     bl,63
@@2:
	sar     bl,3
	add     bl,8
	and     bl,0Fh

	mov     dx,[gusCmdAddr]
	mov     al,0Ch
	out     dx,al
        WWAIT
        add     dx,2
	mov     al,bl
	out     dx,al

	restoreIRQ

	ret
ENDP

CPROC   gusPoke @@addr, @@value

        ENTERPROC
	saveIRQ
        mov     ax,[gusBaseAddr]
        mov     ebx,[@@addr]
        mov     cl,[byte @@value]
        call    __gusPoke
        restoreIRQ
        LEAVEPROC
        ret
ENDP

CPROC   gusPeek @@addr

        ENTERPROC
        saveIRQ
        mov     ax,[gusBaseAddr]
        mov     ebx,[@@addr]
        call    __gusPeek
        mov     cx,ax
        restoreIRQ
        mov     ax,cx
        LEAVEPROC
        ret
ENDP

PROC    __gusPoke NEAR ;ax=port, ebx=addr, cl=data

        push    ax
        mov     dx,ax
	add     dx,103h
        mov     al,43h
        out     dx,al
        inc     dx
        mov     ax,bx
        out     dx,ax
        dec     dx
	mov     al,44h
	out     dx,al
	add     dx,2
        shr     ebx,16
	mov     al,bl
	out     dx,al
	pop     dx
        add     dx,107h
	mov     al,cl
        out     dx,al
        ret
ENDP

PROC    __gusPeek NEAR ;ax=port, ebx=addr

        push    ax
        mov     dx,ax
        add     dx,103h
        mov     al,43h
        out     dx,al
        inc     dx
        mov     ax,bx
        out     dx,ax
        dec     dx
        mov     al,44h
        out     dx,al
        add     dx,2
        shr     ebx,16
        mov     al,bl
        out     dx,al
        pop     dx
        add     dx,107h
        in      al,dx
        ret
ENDP

;/*************************************************************************
; *
; *     Description : Init
; *
; *     Input       :   ax = @@channel count
; *                     bx = base address
; *
; ************************************************************************/

PROC    _gusReset NEAR

	cmp     ax,14
	jae     @@ok
	mov     ax,14
@@ok:
	cmp     ax,32
	ja      @@err
	mov     [gusVoices],al
	mov     [gusBaseAddr],bx
	add     bx,102h
	mov     [gusChannelAddr],bx
	inc     bx
	mov     [gusCmdAddr],bx

	saveIRQ

	mov     dx,[gusCmdAddr]         ; Pull reset
	mov     al,4ch
	out     dx,al
        WWAIT
        add     dx,2
	sub     al,al
	out     dx,al

	REPT    10
	    DELAY
	ENDM

	mov     dx,[gusCmdAddr]         ; Release reset
	mov     al,4ch
	out     dx,al
        WWAIT
        add     dx,2
	mov     al,1
	out     dx,al

	REPT    10
	    DELAY
	ENDM

	mov     dx,[gusBaseAddr]        ; Reset MIDI
	add     dx,100h
	mov     al,3
	out     dx,al

	REPT    10
	    DELAY
	ENDM

	mov     dx,[gusBaseAddr]
	add     dx,100h
	mov     al,0
	out     dx,al

	mov     dx,[gusCmdAddr]         ; Disable DMA
	mov     al,41h
	out     dx,al
        WWAIT
        add     dx,2
	mov     al,0
	out     dx,al
	sub     dx,2

	mov     al,45h                  ; Disable timers
	out     dx,al
        WWAIT
        add     dx,2
	mov     al,0
	out     dx,al
	sub     dx,2

	mov     al,49h                  ; Disable sampling
	out     dx,al
        WWAIT
        add     dx,2
	mov     al,0
	out     dx,al
	sub     dx,2

	DELAY

	restoreIRQ
	DELAY
	saveIRQ

	mov     dx,[gusBaseAddr]        ; Ack any IRQ
	add     dx,6
	in      al,dx

	mov     dx,[gusCmdAddr]         ; Ack DMA IRQ
	mov     al,41h
	out     dx,al
	add     dx,2
	in      al,dx
	sub     dx,2

	mov     al,49h                  ; Ack sampling IRQ
	out     dx,al
	add     dx,2
	in      al,dx
	sub     dx,2

	mov     al,8fh
	out     dx,al
	add     dx,2
	in      al,dx

	mov     dx,[gusCmdAddr]
	mov     al,0eh                  ; Set the number of active voices
	out     dx,al
        WWAIT
        add     dx,2
	mov     al,31
	or      al,0c0h
	out     dx,al

	mov     ecx,32
@@resetloop:
	push    ecx
	dec     ecx
	ecall   gusStopChannel ecx
	pop     ecx

	mov     dx,[gusChannelAddr]     ; Reset voices
	mov     al,cl
	dec     al
	out     dx,al

	inc     dx
	mov     al,6
	out     dx,al
        WWAIT
        add     dx,2
	mov     al,0                    ; Volume ramp speed = 0
	out     dx,al
	sub     dx,2

	mov     al,0Dh                  ; Turn ramp off
	out     dx,al
        WWAIT
        add     dx,2
	mov     al,11b
	out     dx,al
	DELAY
	out	dx,al
        WWAIT
        sub     dx,2

	mov     al,9
	out     dx,al
        WWAIT
        inc     dx
	sub     ax,ax
	out     dx,ax
	DELAY
	out	dx,ax
	dec     dx

	mov     al,0
	out     dx,al
        WWAIT
        add     dx,2
	mov     al,11b                  ; Turn voice off
	out     dx,al
	DELAY
	out	dx,al

	loop    @@resetloop

	restoreIRQ
	DELAY
	saveIRQ

	mov     dx,[gusBaseAddr]        ; Ack any IRQ
	add     dx,6
	in      al,dx

	mov     dx,[gusCmdAddr]         ; Ack DMA IRQ
	mov     al,41h
	out     dx,al
	add     dx,2
	in      al,dx
	sub     dx,2

	mov     al,49h                  ; Ack sampling IRQ
	out     dx,al
	add     dx,2
	in      al,dx
	sub     dx,2

	mov     al,8fh
	out     dx,al
	add     dx,2
	in      al,dx

	mov     dx,[gusCmdAddr]
	mov     al,0eh                  ; Set the number of active voices
	out     dx,al
	add     dx,2
	mov     al,[byte gusVoices]
	dec     al
	or      al,0c0h
	out     dx,al

	mov     dx,[gusCmdAddr]         ; Reset
	mov     al,4ch
	out     dx,al
        WWAIT
        add     dx,2
	mov     al,7
	out     dx,al

	mov     dx,[gusBaseAddr]
        mov     al,[mixReg]             ; Enable output & line input
	out     dx,al

	restoreIRQ

	sub     _ax,_ax
	jmp     @@eksitti
@@err:
	mov     _ax,-1
@@eksitti:
	ret
ENDP

;/*************************************************************************
; *
; *     Function    :   void dma64(long gusStart,long start,unsigned length);
; *
; ************************************************************************/

CPROC   gusDMADownload @@gusStart, @@from, @@len

        ENTERPROC  _di _si

        PUSHDS                          ; First move the data to DMA buffer
        LESDI   [gusDMAbuffer]
        LDSSI   [@@from]
        cld
        mov     ecx,[@@len]
        shr     ecx,2
        rep     movsd
        mov     ecx,[@@len]
        and     ecx,3
        rep     movsb
        POPDS

	cmp     [gusDMA],4
	jl      @@gus8
        mov     eax,[@@gusStart]        ; Translate address for 16-bit DMA
	mov     edx,eax
	shr     eax,1
	and     eax,0001FFFFh
	and     edx,000c0000h
	or      eax,edx
	mov     [@@gusStart],eax
@@gus8:
        mov     eax,[gusDMAbufferPhys]
        mov     ebx,eax
	shr	ebx,16
        cmp     [gusDMA],4
	jb	@@8bitDMA
	push	bx
	shr	bl,1
	rcr	ax,1			; For word addressing
	pop	bx
        inc     [@@len]
        shr     [@@len],1               ; For word count
@@8bitDMA:
        mov     cx,bx
        mov     bx,ax                   ; Offset
        mov     ah,cl                   ; Page

	cli
	mov     al,[gusDMA]
	or      al,4
	mov     dx,[curDMA.wrsmr]
	out     dx,al                   ; Break On
	mov     al,[gusDMA]
	and     al,3
	or      al,048h
	mov     dx,[curDMA.wrmode]
	out     dx,al
	mov     dx,[curDMA.page]
	mov     al,ah
	out     dx,al                   ; Page
	mov     al,0
	mov     dx,[curDMA.clear]
	out     dx,al                   ; Reset counter

	mov     dx,[curDMA.addr]
	mov     al,bl
	out     dx,al                   ; Offset
	mov     al,bh
	out     dx,al

	mov     al,0
	mov     dx,[curDMA.clear]
	out     dx,al                   ; Reset counter

	mov	ecx,[@@len]
	jcxz    @@zero
	dec     cx
@@zero:
	mov     dx,[curDMA.count]
	mov     al,cl
	out     dx,al                   ; Count
	mov     al,ch
	out     dx,al

	mov     al,[gusDMA]
	and     al,3
	mov     dx,[curDMA.wrsmr]
	out     dx,al                   ; Break Off

	shr     [@@gusStart],4

	saveIRQ

	mov     dx,[gusCmdAddr]
	mov     al,42h
        out     dx,al
        inc     dx
	mov     ax,[WORD @@gusStart]
	out     dx,ax
        dec     dx

        mov     al,41h
	out     dx,al
	add     dx,2
        mov     al,10000001b            ; Invert MSB, full speed, 8-bit DATA
	cmp     [gusDMA],4
	jl      @@not16
	or      al,00000100b
@@not16:
	out     dx,al                   ; Start transfer

	restoreIRQ
        sti

        mov     _cx,4000
@@startloop:
        loop    @@startloop             ; Wait for transfer to start
@@wait:
        mov     dx,[gusCmdAddr]
	mov     al,41h
        cli
        out     dx,al
	add     dx,2
        in      al,dx
        sti
        test    al,40h
        jz      @@wait
@@waitdone:
        mov     ecx,4000
@@delay:
        loop    @@delay

        cli
        mov     al,[gusDMA]
	or      al,4
	mov     dx,[curDMA.wrsmr]
	out     dx,al                   ; Break On
	mov     dx,[gusCmdAddr]
	mov     al,41h
        out     dx,al
	add     dx,2
	mov     al,0                    ; Stop GUS DMA
	out     dx,al
        sti

        LEAVEPROC _di _si
	ret
ENDP

;/*************************************************************************
; *
; *     Function : void gushmCopyTo(GUSH handle, void *ptr, long start, long length);
; *
; ************************************************************************/

CPROC   gushmCopyTo @@handle,@@pptr,@@start,@@len
LOCVARS _dword @@s_page, _dword @@e_page, _dword @@s_addr, _dword @@e_addr

	ENTERPROC _di _si

        cmp     [useDMAdownload],1
	jne     @@oldmethod

	saveIRQ

        mov     dx,[gusBaseAddr]        ; Ack any IRQ
	add     dx,6
	in      al,dx

	mov     dx,[gusCmdAddr]         ; Ack DMA IRQ
	mov     al,41h
	out     dx,al
	add     dx,2
	in      al,dx

	restoreIRQ

        mov     eax,[@@start]
        add     [@@handle],eax
@@dloadloop:
        mov     ecx,[@@len]
        cmp     _cx,[gusDMAbufferSize]   ; Is it smaller thatn DMA buf size?
        jb      @@lastdload

        sub     esi,esi
        mov     _si,[gusDMAbufferSize]  ; Dload bufsize bytes
        ecall   gusDMADownload [@@handle],[@@pptr],esi

        add     [@@handle],esi          ; Increment pointers
        add     [@@pptr],esi
        sub     [@@len],esi             ; Decrement length
        jmp     @@dloadloop
@@lastdload:
        jecxz   @@dloaddone

        ecall   gusDMADownload [@@handle],[@@pptr],ecx  ; Dload rest
        jmp     @@dloaddone

@@oldmethod:

        mov     eax,[@@start]
        add     [@@handle],eax
        mov     si,[WORD HIGH @@handle]
        mov     di,[WORD LOW @@handle]
	mov     ecx,[@@len]
        add     ecx,4
	mov     dx,[gusCmdAddr]
        mov     al,44h          ; Dump upper byte, only do it on carry from now
	cli
	out     dx,al           ; on.
        add     dx,2
	mov     ax,si
	out     dx,al
        sti
        sub     dx,2
        PUSHDS
        LDSBX   [@@pptr]
ALIGN 4
@@MainLoop:
	mov     al,43h
        cli
        out     dx,al
        inc     dx
        mov     ax,di
	out     dx,ax           ; Set address
        sti

	add     dx,3
        mov     al,[_bx]
        inc     _bx
        xor     al,80h
        out     dx,al           ; Download byte
        sub     dx,4
	add     di,1
	jc      @@DoLoop
        dec     _cx
        jnz     @@MainLoop
	jmp     short @@done
@@DoLoop:
	inc     si
	mov     al,44h
	cli
	out     dx,al
	add     dx,2
	mov     ax,si
	out     dx,al
	sti
	sub     dx,2
	loop    @@MainLoop
@@done:
	POPDS
@@dloaddone:

	LEAVEPROC _di _si
	ret
ENDP

;/*************************************************************************
; *
; *     Function : int gusDownloadSample(void *ptr, long ptag, long length);
; *
; ************************************************************************/

CPROC   gusDownloadSample @@pptr,@@ptag,@@len

	ENTERPROC edi esi
	ecall   gushmAlloc [@@len]
IFDEF __32__
        test    eax,eax
        jz      @@errorexit
	push    eax
	ecall   gushmCopyTo eax,[@@pptr],<LARGE 0>,[@@len]
	pop     eax
	ecall   insertSample [@@ptag],eax
ELSE
        mov     cx,dx
        or      cx,ax
        jz      @@errorexit
        push    dx ax
	ecall   gushmCopyTo <dx ax>,[@@pptr],<LARGE 0>,[@@len]
	pop     ax dx
	ecall   insertSample [@@ptag],<dx ax>
ENDIF
        sub     _ax,_ax
        jmp     @@exit
@@errorexit:
        mov     _ax,-1
@@exit:
	LEAVEPROC edi esi
	ret
ENDP

;/*************************************************************************
; *
; *     Function : void gusUnloadSample(void *ptr);
; *
; ************************************************************************/

CPROC   gusUnloadSample @@pptr

	ENTERPROC
	ecall   findSample [@@pptr]
	cmp	_bx,-1
	je	@@exit
	mov     [ESBX+SAMPLELINK.origSample],0   ; Clear entry
	ecall   gushmFree eax
@@exit:
	LEAVEPROC
	ret
ENDP

;/*************************************************************************
; *
; *     Function : void gusUnloadAll(void);
; *
; ************************************************************************/

CPROC   gusUnloadAll

	ENTERPROC _di _si
	ecall   gushmFreeAll
        LESDI   [sampleList]
        sub     eax,eax
	mov     _cx,(SIZE SAMPLELINK)*MAXSAMPLE/4
	cld
	rep     stosd
	mov     [sampleListLength],0
	LEAVEPROC _di _si
	ret
ENDP

;/*************************************************************************
; *
; *     Function : long gusGetSamplingRate(void);
; *
; ************************************************************************/

CPROC   gusGetSamplingRate

	movzx   ebx,[gusVoices]
	sub     ebx,14
	shl     ebx,1
        movzx   eax,[freqs+_bx]
        cwd
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   ushort gusGetVolume(short @@channel);
; *
; *     Description :   Returns the current volume on '@@channel'
; *
; ************************************************************************/

CPROC   gusGetVolume @@channel

        ENTERPROC
        mov     ebx,[@@channel]
	shl     ebx,1
        movzx   eax,[chVolume+_bx]
        cwd
        LEAVEPROC
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   ulong gusGetRate(short @@channel);
; *
; *     Description :   Returns the current frequency on '@@channel'
; *
; ************************************************************************/

CPROC   gusGetRate @@channel

        ENTERPROC

	selectChannel	<[byte @@channel]>

	sub	eax,eax
	mov	dx,[gusCmdAddr]
	mov	al,81h
	out	dx,al
	inc	dx
	in	ax,dx
	shr	ax,1

	movzx   _bx,[gusVoices]
	sub     _bx,14
	shl     _bx,1
	movzx   ecx,[freqs+_bx]

	imul	ecx
	shr	eax,9
	sub	edx,edx

IF16    <shld   edx,eax,16>
	LEAVEPROC
	ret
ENDP

;/*************************************************************************
; *
; *     Function    :   ulong gusGetPosition(short @@channel);
; *
; *     Description :   Returns the current position on '@@channel'
; *
; ************************************************************************/

CPROC   gusGetPosition @@channel
LOCALVAR        _dword @@pos

        ENTERPROC
        saveIRQ

        selectChannel <[byte @@channel]>

	mov     dx,[gusCmdAddr]         ; Get position
        mov     al,8ah
        out     dx,al
	inc     dx
        sub     eax,eax
	in      ax,dx
        and     ax,01FFFh
        shl     eax,7
        mov     [@@pos],eax
        dec     dx
        mov     al,8bh
        out     dx,al
        inc     dx
        in      ax,dx
        shr     ax,9
        or      [WORD @@pos],ax

        restoreIRQ

        mov     eax,[@@pos]             ; Absolute position
        mov     ebx,[@@channel]         ; Convert it to relative
	shl     ebx,2                   ; position
	sub     eax,[chBase+_bx]
IF16    <shld   edx,eax,16>
	LEAVEPROC
	ret
ENDP

;/*************************************************************************
; *
; *     Function    :   ushort gusGetPanning(short @@channel);
; *
; *     Description :   Returns the current pan value on '@@channel'
; *
; ************************************************************************/

CPROC   gusGetPanning @@channel

        ENTERPROC
        saveIRQ

        selectChannel <[byte @@channel]>

	mov     dx,[gusCmdAddr]         ; Get Pan position
        mov     al,8Ch
        out     dx,al
        add     dx,2
        in      al,dx
	sub     al,8
        shl     al,3
        sub     ah,ah
        mov     bx,ax

        restoreIRQ

IF32    <movsx  eax,bx>
IF16    <mov    ax,bx>
        LEAVEPROC
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   ulong gusGetSample(short @@channel);
; *
; *     Description :   Returns a pointer to the current sample on '@@channel'
; *
; ************************************************************************/

CPROC   gusGetSample @@channel

        ENTERPROC
	mov     ebx,[@@channel]
        shl     ebx,2
	mov     eax,[chBase+_bx]
IF16    <shld   edx,eax,16>
        LEAVEPROC
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   short gusSetupChannels(short count, ushort *volTable);
; *
; *     Description :   Sets a 'count' channels on GUS
; *
; ************************************************************************/

CPROC   gusSetupChannels @@count,@@volTable

	ENTERPROC
	saveIRQ
        mov     eax,[@@count]
	cmp     ax,14
        jg      @@10
        mov     ax,14
@@10:
        mov     [gusVoices],al

        sub     ecx,ecx
        mov     cl,32
@@loop1:
	push	ecx
	ecall	gusStopChannel ecx
	pop	ecx
        loop    @@loop1

        sti
        mov     _cx,10000               ; To clear all channels...
@@waitloop:
        loop    @@waitloop

        cli
        mov     dx,[gusCmdAddr]
        mov     al,0eh                  ; Set the number of active voices
        out     dx,al
	add     dx,2
        mov     al,[gusVoices]
        dec     al
        or      al,0c0h
	out     dx,al

        sub     ecx,ecx
        mov     cl,32
@@loop:
	push	ecx
	ecall	gusStopChannel ecx
	pop	ecx
	loop	@@loop
@@exit:
	restoreIRQ
	LEAVEPROC
	ret
ENDP

;/*************************************************************************
; *
; *     Function    :   int gusGetChannelStatus(short @@channel);
; *
; *     Description :   Returns the status of the channel
; *
; ************************************************************************/

CPROC   gusGetChannelStatus @@channel

	ENTERPROC _si
	sub       _si,_si
	saveIRQ
	mov     ebx,[@@channel]
	cmp     [_bx+chMuted],1
	jne     @@1
	or      _si,CH_PAUSED
	jmp     @@exit
@@1:
	selectChannel <[byte @@channel]>

	mov     dx,[gusCmdAddr]         ; Get voice status
	mov     al,80h
	out     dx,al
	add     dx,2
	in      al,dx
	test    al,00000001b
	jnz     @@2
	or      _si,CH_PLAYING
	test    al,00001000b
	jz      @@2
	or      _si,CH_LOOPING
@@2:
@@exit:
	restoreIRQ
	mov       _ax,_si           ; Return status in (E)AX
	LEAVEPROC _si
	ret
ENDP

ENDS

END
