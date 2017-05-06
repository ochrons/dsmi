{  ************************************************************************
   *
   *    File        : ULTLOAD.PAS
   *
   *    Description : Module loader for AMP
   *
   *    Copyright (C) 1994 Jussi Lahdenniemi
   *
   ************************************************************************ }

{$I+,R-,X+}

Unit ULTLoad;

interface
uses mcp,amp,loaders,csupport;

function loadULT(var f:file;var module:PModule):longint;
function ampLoadULT(name:string;options:longint):PModule;

implementation
{$IFDEF USE_EMS}
uses emhm;
{$ENDIF}

const BASIC_FREQ = 8368;

      instrRates : array[0..15] of word = ( 856,850,844,838,832,826,820,814,
                                            907,900,894,887,881,875,868,862 );

var curTrack:integer;
    patUsed:array[0..255] of byte;
    insc:byte;

type TULTHeader         = Record
       ID               : array[0..14] of char;
       songname         : array[0..31] of char;
       reserved         : byte;
     end;

     TULTInstrument     = Record
       sampleName       : array[0..31] of char;
       dosName          : array[0..11] of char;
       loopStart,
       loopEnd          : longint;
       sizeStart,
       sizeEnd          : longint;
       volume           : byte;
       bidi             : byte;
       finetune         : word;
     end;

var ulthdr:TULTHeader;

Function loadInstruments(var f:file;module:PModule):integer;
var t,a:integer;
    b:word;
    ulti:TULTInstrument;
    instr:PInstrument;

begin
  blockread(f,ulthdr,sizeof(TULTHeader));
  move(ulthdr.songname,module^.name,20);
  module^.name[20]:=#0;
{  module^.channelCount:=ulthdr.channelCount;}
  seek(f,filepos(f)+ulthdr.reserved*32);

{  for t:=0 to 31 do begin
    a:=mtmhdr.pan[t];
    if a in [7,8] then module^.channelPanning[t]:=0 else
      if a<7 then module^.channelPanning[t]:=(a-7)*9 else
        module^.channelPanning[t]:=(a-8)*9;
  end;}

  blockread(f,insc,1);
  module^.instrumentCount:=insc;
  module^.instruments:=calloc(insc,sizeof(TInstrument));
  loadInstruments:=MERR_MEMORY;
  if module^.instruments=nil then exit;
  inc(module^.size,insc*sizeof(TInstrument));
  for t:=0 to insc-1 do begin
    blockread(f,ulti,sizeof(TULTInstrument));
    loadInstruments:=MERR_FILE;
    if ioresult<>0 then exit;
    instr:=@module^.instruments^[t];
    instr^.insType:=0;
    move(ulti.sampleName,instr^.name,22);
    instr^.name[22]:=#0;
    instr^.sample:=nil;
    instr^.rate:=856*BASIC_FREQ div instrRates[ulti.finetune and $f];
    writeln('Finetune: ',ulti.finetune);
    if ulti.volume>64 then instr^.volume:=64 else instr^.volume:=ulti.volume;
    instr^.size:=ulti.sizeEnd-ulti.sizeStart-1;
    instr^.loopstart:=ulti.loopStart;
    b:=ulti.loopend;
    if b<3 then b:=0;
    instr^.loopend:=b;
    if instr^.loopend>instr^.size then instr^.loopend:=instr^.size;
    if instr^.loopstart>instr^.loopend then instr^.loopend:=0;
    if instr^.loopend=0 then instr^.loopstart:=0;
  end;
  loadInstruments:=MERR_NONE;
end;

Function loadPatterns(var f:file;module:PModule):integer;
Var pos,row,t,j,a,i,chan,tick,curTrack              : Integer;
    note,ins,volume,command,data,curins,curvolume,b : byte;
    command2,data2                                  : byte;
    bt,nvalue,count,volsld,breakat,tempo            : word;
    track                                           : PTrack;
    temptrack                                       : Array[0..767] of byte;
    buffer                                          : Array[0..64*5*32] of byte;
    repval,repcnt                                   : byte;
    orders                                          : array[0..255] of byte;
    lastPattern                                     : integer;
    patcount                                        : integer;
    pat                                             : PPattern;
    bptr                                            : integer;

Procedure insertNote(a,b:integer);
Begin
  temptrack[pos*3]:=tick;
  temptrack[pos*3+1]:=a;
  temptrack[pos*3+2]:=b;
  inc(pos);
end;

Procedure insertCmd(a,b:integer);
Begin
  temptrack[pos*3]:=tick;
  temptrack[pos*3+1]:=a;
  temptrack[pos*3+2]:=b;
  inc(pos);
end;

Begin
  blockread(f,orders,256);
  lastPattern:=0;
  for t:=0 to 255 do if (orders[t]<>255) and (orders[t]>lastPattern) then
    lastPattern:=orders[t];
  module^.patternCount:=lastPattern;
  module^.channelCount:=0;
  patcount:=0;
  blockread(f,module^.channelCount,1);
  blockread(f,patcount,1);
  seek(f,filepos(f)+module^.channelCount);
  inc(module^.channelCount);
  inc(patcount);
  module^.patterns:=calloc(module^.patternCount,sizeof(TPattern));
  loadPatterns:=MERR_MEMORY;
  if module^.patterns=nil then exit;
  inc(module^.size,module^.patternCount*sizeof(TPattern));
  for t:=0 to module^.patternCount-1 do begin
    patUsed[orders[t]]:=1;
    pat:=addr(module^.patterns^[t]);
    pat^.length:=64;
    for i:=0 to module^.channelCount-1 do pat^.tracks[i]:=
      pointer(byte(orders[t]<>$ff)*(orders[t]*module^.channelCount+1+i));
  end;
  curTrack:=1;
  count:=module^.patternCount*module^.channelCount;
  module^.trackCount:=count;
  module^.tracks:=calloc(count+4,sizeof(PTrack));
  if module^.tracks=nil then begin loadPatterns:=MERR_MEMORY; exit end;
  inc(module^.size,(count+4)*sizeof(PTrack));
  for t:=0 to patcount-1 do begin
    bptr:=0;
    blockread(f,buffer,64*5*module^.channelCount,j);
{    if j<>64*5 then begin loadPatterns:=MERR_FILE; exit end;}
    for j:=0 to module^.channelCount-1 do begin
      pos:=0;
      tick:=0;
      ins:=0;
      curins:=$f0;
      fillchar(temptrack,768,$ff);
      tick:=0;
      while tick<64 do begin
        note:=$ff;
        nvalue:=buffer[bptr];
        if nvalue=$fc then begin
          repval:=buffer[bptr+1];
          inc(bptr,2);
          nvalue:=buffer[bptr];
        end else repval:=1;
        if nvalue>0 then note:=nvalue+21;
        for repcnt:=1 to repval do begin
          command:=buffer[bptr+2] and $f;
          command2:=buffer[bptr+2] shr 4;
          data:=buffer[bptr+4];
          data2:=buffer[bptr+3];
          volume:=255;
          if command=$c then if data>64 then volume:=64 else volume:=data;
          if command2=$c then if data2>64 then volume:=64 else volume:=data2;
          ins:=buffer[bptr+1];
          if ins<>0 then begin
            dec(ins);
            if ins<>curins then begin
              insertCmd(cmdInstr,ins);
              module^.instruments^[ins].insType:=1;
            end else begin
              if (note=$ff) and (volume>64) then begin
                insertCmd(cmdVolumeAbs,module^.instruments^[ins].volume);
    {            insertCmd(cmdOffset,0);}
              end;
            end;
            curIns:=ins;
            inc(ins);
          end;
          if (command=$e) and ((data shr 4)=$d) and ((data and $f)<>0) and (note<>$ff) then begin
            insertCmd(cmdNoteDelay,data and $f);
            command:=$ff;
          end;
          if command=3 then begin
            insertCmd(cmdBenderTo,data);
            command:=$ff;
          end;
          if note<>$ff then begin
            dec(ins);
            if (ins<>$ff) and (command<>$c) and (command2<>$c) then volume:=module^.instruments^[ins].volume;
            insertNote(note,volume);
          end else if volume<65 then insertCmd(cmdVolumeAbs,volume);
          case command of
            $f : if (data in [1..31]) or (loadOptions and LM_OLDTEMPO>0) then
                   insertCmd(cmdTempo,data) else insertCmd(cmdExtTempo,data);
            $b : if (data<=7) then insertCmd(cmdPan,(7-data)*9)
                              else insertCmd(cmdPan,(data-8)*9);
            $d : insertCmd(cmdBreak,0);
            $a : begin
                   if data>=16 then data:=data div 16 else data:=-data;
                   insertCmd(cmdVolume,data);
                 end;
            2  : if data<>0 then begin
                   if data>127 then data:=127;
                   insertCmd(cmdBender,-data);
                 end;
            1  : if data<>0 then begin
                   if data>127 then data:=127;
                   insertCmd(cmdBender,-data);
                 end;
            4  : insertCmd(cmdVibrato,data);
            $e : begin
                   i:=data shr 4;
                   data:=data and $f;
                   case i of
                     9  : insertCmd(cmdRetrig,data);
                     1  : insertCmd(cmdFinetune,-data);
                     2  : insertCmd(cmdFinetune,data);
                     $a : insertCmd(cmdFinevol,data);
                     $b : insertCmd(cmdFinevol,-data);
                     $c : insertCmd(cmdNoteCut,data);
                     $d : insertCmd(cmdNoteDelay,data);
                   end;
                 end;
          end;
          inc(tick);
        end;
        if tick>64 then writeln('t: ',tick,' ',repval);
        inc(bptr,5);
      end;
      if pos=0 then track:=nil else begin
        inc(pos);
        if (loadOptions and LM_IML)>0 then
          if curTrack>1 then
          for i:=1 to curTrack-1 do
            if module^.tracks^[i]<>nil then
            if (module^.tracks^[i]^.size=pos) and
               (memcmp(@temptrack,pointer(longint(module^.tracks^[i])+3),pos*3)=0) then begin
                 track:=module^.tracks^[i];
                 pos:=0;
                 i:=curtrack-1;
               end;
        if pos<>0 then begin
          track:=malloc(pos*3+3);
          if track<>nil then begin
            inc(module^.size,pos*3+3);
            track^.size:=pos;
            track^.trkType:=0;
            move(temptrack,pointer(longint(track)+3)^,pos*3);
          end;
        end;
      end;
      module^.tracks^[curTrack]:=track;
      inc(curTrack);
    end;
    seek(f,filepos(f)-(64*5*module^.channelCount-bptr));
  end;
  loadPatterns:=MERR_NONE;
end;

Function loadSamples(var f:file; var module:PModule):integer;
Var t,i,a,b,l     : Word;
    c             : Longint;
    j             : integer;
    instr         : PInstrument;
    temp          : Array[0..31] of byte;
    {$IFDEF USE_EMS}
    handle        : TEMSH;
    {$ENDIF}
Begin
  writeln(filepos(f));
  for t:=0 to module^.instrumentCount-1 do begin
    instr:=@module^.instruments^[t];
    if ((loadOptions and LM_IML)>0) and (instr^.insType=0) then begin
      seek(f,filepos(f)+instr^.size);
      instr^.size:=0;
    end;
    if instr^.size>4 then begin
      a:=instr^.loopend-instr^.loopstart;
      if (instr^.loopend<>0) and (a<crit_size) then begin
        b:=(Crit_Size div a)*a;
        instr^.loopend:=instr^.loopstart+b;
        loadSamples:=MERR_MEMORY;
        instr^.sample:=malloc(instr^.loopend);
        if instr^.sample=nil then exit;
        inc(module^.size,instr^.loopend);
        if instr^.size>instr^.loopend then begin
          loadSamples:=MERR_FILE;
          blockread(f,instr^.sample^,instr^.loopend);
          if IOresult<>0 then exit;
          seek(f,filepos(f)+instr^.size-instr^.loopend);
        end else begin
          loadSamples:=MERR_FILE;
          blockread(f,instr^.sample^,instr^.size);
          if IOresult<>0 then exit;
        end;
        instr^.size:=instr^.loopend;
        for i:=1 to (Crit_Size div a)-1 do
          move(pointer(longint(instr^.sample)+instr^.loopstart)^,
               pointer(longint(instr^.sample)+instr^.loopstart+a*i)^,a);
        mcpConvertSample(instr^.sample,instr^.size);
      end else begin
        if instr^.size>65510 then a:=65510 else a:=instr^.size;
        instr^.sample:=malloc(a);
        loadSamples:=MERR_MEMORY;
        if instr^.sample=nil then exit;
        inc(module^.size,a);
        loadSamples:=MERR_CORRUPT;
        blockread(f,instr^.sample^,a,j);
        if IOresult<>0 then exit;
        if a<instr^.size then begin
          blockread(f,temp,instr^.size-a);
          instr^.size:=a;
        end;
        mcpConvertSample(instr^.sample,instr^.size);
{$IFDEF USE_EMS}
        handle:=0;
        if instr^.size>2048 then begin
          handle:=emsAlloc(instr^.size);
          if handle>0 then begin
            emsCopyTo(handle,instr^.sample,0,instr^.size);
            free(instr^.sample);
            instr^.sample:=ptr($ffff,handle);
          end;
        end;
{$ENDIF}
      end;
    end else begin
      instr^.size:=0;
      instr^.sample:=nil;
    end;
  end;
  loadSamples:=MERR_NONE;
end;

Procedure joinTracks2Patterns(var module:PModule);
Var t,i     : Word;
    pat     : PPattern;
Begin
  for t:=0 to module^.patternCount-1 do begin
    pat:=@module^.patterns^[t];
    for i:=0 to module^.channelCount-1 do
      pat^.tracks[i]:=module^.tracks^[word(pat^.tracks[i])];
  end;
end;

Function loadULT;
var a:integer;
begin
  module^.tempo:=125;
  module^.speed:=6;
  a:=loadInstruments(f,module);
  loadULT:=a;
  if a<MERR_NONE then exit;
  a:=loadPatterns(f,module);
  loadULT:=a;
  if a<MERR_NONE then exit;
  a:=loadSamples(f,module);
  loadULT:=a;
  if a<MERR_NONE then exit;
  joinTracks2Patterns(module);
  loadULT:=a;
end;

Function ampLoadULT;
var f      : file;
    l      : longint;
    module : PModule;
    b      : integer;
    ID     : string[11];

begin
  loadOptions:=options;
  module:=malloc(sizeof(TModule));
  if module=nil then begin
    moduleError:=MERR_MEMORY;
    ampLoadULT:=nil;
    exit
  end;
  fillchar(module^,sizeof(TModule),0);
  assign(f,name);
  reset(f,1);
  if ioresult<>0 then begin
    moduleError:=MERR_FILE;
    ampLoadULT:=nil;
    free(module);
    exit
  end;
  module^.modType:=MOD_NONE;
  blockread(f,id[1],11);
  id[0]:=#11;
  if id='MAS_UTrack_' then module^.modType:=MOD_ULT;
  if module^.modType=MOD_NONE then begin
    moduleError:=MERR_TYPE;
    ampLoadULT:=nil;
    free(module);
    exit
  end;
  b:=loadULT(f,module);
  moduleError:=b;
  if b=MERR_NONE then begin
    seek(f,0);
    module^.filesize:=filepos(f);
  end else begin
    ampFreeModule(module);
    free(module);
    module:=nil;
  end;
  close(f);
  ampLoadULT:=module;
end;

end.
