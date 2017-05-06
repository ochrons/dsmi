Unit emhm; { (C) 1993 Jussi Lahdenniemi,
             original C version (C) 1993 Otto Chrons

             EMS Heap Manager }

{$IFDEF DPMI}
'Only in real mode!'
{$ENDIF}

{$X+}

Interface

const EMS_ERROR    = -1;
      EMS_MEMORY   = -2;
      EMS_PAGE     = -3;
      EMS_HANDLE   = -4;

type  TEMSH        = integer;

Function  emsInit(minmem,maxmem:integer):integer;
Procedure emsClose;
Function  emsAlloc(size:longint):TEMSH;
Procedure emsFree(handle:TEMSH);
Function  emsLock(handle:TEMSH;start:longint;length:word):pointer;
Function  emsCopyTo(handle:TEMSH;ptr:Pointer;start,length:longint):integer;
Function  emsCopyFrom(ptr:Pointer;handle:TEMSH;start,length:longint):integer;
Function  emsCopy(handleTo,handleFrom:TEMSH;start1,start2,length:longint):integer;
Procedure emsSaveState;
Procedure emsRestoreState;
Function  emsHeapfree:longint;
Procedure emsShowHeap;

Implementation
uses CSupport;

{ Internal structures }

const EMSMOVE_CONV    = 0;
      EMSMOVE_EMS     = 1;

type  PHandle         = ^THandle;
      THandle         = record
        handle        : TEMSH;
        start,size    : longint;
        next,prev     : PHandle;
      end;

      PEmsMove        = ^TEmsMove;
      TEmsMove        = record          { Structure for memory moves }
        size          : longint;        { to/from EMS                }
        srcType       : byte;
        srcHandle     : word;
        srcOffset     : word;
        srcSegment    : word;
        destType      : byte;
        destHandle    : word;
        destOffset    : word;
        destSegment   : word;
      end;

{ External low-level functions }

{$F+}
Function  _emsInit:integer; external;
Function  _emsAllocPages(pages:integer):integer; external;
Function  _emsMapPages(lpage,ppage:integer):integer; external;
Procedure _emsSaveState; external;
Procedure _emsRestoreState; external;
Function  _emsQueryFree:integer; external;
Function  _emsGetFrame:word; external;
Procedure _emsMoveMem(move:PEmsMove); external;
Procedure _emsClose; external;
{$L EMSHARD.OBJ}
{$F-}

{ Internal varliables }

const emsMax          : longint = 0;
      emsMem          : longint = 0;
      first           : PHandle = nil;
      last            : PHandle = nil;
      locked          : PHandle = nil;
      status          : integer = 0;
      physicalPages   : array[0..3] of integer = (0,0,0,0);
      nextHandle      : TEMSH   = 0;
      EMMname         : array[0..8] of char = ('E','M','M','X','X','X','X','0',#0);

var   lowHandle       : integer;
      frame           : pointer;

{ EMS heap manager internal functions }

Function findHandle(which:TEMSH):PHandle;
var handle : PHandle;
begin
  handle:=first;
  if which=0 then begin findHandle:=nil; exit end;
  while (handle^.next<>nil) do begin
    if handle^.handle=which then begin findHandle:=handle; exit end;
    handle:=handle^.next;
  end;
  findHandle:=nil;
end;

{ EMS heap manager interface functions }

Function  emsInit(minmem,maxmem:integer):integer;
var a:word;
Label noems,emsfound;
begin
  if status<>0 then begin emsInit:=EMS_ERROR; exit end;
  asm
        mov     ax,3d00h
        mov     dx,offset EMMname
        int     21h
        jc      noems
        mov     bx,ax
        mov     ax,4400h
        int     21h
        pushf
        mov     ax,3e00h
        int     21h
        popf
        jc      noems
        and     dx,80h
        jz      noems
        jmp     emsfound
  end;
noems:
  emsInit:=EMS_ERROR;
  exit;
emsfound:
  if _emsInit<>0 then begin emsInit:=EMS_ERROR; exit end;
  emsMEM:=longint(maxmem)*1024;
  a:=longint(_emsQueryFree)*16;
  if a<minmem then begin emsInit:=EMS_MEMORY; exit end;
  if a>maxmem then begin
    lowHandle:=_emsAllocPages((maxmem+15) div 16);
    if lowHandle<0 then begin emsInit:=EMS_MEMORY; exit end;
  end else begin
    lowHandle:=_emsAllocPages(a div 16);
    if lowHandle<0 then begin emsInit:=EMS_MEMORY; exit end;
    emsMem:=longint(a)*1024;
  end;
  new(first);
  new(last);
  with first^ do begin
    handle:=0;
    start:=0;
    size:=0;
    next:=last;
    prev:=nil;
  end;
  with last^ do begin
    handle:=0;
    start:=emsMem;
    size:=0;
    next:=nil;
    prev:=first;
  end;
  status:=1;
  frame:=ptr(_emsGetFrame,0);
  atExit(@emsClose);
  emsInit:=0;
end;

Procedure emsClose;
var handle,h:PHandle;
begin
  handle:=first;
  if status<>1 then exit;
  _emsClose;
  status:=0;
  while (handle<>nil) do begin
    h:=handle^.next;
    dispose(handle);
    handle:=h;
  end;
end;

Function  emsAlloc(size:longint):TEMSH;
var newHandle,handle,best : PHandle;
    bestSize,a,b          : longint;
    align                 : integer;
begin
  handle:=first;
  best:=first;
  bestSize:=33554432; { 32 MB }
  align:=0;
  if status<>1 then begin emsAlloc:=-1; exit end;
  size:=(size+15) and (not longint(15));
  if size>=48*1024 then align:=1;
  while handle^.next<>nil do begin
    if align<>0 then a:=handle^.next^.start-(((handle^.start+16383) and (not longint(16383)))+handle^.size)
      else a:=handle^.next^.start-(handle^.start+handle^.size);
    if (a>size) and (a<bestSize) then begin
      bestSize:=a;
      best:=handle;
    end;
    handle:=handle^.next;
  end;
  if bestSize=33554432 then begin emsAlloc:=EMS_MEMORY; exit end;
  new(newHandle);
  newHandle^.next:=best^.next;
  best^.next:=newHandle;
  newHandle^.prev:=best;
  newHandle^.next^.prev:=newHandle;
  newHandle^.start:=best^.start+best^.size;
  if align<>0 then newHandle^.start:=(newHandle^.start+16383) and (not longint(16383));
  newHandle^.size:=size;
  inc(nextHandle);
  newHandle^.handle:=nextHandle;
  emsAlloc:=nextHandle;
end;

Procedure emsFree(handle:TEMSH);
var h:PHandle;
begin
  if status<>1 then exit;
  h:=findHandle(handle);
  if h=nil then exit;
  h^.prev^.next:=h^.next;
  h^.next^.prev:=h^.prev;
  dispose(h);
end;

Function  emsLock(handle:TEMSH;start:longint;length:word):pointer;
var h              : PHandle;
    mapped         : longint;
    page,pPage     : integer;
    ptr            : Pointer;
    tmp            : longint;
begin
  mapped:=0;
  pPage:=0;
  if status<>1 then begin emsLock:=nil; exit end;
  h:=findHandle(handle);
  if h=nil then begin emsLock:=nil; exit end;
  if start>h^.size then begin emsLock:=nil; exit end;
  if length+start>h^.size then length:=h^.size-start;
  page:=longint(h^.start+start) div 16384;
  tmp:=h^.start+start-longint(page)*16384;
  ptr:=pointer((longint(seg(frame^)+tmp shr 4) shl 16)+(tmp and longint($F)));
  mapped:=16384-h^.start+start+longint(page)*16384;
  _emsMapPages(page,pPage);
  physicalPages[pPage]:=page;
  while (length>mapped) and (pPage<3) do begin
    inc(page);
    inc(pPage);
    _emsMapPages(page,pPage);
    physicalPages[pPage]:=page;
    inc(mapped,16384);
  end;
  emsLock:=ptr;
end;

Function  emsCopyTo(handle:TEMSH;ptr:Pointer;start,length:longint):integer;
var h       : PHandle;
    move    : TEMSMove;
begin
  if status<>1 then begin emsCopyTo:=-1; exit end;
  h:=findHandle(handle);
  if h=nil then begin emsCopyTo:=-4; exit end;
  with move do begin
    size:=length;
    srcType:=EMSMOVE_CONV;
    srcHandle:=0;
    srcOffset:=ofs(ptr^);
    srcSegment:=seg(ptr^);
    destType:=EMSMOVE_EMS;
    destHandle:=lowHandle;
    destOffset:=(h^.start+start) and 16383;
    destSegment:=(h^.start+start) div 16384;
  end;
  _emsMoveMem(@move);
  emsCopyTo:=0;
end;

Function  emsCopyFrom(ptr:Pointer;handle:TEMSH;start,length:longint):integer;
var h       : PHandle;
    move    : TEMSMove;
begin
  if status<>1 then begin emsCopyFrom:=-1; exit end;
  h:=findHandle(handle);
  if h=nil then begin emsCopyFrom:=-4; exit end;
  with move do begin
    size:=length;
    destType:=EMSMOVE_CONV;
    destHandle:=0;
    destOffset:=ofs(ptr^);
    destSegment:=seg(ptr^);
    srcType:=EMSMOVE_EMS;
    srcHandle:=lowHandle;
    srcOffset:=(h^.start+start) and 16383;
    srcSegment:=(h^.start+start) div 16384;
  end;
  _emsMoveMem(@move);
  emsCopyFrom:=0;
end;

Function  emsCopy(handleTo,handleFrom:TEMSH;start1,start2,length:longint):integer;
var h1,h2   : PHandle;
    move    : TEMSMove;
begin
  if status<>1 then begin emsCopy:=-1; exit end;
  h1:=findHandle(handleTo);
  if h1=nil then begin emsCopy:=-4; exit end;
  h2:=findHandle(handleFrom);
  if h2=nil then begin emsCopy:=-4; exit end;
  with move do begin
    size:=length;
    destType:=EMSMOVE_EMS;
    destHandle:=lowHandle;
    destOffset:=(h1^.start+start1) and 16383;
    destSegment:=(h1^.start+start1) div 16384;
    srcType:=EMSMOVE_EMS;
    srcHandle:=lowHandle;
    srcOffset:=(h2^.start+start2) and 16383;
    srcSegment:=(h2^.start+start2) div 16384;
  end;
  _emsMoveMem(@move);
  emsCopy:=0;
end;

Procedure emsSaveState;
begin
  if status<>1 then exit;
  _emsSaveState;
end;

Procedure emsRestoreState;
begin
  if status<>1 then exit;
  _emsRestoreState;
end;

Function  emsHeapfree:longint;
begin
  if status<>1 then begin emsHeapfree:=0; exit end;
  emsHeapfree:=longint(_emsQueryFree)*16384;
end;

Procedure emsShowHeap; { Debugging function }
var h:PHandle;
begin
  h:=first;
  if status<>1 then exit;
  writeln('EMS Heap:');
  while h^.next<>nil do begin
    with h^ do
      writeln('Start: ',start,', size: ',size,', end: ',start+size);
    h:=h^.next;
  end;
end;

end.
