Program sampleConstruct; { (C) 1993 Jussi Lahdenniemi }
                         { -------------------------- }

uses MCP,crt,SDI__SB,det_SB;

Const wfPulse           = 1;
      wfSaw             = 2;
      wfSinus           = 3;
      wfOctagon         = 4;

Type Psample            = ^Tsample;
     Tsample            = Record
       attack,
       decay,
       sustain,
       release          : Word;
       Waveform         : Byte;
     end;

Function wave(stage:real;wf:Byte):real;
begin
  case wf of
    wfPulse   : if stage<0.5 then wave:=-1 else wave:=1;
    wfSaw     : if stage<0.5 then wave:=-1+stage*4 else wave:=1-(stage-0.5)*4;
    wfSinus   : wave:=sin(2*pi*stage);
    wfOctagon : if stage<0.167 then wave:=-0.5-stage*3 else
                if stage<0.333 then wave:=-1 else
                if stage<0.500 then wave:=-1+(stage-0.333)*3 else
                if stage<0.667 then wave:=0.5+(stage-0.667)*3 else
                if stage<0.833 then wave:=1 else
                                    wave:=1-(stage-0.833)*3;
  end;
end;

Procedure makeSample(sample:Pointer;len:word;sRate:Word;sInfo:Tsample);
var w,w2:word;
    r,r2:real;
    vol:byte;
    wl,wl2:word;
    t:word;
begin
  vol:=0;
  wl:=round(sRate/523.3);
  t:=0;
  for w:=0 to len-1 do begin
    mem[seg(sample^):ofs(sample^)+w]:=
      128+round(vol*wave((w mod wl)/wl,sInfo.waveForm));
    inc(t);
    if t mod 100=0 then
    if t<sInfo.attack then inc(vol,byte(vol<127)) else
    if t<sInfo.attack+sInfo.decay then dec(vol,byte(vol>0)) else
    if t<sInfo.attack+sInfo.decay+sInfo.sustain then vol:=vol else
    if t<sInfo.attack+sInfo.decay+sInfo.release then dec(vol,byte(vol>0));
  end;
end;

var si:Tsample;
    sm:pointer;
    mi:TmcpStruct;
    buf,tab:pointer;
    sc:TsoundCard;
    sr:TsampleInfo;
    f:file;

begin
  if detectSB(@sc)<>0 then halt(1);
  mcpInitSoundDevice(SDI_SB,@sc);
  mi.samplingRate:=10000;
  mi.options:=0;
  getmem(buf,4096+16+MCP_tableSize);
  mi.bufferSeg:=seg(buf^)+ofs(buf^) div 8;
  mi.bufferSize:=4096;
  mi.reqSize:=1536;
  if mcpInit(mi)<>0 then begin writeln('mcp'); halt(2); end;
  si.attack:=4000;
  si.decay:=2000;
  si.sustain:=6000;
  si.release:=10000;
  si.waveform:=wfOctagon;
  getmem(sm,30000);
  writeln('Calculating..');
  makeSample(sm,30000,10000,si);
  writeln('Playing..');
  with sr do begin
    sample:=sm;
    length:=30000;
    loopstart:=0;
    loopend:=29999;
    rate:=10000;
    volume:=64;
  end;
  mcpOpenChannels(1,volume_Linear,nil);
  mcpStartVoice;
  mcpSetMasterVolume(64);
  mcpSetSample(0,@sr);
  mcpPlaySample(0,10000,64);
  repeat
    writeln(mcpGetBufferDelta);
    mcpCalcBuffer(mcpGetBufferDelta);
    delay(20);
  until keypressed;
  mcpClose;
  assign(f,'samp');
  rewrite(f,1);
  blockwrite(f,sm^,30000);
  close(f);
end.
