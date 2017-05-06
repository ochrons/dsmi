{ -------------------------------------------------------------------------- }
{                                                                            }
{                                FARLOAD.PAS                                 }
{                                -----------                                 }
{                                                                            }
{                         (C) 1993 Jussi Lahdenniemi                         }
{                                                                            }
{                                                                            }
{ Farandole composer module loader                                           }
{                                                                            }
{ -------------------------------------------------------------------------- }

unit farload;

interface
uses mcp,amp,loaders,csupport;

Function loadFAR(var fl:file;var modl:PModule):integer;
Function ampLoadFAR(name:string;options:Integer):PModule;

implementation
{$IFDEF USE_EMS}
uses emhm;
{$ENDIF}

const BASIC_FREQ = 8368;

type PFarHeader = ^TFarHeader;
     TFarHeader = Record
       magic    : longint;
       name     : array[0..39] of char;
       dummy1   : array[0..2] of byte;
       hdrlen   : word;
       version  : byte;
       channelmap : array[0..15] of byte;
       dummy2   : array[0..8] of byte;
       tempo    : byte;
       pan      : array[0..15] of byte;
       dummy3   : array[0..3] of byte;
       stlen    : word;
     end;

     PFarHeader2= ^TFarHeader2;
     TFarHeader2= Record
       order    : array[0..255] of byte;
       patcount,
       orderlen,
       loopto   : byte;
       patsize  : array[0..255] of word;
     end;

     PInsFar    = ^TInsFar;
     TInsFar    = Record
       name     : array[0..31] of char;
       length   : longint;
       finetune : byte;
       volume   : byte;
       loopStart,
       loopEnd  : longint;
       sampleType,
       loopMode : byte;
     end;

     PRowFar    = ^TRowFar;
     TRowFar    = Record
       note,
       ins,
       vol,
       eff      : byte;
     end;

var      patUsed : array[0..255] of byte;
         module  : PModule;
         f       : file;
         hdr     : TFarHeader;
         hdr2    : TFarHeader2;

function getTempo(tempo:integer):integer;
var a,b:longint;
begin
  a:=5000*tempo div 32;
  b:=a div 100;
  if a>1500 then a:=1500;
  getTempo:=125-(125-125*b div (b+1))*(a mod 100) div 100;
end;

function getSpeed(tempo:integer):integer;
begin
  getSpeed:=50*tempo div 32;
end;

function loadHeader:integer;
var t,i,count,a : integer;
    pat         : PPattern;

begin
  seek(f,0);
  blockread(f,hdr,sizeof(TFarHeader));
  loadHeader:=MERR_FILE;
  if IOresult<>0 then exit;
  seek(f,hdr.stlen+filepos(f));
  blockread(f,hdr2,sizeof(TFarHeader2));
  move(hdr.name,module^.name,32);
  module^.name[31]:=#0;
  module^.tempo:=getTempo(hdr.tempo);
  module^.speed:=getSpeed(hdr.tempo);
  for t:=0 to 15 do begin
    a:=hdr.pan[t];
    if a in [7,8] then a:=0 else
      if a<7 then a:=(a-7)*9 else a:=(a-8)*9;
    module^.channelPanning[t]:=a;
    if hdr.channelmap[t]<>0 then module^.channelCount:=t+1;
  end;
  count:=hdr2.orderlen;
  module^.patternCount:=count;
  module^.patterns:=calloc(count,sizeof(TPattern));
  loadHeader:=MERR_MEMORY;
  if module^.patterns=nil then exit;
  inc(module^.size,count*sizeof(TPattern));
  for t:=0 to count-1 do begin
    patUsed[hdr2.order[t]]:=1;
    pat:=@module^.patterns^[t];
    pat^.length:=256;
    for i:=0 to 15 do if hdr2.order[t]=$ff then pat^.tracks[i]:=nil else
      pat^.tracks[i]:=pointer(longint(hdr2.order[t]*16+1+i));
  end;
  module^.instruments:=calloc(64,sizeof(TInstrument));
  if module^.instruments=nil then exit;
  loadHeader:=MERR_NONE;
end;

Function loadPatterns:integer;

type TArray                                       = Array[0..255] of TRowFar;
var pos,row,t,j,i,tick,curTrack                   : integer;
    note,ins,volume,command,data,curins           : byte;
    count,buffersize                              : word;
    track                                         : PTrack;
    temptrack                                     : Array[0..575] of byte;
    buffer                                        : ^TArray;
    c                                             : TRowFar;

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

begin
  bufferSize:=64*16*sizeof(TRowFar);
  curTrack:=1;
  buffer:=malloc(bufferSize);
  loadPatterns:=MERR_MEMORY;
  if buffer=nil then exit;
  count:=0;
  for t:=0 to 255 do if hdr2.patsize[t]<>0 then count:=t+1;
  count:=count shl 4;
  module^.trackCount:=count;
  module^.tracks:=calloc(count+4,sizeof(PTrack));
  if module^.tracks=nil then exit;
  inc(module^.size,(count+4)*sizeof(PTrack));
  module^.tracks^[0]:=nil;
  for t:=0 to 255 do if hdr2.patsize[t]<>0 then begin
    blockread(f,data,1);
    loadPatterns:=MERR_FILE;
    if IOresult<>0 then exit;
    row:=data+1;
    seek(f,filepos(f)+1);
    if hdr2.patsize[t]>buffersize then begin
      free(buffer);
      buffersize:=hdr2.patsize[t];
      buffer:=malloc(buffersize);
      loadPatterns:=MERR_MEMORY;
      if buffer=nil then exit;
    end;
    loadPatterns:=MERR_FILE;
    blockread(f,buffer^,hdr2.patsize[t]-2);
    if IOresult<>0 then exit;
    for j:=0 to 15 do begin
      fillchar(temptrack,576,$ff);
      pos:=0;
      curins:=$f0;
      for tick:=0 to row do begin
        if (tick=row) and (j=0) and (tick<>255) then insertCmd(cmdBreak,0);
        note:=0;
        volume:=$ff;
        ins:=$ff;
        c:=buffer^[tick*16+j];
        if c.note<>0 then begin
          note:=c.note;
          ins:=c.ins;
          if ins<>curins then begin
            curins:=ins;
            insertCmd(cmdInstr,ins);
            module^.instruments^[ins].insType:=1;
          end;
        end;
        if c.vol=0 then volume:=$ff else volume:=c.vol;
        command:=c.eff shr 4;
        data:=c.eff and $f;
        if command=3 then insertCmd(cmdBenderTo,data);
        if note<>0 then
          if volume<>255 then insertNote(note+47,volume*4)
            else insertNote(note+47,255)
          else if volume<>255 then insertCmd(cmdVolumeAbs,volume*4);
        case command of
          1 : insertCmd(cmdBender,-data);
          2 : insertCmd(cmdBender,data);
          4 : insertCmd(cmdRetrig,data);
          $b: if data in [7,8] then insertCmd(cmdPan,0) else
              if data<7 then insertCmd(cmdPan,byte((integer(data)-7)*9)) else
                             insertCmd(cmdPan,byte((integer(data)-8)*9));
          $f: begin
                insertCmd(cmdExtTempo,getTempo(data));
                insertCmd(cmdTempo,getSpeed(data));
              end;
        end;
      end;
      if pos=0 then track:=nil else begin
        inc(pos);
        if loadOptions and LM_IML>0 then
          for i:=1 to curTrack-2 do
            if module^.tracks^[i]<>nil then
            if (module^.tracks^[i]^.size=pos) and
               (memcmp(@temptrack,pointer(longint(module^.tracks^[i])+3),pos*3)=0)
                 then begin
                   track:=module^.tracks^[i];
                   pos:=0;
                   break;
                 end;
        if pos<>0 then begin
          track:=malloc(pos*3+3);
          if track<>nil then begin
            inc(module^.size,pos*3+3);
            track^.size:=pos;
            track^.trkType:=0;
            move(temptrack,pointer(longint(track)+3)^,pos*3);
          end else begin
            loadPatterns:=MERR_MEMORY;
            exit;
          end;
        end;
      end;
      module^.tracks^[curTrack]:=track;
      inc(curTrack);
    end;
  end else if t<module^.trackCount div 16 then
    for j:=0 to 15 do begin
      module^.tracks^[curTrack]:=nil;
      inc(curTrack);
    end;
  free(buffer);
  loadPatterns:=MERR_NONE;
end;

Function loadSamples:integer;
Var t,i,lastins   : Word;
    instr         : Pinstrument;
    ins           : TInsFar;
    length,a,b    : Longint;
    sample        : Pointer;
    samplemap     : array[0..7] of byte;
    {$IFDEF USE_EMS}
    handle        : TEmsh;
    {$ENDIF}
Begin
  lastins:=0;
  module^.instrumentCount:=0;
  blockread(f,sampleMap,8);
  for t:=0 to 63 do begin
    instr:=@module^.instruments^[t];
    if (sampleMap[t div 8] and (1 shl (t and 7)))<>0 then begin
      lastins:=t;
      blockread(f,ins,sizeof(ins));
      instr^.size:=ins.length;
      if ins.loopMode<>0 then begin
        instr^.loopstart:=ins.loopstart;
        instr^.loopend:=ins.loopend;
      end else begin
        instr^.loopstart:=0;
        instr^.loopend:=0;
      end;
      instr^.volume:=64;
      instr^.rate:=BASIC_FREQ;
      length:=instr^.size;
      if (instr^.size>0) and (instr^.insType=1) then begin
        a:=instr^.loopend-instr^.loopstart;
        if (instr^.loopend<>0) and (a<crit_size) then begin
          b:=(Crit_Size div a)*a;
          instr^.loopend:=instr^.loopstart+b;
          loadSamples:=MERR_MEMORY;
          instr^.sample:=malloc(instr^.loopend+16);
          if instr^.sample=nil then exit;
          inc(module^.size,instr^.loopend);
          loadSamples:=MERR_FILE;
          blockread(f,instr^.sample^,instr^.size);
          if IOresult<>0 then exit;
          instr^.size:=instr^.loopend;
          for i:=1 to (Crit_Size div a)-1 do
            move(pointer(longint(instr^.sample)+instr^.loopstart)^,
                 pointer(longint(instr^.sample)+instr^.loopstart+a*i)^,a);
        end else begin
          if instr^.insType<>1 then begin
            seek(f,filepos(f)+length);
            continue;
          end;
          inc(module^.size,length);
          instr^.sample:=malloc(instr^.size+16);
          loadSamples:=MERR_MEMORY;
          if instr^.sample=nil then exit;
          loadSamples:=MERR_FILE;
          blockread(f,instr^.sample^,instr^.size);
          mcpConvertSample(instr^.sample,length);
          if IOresult<>0 then exit;
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
        seek(f,filepos(f)+instr^.size);
        instr^.size:=0;
        instr^.sample:=nil;
      end;
    end else begin
      instr^.sample:=nil;
      instr^.size:=0;
    end;
  end;
  module^.instrumentCount:=lastins+1;
  loadSamples:=MERR_NONE;
end;

Procedure joinTracks2Patterns;
Var t,i     : Word;
    pat     : PPattern;
Begin
  for t:=0 to module^.patternCount-1 do begin
    pat:=@module^.patterns^[t];
    for i:=0 to module^.channelCount-1 do
      pat^.tracks[i]:=module^.tracks^[word(pat^.tracks[i])];
  end;
end;

Function loadFAR;
var a:integer;
begin
  move(fl,f,sizeof(f));
  module:=modl;
  module^.size:=0;
  a:=loadHeader; if a<MERR_NONE then begin loadFAR:=a; exit end;
  a:=loadPatterns; if a<MERR_NONE then begin loadFAR:=a; exit end;
  a:=loadSamples; if a<MERR_NONE then begin loadFAR:=a; exit end;
  joinTracks2Patterns;
  loadFAR:=a;
end;

Function ampLoadFAR;
var f      : file;
    l      : longint;
    module : PModule;
    b      : integer;
    ID     : string[4];

begin
  loadOptions:=options;
  module:=malloc(sizeof(TModule));
  if module=nil then begin
    moduleError:=MERR_MEMORY;
    ampLoadFAR:=nil;
    exit
  end;
  fillchar(module^,sizeof(TModule),0);
  assign(f,name);
  reset(f,1);
  if ioresult<>0 then begin
    moduleError:=MERR_FILE;
    ampLoadFAR:=nil;
    free(module);
    exit
  end;
  module^.modType:=MOD_NONE;
  blockread(f,id[1],4);
  id[0]:=#4;
  if id='FARþ' then module^.modType:=MOD_FAR;
  if module^.modType=MOD_NONE then begin
    moduleError:=MERR_TYPE;
    ampLoadFAR:=nil;
    free(module);
    exit
  end;
  blockread(f,module^.name,32);
  module^.name[31]:=#0;
  b:=loadFAR(f,module);
  moduleError:=b;
  if b=MERR_NONE then begin
    module^.modType:=MOD_FAR;
    seek(f,0);
    module^.filesize:=filepos(f);
  end else begin
    ampFreeModule(module);
    free(module);
    module:=nil;
  end;
  close(f);
  ampLoadFAR:=module;
end;

end.
