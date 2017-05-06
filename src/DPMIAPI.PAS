(****************************************************************************

                                  DPMIAPI.PAS
                                  -----------

                           (C) 1993 Jussi Lahdenniemi

DPMI API routines for Borland Pascal 7.0

****************************************************************************)

Unit DPMIAPI;

{$IFNDEF DPMI}
'This unit must be compiled in protected mode!'
{$ENDIF}

Interface

Function  dpmiSeg2slc(seg:word):word;
Function  dpmiGetLinearAddr(slc:word):Longint;
Function  dpmiAllocDOS(amount:word;var segment,slc:word):word;
Function  dpmiFreeDOS(slc:word):boolean;
Function  dpmiResizeDOS(slc:word;newsize:word):word;
Procedure dpmiVersion(var verMaj,verMin,processor:byte;var flags:word);

const prc286              = 1;
      prc386              = 2;
      prc486              = 3;

      flg386              = 1;
      flgRealInt          = 2;
      flgVirtualMemory    = 4;

Implementation
uses dos;

var r:registers;

Function dpmiSeg2Slc;
begin
  r.ax:=2;
  r.bx:=seg;
  intr($31,r);
  if r.flags and 1=1 then dpmiSeg2Slc:=0 else dpmiSeg2Slc:=r.ax;
end;

Function dpmiGetLinearAddr;
begin
  r.ax:=6;
  r.bx:=slc;
  intr($31,r);
  if r.flags and 1=1 then dpmiGetLinearAddr:=0 else
    dpmiGetLinearAddr:=longint(r.cx)*65536+longint(r.dx);
end;

Function dpmiAllocDOS;
begin
  r.ax:=$100;
  r.bx:=amount;
  intr($31,r);
  if r.flags and 1=1 then dpmiAllocDOS:=r.bx else begin
    segment:=r.ax;
    slc:=r.dx;
    dpmiAllocDOS:=0;
  end;
end;

Function dpmiFreeDOS;
begin
  r.ax:=$101;
  r.dx:=slc;
  intr($31,r);
  dpmiFreeDOS:=r.flags and 1=0;
end;

Function dpmiResizeDOS;
begin
  r.ax:=$102;
  r.bx:=newsize;
  r.dx:=slc;
  intr($31,r);
  if r.flags and 1=1 then dpmiResizeDOS:=r.bx else dpmiResizeDOS:=0;
end;

Procedure dpmiVersion;
begin
  r.ax:=$400;
  intr($31,r);
  verMaj:=r.ah;
  verMin:=r.al;
  case r.cl of
    2 : processor:=prc286;
    3 : processor:=prc386;
    4 : processor:=prc486;
  end;
  flags:=r.bx;
end;

end.
