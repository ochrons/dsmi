{ -------------------------------------------------------------------------- }
{                                                                            }
{                                 GUSHM.PAS                                  }
{                                 ---------                                  }
{                                                                            }
{                         (C) 1993 Jussi Lahdenniemi                         }
{         Original C file (C) 1993 Otto Chrons                               }
{                                                                            }
{ GUS Heap Manager                                                           }
{                                                                            }
{ -------------------------------------------------------------------------- }

unit gushm;

interface

type PGUSH              = ^TGUSH;
     TGUSH              = longint;

     PGHandle           = ^TGHandle;
     TGHandle           = Record
       handle           : TGUSH;
       start,size       : longint;
       next,prev        : PGHandle;
     end;

Const GUS_MEMORY = -1;

function  gushmInit:integer;
procedure gushmClose;
procedure gushmFreeAll;
function  gushmAlloc(size:longint):TGUSH;
procedure gushmFree(handle:TGUSH);
function  gushmCopyTo(handle:TGUSH;ptr:pointer;start,length:longint):integer;

implementation
uses csupport,gus;

const first     : PGHandle = nil;
      last      : PGHandle = nil;
      locked    : PGHandle = nil;
      status    : integer  = 0;
      nextHandle: TGUSH    = 0;

var   frame     : pointer;

function findHandle(which:TGUSH):PGHandle;
var handle:PGHandle;
begin
  handle:=first;
  if which=0 then begin findHandle:=nil; exit end;
  while handle^.next<>nil do begin
    if handle^.handle=which then begin findHandle:=handle; exit end;
    handle:=handle^.next;
  end;
  findHandle:=nil;
end;

function gushmInit:integer;
var a    : word;
    h,h2 : PGHandle;
begin
  first:=malloc(sizeof(TGHandle));
  last:=malloc(sizeof(TGHandle));
  first^.handle:=32;
  first^.start:=32;
  first^.size:=0;
  first^.next:=last;
  first^.prev:=nil;
  move(first^,last^,sizeof(TGHandle));
  last^.next:=nil;
  last^.prev:=first;
  gusPoke(262144,$55);
  a:=256;
  if gusPeek(262144)=$55 then begin
    a:=512;
    gusPoke(524288,$55);
    if gusPeek(524288)=$55 then a:=1024;
  end;
  last^.handle:=longint(1024)*longint(a);
  last^.start:=last^.handle;
  status:=1;
  gushmInit:=0;
end;

procedure gushmClose;
var handle,h : PGHandle;
begin
  handle:=first;
  if status<>1 then exit;
  status:=0;
  while handle<>nil do begin
    h:=handle^.next;
    free(handle);
    handle:=h;
  end;
end;

procedure gushmFreeAll;
var handle,h : PGHandle;
begin
  handle:=first^.next;
  if status<>1 then exit;
  while handle^.next<>nil do begin
    h:=handle^.next;
    free(handle);
    handle:=h;
  end;
end;

function gushmAlloc(size:longint):TGUSH;
var newHandle,handle,best : PGHandle;
    bestSize,a,b          : longint;
    align                 : integer;
begin
  if status<>1 then begin gushmAlloc:=-1; exit end;
  handle:=first;
  best:=first;
  bestSize:=33554432; { 32 MB }
  align:=0;
  size:=(size+32) and not longint(31);
  while handle^.next<>nil do begin
    a:=handle^.next^.start-(handle^.start+handle^.size);
    if (handle^.start+handle^.size) div 262144 <>
       (handle^.start+handle^.size+size) div 262144 then begin
      a:=handle^.next^.start-((handle^.start+handle^.size+size) and not longint(262143));
      if (a>size) and (a<bestSize) then begin
        bestSize:=a;
        best:=handle;
        align:=1;
      end;
    end else
    if (a>size) and (a<bestSize) then begin
      bestSize:=a;
      best:=handle;
      align:=0;
    end;
    handle:=handle^.next;
  end;
  newHandle:=malloc(sizeof(TGHandle));
  if newHandle=nil then begin gushmAlloc:=GUS_MEMORY; exit end;
  newHandle^.next:=best^.next;
  best^.next:=newHandle;
  newHandle^.prev:=best;
  newHandle^.next^.prev:=newHandle;
  if align>0 then newHandle^.start:=(best^.start+best^.size+size) and not longint(262143)
    else newHandle^.start:=best^.start+best^.size;
  newHandle^.size:=size;
  newHandle^.handle:=newHandle^.start;
  gushmAlloc:=newHandle^.start;
end;

procedure gushmFree(handle:TGUSH);
var h:PGHandle;
begin
  if status<>1 then exit;
  h:=findHandle(handle);
  if h=nil then exit;
  h^.prev^.next:=h^.next;
  h^.next^.prev:=h^.prev;
  free(h);
end;

procedure gushmShowHeap;                { Debugging function }
var h:PGHandle;
begin
  if status<>1 then exit;
  h:=first;
  writeln('GUS Heap:');
  while (h^.next<>nil) do with h^ do begin
    writeln('Start: ',start,', size: ',size,', end: ',start+size,', tag: ',handle);
    h:=next;
  end;
end;

end.
