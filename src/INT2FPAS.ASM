; Interrupt 2fh handler for PAS compatability with DPMI
; (C) 1993 Jussi Lahdenniemi

                IDEAL
                MODEL TPASCAL
                JUMPS
                P386

DATASEG

old2f           DW    ?
old2fseg        DW    ?

sEDI            DD    ?
sESI            DD    ?
sEBP            DD    ?
sRes            DD    ?
sEBX            DD    ?
sEDX            DD    ?
sECX            DD    ?
sEAX            DD    ?
sflg            DW    ?
sES             DW    ?
sDS             DW    ?
sFS             DW    ?
sGS             DW    ?
sIP             DW    ?
sCS             DW    ?
sSP             DW    ?
sSS             DW    ?

CODESEG

                PUBLIC new2f,init2f,release2f

PROC            new2f FAR

                pushf
                cmp  ah,0bch
                je   @@PASint
                popf
                jmp  [dword ptr old2f]
@@PASint:       mov  [sEAX],eax
                pushf
                pop  ax
                mov  [sFlg],ax
                mov  [sEBX],ebx
                mov  [sECX],ecx
                mov  [sEDX],edx
                mov  [sEDI],edi
                mov  [sESI],esi
                mov  [sEBP],ebp
                mov  [sES],es
                mov  [sDS],ds
                mov  [sFS],fs
                mov  [sGS],gs
                mov  [sCS],cs
                mov  [sSP],sp
                mov  [sSS],ss
                mov  ax,300h
                mov  bl,2fh
                sub  bh,bh
                les  di,[sEDI]
                int  31h
                mov  ebx,[sEBX]
                mov  ecx,[sECX]
                mov  edx,[sEDX]
                mov  edi,[sEDI]
                mov  esi,[sESI]
                mov  ebp,[sEBP]
                mov  es,[sES]
                mov  ds,[sDS]
                mov  fs,[sFS]
                mov  gs,[sGS]
                mov  sp,[sSP]
                mov  ss,[sSS]
                mov  ax,[sFlg]
                push ax
                popf
                mov  eax,[sEAX]
                iret
ENDP

PROC            init2f FAR

                push ds
                mov  ah,35h
                mov  al,2fh
                int  21h
                mov  [old2f],bx
                mov  [old2fseg],es
                mov  ah,25h
                mov  al,2fh
                mov  bx,DATA
                mov  ds,bx
                mov  dx,offset new2f
                int  21h
                pop  ds
                ret
ENDP

PROC            release2f FAR

                push ds
                mov  ah,25h
                mov  al,2fh
                mov  ds,[old2fseg]
                mov  dx,[old2f]
                int  21h
                pop  ds
                ret
ENDP

END
