(***************************************************************************

                                 AMFLOAD.PAS
                                 -----------

                          (C) 1993 Jussi Lahdenniemi

loadAMF and ampLoadAMF functions
Original C version by Otto Chrons

***************************************************************************)

Unit AMFload;  {$I-,X+}

Interface
Uses AMP,Loaders,Csupport;

Function LoadAMF(Var f:File;Var Module:PModule):Integer;
Function ampLoadAMF(name:String;options:longint):PModule;

Implementation
{$IFDEF USE_EMS}
uses emhm;
{$ENDIF}

type TOldInstrument = record
       t           : byte;
       name        : array[0..31] of char;
       filename    : array[0..12] of char;
       sample      : pointer;
       size        : word;
       rate        : word;
       volume      : byte;
       loopstart,
       loopend     : word;
     end;

const order16 : array[0..15] of shortint = (PAN_LEFT,PAN_RIGHT,PAN_RIGHT,PAN_LEFT,PAN_LEFT,PAN_RIGHT,PAN_RIGHT,PAN_LEFT,
				            PAN_LEFT,PAN_RIGHT,PAN_RIGHT,PAN_LEFT,PAN_LEFT,PAN_RIGHT,PAN_RIGHT,PAN_LEFT);

Procedure joinTracks2Patterns(Var Module:PModule);
Var t,i   : Integer;
    pat   : PPattern;
Begin
  For t:=0 to Module^.PatternCount-1 do begin
    pat:=@Module^.patterns^[t];
    for i:=0 to Module^.ChannelCount-1 do
      if module^.trackCount<word(pat^.tracks[i]) then pat^.tracks[i]:=nil else
        pat^.tracks[i]:=Module^.tracks^[word(pat^.tracks[i])];
  end;
end;

Function loadAMF(var f:file; var module:PModule):Integer;
Type sh              = Array[0..32000] of word;
Var a,t,i,pan        : Integer;
    sample           : ^sh;
    tracks           : ^sh;
    l                : longint;
    track            : PTrack;
    Smp              : Pointer;
    oldIns           : Boolean;
    oi               : TOldInstrument;
    instr            : TInstrument;
{$IFDEF USE_EMS}
    handle           : TEMSH;
{$ENDIF}
Const insPtr         : Integer = 0;
      size           : Integer = 0;
      trckPtr        : Integer = 0;

Begin
  size:=0;
  trckPtr:=0;
  insPtr:=0;
  module^.tempo:=125;
  module^.speed:=6;
  Seek(f,0);
  Blockread(f,l,4);
  BLockread(f,module^.name,32);
  loadAMF:=MERR_TYPE;
  oldIns:=true;
  if l>=$0C464D41 then pan:=32 else pan:=16;
  if l=$01464D41 then size:=3 else
  if l>=$0A464D41 then oldIns:=false else
  if (l<>$08464D41) and (l<>$09464D41) then exit;
  Blockread(f,module^.instrumentCount,1);
  Blockread(f,module^.patternCount,1);
  Blockread(f,module^.trackCount,2);
  if l>=$09464D41 then begin
    blockread(f,module^.channelCount,1);
    blockread(f,module^.channelPanning,pan);
    if l<$0B464D41 then move(order16,module^.channelPanning,16);
  end;
  if l>=$0D464D41 then begin
    blockread(f,module^.tempo,1);
    blockread(f,module^.speed,1);
  end;
  loadAMF:=MERR_MEMORY;
  module^.patterns:=calloc(module^.patternCount,sizeof(TPattern));
  if module^.patterns=nil then exit;
  module^.instruments:=calloc(module^.instrumentCount,sizeof(TInstrument));
  if module^.instruments=nil then exit;
  module^.tracks:=calloc(module^.trackCount+4,sizeof(pointer));
  if module^.tracks=nil then exit;
  module^.size:=module^.size+module^.patternCount*sizeof(TPattern)+
                             module^.instrumentCount*sizeof(TInstrument)+
                             module^.trackCount*sizeof(pointer);
  for t:=0 to module^.patternCount-1 do begin
    if l>=$e464d41 then blockread(f,module^.patterns^[t].length,2)
      else module^.patterns^[t].length:=64;
    for i:=0 to module^.channelCount-1 do
      blockread(f,module^.patterns^[t].tracks[i],2);
  end;
  sample:=calloc(module^.instrumentCount,sizeof(word));
  for t:=0 to module^.instrumentCount-1 do begin
    if oldIns then begin
      blockread(f,oi,sizeOf(TOldInstrument));
      move(oi,module^.instruments^[t],sizeOf(TOldInstrument));
      with module^.instruments^[t] do begin
        size:=oi.size;
        rate:=oi.rate;
        volume:=oi.volume;
        loopstart:=oi.loopstart;
        loopend:=oi.loopend;
        if loopend=65535 then loopend:=0;
      end;
    end else blockread(f,module^.instruments^[t],sizeof(TInstrument));
    if Integer(module^.instruments^[t].sample)>insPtr then begin
      sample^[insPtr]:=module^.instruments^[t].size;
      inc(insPtr);
    end;
  end;
  tracks:=calloc(module^.trackCount,sizeof(Word));
  for t:=0 to module^.trackCount-1 do begin
    blockread(f,tracks^[t],2);
    if tracks^[t]>trckPtr then trckPtr:=tracks^[t];
  end;

  for i:=1 to module^.trackCount do
    module^.tracks^[i]:=nil;
  for t:=0 to trckPtr-1 do begin
    Blockread(f,a,2);
    Blockread(f,i,1);
    if a=0 then track:=nil else begin
      track:=malloc(3*a+6);
      loadAMF:=MERR_MEMORY;
      if track=nil then exit;
      inc(module^.size,3*a+6);
      track^.trkType:=0;
      track^.size:=a;
      blockread(f,track^.notes,a*3+size);
    end;
    for i:=0 to module^.trackCount-1 do
      if tracks^[i]=t+1 then module^.tracks^[i+1]:=track;
  end;

  for t:=0 to insPtr-1 do begin
    if sample^[t]>0 then begin
      smp:=malloc(sample^[t]+16);
      loadAMF:=-1;
      if smp=nil then exit;
      inc(module^.size,sample^[t]+16);
      blockread(f,smp^,sample^[t]);
      loadAMF:=-2;
      if IOresult<>0 then exit;
{$IFDEF USE_EMS}
      handle:=0;
      if sample^[t]>2048 then begin
        handle:=emsAlloc(sample^[t]);
        if handle>0 then begin
          emsCopyTo(handle,smp,0,sample^[t]);
          free(smp);
          smp:=ptr($ffff,handle);
        end;
      end;
{$ENDIF}
      for i:=0 to module^.instrumentCount-1 do
        if (word(module^.instruments^[i].sample)=t+1) and
           (longint(module^.instruments^[i].sample) and $FFFF0000=0) then
             module^.instruments^[i].sample:=smp;
    end;
  end;
  for i:=0 to module^.instrumentCount-1 do
    if longint(module^.instruments^[i].sample) and $FFFF0000=0 then
       module^.instruments^[i].sample:=nil;
  jointracks2Patterns(module);
  free(pointer(sample));
  free(pointer(tracks));
  loadAMF:=MERR_NONE;
End;

Function ampLoadAMF(name:String;options:longint):PModule;
var f         : file;
    l         : longint;
    module    : PModule;
    t,b       : integer;

begin
  ampLoadAMF:=nil;
  loadOptions:=options;
  module:=malloc(sizeof(TModule));
  if module=nil then begin
    moduleError:=MERR_Memory;
    exit;
  end;
  fillchar(module^,sizeof(TModule),0);
  assign(f,name);
  reset(f,1);
  if IOresult<>0 then begin
    moduleError:=MERR_File;
    exit;
  end;
  seek(f,0);
  blockread(f,l,4);
  if (l and $ffffff=$464D41) then begin
    module^.modType:=MOD_AMF;
    blockread(f,module^.name,20);
    module^.name[20]:=#0;
    if (l=$01464D41) or (l=$08464D41) then begin
      module^.channelCount:=4;
      move(order4,module^.channelPanning,4);
    end;
  end else begin
    module^.modType:=MOD_NONE;
    moduleError:=MERR_Type;
    exit;
  end;
  b:=loadAMF(f,module);
  moduleError:=b;
  if b=MERR_None then module^.filesize:=filesize(f) else begin
    ampFreeModule(module);
    free(module);
    module:=nil;
  end;
  close(f);
  ampLoadAMF:=module;
end;

end.
