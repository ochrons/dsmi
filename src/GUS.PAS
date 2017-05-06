{ -------------------------------------------------------------------------- }
{                                                                            }
{                                  GUS.PAS                                   }
{                                  -------                                   }
{                                                                            }
{                         (C) 1993 Jussi Lahdenniemi                         }
{        Original C files (C) 1993 Otto Chrons                               }
{                                                                            }
{ GUS interface for DSMI                                                     }
{ and GUS heap manager                                                       }
{                                                                            }
{ -------------------------------------------------------------------------- }

{$I-,R-,X+,F+}

Unit gus;

Interface
uses mcp,cdi;

const MAXSAMPLE = 128;

Var sampleList       : array[0..MAXSAMPLE-1] of record
      origSample     : longint;
      gusSample      : longint;
    end;
    sampleListLength : longint;
    gusDeltaTime     : longint;

const gusStatus      : byte = 0;

        ID_GUS       = 10;
        GUS_TIMER    = 1193180 div 101;

Function  gusInit(scard:PSoundCard):integer;
Procedure gusClose;
Function  gusStartVoice:integer;
Function  gusStopVoice:integer;
Function  gusPeek(addr:longint):byte;
Procedure gusPoke(addr:longint;value:longint);
Function  gusGetSamplingRate:word;

Function  gusGetDelta:Longint;
Procedure gusPoll(time:Longint);
Function  gusMuteChannel(Channel:longint):Integer;
Function  gusUnmuteChannel(Channel:longint):Integer;
Function  gusStopChannel(Channel:longint):Integer;
Function  gusMuteAll:Integer;
Function  gusUnmuteAll:Integer;
Function  gusSetSample(channel:longint;s:PSampleInfo):Integer;
Function  gusPlaySample(channel:longint;rate:Longint;volume:longint):Integer;
Function  gusSetVolume(channel:longint;Volume:longint):Integer;
Function  gusSetRate(channel:longint;Rate:Longint):Integer;
Function  gusSetPosition(channel:longint;Position:Longint):Integer;
Procedure gusSetPanning(channel,panning:longint);
Function  gusSetMasterVolume(Volume:longint):Integer;
Function  gusDownloadSample(ptr:pointer;tag,length:longint):integer;
Procedure gusUnloadSample(sample:pointer);
Procedure gusUnloadAll;
Function  gusGetVolume(channel:longint):integer;
Function  gusGetRate(channel:longint):longint;
Function  gusGetPosition(channel:longint):longint;
Function  gusGetPanning(channel:longint):longint;
Function  gusGetSample(channel:longint):pointer;
Function  gusGetChannelStatus(channel:longint):integer;
Function  gusSetupChannels(count:longint;volTable:pointer):integer;
Procedure gusInterrupt; Interrupt;

Const CDI_GUS        : TCDIdevice = (
    setsample        : @gusSetSample;
    playsample       : @gusPlaySample;
    setvolume        : @gusSetVolume;
    setfrequency     : @gusSetRate;
    setlinearrate    : @nullFunction;
    setposition      : @gusSetPosition;
    setpanning       : @gusSetPanning;
    setmastervolume  : @gusSetMasterVolume;
    mutechannel      : @gusMuteChannel;
    unmutechannel    : @gusUnmuteChannel;
    stopchannel      : @gusStopChannel;
    muteall          : @gusMuteAll;
    unmuteall        : @gusUnmuteAll;
    poll             : @gusPoll;
    getdelta         : @gusGetDelta;
    download         : @gusDownloadSample;
    unload           : @gusUnloadSample;
    unloadall        : @gusUnloadAll;
    getvolume        : @gusGetVolume;
    getfrequency     : @gusGetRate;
    getposition      : @gusGetPosition;
    getpan           : @gusGetPanning;
    getsample        : @gusGetSample;
    setupch          : @gusSetupChannels;
    getchannelstatus : @gusGetChannelStatus);

{ GUS heap manager }

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
procedure gushmShowHeap;

Implementation
{$IFNDEF DPMI}
uses csupport;
{$ELSE}
uses csupport,dpmiapi;
{$ENDIF}

Function  gusInit(scard:PSoundCard):integer; external;
Procedure gusClose; external;
Function  gusStartVoice:integer; external;
Function  gusStopVoice:integer; external;
Function  gusPeek(addr:longint):byte; external;
Procedure gusPoke(addr:longint;value:longint); external;
Function  gusGetSamplingRate:word; external;

Function  gusGetDelta:Longint; external;
Procedure gusPoll(time:Longint); external;
Function  gusMuteChannel(channel:longint):Integer; external;
Function  gusUnmuteChannel(channel:longint):Integer; external;
Function  gusStopChannel(channel:longint):Integer; external;
Function  gusMuteAll:Integer; external;
Function  gusUnmuteAll:Integer; external;
Function  gusSetSample(channel:longint;s:PSampleInfo):Integer; external;
Function  gusPlaySample(channel:longint;rate:Longint;volume:longint):Integer; external;
Function  gusSetVolume(channel:longint;Volume:longint):Integer; external;
Function  gusSetRate(channel:longint;Rate:Longint):Integer; external;
Function  gusSetPosition(channel:longint;Position:Longint):Integer; external;
Procedure gusSetPanning(channel,panning:longint); external;
Function  gusSetMasterVolume(Volume:longint):Integer; external;
Function  gusDownloadSample(ptr:pointer;tag,length:longint):integer; external;
Procedure gusUnloadSample(sample:pointer); external;
Procedure gusUnloadAll; external;
Function  gusGetVolume(channel:longint):integer; external;
Function  gusGetRate(channel:longint):longint; external;
Function  gusGetPosition(channel:longint):longint; external;
Function  gusGetPanning(channel:longint):longint; external;
Function  gusGetSample(channel:longint):pointer; external;
Function  gusGetChannelStatus(channel:longint):integer; external;
Function  gusSetupChannels(count:longint;volTable:pointer):integer; external;
Procedure gusInterrupt; external;

{$L gus.obj}

Function  D_malloc(s:longint):pointer;
begin
  D_malloc:=malloc(s);
end;

Procedure D_free(p:pointer);
begin
  free(p);
end;

Function  D_calloc(s,t:longint):pointer;
begin
  D_calloc:=calloc(s,t);
end;

{ GUS Heap Manager }

const first     : PGHandle = nil;
      last      : PGHandle = nil;
      status    : integer  = 0;

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
begin
  first:=malloc(sizeof(TGHandle));
  last:=malloc(sizeof(TGHandle));
  first^.handle:=32;
  first^.start:=32;
  first^.size:=32;
  first^.next:=last;
  first^.prev:=nil;
  move(first^,last^,sizeof(TGHandle));
  last^.next:=nil;
  last^.prev:=first;
  gusPoke(longint(257)*longint(1024),$55);
  a:=256;
  if gusPeek(longint(257)*longint(1024))=$55 then begin
    a:=512;
    gusPoke(longint(513)*longint(1024),$55);
    if gusPeek(longint(513)*longint(1024))=$55 then a:=1024;
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
  first^.next:=last;
  last^.prev:=first;
end;

function gushmAlloc(size:longint):TGUSH;
var newHandle,handle,best : PGHandle;
    bestSize,a            : longint;
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
  if h^.prev<>nil then h^.prev^.next:=h^.next else first:=h^.next;
  if h^.next<>nil then h^.next^.prev:=h^.prev else last:=h^.prev;
  free(h);
end;

procedure gushmShowHeap;                { Debugging function }
var h:PGHandle;
begin
  if status<>1 then exit;
  h:=first;
  writeln('GUS Heap:');
  while (h^.next<>nil) do with h^ do begin
    writeln('Start: ',start,', size: ',size,', end: ',start+size,', handle: ',handle);
    h:=next;
  end;
end;

end.
