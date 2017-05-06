{$X+}
Program testDAC; { An example program for the SDI_DAC }

{$I dsmi.inc} ,crt;

var c:char;
    s:string;
    mcpstrc:TMcpStruct;
    temp:pointer;
    module:PModule;
    scard:TSoundCard;

begin
  clrscr;
  writeln('Example program by Jussi Lahdenniemi');
  writeln;
  writeln('Specify the sound device :');
  writeln;
  writeln(' 1. DAC in LPT1 (0378h)');
  writeln(' 2. DAC in LPT2 (0278h)');
  writeln(' 3. PC speaker');
  writeln(' 0. No playing, PLEASE!');
  writeln;
  write('Make Your Choice : ');
  repeat
    c:=readkey;
  until c in ['0'..'3'];
  writeln(c);
  if c='0' then halt(0);
  writeln;
  write('Which song would you like to play : ');
  readln(s);
  writeln;
  writeln('Loading..');
  module:=ampLoadModule(s,0);
  if module=nil then begin
    writeln(' ** Load failure!');
    halt(1);
  end;
  writeln('Initializing..');
  tsInit;
  atexit(@tsClose);
  case c of
    '1' : scard.ioport:=$378;
    '2' : scard.ioport:=$278;
    '3' : scard.ioport:=$42;
  end;
  scard.samplesize:=1;
  scard.stereo:=false;
  if mcpInitSoundDevice(sdi_dac,@scard)<>0 then begin
    writeln(' ** Initialisation failure!');
    halt(1);
  end;
  mcpstrc.options:=0;
  temp:=malloc(4096*2+MCP_Tablesize+16);
  with mcpstrc do begin
    bufferSeg:=seg(temp^)+1;
    bufferLinear:=longint(bufferSeg)*16;
    bufferSize:=8192;
    reqSize:=4096;
    samplingRate:=21000;
  end;
  if mcpInit(@mcpstrc)<>0 then begin
    writeln(' ** Initialisation failure!');
    halt(1);
  end;
  atexit(@mcpClose);
  cdiInit;
  cdiRegister(@CDI_MCP,0,31);
  if ampInit(0)<>0 then begin
    writeln(' ** Initialisation failure!');
    halt(1);
  end;
  atexit(@ampClose);
  tsAddRoutine(@ampInterrupt,AMP_Timer);
  setDACTimer(tsGetTimerRate);
  mcpStartVoice;
  cdiSetupChannels(0,module^.channelCount,nil);
  writeln('Playing... Press any key to quit');
  ampPlayModule(module,PM_Loop);
  while not keypressed do writeln(port[$379]);
  readkey;
  ampStopModule;
end.
