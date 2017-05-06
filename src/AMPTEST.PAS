Uses MCP,AMP,SDI__SB,SDI__DAC,Loaders,MODload,STMload,AMFload,Crt; {$f+}

var f:file;
    md:Pmodule;
    Scard:TSoundCard;

begin
  clrscr;
  assign(f,'c:\sb\st\song\chip3.mod');
  reset(f,1);
  new(md);
  fillchar(md^,sizeof(TModule),0);
  loadOptions:=LM_IML;
  md^.type_:=3;
  md^.channelcount:=4;
  md^.channelorder[0]:=$0;
  md^.channelorder[1]:=$1;
  md^.channelorder[2]:=$2;
  md^.channelorder[3]:=$3;
  writeln(loadMOD(f,md));
  close(f);
  writeln(md^.size);
  writeln(tsInit);
  if mcpDetectSB(@Scard)<>0 then halt(1);
  writeln(mcpInitSoundDevice(SDI_DAC,@Scard));
  writeln(mcpInit(20000,0,1536));
  writeln(ampInit(amp_Interrupt));
  writeln(mcpOpenChannels(4));
  writeln(mcpStartVoice);
  writeln(ampPlayModule(md^,0));
  repeat
{    if mcpGetBufferDelta>20000/50 then begin
      ampPlayRow;
      mcpCalcBuffer(20000 div 50);
    end;}
  Until keypressed;
  ampClose;
  writeln(mcpClose);
  tsClose;
end.
