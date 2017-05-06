(***************************************************************************

                                 STMLOAD.PAS
                                 -----------

                          (C) 1993 Jussi Lahdenniemi

loadSTM and ampLoadSTM functions
Original C version by Otto Chrons

***************************************************************************)

Unit STMLoad; {$I-,X+}

Interface
Uses MCP,AMP,Loaders,CSupport;

Function LoadSTM(Var File_:File;Var Module:PModule):Integer;
Function ampLoadSTM(name:String;options:longint):PModule;

Implementation
{$IFDEF USE_EMS}
uses emhm;
{$ENDIF}

Var curTrack            : Integer;
    patUsed             : Array[0..254] of byte;

Type TSTMinst           = Record
                            Name        : Array[0..12] of char;
                            Disk        : Byte;
                            Position    : Word;
                            Length      : Word;
                            Loopstart   : Word;
                            Loopend     : Word;
                            Volume      : Byte;
                            __a         : Byte;
                            Rate        : Word;
                            __b         : Longint;
                            __c         : Word;
                          End;

Function loadinstruments(Var f:File;Var Module:PModule):Integer;
Var t,a          : Integer;
    STMi         : TSTMinst;
    instr        : Pinstrument;

Begin
  With Module^ do begin
    instrumentCount:=31;
    instruments:=calloc(31,sizeof(Tinstrument));
    If instruments=Nil then begin loadinstruments:=-1; exit end;
    Size:=Size+31*sizeof(Tinstrument);
    Seek(f,48);
    a:=0;
    t:=0;
    while (a<>-1) and (t<31) do begin
      Blockread(f,STMi,sizeof(TSTMinst),a);
      if a<>sizeOf(TSTMinst) then a:=-1;
      instr:=@instruments^[t];
      instr^.insType:=0;
      strcpy(instr^.name,STMi.name);
      strcpy(instr^.filename,STMi.name);
      instr^.sample:=nil;
      word(instr^.sample):=STMi.position;
      instr^.rate:=STMi.rate;
      instr^.volume:=STMi.volume;
      instr^.size:=STMi.length;
      instr^.loopstart:=STMi.loopstart;
      instr^.loopend:=STMi.loopend;
      if instr^.loopend=65535 then instr^.loopend:=0;
      if (instr^.loopend<>0) and (instr^.loopend<instr^.size) then instr^.size:=instr^.loopend;
      if (instr^.loopend>instr^.size) and (instr^.loopend<>0) then
         instr^.loopend:=instr^.size;
      if instr^.loopstart>instr^.loopend then instr^.loopend:=0;
      if instr^.loopend=0 then instr^.loopstart:=0;
      inc(t);
    end;
  end;
  if a=-1 then loadinstruments:=-2 else loadinstruments:=0;
end;

Function loadPatterns(Var f:file; module:PModule):Integer;
Var orders       : Array[0..127] of byte;
    ptr          : pointer;
    t,count      : integer;
    pat          : PPattern;
Begin
  Fillchar(patUsed,255,0);
  Seek(f,48+31*32);
  Blockread(f,orders,128);
  loadPatterns:=-2;
  if IOresult<>0 then exit;
  count:=0;
  while (count<128) and (orders[count]<>99) do inc(count);
  module^.patternCount:=count;
  module^.patterns:=calloc(count,sizeof(TPattern));
  loadPatterns:=-1;
  if module^.patterns=nil then exit;
  inc(module^.size,count*sizeof(TPattern));
  for t:=0 to count-1 do begin
    patUsed[orders[t]]:=1;
    pat:=@module^.patterns^[t];
    pat^.length:=64;
    pat^.tracks[0]:=pointer(orders[t]*4+1);
    pat^.tracks[1]:=pointer(orders[t]*4+2);
    pat^.tracks[2]:=pointer(orders[t]*4+3);
    pat^.tracks[3]:=pointer(orders[t]*4+4);
  end;
  loadPatterns:=0;
end;

Function STM2AMF(buffer:pointer;trk:Integer; module:PModule):PTrack;
Type b = Array[0..65519] of byte;
Var tracks            : PTrack;
    i,t,pos,tick,a   : Integer;
    note,ins,volume,
    command,data,
    curins,curvolume : Byte;
    Temptrack        : Array[0..575] of byte;

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
  pos:=0;
  tick:=0;
  curins:=$F0;
  curvolume:=64;
  inc(longint(buffer),trk*4);
  Fillchar(temptrack,575,$FF);
  for t:=0 to 63 do begin
    tick:=t;
    note:=b(buffer^)[t*16];
    command:=(b(buffer^)[t*16+2] and $f)+64;
    if command=ord('G') then begin
      insertCmd(cmdBenderTo,b(buffer^)[t*16+3]);
      command:=0;
    end;
    if command=ord('K') then insertCmd(cmdBenderTo,0);
    volume:=(b(buffer^)[t*16+1] and 7)+(b(buffer^)[t*16+2] and $F0) div 2;
    if volume>65 then volume:=65;
    if note<>$FF then begin
      ins:=(b(buffer^)[t*16+1] shr 3)-1;
      if (ins<>curins) and (ins<>$FF) then begin
        insertCmd(cmdInstr,ins);
        module^.instruments^[ins].insType:=1;
        curins:=ins;
      end;
      if (ins<>$FF) and (volume=65) then volume:=module^.instruments^[ins].volume;
      if (volume=65) then volume:=255;
      note:=36+(note and $F)+(note shr 4)*12;
      insertNote(note,volume);
    end else if volume<65 then
      InsertCmd(cmdVolumeAbs,volume);
    if command<>64 then begin
      data:=b(buffer^)[t*16+3];
      case chr(command) of
        'A' : insertCmd(cmdTempo,data shr 4);
        'B' : insertCmd(cmdGoto,data);
        'C' : insertCmd(cmdBreak,0);
        'D' : begin
                if (data>=16) then data:=data shr 4 else data:=-data;
                insertCmd(cmdVolume,data);
              end;
        'E' : begin
                if (data>127) then data:=127;
                insertCmd(cmdBender,data);
              end;
        'F' : begin
                if (data>127) then data:=127;
                insertCmd(cmdBender,-data);
              end;
        'H' : insertCmd(cmdVibrato,data);
        'I' : insertCmd(cmdTremolo,data);
        'J' : insertCmd(cmdArpeggio,data);
        'K' : begin
                if data>=16 then data:=data shr 4 else data:=-data;
                insertCmd(cmdToneVol,data);
              end;
        'L' : begin
                if data>=16 then data:=data shr 4 else data:=-data;
                insertCmd(cmdVibrVol,data);
              end;
        'O' : insertCmd(cmdSync,data);
      end;
    end;
  end;
  if pos=0 then tracks:=nil else begin
    inc(pos);
    if (loadOptions and LM_IML)>0 then
      for i:=1 to curTrack-1 do
        if module^.tracks^[i]<>nil then
        if (module^.tracks^[i]^.size=pos) and
           (memcmp(@temptrack,pointer(longint(module^.tracks^[i])+3),pos*3)=0) then begin
             STM2AMF:=module^.tracks^[i];
             exit;
           end;
    tracks:=PTrack(malloc(pos*3+3));
    if tracks<>nil then begin
      inc(module^.size,pos*3+3);
      tracks^.size:=pos;
      tracks^.trkType:=0;
      move(temptrack,pointer(longint(tracks)+3)^,pos*3);
    end;
  end;
  STM2AMF:=tracks;
end;

Function loadTracks(Var f:file;var module:PModule):Integer;
Var Count    : Byte;
    t,a      : Integer;
    Buffer   : Array[0..1023] of byte;

Begin
  seek(f,33);
  Blockread(f,count,1);
  module^.trackCount:=count*4;
  module^.tracks:=calloc(count*4+4,sizeof(PTrack));
  if module^.tracks=nil then begin loadTracks:=-1; exit end;
  inc(module^.size,(count*4+4)*sizeof(PTrack));
  seek(f,48+32*31+128);
  module^.tracks^[0]:=nil;
  curTrack:=1;
  for t:=0 to count-1 do begin
    if ((loadOptions and LM_IML)>0) and (patUsed[t]=0) then begin
      module^.tracks^[curTrack]:=nil; inc(curTrack);
      module^.tracks^[curTrack]:=nil; inc(curTrack);
      module^.tracks^[curTrack]:=nil; inc(curTrack);
      module^.tracks^[curTrack]:=nil; inc(curTrack);
      seek(f,filepos(f)+1024);
    end else begin
      Blockread(f,buffer,1024);
      if IOresult=0 then begin
        module^.tracks^[curTrack]:=STM2AMF(@buffer,0,module); inc(curTrack);
        module^.tracks^[curTrack]:=STM2AMF(@buffer,1,module); inc(curTrack);
        module^.tracks^[curTrack]:=STM2AMF(@buffer,3,module); inc(curTrack);
        module^.tracks^[curTrack]:=STM2AMF(@buffer,2,module); inc(curTrack);
      end else begin
        loadTracks:=-2;
        exit;
      end;
    end;
  end;
  loadTracks:=0;
end;

Function loadSamples(var f:file; var module:PModule):integer;
Var t,i,a,b       : Word;
    instr         : Pinstrument;
    c             : byte;
{$IFDEF USE_EMS}
    handle        : TEMSH;
{$ENDIF}
Begin
  for t:=0 to module^.instrumentCount-1 do begin
    instr:=@module^.instruments^[t];
    if ((loadOptions and LM_IML)>0) and (instr^.insType=0) then instr^.size:=0;
    if instr^.size>0 then begin
      seek(f,longint(word(instr^.sample))*16);
      a:=instr^.loopend-instr^.loopstart;
      if (instr^.loopend<>0) and (a<crit_size) then begin
        b:=(Crit_Size div a)*a;
        instr^.loopend:=instr^.loopstart+b;
        loadSamples:=-1;
        instr^.sample:=malloc(instr^.loopend+16);
        if instr^.sample=nil then exit;
        inc(module^.size,instr^.loopend);
        loadSamples:=-2;
        blockread(f,instr^.sample^,instr^.size);
        if IOresult<>0 then exit;
        instr^.size:=instr^.loopend;
        for i:=1 to (Crit_Size div a)-1 do
          move(pointer(longint(instr^.sample)+instr^.loopstart)^,
               pointer(longint(instr^.sample)+instr^.loopstart+a*i)^,a);
        mcpConvertSample(instr^.sample,instr^.size);
      end else begin
        instr^.sample:=malloc(instr^.size+16);
        loadSamples:=-1;
        if instr^.sample=nil then exit;
        inc(module^.size,instr^.size);
        loadSamples:=-2;
        blockread(f,instr^.sample^,instr^.size);
        if IOresult<>0 then exit;
      end;
      mcpConvertSample(instr^.sample,instr^.size);
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
    end else begin
      instr^.size:=0;
      instr^.sample:=nil;
    end;
  end;
  loadSamples:=0;
end;

Procedure joinTracks2Patterns(var module:PModule);
Var t,i     : Word;
    pat     : PPattern;
Begin
  for t:=0 to module^.patternCount-1 do begin
    pat:=@module^.patterns^[t];
    for i:=0 to 3 do
      if word(pat^.tracks[i])<=module^.trackCount then
        pat^.tracks[i]:=module^.tracks^[word(pat^.tracks[i])] else
        pat^.tracks[i]:=nil;
  end;
end;

Function loadSTM;
var a:integer;
Begin
  module^.tempo:=125;
  module^.speed:=6;
  a:=loadinstruments(file_,module);
  loadSTM:=a;
  if a<>0 then exit;
  a:=loadPatterns(file_,module);
  loadSTM:=a;
  if a<>0 then exit;
  a:=loadTracks(file_,module);
  loadSTM:=a;
  if a<>0 then exit;
  a:=loadSamples(file_,module);
  loadSTM:=a;
  if a<>0 then exit;
  joinTracks2Patterns(module);
  loadSTM:=0;
end;

Function ampLoadSTM(name:String;options:longint):PModule;
var f         : file;
    l         : longint;
    module    : PModule;
    t,b       : integer;

begin
  ampLoadSTM:=nil;
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
  seek(f,28);
  blockread(f,t,2);
  if t=$21A then begin
    module^.modType:=MOD_STM;
    seek(f,0);
    blockread(f,module^.name,20);
    module^.name[20]:=#0;
    module^.channelCount:=4;
  end else begin
    module^.modType:=MOD_NONE;
    moduleError:=MERR_Type;
    exit;
  end;
  b:=loadSTM(f,module);
  moduleError:=b;
  if b=MERR_None then module^.filesize:=filesize(f) else begin
    ampFreeModule(module);
    free(module);
    module:=nil;
  end;
  close(f);
  ampLoadSTM:=module;
end;

end.
