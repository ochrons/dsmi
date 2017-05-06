;* REVERB16.ASM Reverb routines for 16-bit real mode
;*
;* Copyright 1994 Otto Chrons
;*
;* First revision 06-17-94 05:44:42pm
;*
;* Revision history:
;*
;*

        IDEAL
        P386
        MODEL LARGE,C

STRUC REVERB
        position        DW ?
        gain            DD ?
ENDS

MACRO   echoLeft echonum
        mov     bx,[(SIZE REVERB)*echonum+reverbs.position]
        inc     bx
        mov     eax,[(SIZE REVERB)*echonum+reverbs.gain]
        and     bx,dx
        mov     [(SIZE REVERB)*echonum+reverbs.position],bx
        shl     bx,1
        add     bx,cx
        movsx   ebx,[WORD es:bx]
        imul    eax,ebx
        add     esi,eax
ENDM

MACRO   echoRight echonum
        mov     bx,[(SIZE REVERB)*echonum+reverbs.position]
        mov     eax,[(SIZE REVERB)*echonum+reverbs.gain]
        shl     bx,1
        add     bx,cx
        movsx   ebx,[WORD es:bx]
        imul    eax,ebx
        add     esi,eax
ENDM

DATASEG

        ; These variables are defined in DMP.C

        EXTRN   delayLineLeft:DWORD, delayLineRight:DWORD, delayLineMono:DWORD
        EXTRN   delayLineSize:WORD, delayLinePosition:WORD, reverbCount:WORD
        EXTRN   reverbs:REVERB:8
        EXTRN   reverbFeedback:DWORD

        prevval         DD 0
        prevvalR        DD 0
        prevvalOut      DD 0
        prevvalOutR     DD 0

CODESEG

        PUBLIC  reverbEffectsASM

        LABEL   offsetstereo16 WORD

                DW offset stereo161
                DW offset stereo162
                DW offset stereo163
                DW offset stereo164
                DW offset stereo165
                DW offset stereo166
                DW offset stereo167
                DW offset stereo168

        LABEL   offsetstereo16R WORD

                DW offset stereo16R1
                DW offset stereo16R2
                DW offset stereo16R3
                DW offset stereo16R4
                DW offset stereo16R5
                DW offset stereo16R6
                DW offset stereo16R7
                DW offset stereo16R8

        LABEL   offsetstereo8 WORD

                DW offset stereo81
                DW offset stereo82
                DW offset stereo83
                DW offset stereo84
                DW offset stereo85
                DW offset stereo86
                DW offset stereo87
                DW offset stereo88

        LABEL   offsetstereo8R WORD

                DW offset stereo8R1
                DW offset stereo8R2
                DW offset stereo8R3
                DW offset stereo8R4
                DW offset stereo8R5
                DW offset stereo8R6
                DW offset stereo8R7
                DW offset stereo8R8

        LABEL   offsetMono16 WORD

                DW offset mono161
                DW offset mono162
                DW offset mono163
                DW offset mono164
                DW offset mono165
                DW offset mono166
                DW offset mono167
                DW offset mono168

        LABEL   offsetMono8 WORD

                DW offset mono81
                DW offset mono82
                DW offset mono83
                DW offset mono84
                DW offset mono85
                DW offset mono86
                DW offset mono87
                DW offset mono88

PROC    reverbEffectsASM uses di si, buffer:DWORD, buflen:DWORD, datatype:DWORD
LOCAL   cmask:WORD

        mov     ax,[delayLineSize]
        dec     ax
        mov     [cmask],ax                      ; Mask for pointers

        mov     al,[BYTE datatype]              ; Is it stereo data?
        test    al,2
        jz      @@monoreverb

        test    al,1
        jz      @@stereo8bit

@@stereo16loop:
        cmp     [buflen],0                      ; End of loop?
        je      @@exit

        sub     esi,esi                         ; ESI = revval
        les     bx,[buffer]
        movsx   edi,[word es:bx]                ; EDI = inval
        mov     bx,[reverbCount]
        mov     dx,[cmask]
        dec     bx
        les     cx,[delayLineLeft]
        shl     bx,1
        jmp     [bx+offsetstereo16]               ; Jump to correct routine
stereo168:
        echoleft 7
stereo167:
        echoleft 6
stereo166:
        echoleft 5
stereo165:
        echoleft 4
stereo164:
        echoleft 3
stereo163:
        echoleft 2
stereo162:
        echoleft 1
stereo161:
        echoleft 0
stereo160:
        sar     esi,8

        add     esi,[prevval]                   ; Low pass filter
        mov     bx,[delayLinePosition]
        sar     esi,1

        mov     eax,[reverbFeedback]
        inc     bx
        imul    eax,esi
        and     bx,dx
        mov     [prevval],esi

        sar     eax,8
        mov     [delayLinePosition],bx
        add     eax,edi
        shl     bx,1
        add     esi,edi
        add     bx,cx

        mov     edx,esi
        add     esi,[prevvalOut]                ; Low pass filter
        mov     [prevvalOut],edx
        sar     esi,1

        cmp     esi,32767
        jle     @@stereo16comp1
        mov     si,32767
        cmp     eax,32767
        jle     @@stereo16comp2
        mov     ax,32767
@@stereo16comp2:
        jmp     @@stereo16compdone
@@stereo16comp1:
        cmp     esi,-32768
        jge     @@stereo16compdone
        mov     si,-32768
        cmp     eax,-32768
        jge     @@stereo16compdone
        mov     ax,-32768
@@stereo16compdone:

        mov     [es:bx],ax                      ; Store tempval to delay line

        les     bx,[buffer]
        mov     [es:bx],si
        add     bx,2
        mov     [WORD LOW buffer],bx

        sub     esi,esi                         ; ESI = revval
;       les     bx,[buffer]
        movsx   edi,[word es:bx]                ; EDI = inval
        mov     bx,[reverbCount]
        mov     dx,[cmask]
        dec     bx
        les     cx,[delayLineRight]
        shl     bx,1
        jmp     [bx+offsetstereo16R]               ; Jump to correct routine
stereo16R8:
        echoright 7
stereo16R7:
        echoright 6
stereo16R6:
        echoright 5
stereo16R5:
        echoright 4
stereo16R4:
        echoright 3
stereo16R3:
        echoright 2
stereo16R2:
        echoright 1
stereo16R1:
        echoright 0
stereo16R0:
        sar     esi,8

        add     esi,[prevvalR]                  ; Low pass filter
        sar     esi,1

        mov     eax,[reverbFeedback]
        imul    eax,esi
        mov     [prevvalR],esi

        sar     eax,8
        mov     bx,[delayLinePosition]
        add     eax,edi
        shl     bx,1
        add     esi,edi
        add     bx,cx

        mov     edx,esi
        add     esi,[prevvalOutR]               ; Low pass filter
        mov     [prevvalOutR],edx
        sar     esi,1

        cmp     esi,32767
        jle     @@stereo16Rcomp1
        mov     si,32767
        cmp     eax,32767
        jle     @@stereo16Rcomp2
        mov     ax,32767
@@stereo16Rcomp2:
        jmp     @@stereo16Rcompdone
@@stereo16Rcomp1:
        cmp     esi,-32768
        jge     @@stereo16Rcompdone
        mov     si,-32768
        cmp     eax,-32768
        jge     @@stereo16Rcompdone
        mov     ax,-32768
@@stereo16Rcompdone:

        mov     [es:bx],ax                      ; Store tempval to delay line

        les     bx,[buffer]
        mov     [es:bx],si
        add     bx,2
        mov     [WORD LOW buffer],bx
        dec     [buflen]

        jmp     @@stereo16loop
        jmp     @@exit
@@stereo8bit:

@@stereo8loop:
        cmp     [buflen],0                      ; End of loop?
        je      @@exit

        sub     esi,esi                         ; ESI = revval
        sub     al,al
        les     bx,[buffer]
        mov     ah,[byte es:bx]                ; EDI = inval
        mov     bx,[reverbCount]
        xor     ah,80h
        mov     dx,[cmask]
        shl     eax,16
        dec     bx
        sar     eax,16
        les     cx,[delayLineLeft]
        mov     edi,eax
        shl     bx,1
        jmp     [bx+offsetstereo8]               ; Jump to correct routine
stereo88:
        echoleft 7
stereo87:
        echoleft 6
stereo86:
        echoleft 5
stereo85:
        echoleft 4
stereo84:
        echoleft 3
stereo83:
        echoleft 2
stereo82:
        echoleft 1
stereo81:
        echoleft 0
stereo80:
        sar     esi,8

        add     esi,[prevval]                   ; Low pass filter
        mov     bx,[delayLinePosition]
        sar     esi,1

        mov     eax,[reverbFeedback]
        inc     bx
        imul    eax,esi
        and     bx,dx
        mov     [prevval],esi

        sar     eax,8
        mov     [delayLinePosition],bx
        add     eax,edi
        shl     bx,1
        add     esi,edi
        add     bx,cx

        mov     edx,esi
        add     esi,[prevvalOut]                ; Low pass filter
        mov     [prevvalOut],edx
        sar     esi,1

        cmp     esi,32767
        jle     @@stereo8comp1
        mov     si,32767
        cmp     eax,32767
        jle     @@stereo8comp2
        mov     ax,32767
@@stereo8comp2:
        jmp     @@stereo8compdone
@@stereo8comp1:
        cmp     esi,-32768
        jge     @@stereo8compdone
        mov     si,-32768
        cmp     eax,-32768
        jge     @@stereo8compdone
        mov     ax,-32768
@@stereo8compdone:

        mov     [es:bx],ax                      ; Store tempval to delay line

        mov     ax,si
        les     bx,[buffer]
        xor     ah,80h
        mov     [es:bx],ah
        inc     bx
        mov     [WORD LOW buffer],bx

        sub     esi,esi                         ; ESI = revval
        sub     al,al
;       les     bx,[buffer]
        mov     ah,[byte es:bx]                 ; EDI = inval
        mov     bx,[reverbCount]
        xor     ah,80h
        mov     dx,[cmask]
        shl     eax,16
        dec     bx
        sar     eax,16
        les     cx,[delayLineRight]
        mov     edi,eax
        shl     bx,1
        jmp     [bx+offsetstereo8R]               ; Jump to correct routine
stereo8R8:
        echoright 7
stereo8R7:
        echoright 6
stereo8R6:
        echoright 5
stereo8R5:
        echoright 4
stereo8R4:
        echoright 3
stereo8R3:
        echoright 2
stereo8R2:
        echoright 1
stereo8R1:
        echoright 0
stereo8R0:
        sar     esi,8

        add     esi,[prevvalR]                  ; Low pass filter
        sar     esi,1

        mov     eax,[reverbFeedback]
        imul    eax,esi
        mov     [prevvalR],esi

        sar     eax,8
        mov     bx,[delayLinePosition]
        add     eax,edi
        shl     bx,1
        add     esi,edi
        add     bx,cx

        mov     edx,esi
        add     esi,[prevvalOutR]               ; Low pass filter
        mov     [prevvalOutR],edx
        sar     esi,1

        cmp     esi,32767
        jle     @@stereo8Rcomp1
        mov     si,32767
        cmp     eax,32767
        jle     @@stereo8Rcomp2
        mov     ax,32767
@@stereo8Rcomp2:
        jmp     @@stereo8Rcompdone
@@stereo8Rcomp1:
        cmp     esi,-32768
        jge     @@stereo8Rcompdone
        mov     si,-32768
        cmp     eax,-32768
        jge     @@stereo8Rcompdone
        mov     ax,-32768
@@stereo8Rcompdone:

        mov     [es:bx],ax                      ; Store tempval to delay line

        mov     ax,si
        les     bx,[buffer]
        xor     ah,80h
        mov     [es:bx],ah
        inc     bx
        mov     [WORD LOW buffer],bx
        dec     [buflen]

        jmp     @@stereo8loop

@@monoreverb:
        test    al,1                            ; Is it 8-bit or 16-bit?
        jz      @@mono8bit

@@mono16loop:
        cmp     [buflen],0                      ; End of loop?
        je      @@exit

        sub     esi,esi                         ; ESI = revval
        les     bx,[buffer]
        movsx   edi,[word es:bx]                ; EDI = inval
        mov     bx,[reverbCount]
        mov     dx,[cmask]
        dec     bx
        les     cx,[delayLineMono]
        shl     bx,1
        jmp     [bx+offsetMono16]               ; Jump to correct routine
mono168:
        echoLeft 7
mono167:
        echoLeft 6
mono166:
        echoLeft 5
mono165:
        echoLeft 4
mono164:
        echoLeft 3
mono163:
        echoLeft 2
mono162:
        echoLeft 1
mono161:
        echoLeft 0
mono160:
        sar     esi,8

        mov     bx,[delayLinePosition]
        add     esi,[prevval]                   ; Low pass filter

        mov     eax,[reverbFeedback]
        sar     esi,1
        inc     bx
        imul    eax,esi
        and     bx,dx
        mov     [prevval],esi

        sar     eax,8
        mov     [delayLinePosition],bx
        add     eax,edi
        shl     bx,1
        add     esi,edi
        add     bx,cx

        mov     edx,esi
        add     esi,[prevvalOut]                ; Low pass filter
        mov     [prevvalOut],edx
        sar     esi,1

        cmp     esi,32767
        jle     @@mono16comp1
        mov     si,32767
        cmp     eax,32767
        jle     @@mono16comp2
        mov     ax,32767
@@mono16comp2:
        jmp     @@mono16compdone
@@mono16comp1:
        cmp     esi,-32768
        jge     @@mono16compdone
        mov     si,-32768
        cmp     eax,-32768
        jge     @@mono16compdone
        mov     ax,-32768
@@mono16compdone:

        mov     [es:bx],ax                      ; Store tempval to delay line

        les     bx,[buffer]
        mov     [es:bx],si
        add     bx,2
        mov     [WORD LOW buffer],bx
        dec     [buflen]
        jmp     @@mono16loop
@@mono8bit:

@@mono8loop:
        cmp     [buflen],0                      ; End of loop?
        je      @@exit

        sub     esi,esi                         ; ESI = revval
        sub     al,al
        les     bx,[buffer]
        mov     ah,[byte es:bx]                 ; EDI = inval
        mov     bx,[reverbCount]
        xor     ah,80h
        shl     eax,16
        sar     eax,16
        dec     bx
        mov     edi,eax
        shl     bx,1
        mov     dx,[cmask]
        les     cx,[delayLineMono]
        jmp     [bx+offsetMono8]               ; Jump to correct routine
mono88:
        echoLeft 7
mono87:
        echoLeft 6
mono86:
        echoLeft 5
mono85:
        echoLeft 4
mono84:
        echoLeft 3
mono83:
        echoLeft 2
mono82:
        echoLeft 1
mono81:
        echoLeft 0
mono80:
        sar     esi,8

        add     esi,[prevval]
        mov     bx,[delayLinePosition]
        sar     esi,1

        mov     eax,[reverbFeedback]
        inc     bx
        imul    eax,esi
        and     bx,dx

        sar     eax,8
        mov     [delayLinePosition],bx
        add     eax,edi
        mov     [prevval],esi
        shl     bx,1
        add     esi,edi
        add     bx,cx

        mov     edx,esi
        add     esi,[prevvalOut]                ; Low pass filter
        mov     [prevvalOut],edx
        sar     esi,1

        cmp     esi,32767
        jle     @@mono8comp1
        mov     si,32767
        cmp     eax,32767
        jle     @@mono8comp2
        mov     ax,32767
@@mono8comp2:
        jmp     @@mono8compdone
@@mono8comp1:
        cmp     esi,-32768
        jge     @@mono8compdone
        mov     si,-32768
        cmp     eax,-32768
        jge     @@mono8compdone
        mov     ax,-32768
@@mono8compdone:

        mov     [es:bx],ax                      ; Store tempval to delay line

        mov     ax,si
        les     bx,[buffer]
        xor     ah,80h
        mov     [es:bx],ah
        inc     bx
        mov     [WORD LOW buffer],bx
        dec     [buflen]
        jmp     @@mono8loop
@@exit:
        ret
ENDP

END
