(***************************************************************************

                                 CSUPPORT.PAS
                                 ------------

                          (C) 1993 Jussi Lahdenniemi

C-language support functions

***************************************************************************)

Unit Csupport;

Interface

Function  Ascz2Str(Var Az):String;
Procedure Str2Ascz(S:String;Var Az);
Function  calloc(Cnt:Word;Size:Word):Pointer;
Function  malloc(Size:Word):Pointer;
Procedure free(p:pointer);
Procedure strcpy(var Dest,Sourc);
Procedure strncpy(var Dest,Sourc;MaxCnt:Word);
Function  memcmp(a,b:pointer;len:word):integer;
Procedure atexit(func:pointer);

Const mallocMinLeft : Longint = 0;  { Min. mem left before allocating }

Implementation
uses DOS;

const fflag : boolean = false;

Type TAscz = Array[0..255] of char;

Function Ascz2Str;
Var S:String;
    W:Word;
Begin
  S:='';
  W:=0;
  While (TAscz(Az)[w]<>#0) and (W<255) do begin
    S:=S+TAscz(Az)[W];
    Inc(W);
  end;
  Ascz2Str:=s;
end;

Procedure Str2Ascz;
Var W:Word;
Begin
  For w:=1 to length(S) do TAscz(Az)[w]:=S[w];
end;

Function calloc;
var p:pointer;
Begin
  p:=malloc(Cnt*Size);
  fillchar(p^,Cnt*Size,0);
  calloc:=p;
end;

Function malloc;
Var P:Pointer;
Begin
  if MaxAvail<Size+4+8+mallocMinLeft then malloc:=nil else begin
    Getmem(p,Size+4+8);
    meml[seg(p^):ofs(p^)]:=Size;
    malloc:=pointer(longint(p)+4);
  end;
end;

Procedure free(p:pointer);
var b:boolean;
begin
{$IFNDEF DPMI}
  if (p<>nil) and (seg(p^)>=seg(heapOrg^)) and (seg(p^)<=seg(heapPtr^)) then
{$ELSE}
  asm
    verw [word ptr p+2]
    db 0fh,94h,0c0h    { setz al }
    mov [b],al
  end;
  fflag:=true;
  if b then
{$ENDIF}
  if (ofs(p^)=4) or (ofs(p^)=12) then
    freemem(pointer(longint(p)-4),meml[seg(p^):ofs(p^)-4]+4+8);
  fflag:=false;
end;

Procedure strcpy;
Var w:word;
Begin
  w:=0;
  repeat
    TAscz(Dest)[w]:=TAscz(Sourc)[w];
    inc(w);
  until Tascz(Sourc)[w-1]=#0;
end;

Procedure strncpy;
Var w:word;
Begin
  w:=0;
  repeat
    TAscz(Dest)[w]:=TAscz(Sourc)[w];
    inc(w);
  until (Tascz(Sourc)[w-1]=#0) or (w=MaxCnt);
end;

Function memcmp; assembler;
asm
            push        ds
            mov         cx,[len]
            mov         ax,cx
            Jcxz        @@Null
            Lds         si,[a]
            Les         di,[b]
            Cld
            Rep         Cmpsb
            Mov         al,[si-1]
            Xor         ah,ah
            Mov         cl,es:[di-1]
            Xor         ch,ch
@@Null:     Pop         ds
            Sub         ax,cx
end;

{$F+}

type TExitProc  = Procedure;
var oldExit     : Pointer;
    exitProcs   : Array[1..1000] of TExitProc;
const exitCnt   : word = 0;

Procedure atexit_proc;
var w:word;

begin
  for w:=exitCnt downto 1 do exitProcs[w];
  exitProc:=oldExit;
end;

Procedure atexit;
begin
  inc(exitCnt);
  exitProcs[exitCnt]:=TExitProc(func);
end;

begin
  oldExit:=exitProc;
  exitProc:=@atexit_proc;
end.
