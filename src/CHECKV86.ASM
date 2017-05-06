; Check if the processor (386->) is in the v86-mode

               MODEL TPASCAL
               P386
               IDEAL

CODESEG

               PUBLIC INV86

PROC           INV86  FAR

               Pushfd
               Pop    eax
               Test   eax,20000h
               JZ     @@Nov86
               Mov    ax,1
               Ret
@@NOV86:       Sub    ax,ax
               Ret
ENDP

END
