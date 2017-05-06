(***************************************************************************

                                 MODLOAD.PAS
                                 -----------

                          (C) 1993 Jussi Lahdenniemi

loadMOD and ampLoadMOD functions
Original C version by Otto Chrons

***************************************************************************)

Unit MODLoad; {$I-}

Interface
Uses MCP,AMP,Loaders,CSupport;

Function LoadMOD(Var File_:File;Var Module:PModule):Integer;

Implementation

Const order8            : array[0..7] of byte =
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

Function loadHeader:Integer;
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
  if module^.patterns:=nil then begin
    loadHeader:=MERR_MEMORY;
    exit;
  end;
  inc(module^.size,count*sizeof(TPattern));
  for t:=0 to count-1 do begin
    patUsed[hdr.orders[t]]:=1;
    pat:=@(module^.patterns^[t]);
    pat^.length:=64;
    for i:=0 to 7 do pat^.track[i]:=
      pointer(byte(hdr.orders[t]<>$ff)*(hdr.orders[t]*8+1+i));
  end;
  loadHeader:=MERR_NONE;
end;

type TIns669 = Record
       name                     : array[0..12] of char;
       length,loopstart,loopend : longint;
     end;

Function loadInstruments(Var f:File;Var Module:PModule):Integer;
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
      strcpy(instr^.filename,MODi.name);
      instr^.filename[12]:=#0;
      instr^.sample:=nil;
      instr^.rate:=856*Basic_Freq div instrRates[MODi.finetune and $F];
      instr^.volume:=MODi.volume;
      if instr^.volume>64 then instr^.volume:=64;
      instr^.size:=swapb(MODi.length)*2;
      instr^.loopstart:=swapb(MODi.loopstart)*2;
      b:=swapb(MODi.looplength)*2;
      if b<3 then b:=0 else b:=b+instr^.loopstart;
      instr^.loopend:=b;
      if (instr^.loopend>instr^.size) and (instr^.loopend<>0) then
         instr^.loopend:=instr^.size;
      if instr^.loopstart>instr^.loopend then instr^.loopend:=0;
      if instr^.loopend=0 then instr^.loopstart:=0;
      inc(t);
    end;
  end;
  if a<>1 then loadInstruments:=MERR_FILE else loadInstruments:=MERR_NONE;
end;

Function loadPatterns(Var f:file; module:PModule):Integer;
Var orders       : Array[0..127] of byte;
    ptr          : pointer;
    a,t,i        : Integer;
    pat          : PPattern;
    count        : Integer;
    lastPattern  : Integer;

Begin
  count:=0;
  lastPattern:=0;
  Fillchar(patUsed,255,0);
  Seek(f,20+module^.instrumentCount*30);
  Blockread(f,count,1);
  Blockread(f,orders,1);
  Blockread(f,orders,128);
  for t:=0 to 127 do if lastPattern<orders[t] then lastPattern:=orders[t];
  inc(lastPattern);
  module^.patternCount:=count;
  module^.trackCount:=lastPattern*module^.channelCount;
  module^.patterns:=calloc(count,sizeof(TPattern));
  loadPatterns:=MERR_MEMORY;
  if module^.patterns=nil then exit;
  inc(module^.size,count*sizeof(TPattern));
  if count>0 then
  for t:=0 to count-1 do begin
    patUsed[orders[t]]:=1;
    pat:=@module^.patterns^[t];
    pat^.length:=64;
    for i:=0 to module^.channelCount-1 do
      pat^.tracks[module^.channelPanning[i]]:=pointer(orders[t]*module^.channelCount+1+i);
  end;
  loadPatterns:=MERR_NONE;
end;

Function MOD2AMF(buffer:pointer;trk:Integer; module:PModule):PTrack;
Type b = Array[0..65519] of byte;
Var tracks            : PTrack;
    i,t,pos,tick,
    a,rowAdd         : Integer;
    note,noNote,oldNote,
    ins,volume,
    command,data,
    curins,curvolume : Byte;
    nvalue           : Word;
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
  ins:=0;
  oldNote:=0;
  curins:=$F0;
  inc(longint(buffer),trk*4);
  Fillchar(temptrack,576,$FF);
  rowAdd:=4*module^.channelCount;
  for t:=0 to 63 do begin
    tick:=t;
    note:=$FF;
    noNote:=0;
    nvalue:=(b(buffer^)[t*rowAdd] and $F)*256+b(buffer^)[t*rowAdd+1];
    if nvalue<>0 then for i:=0 to 60 do
      if (nvalue>=modNotes[i]) then begin
        note:=i+36;
        i:=60;
      end;
    command:=(b(buffer^)[t*rowAdd+2] and $f);
    data:=b(buffer^)[t*rowAdd+3];
    volume:=255;
    if command=$C then begin
      volume:=data;
      if volume>64 then volume:=64;
    end;
    ins:=(b(buffer^)[t*rowAdd+2] shr 4) or (b(buffer^)[t*rowAdd] and $10);
    if ins<>0 then begin
      dec(ins);
      if ins<>curIns then begin
        insertCmd(cmdInstr,ins);
        module^.instruments^[ins].insType:=1;
      end else
        if (note=$ff) and (volume>64) then
          insertCmd(cmdVolumeAbs,module^.instruments^[ins].volume);
      curIns:=ins;
      inc(ins);
    end;
    if (command=$e) and (data shr 4=$d) and (data and $f<>0) and (note<>$ff) then begin
      insertCmd(cmdNoteDelay,data and $f);
      command:=$ff;
    end;
    if command=3 then begin
      insertCmd(cmdBenderTo,data);
      command:=$ff;
    end;
    if note<>$FF then begin
      dec(ins);
      if (ins<>$ff) and (command<>$c) then
        volume:=module^.instruments^[ins].volume;
      insertNote(note,volume);
    end else if volume<65 then insertCmd(cmdVolumeAbs,volume);
    case command of
      $f : if (data>0) and (data<32) then insertCmd(cmdTempo,data)
             else insertCmd(cmdExtTempo,data);
      $b : insertCmd(cmdGoto,data);
      $d : insertCmd(cmdBreak,0);
      $a : begin
             if (data>=16) then data:=data div 16 else data:=-data;
             insertCmd(cmdVolume,data);
           end;
      $2 : begin
             if (data>127) then data:=127;
             insertCmd(cmdBender,data);
           end;
      $1 : begin
             if (data>127) then data:=127;
             insertCmd(cmdBender,-data);
           end;
      $4 : insertCmd(cmdVibrato,data);
      $5 : begin
             if data>=16 then data:=data div 16 else data:=-data;
             insertCmd(cmdToneVol,data);
           end;
      $6 : begin
             if data>=16 then data:=data div 16 else data:=-data;
             insertCmd(cmdVibrVol,data);
           end;
      $7 : insertCmd(cmdTremolo,data);
      $0 : if data<>0 then insertCmd(cmdArpeggio,data);
      $9 : insertCmd(cmdOffset,data);
      $e : begin
             i:=data shr 4;
             data:= data and $f;
             case i of
               9 : insertCmd(cmdRetrig,data);
               1 : insertCmd(cmdFinetune,-data);
               2 : insertCmd(cmdFinetune,data);
              $a : insertCmd(cmdFinevol,data);
              $b : insertCmd(cmdFinevol,-data);
              $c : insertCmd(cmdNoteCut,data);
             end;
           end;
    end;
  end;
  if pos=0 then tracks:=nil else begin
    inc(pos);
    if (loadOptions and LM_IML)>0 then
      if curTrack>1 then
      for i:=1 to curTrack-1 do
        if module^.tracks^[i]<>nil then
        if (module^.tracks^[i]^.size=pos) and
           (memcmp(@temptrack,pointer(longint(module^.tracks^[i])+3),pos*3)=0) then begin
             MOD2AMF:=module^.tracks^[i];
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
  MOD2AMF:=tracks;
end;

Function loadTracks(Var f:file;var module:PModule):Integer;
Var Count    : Byte;
    t,i,a,c  : Integer;
    Buffer   : Array[0..2047] of byte;

Begin
  a:=module^.channelCount;
  count:=module^.trackCount div a;
  module^.tracks:=calloc(count*a+4,sizeof(PTrack));
  if module^.tracks=nil then begin loadTracks:=MERR_MEMORY; exit end;
  inc(module^.size,(count*a+4)*sizeof(PTrack));
  seek(f,20+30*module^.instrumentCount+128+2+byte(module^.instrumentCount<>15)*4);
  module^.tracks^[0]:=nil;
  curTrack:=1;
  if count>0 then
  for t:=0 to count-1 do begin
    if ((loadOptions and LM_IML)>0) and (patUsed[t]=0) then begin
      for i:=0 to module^.channelCount-1 do begin
        module^.tracks^[curTrack]:=nil; inc(curTrack) end;
      seek(f,filepos(f)+256*module^.channelCount);
    end else
      if (module^.modType=MOD_MOD) or (module^.modType=MOD_15) then begin
        c:=module^.channelCount;
        blockread(f,buffer,256*c,a);
        if a=256*c then
          for i:=0 to c-1 do begin
            module^.tracks^[curTrack]:=MOD2AMF(@buffer,i,module);
            inc(curTrack);
          end else begin
            loadTracks:=MERR_FILE;
            exit;
          end;
      end else if (module^.channelCount=8) and (module^.modType=MOD_TREK) then begin
        Blockread(f,buffer,1024);
        if IOresult=0 then begin
          module^.tracks^[curTrack]:=MOD2AMF(@buffer,0,module); inc(curTrack);
          module^.tracks^[curTrack]:=MOD2AMF(@buffer,1,module); inc(curTrack);
          module^.tracks^[curTrack]:=MOD2AMF(@buffer,2,module); inc(curTrack);
          module^.tracks^[curTrack]:=MOD2AMF(@buffer,3,module); inc(curTrack);
        end else begin
          loadTracks:=MERR_FILE;
          exit;
        end;
        Blockread(f,buffer,1024);
        if IOresult=0 then begin
          module^.tracks^[curTrack]:=MOD2AMF(@buffer,0,module); inc(curTrack);
          module^.tracks^[curTrack]:=MOD2AMF(@buffer,1,module); inc(curTrack);
          module^.tracks^[curTrack]:=MOD2AMF(@buffer,2,module); inc(curTrack);
          module^.tracks^[curTrack]:=MOD2AMF(@buffer,3,module); inc(curTrack);
        end else begin
          loadTracks:=MERR_FILE;
          exit;
        end;
      end;
  end;
  loadTracks:=MERR_NONE;
end;

Function loadSamples(var f:file; var module:PModule):integer;
Var t,i,a,b,l     : Word;
    c             : Longint;
    instr         : PInstrument;
    temp          : Array[0..31] of byte;
Begin
  seek(f,20+30*module^.instrumentCount+128+2+4*byte(module^.instrumentCount<>15)+longint(module^.trackCount)*256);
  for t:=0 to module^.instrumentCount-1 do begin
    instr:=@module^.instruments^[t];
    if ((loadOptions and LM_IML)>0) and (instr^.insType=0) then begin
      seek(f,filepos(f)+instr^.size);
      instr^.size:=0;
    end;
    if instr^.size>0 then begin
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
      end else begin
        if instr^.size>65510 then a:=65510 else a:=instr^.size;
        instr^.sample:=malloc(a);
        loadSamples:=MERR_MEMORY;
        if instr^.sample=nil then exit;
        inc(module^.size,a);
        loadSamples:=MERR_CORRUPT;
        blockread(f,instr^.sample^,a);
        if IOresult<>0 then exit;
        if a<instr^.size then begin
          blockread(f,temp,instr^.size-a);
          instr^.size:=a;
        end;
      end;
      mcpConvertSample(instr^.sample,instr^.size);
      if (loadOptions and LM_IML)>0 then begin
        a:=instr^.size;
        if t>0 then
        for i:=0 to t-1 do
          if (module^.instruments^[i].size=a) and
             (memcmp(instr^.sample,module^.instruments^[i].sample,instr^.size)=0) then begin
               free(instr^.sample);
               dec(module^.size,instr^.size);
               instr^.sample:=module^.instruments^[i].sample;
               i:=t-1;
             end;
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

Function loadMOD;
var a:integer;
Begin
  module^.tempo:=125;
  module^.speed:=6;
  a:=loadInstruments(file_,module);
  loadMOD:=a;
  if a<>MERR_NONE then exit;
  a:=loadPatterns(file_,module);
  loadMOD:=a;
  if a<>MERR_NONE then exit;
  a:=loadTracks(file_,module);
  loadMOD:=a;
  if a<>MERR_NONE then exit;
  a:=loadSamples(file_,module);
  loadMOD:=a;
  if (a<>MERR_NONE) and (a<>MERR_CORRUPT) then exit;
  joinTracks2Patterns(module);
  if module^.modType=MOD_15 then module^.modType:=MOD_MOD;
end;

Function ampLoadMOD(name:String;options:Integer):PModule;
Var f:file;
    l:longint;
    module:PModule;
    b:Integer;
begin
  loadOptions:=options;
  module:=malloc(sizeof(TModule));
  if module=nil then begin
    moduleError:=MERR_MEMORY;
    ampLoadMOD:=nil;
    exit;
  end;
  fillchar(module^,0,sizeof(module^));
  assign(f,name);
  reset(f,1);
  if IOresult<>0 then begin
    moduleError:=MERR_FILE;
    ampLoadMOD:=nil;
    exit;
  end;
  module^.modType:=MOD_NONE;
  seek(f,1080);
  blockread(f,l,4);
  if (l=$2E4B2E4D) or (l=$34544C46) then begin
    module^.modType:=MOD_MOD;
    seek(f,0);
    blockread(f,module^.name,20);
    module^.name[20]:=#0;
    module^.channelCount:=4;
    move(order4,module^.channelPanning,4);
  end else if l=$38544C46 then begin
    module^.modType:=MOD_TREK;
    seek(f,0);
    blockread(f,module^.name,20);
    module^.name[20]:=#0;
    module^.channelCount:=8;
    move(order8,module^.channelPanning,8);
  end else if l=$4e484336 then begin
    module^.modType:=MOD_MOD;
    seek(f,0);
    blockread(f,module^.name,20);
    module^.name[20]:=#0;
    module^.channelCount:=6;
    move(order6,module^.channelPanning,6);
  end else if l=$4e484338 then begin
    module^.modType:=MOD_MOD;
    seek(f,0);
    blockread(f,module^.name,20);
    module^.name[20]:=#0;
    module^.channelCount:=8;
    move(order8,module^.channelPanning,8);
  end else begin
    module^.modType:=MOD_15;
    seek(f,0);
    blockread(f,module^.name,20);
    module^.name[20]:=#0;
    module^.channelCount:=4;
    move(order4,module^.channelPanning,4);
  end;
  if module^.modType=MOD_NONE then begin
    moduleError:=MERR_TYPE;
    ampLoadMOD:=nil;
    exit;
  end;
  b:=loadMOD(f,module);
  moduleError:=b;
  if b=MERR_NONE then module^.filesize:=filesize(f) else begin
    ampFreeModule(module);
    free(module);
    module:=nil;
  end;
  close(f);
  ampLoadMOD:=module;
end;

end.
