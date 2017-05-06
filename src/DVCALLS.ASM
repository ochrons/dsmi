                                TITLE DESQview Interfaces

; Taken from the DESQview manual, page 196, appendix J:
;                    DESQview's application program interface

; This listing can be assembled with the IBM or Microsoft Assembler and
; then linked with the program. It should work "as is" when linked to
; Assembler or MS Pascal programs. It isn't linkable "as is" to Turbo
; Pascal or Compiled BASIC - but can be easily adapted to these languages
; as well. For registered owners of DESQview can contact Quarterdeck if
; you need assistance.

MODEL LARGE,C

DVINT_SEG SEGMENT 'CODE'
        ASSUME CS:DVINT_SEG

        PUBLIC  getDVVersion,getDVVideoBuffer,dvPause
        PUBLIC  dvBeginCritical,dvEndCritical

IN_DV   DB 1

getDVVersion PROC FAR
; Description:
; Returns a zero if the program is >not< running under DESQview.
; Otherwise, it returns the current DESQview version number. If
; the program already uses DOS or the BIOS to write to the screen,
; you should call this routine (rather than DV_GET_VIDEO_BUFFER)
; when you initialize the program.

;Notes:
; Returns in AH/AL the DESQview major/minor version numbers,
;   and set up the IN_DV variable for later use.
; Returns 0 in AX if DESQview isn't there.
        PUSH    BX
        PUSH    CX
        PUSH    DX
        MOV     CX,'DE'         ; set CX to 4445H; DX to 5351H
        MOV     DX,'SQ'         ; (AN INVALID DAT)
        MOV     AX,2B01H        ; DOS' SET DATE FUNCTION
        INT     21H             ; CALL DOS
        CMP     AL,0FFH         ; DID DOS SEE IT AS INVALID?
        JE      NO_DESQVIEW     ; IF SO, DESQVIEW ISN'T THERE
        MOV     AX,BX           ; AH=MAJOR VERSION; AL=MINOR VERS
        MOV     CS:IN_DV,1      ; SET INTERNAL VARIABLE USE BY
        JMP     SHORT DVGV_X    ;       OTHER ROUTINES
NO_DESQVIEW:
        SUB     AX,AX           ; RETURN NO DESQview (version 0)
DVGV_X: POP     DX
        POP     CX
        POP     BX
        RET
ENDP

getDVVideoBuffer PROC FAR
; Descriptions:
; Takes the hardware video segment on the stack and returns that
; segment (if DESQview is not present) or returns that segment of
; DESQview's alternate video buffer. You should call this routine
; when you initialize the program if the program normally writes
; directly to the video buffer.

; Notes:
; Takes the hardware video segment on the stack and returns that
; segment (if DESQview is not present) or DESQview's alternate
; video buffer in AX. Sets up the IN_DV variable for later use.
; Call this instead of DV_GET_VERSION if your program writes
; directly to video memory.
        PUSH    BP
        MOV     BP,SP
        PUSH    DI
        PUSH    ES
        MOV     ES,[BP+6]       ; Put the hardware segment into ES
        CALL    getDVVersion    ; Returns AX=0 if not in DESQview
        TEST    AX,AX           ; In DV?
        JZ      DVGVB_X         ; Jump if not
; Since DESQview is running, get the alternate screen buffer
        MOV     AH,0FEH         ; DV's get buffer function
        INT     10H             ; Returns ES:DI as alternate buffer
DVGVB_X:
        MOV     AX,ES           ; Return correct video buffer in ES
        POP     ES
        POP     DI
        POP     BP
        RET     2
ENDP

API_CALL PROC NEAR
; This local routine takes a program interface function in BX,
; and makes that call to DESQview after switching onto a stack
; that DESQview provides for your program.
        PUSH    AX
        MOV     AX,101AH        ; The function to switch to DV's stack
        INT     15H             ; DV's software interrupt
        MOV     AX,BX           ; Move the desired function to AX
        INT     15H             ; Make that call
        MOV     AX,1025H        ; Function to switch off of DV's stack
        INT     15H             ; Make that call
        POP     AX
        RET
API_CALL ENDP

dvPause PROC FAR
; Descriptions:
; If the program waits for input when it's idle, DESQview won't
; waste any processor time on it until the user types the next key.
; However, if the program sits in a loop polling the keyboard
; when it's basically idle, you'll probably want to use the
; DV_PAUSE call to relinquish the remainder of your time slice
; when you see that the event you're polling for hasn't yet occurred.
; This minimizes the amount that the program's polling loop affects
; other programs running in background.

; Notes:
; This routine tells DESQview not to slice away from your program
; Takes no parameters and returns nothing.
        CMP     CS:IN_DV,1      ; Are we in DESQview?
        JNE     DVP_X           ; If not, nothing to do
        PUSH    BX              ; Else make the pause function call
        MOV     BX,1000H        ; This is the function code
        CALL    API_CALL        ; Do it
        POP     BX
DVP_X:  RET
ENDP

dvBeginCritical PROC FAR
; Descriptions:
; This call is used in conjunction with the call DV_END_CRITICAL to
; define a section of code that DESQview won't "slice out of". Use
; this for timing critical operations.

; Notes:
; This routine tells DESQview not to slice away your program
; until you make a DV_END_CRITICAL call.
; Takes no parameters and returns nothing.
        CMP     CS:IN_DV,1      ; Are we in DESQview?
        JNE     DVBC_X          ; If not, nothing to do
        PUSH    BX              ; Else make the begin critical call
        MOV     BX,101BH        ; This is the function code
        CALL    API_CALL        ; Do it
        POP     BX
DVBC_X: RET
ENDP

dvEndCritical PROC FAR
; Descriptions:
; This call defines the end of the critical operations.

; Notes:
; This routine tells DESQview that it is all right to slice away
; from your program again.
; Takes no parameters and returns nothing.
        CMP     CS:IN_DV,1      ; Are we in DESQview?
        JNE     DVEC_X          ; If not, nothing to do
        PUSH    BX              ; Else make the end critical call
        MOV     BX,101CH        ; This is the function code
        CALL    API_CALL        ; Do it
        POP     BX
DVEC_X: RET
ENDP

ENDS
END

