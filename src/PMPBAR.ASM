; ***************************************************************************
;
;                                 PMPBAR.ASM
;                                 ----------
;
;                         (C) 1993 Jussi Lahdenniemi
;
; Color bar routine for PMP 2.20+
;
; You can use this routine and/or it's idea in your own products, but
; you must mention me somewhere.
;
; NOTICE! The routine disables the interrupts, but DOES NOT enable them!
;
; ***************************************************************************

                   IDEAL
                   MODEL TPASCAL
                   JUMPS
                   P386

;DEFINE             DEBUG

                   CODESEG

                   PUBLIC clrBars

                   MACRO waitRetr
                   Mov      dx,3dah
                   In       al,dx         ; WaitDisp:
                   test     al,1
                   DB       74h,-5        ; jz waitDisp
                   In       al,dx         ; WaitRetr:
                   test     al,1
                   DB       75h,-5        ; jnz waitRetr
                   ENDM

                   MACRO bkclr X
IFDEF              DEBUG
                   mov   dx,3dah
                   in    al,dx
                   mov   dx,3c0h
                   mov   al,17+32
                   out   dx,al
                   mov   al,x
                   out   dx,al
ENDIF
                   ENDM

                   MACRO setcol X,Z
                   mov      bl,[de&X&]
                   mov      ah,bl
                   and      ah,80h
                   shr      ah,5
                   mov      dl,[q&X&Z&]
                   xchg     ax,bx
                   cbw
                   xor      al,ah
                   sub      al,ah
                   xchg     ax,bx
                   add      dl,bl
                   mov      [q&X&Z&],dl
                   test     dl,128+64
                   jz       @@noChange&X&Z&
                   mov      al,dl
                   and      dl,00111111b
                   mov      [q&X&Z&],dl
                   shr      al,6
                   or       al,ah
                   sub      ah,ah
                   mov      bx,ax
                   mov      al,[byte ptr clrTable+bx]
                   add      [n&X&Z&],al
@@noChange&X&Z&:
                   ENDM

                   MACRO scrlcol Y
                   setcol R,&Y&
                   setcol G,&Y&
                   setcol B,&Y&
                   ENDM

clrTable:          DB       0,1,2,3,0,-1,-2,-3

PROC               clrBars FAR iR:Byte,iG:Byte,iB:Byte,deR:Byte,deG:Byte,deB:Byte,c1:Byte,c2:Byte,r1:Byte,r2:Byte,r3:Byte,r4:Byte,sr:Word

                   LOCAL    nR1:Byte,nG1:Byte,nB1:Byte
                   LOCAL    nR2:Byte,nG2:Byte,nB2:Byte
                   LOCAL    nR3:Byte,nG3:Byte,nB3:Byte
                   LOCAL    nR4:Byte,nG4:Byte,nB4:Byte
                   LOCAL    qR1:Byte,qG1:Byte,qB1:Byte
                   LOCAL    qR2:Byte,qG2:Byte,qB2:Byte
                   LOCAL    qR3:Byte,qG3:Byte,qB3:Byte
                   LOCAL    qR4:Byte,qG4:Byte,qB4:Byte
                   LOCAL    status:Byte
                   LOCAL    linenr:Word

                   Push     ds
                   Push     es
                   cli
                   Mov      [linenr],0
                   Mov      [status],0ffh
                   Mov      dx,3dah
@@waitRetrace:     In       al,dx
                   test     al,8
                   jz       @@waitRetrace
@@waitDisplay:     In       al,dx
                   test     al,8
                   jnz      @@waitDisplay
                   mov      cx,[sr]
                   dec      cx
@@emptyRows:       waitRetr
                   loop     @@emptyRows

                   bkclr 3

                   mov      [qR1],0
                   mov      [qG1],0
                   mov      [qB1],0
                   mov      [qR2],0
                   mov      [qG2],0
                   mov      [qB2],0
                   mov      [qR3],0
                   mov      [qG3],0
                   mov      [qB3],0
                   mov      [qR4],0
                   mov      [qG4],0
                   mov      [qB4],0
                   sub      cx,cx
                   mov      al,[iR]
                   mov      [nR1],al
                   mov      [nR2],al
                   mov      [nR3],al
                   mov      [nR4],al
                   mov      al,[iG]
                   mov      [nG1],al
                   mov      [nG2],al
                   mov      [nG3],al
                   mov      [nG4],al
                   mov      al,[iB]
                   mov      [nB1],al
                   mov      [nB2],al
                   mov      [nB3],al
                   mov      [nB4],al
@@bigLoop:
                   mov      dx,3c8h
                   mov      al,[c1]
                   out      dx,al
                   inc      dx
                   mov      al,[nR1]
                   out      dx,al
                   mov      al,[nG1]
                   out      dx,al
                   mov      bl,[nB1]
                   mov      bh,[nR3]
                   mov      ah,[nG3]
                   waitRetr
                   waitRetr
                   mov      al,bl
                   mov      dx,3c9h
                   out      dx,al
                   mov      al,bh
                   out      dx,al
                   mov      al,ah
                   out      dx,al
                   mov      al,[nB3]
                   out      dx,al
                   cmp      cl,[r1]
                   jae      @@zeroCols1
;                   mov      al,[deR]
;                   add      [nR1],al
;                   mov      al,[deG]
;                   add      [nG1],al
;                   mov      al,[deB]
;                   add      [nB1],al

                   scrlcol 1

                   jmp      @@nonzero1
@@zeroCols1:       mov      [nR1],0
                   mov      [nG1],0
                   mov      [nB1],20
                   test     [status],1
                   jz       @@alr1
                   and      [status],not 1
                   jmp      @@nonzero1
@@alr1:            and      [status],not 16
@@nonzero1:        cmp      cl,[r3]
                   jae      @@zeroCols3
;                   mov      al,[deR]
;                   add      [nR3],al
;                   mov      al,[deG]
;                   add      [nG3],al
;                   mov      al,[deB]
;                   add      [nB3],al

                   scrlcol 3

                   jmp      @@nonzero3
@@zeroCols3:       mov      [nR3],0
                   mov      [nG3],0
                   mov      [nB3],20
                   test     [status],4
                   jz       @@alr3
                   and      [status],not 4
                   jmp      @@nonzero3
@@alr3:            and      [status],not 64
@@nonzero3:

                   mov      dx,3c8h
                   mov      al,[c2]
                   out      dx,al
                   inc      dx
                   mov      al,[nR2]
                   out      dx,al
                   mov      al,[nG2]
                   out      dx,al
                   mov      bl,[nB2]
                   mov      bh,[nR4]
                   mov      ah,[nG4]
                   waitRetr
                   mov      al,bl
                   mov      dx,3c9h
                   out      dx,al
                   mov      al,bh
                   out      dx,al
                   mov      al,ah
                   out      dx,al
                   mov      al,[nB4]
                   out      dx,al
                   cmp      cl,[r2]
                   jae      @@zeroCols2
;                   mov      al,[deR]
;                   add      [nR2],al
;                   mov      al,[deG]
;                   add      [nG2],al
;                   mov      al,[deB]
;                   add      [nB2],al

                   scrlcol 2

                   jmp      @@nonzero2
@@zeroCols2:       mov      [nR2],0
                   mov      [nG2],0
                   mov      [nB2],20
                   test     [status],2
                   jz       @@alr2
                   and      [status],not 2
                   jmp      @@nonzero2
@@alr2:            and      [status],not 32
@@nonzero2:        cmp      cl,[r4]
                   jae      @@zeroCols4
;                   mov      al,[deR]
;                   add      [nR4],al
;                   mov      al,[deG]
;                   add      [nG4],al
;                   mov      al,[deB]
;                   add      [nB4],al

                   scrlcol 4

                   jmp      @@nonzero4
@@zeroCols4:       mov      [nR4],0
                   mov      [nG4],0
                   mov      [nB4],20
                   test     [status],8
                   jz       @@alr4
                   and      [status],not 8
                   jmp      @@nonzero4
@@alr4:            and      [status],not 128
@@nonzero4:

                   inc      [linenr]
                   cmp      [linenr],72
                   jz       @@outtaHere
                   inc      cx
                   jmp      @@bigLoop
@@outtaHere:       Pop      es
                   Pop      ds

                   bkclr  1

;                   Sti
                   Ret
ENDP

END
