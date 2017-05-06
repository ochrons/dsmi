;/************************************************************************
; *
; *     File        : VDS.ASM
; *
; *     Description : Virtual DMA services
; *
; *     Copyright (C) 1993 Otto Chrons
; *
; ***********************************************************************/

	IDEAL
	JUMPS
	P386

	INCLUDE "MODEL.INC"

CSEGMENTS VDS

CDATASEG

	vdsInited       DB ?
ENDS

CCODESEG VDS

	CPUBLIC  vdsInit
	CPUBLIC  vdsEnableDMATranslation, vdsDisableDMATranslation
	CPUBLIC  vdsLockDMA, vdsUnlockDMA


;/*************************************************************************
; *
; *     Function    :   int vdsInit(void);
; *
; *     Description :   Initializes VDS
; *
; *     Returns     :   0 = OK
; *                     -1 = error
; *
; ************************************************************************/

CPROC    vdsInit

        mov     [vdsInited],0

        mov     ax,40h
        mov     es,ax
        mov     al,[es:7Bh]
        test    al,00100000b            ; Are services available?
        mov     ax,-1                   ; Set error code
        jz      @@exit
        mov     [vdsInited],1
        mov     ax,0
@@exit:
        ret
ENDP

;/*************************************************************************
; *
; *     Function    :   int vdsEnableDMATranslation(short DMAchannel);
; *
; *     Description :   Enables DMA buffer translation (default)
; *
; *     Input       :   DMA channel
; *
; *     Returns     :   0 = OK
; *                     -1 = error
; *
; ************************************************************************/

CPROC   vdsEnableDMATranslation @@DMAchannel

	ENTERPROC
	mov     ax,-1
	cmp     [vdsInited],1
	jne     @@exit
	mov     ax,810Ch
	mov     ebx,[@@DMAchannel]         ; Enable DMA
	sub     dx,dx
	int     4Bh                     ; call VDS
	mov     ax,-1
	jc      @@exit                  ; Carry = error
	sub     ax,ax
@@exit:
	LEAVEPROC
	ret
ENDP

;/*************************************************************************
; *
; *     Function    :   int vdsDisableDMATranslation(short DMAchannel);
; *
; *     Description :   Disables DMA buffer translation
; *
; *     Input       :   DMA channel
; *
; *     Returns     :   0 = OK
; *                     -1 = error
; *
; ************************************************************************/

CPROC   vdsDisableDMATranslation @@DMAchannel

	ENTERPROC
	mov     ax,-1
	cmp     [vdsInited],1
	jne     @@exit
	mov     ax,810Bh
	mov     ebx,[@@DMAchannel]         ; Disable DMA
	sub     dx,dx
	int     4Bh                     ; call VDS
	mov     ax,-1
	jc      @@exit                  ; Carry = error
	sub     ax,ax
@@exit:
	LEAVEPROC
	ret
ENDP

;/*************************************************************************
; *
; *     Function    :   int vdsLockDMA(DDS *dds);
; *
; *     Description :   Locks DMA region
; *
; *     Input       :   Pointer to DDS structure
; *
; *     Returns     :   0 = OK
; *                     -1 = error
; *
; ************************************************************************/

CPROC   vdsLockDMA @@pdds

	ENTERPROC _di
	mov     ax,-1
	cmp     [vdsInited],1
	jne     @@exit

	LESDI   [@@pdds]
	mov     ax,8103h                ; Lock DMA region
	mov     dx,0
	int     4Bh
	mov     ax,-1
	jc      @@exit
	sub     ax,ax
@@exit:
	LEAVEPROC _di
	ret
ENDP

;/*************************************************************************
; *
; *     Function    :   int vdsUnlockDMA(DDS *dds);
; *
; *     Description :   Unlocks DMA region
; *
; *     Input       :   Pointer to DDS structure
; *
; *     Returns     :   0 = OK
; *                     -1 = error
; *
; ************************************************************************/

CPROC   vdsUnlockDMA @@pdds

	ENTERPROC _di
	mov     ax,-1
	cmp     [vdsInited],1
	jne     @@exit

	LESDI   [@@pdds]
	mov     ax,8104h                ; Unlock DMA region
	mov     dx,0
	int     4Bh
	mov     ax,-1
	jc      @@exit
	sub     ax,ax
@@exit:
	LEAVEPROC _di
        ret
ENDP

ENDS

END
