Uses MCP,SDI__SB,crt;

Var Scard:TSoundCard;
    Sampleni:TSampleInfo;
    f:file;

Begin
  if mcpDetectSB(@Scard)<>0 then halt(1);
  writeln(mcpInitSoundDevice(SDI_SB,@Scard));
  writeln(mcpInit(20000,0,1536));
  writeln(mcpOpenChannels(2));
  writeln(mcpStartVoice);
  With Sampleni do begin
    assign(f,'c:\sb\st\stins99\divjay');
    reset(f,1);
    getmem(Sample,filesize(f));
    blockread(f,Sample^,filesize(f));
    close(f);
    Length:=8000;
    Loopstart:=0;
    Loopend:=7999;
    Rate:=10000;
    Volume:=64;
  end;
  writeln(mcpPutSample(0,@Sampleni));
  writeln(mcpPutSample(1,@Sampleni));
  writeln(mcpSetRate(1,16000));
  writeln(mcpPutSample(0,@Sampleni));
  repeat
    mcpCalcBuffer(mcpGetBufferDelta);
    Delay(20);
  until keypressed;
  writeln(mcpClose);
end.
