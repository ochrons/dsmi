(***************************************************************************

                                 _669LOAD.PAS
                                 ------------

                          (C) 1993 Jussi Lahdenniemi

load669 and ampLoad669 functions
Original C version by Otto Chrons

***************************************************************************)

Unit _669Load; {$I-,X+}

Interface
Uses MCP,AMP,Loaders,CSupport;

Function Load669(Var File_:File;Var Module_:PModule):Integer;
Function ampLoad669(name:String;options:longint):PModule;

Implementation
{$IFDEF USE_EMS}
uses emhm;
{$ENDIF}

Const order8            : array[0..7] of shortint =
        (PAN_LEFT,PAN_RIGHT,PAN_LEFT,PAN_RIGHT,PAN_LEFT,PAN_RIGHT,PAN_LEFT,PAN_RIGHT);

      Basic_Freq        = 8368;

Type THeader669         = Record
                            magic       : word;
                            message     : Array[0..107] of char;
                            ins,pats,
                            loop        : byte;
                            orders,tempos,
                            breaks      : array[0..127] of byte;
                          end;

Var curTrack            : Integer;
    patUsed             : Array[0..255] of byte;
    module              : PModule;
    f                   : File;
    hdr                 : THeader669;
    lastChan            : Integer;

Function loadHeader(var f:file):Integer;
var t,count,i  : Integer;
    pat        : PPattern;
begin
  seek(f,0);
  blockread(f,hdr,sizeof(hdr));
  module^.channelCount:=8;
  move(order8,module^.channelPanning,8);
  module^.tempo:=80;
  module^.speed:=4;
  count:=0;
  while (count<128) and (hdr.orders[count]<128) do inc(count);
  module^.patternCount:=count;
  module^.patterns:=calloc(count,sizeof(TPattern));
  if module^.patterns=nil then begin
    loadHeader:=MERR_MEMORY;
    exit;
  end;
  inc(module^.size,count*sizeof(TPattern));
  for t:=0 to count-1 do begin
    patUsed[hdr.orders[t]]:=1;
    pat:=addr(module^.patterns^[t]);
    pat^.length:=64;
    for i:=0 to 7 do pat^.tracks[i]:=
      pointer(byte(hdr.orders[t]<>$ff)*(hdr.orders[t]*8+1+i));
  end;
  loadHeader:=MERR_NONE;
end;

function findBT(pat:integer):word;
var i,t:integer;
begin
  for t:=0 to module^.patternCount-1 do
    if hdr.orders[t]=pat then begin
      findBT:=hdr.tempos[t];
      exit;
    end;
  findBT:=0;
end;

type TIns669 = Record
       name                     : array[0..12] of char;
       length,loopstart,loopend : longint;
     end;

Function loadInstruments(Var f:File):Integer;
Var t,i,a,b      : Word;
    ins          : TIns669;
    instr        : PInstrument;

Begin
  With Module^ do begin
    instrumentCount:=hdr.ins;
    instruments:=calloc(hdr.ins,sizeof(TInstrument));
    If instruments=Nil then begin loadInstruments:=MERR_MEMORY; exit end;
    Size:=Size+instrumentCount*sizeof(TInstrument);
    for t:=0 to hdr.ins-1 do begin
      Blockread(f,ins,sizeof(TIns669),a);
      if a<>sizeOf(TIns669) then begin loadInstruments:=MERR_FILE; exit end;
      instr:=@instruments^[t];
      instr^.insType:=0;
      strcpy(instr^.name,ins.name);
      instr^.name[13]:=#0;
      strcpy(instr^.filename,ins.name);
      instr^.filename[12]:=#0;
      instr^.rate:=BASIC_FREQ;
      instr^.volume:=64;
      instr^.size:=ins.length;
      instr^.loopstart:=ins.loopstart;
      instr^.loopend:=byte(ins.loopend<=ins.length)*ins.loopend;
      instr^.sample:=nil;
    end;
  end;
  loadInstruments:=MERR_NONE;
end;

Type TRow669 = Record
       b1,b2,b3 : Byte;
      end;

Function loadPatterns(var f:file):Integer;
Var pos,row,t,j,a,i,chan,tick,curTrack              : Integer;
    note,ins,volume,command,data,curins,curvolume,b : byte;
    bt,nvalue,count,volsld,breakat,tempo            : word;
    track                                           : PTrack;
    temptrack                                       : Array[0..575] of byte;
    buffer                                          : Array[0..63,0..7] of TRow669;
    c                                               : TRow669;

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
  curTrack:=1;
  count:=hdr.pats*8;
  module^.trackCount:=count;
  module^.tracks:=calloc(count+4,sizeof(PTrack));
  if module^.tracks=nil then begin loadPatterns:=MERR_MEMORY; exit end;
  inc(module^.size,(count+4)*sizeof(PTrack));
  for t:=0 to hdr.pats-1 do begin
    tempo:=findBT(t);
    blockread(f,buffer,64*8*3,j);
    if j<>64*8*3 then begin loadPatterns:=MERR_FILE; exit end;
    for j:=0 to 7 do begin
      fillchar(temptrack,576,$ff);
      pos:=0;
      curins:=$f0;
      for tick:=0 to 63 do begin
        if (tick=0) and (j=0) and (tempo<>0) then begin
          insertCmd(cmdTempo,tempo);
          insertCmd(cmdExtTempo,80);
        end;
        if (tick=hdr.breaks[t]) and (j=0) and (tick<>63) then insertCmd(cmdBreak,0);
        note:=0;
        volume:=$ff;
        ins:=$ff;
        c:=buffer[tick,j];
        if c.b1<$fe then begin
          note:=c.b1 shr 2;
          ins:=((c.b1 and $3) shl 4) or (c.b2 shr 4);
          if ins<>curIns then begin
            curIns:=ins;
            insertCmd(cmdInstr,ins);
            module^.instruments^[ins].insType:=1;
          end;
        end;
        if c.b1<$ff then volume:=c.b2 and $f;
        command:=c.b3 shr 4;
        data:=c.b3 and $f;
        if command=2 then insertCmd(cmdBenderTo,data);
        if note<>0 then begin
          if volume<>$ff then insertNote(note+36,volume*4) else
            insertNote(note+36,255);
        end else if volume<>$ff then insertCmd(cmdVolumeAbs,volume*4);
        case command of
          0 : insertCmd(cmdBender,data);
          1 : insertCmd(cmdBender,-data);
          3 : insertCmd(cmdFinetune,-1);
          4 : insertCmd(cmdVibrato,data shl 4+1);
          5 : insertCmd(cmdTempo,data);
        end;
      end;
      if pos=0 then track:=nil else begin
        inc(pos);
        if loadOptions and LM_IML>0 then for i:=1 to curTrack-1 do
          if module^.tracks^[i]<>nil then
            if (module^.tracks^[i]^.size=pos) and
               (memcmp(@temptrack,pointer(longint(module^.tracks^[i])+3),pos*3)=0) then begin
              track:=module^.tracks^[i];
              pos:=0;
              i:=curTrack-1;
            end;
        if pos<>0 then begin
          track:=malloc(pos*3+3);
          if track<>nil then begin
            inc(module^.size,pos*3+3);
            track^.size:=pos;
            track^.trkType:=0;
            move(temptrack,pointer(longint(track)+3)^,pos*3);
          end else begin loadPatterns:=MERR_MEMORY; exit end;
        end;
      end;
      module^.tracks^[curTrack]:=track;
      inc(curTrack);
    end;
  end;
  loadPatterns:=MERR_NONE;
end;

Function loadSamples(var f:file):integer;
Var t,i           : Word;
    instr         : PInstrument;
    length,a,b    : Longint;
    sample        : Pointer;
    c             : byte;
{$IFDEF USE_EMS}
    handle        : TEMSH;
{$ENDIF}
Label cont;
Begin
  seek(f,longint($1f1)+longint(hdr.ins)*longint(sizeof(TIns669))+longint(hdr.pats)*longint($600));
  for t:=0 to hdr.ins-1 do begin
    instr:=@module^.instruments^[t];
    length:=instr^.size;
    if (length>0) and (instr^.insType=1) then begin
      a:=instr^.loopend-instr^.loopstart;
      if (instr^.loopend<>0) and (a<crit_size) then begin
        b:=(Crit_Size div a)*a;
        instr^.loopend:=instr^.loopstart+b;
        loadSamples:=MERR_MEMORY;
        instr^.sample:=malloc(instr^.loopend+16);
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
      end else begin
        if instr^.insType<>1 then begin
          seek(f,length+filepos(f));
          goto cont;
        end;
        inc(module^.size,length);
        instr^.sample:=malloc(length);
        loadSamples:=MERR_MEMORY;
        if instr^.sample=nil then exit;
        loadSamples:=MERR_CORRUPT;
        blockread(f,instr^.sample^,length);
        if IOresult<>0 then exit;
        { Remove clicks }
        c:=128;
        if instr^.loopend<>0 then c:=mem[seg(instr^.sample^):ofs(instr^.sample^)+instr^.loopstart];
        mem[seg(instr^.sample^):ofs(instr^.sample^)+instr^.size-1]:=c;
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
      seek(f,instr^.size+filepos(f));
      instr^.size:=0;
      instr^.sample:=nil;
    end;
cont:
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

Function load669;
var a:integer;
Begin
  module:=module_;
  module^.size:=0;
  lastChan:=0;
  a:=loadHeader(file_);
  load669:=a;
  if a<>MERR_NONE then exit;
  a:=loadInstruments(file_);
  load669:=a;
  if a<>MERR_NONE then exit;
  a:=loadPatterns(file_);
  load669:=a;
  if a<>MERR_NONE then exit;
  a:=loadSamples(file_);
  load669:=a;
  if (a<>MERR_NONE) and (a<>MERR_CORRUPT) then exit;
  joinTracks2Patterns(module);
  load669:=a;
end;

Function ampLoad669(name:String;options:longint):PModule;
Var f:file;
    l:longint;
    module:PModule;
    b:Integer;
begin
  loadOptions:=options;
  module:=malloc(sizeof(TModule));
  if module=nil then begin
    moduleError:=MERR_MEMORY;
    ampLoad669:=nil;
    exit;
  end;
  fillchar(module^,0,sizeof(module^));
  assign(f,name);
  reset(f,1);
  if IOresult<>0 then begin
    moduleError:=MERR_FILE;
    ampLoad669:=nil;
    exit;
  end;
  module^.modType:=MOD_NONE;
  seek(f,0);
  blockread(f,b,2);
  if b<>$6669 then begin
    moduleError:=MERR_TYPE;
    free(module);
    ampLoad669:=nil;
    exit;
  end;
  blockread(f,module^.name,32);
  module^.name[31]:=#0;
  moduleError:=load669(f,module);
  if moduleError=MERR_NONE then begin
    module^.modType:=MOD_669;
    module^.filesize:=filesize(f)
   end else begin
    ampFreeModule(module);
    free(module);
    module:=nil;
  end;
  close(f);
  ampLoad669:=module;
end;

end.
