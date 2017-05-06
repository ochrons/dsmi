; m2wav.asm - ASM routines for m2wav.pas
; (C) 1994 Jussi Lahdenniemi

        model   tpascal
        ideal
        p386
        jumps

struc   REVERB

pos     dd      ?
gain    dd      ?

ENDS

dataseg

        extrn   delayLineSize:dword,delayLineLeft:dword,delayLineRight:dword
        extrn   delayLineMono:FAR,delayLinePosition:dword
        extrn   reverbCount:dword,reverbs:REVERB,reverbFeedback:dword

codeseg

        public  reverbEffectsAsm

proc    reverbEffectsAsm FAR buffer:dword,len:dword,datatype:dword

local   cmask:dword,prvvstore:dword

        mov     eax,[delayLineSize]
        dec     eax
        mov     [cmask],eax
        sub     eax,eax
        mov     [prvvstore],eax
        les     si,[buffer]
        test    [datatype],2
        jz      no16
        test    [datatype],1
        jz      noStereo16

        ; stereo 16-bit reverb

        mov     fs,[word delayLineLeft+2]
        mov     gs,[word delayLineRight+2]
st16l:
        sub     ecx,ecx
        mov     edx,[reverbCount]
        mov     di,offset reverbs
@@la:
        mov     ebx,[ds:di]
        inc     ebx
        and     ebx,[cmask]
        mov     [ds:di],ebx
        add     bx,bx
        add     bx,[word delayLineLeft]
        movsx   ebx,[word fs:bx]
        imul    ebx,[ds:di+4]
        add     ecx,ebx
        add     di,8
        dec     edx
        jnz     @@la
        sar     ecx,8
        add     ecx,eax
        sar     ecx,1
        mov     eax,ecx
        mov     edx,ecx
        imul    edx,[reverbFeedback]
        sar     edx,8
        movsx   ebx,[word es:si]
        add     edx,ebx
        add     ecx,ebx
        cmp     ecx,32767
        jle     @@lb
        mov     ecx,32767
        cmp     edx,32767
        jle     @@lb
        mov     edx,32767
@@lb:
        cmp     ecx,-32768
        jge     @@lc
        mov     ecx,-32768
        cmp     edx,-32768
        jge     @@lc
        mov     edx,-32768
@@lc:
        mov     edi,[delayLinePosition]
        inc     edi
        and     edi,[cmask]
        mov     [delayLinePosition],edi
        add     di,di
        add     di,[word delayLineLeft]
        mov     [fs:di],dx
        mov     [es:si],cx
        add     si,2
        xchg    eax,[prvvstore]
right:
        sub     ecx,ecx
        mov     edx,[reverbCount]
        mov     di,offset reverbs
@@ra:
        mov     bx,[ds:di]
        add     bx,bx
        add     bx,[word delayLineRight]
        movsx   ebx,[word gs:bx]
        imul    ebx,[ds:di+4]
        add     ecx,ebx
        add     di,8
        dec     edx
        jnz     @@ra
        sar     ecx,8
        add     ecx,eax
        sar     ecx,1
        mov     eax,ecx
        mov     edx,ecx
        imul    edx,[reverbFeedback]
        sar     edx,8
        movsx   ebx,[word es:si]
        add     edx,ebx
        add     ecx,ebx
        cmp     ecx,32767
        jle     @@rb
        mov     ecx,32767
        cmp     edx,32767
        jle     @@rb
        mov     edx,32767
@@rb:
        cmp     ecx,-32768
        jge     @@rc
        mov     ecx,-32768
        cmp     edx,-32768
        jge     @@rc
        mov     edx,-32768
@@rc:
        mov     di,[word delayLinePosition]
        add     di,di
        add     di,[word delayLineRight]
        mov     [gs:di],dx
        mov     [es:si],cx
        add     si,2
        xchg    eax,[prvvstore]
        dec     [len]
        jnz     st16l
        ret

noStereo16:

        ; Mono 16-bit reverb
        ret

no16:

        test    [datatype],1
        jz      noStereo8

        ; Stereo 8-bit reverb
        ret

noStereo8:

        ret

ENDP

END
