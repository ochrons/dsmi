Program TMP; { (C) 1992 Jussi Lahdenniemi }

Uses MCP,              { Multi Channel Player }
     AMP,              { Advanced Module Player }
     SDI__SB,          { Sound Device Interface for Sound Blaster (pro) }
     Det_SB,           { SB/SBPro detection routines }
     LoadM,            { The loader for the modules }
     DOS,Memory,CRT,   { Those normal units of TPascal }
     GetCPU;           { GetCPUtype function }


{$f+,i-,m 16384,0,655360}

var fil           : file;
    module        : Pmodule;
    Scard         : TSoundCard;
    i             : integer;
    pro           : boolean;
    mcps          : TMCPstruct;
    playBuf       : Pointer;
    r             : registers;

Procedure Break(s:String);         { Break if an error occurs }
Begin
  Writeln('* ERROR! * ',s);
  halt(1);
end;

begin
  writeln;
  writeln;
  writeln;
  writeln('  -----------------------  ---  --------------------------');
  writeln('  Temporary Module Player  TMP  (C) 1992 Jussi Lahdenniemi');
  writeln('  -----------------------  ---  --------------------------');
  writeln('  Version 1.00002á');
  writeln;
  writeln('  Using the AMP routines from Otto Chrons');
  writeln('  Converted to Pascal by Jussi Lahdenniemi');
  writeln;
  writeln;
  if paramcount=0 then begin
    Writeln('Please specify the module name on the command line!');
    halt(1);
  end;
  assign(fil,paramstr(1));
  reset(fil,1);
  if IOresult<>0 then Break('File not found!');
  close(fil);
  module:=ampLoadModule(paramstr(1),LM_IML);
  if module=nil then Break('Error loading the module!');
  if tsInit<>0 then Break('Error initializing the player!');    { Initialize}
  pro:=false;                                                   { the player}
  if detectSBpro(@Scard)=0 then pro:=true else
  if detectSB(@Scard)<>0 then Break('No SB found!');         {  ...      }
  if pro then i:=mcpInitSoundDevice(SDI_SBPro,@Scard) else
              i:=mcpInitSoundDevice(SDI_SB,@Scard);
  If i<>0 then Break('Error initializing the SB!');
  getmem(playBuf,4096+16+MCP_TableSize+MCP_QualitySize);
  with mcps do begin
    samplingRate:=20000;
    Options:=mcp_Quality;
    bufferSeg:=seg(playBuf^)+ofs(playBuf^) div 8;
{$IFNDEF DPMI}
    bufferLinear:=longint(bufferSeg)*16;
{$ELSE}
    r.ax:=6;
    r.bx:=bufferSeg;
    intr($31,r);
    bufferLinear:=longint(r.cx)*65536+longint(r.dx);
{$ENDIF}
    bufferSize:=4096;
    reqSize:=1536;
  end;
  i:=mcpInit(mcps);
  i:=i or ampInit(0);
  i:=i or mcpOpenChannels(4,1,nil);
  i:=i or mcpStartVoice;
  i:=i or ampPlayModule(module^,PM_Loop);                       { And PLAY! }
  if i<>0 then Break('Error initializing the player!');
  Writeln('Playing the file ',paramstr(1));
  tsAddRoutine(@ampInterrupt,ampTimer);
  swapvectors;
  exec(getenv('COMSPEC'),'');
  swapvectors;
  repeat
  until keypressed;
  while keypressed do readkey;
  if DosError<>0 then Writeln('Error shelling to DOS! (Maybe not enough memory..)');
  ampClose;                                   { Deinitialization }
  mcpClose;
  tsClose;
  writeln;
  writeln;
  writeln;
  Writeln(' THE PASCAL-LANGUAGE ROUTINES USED IN THIS PLAYER ARE CONVERTED BY ME');
  writeln(' FROM THE C-LANGUAGE ONES. THEY ARE AT THE MOMENT ONLY ON THE BETA-TESTING');
  writeln(' STAGE! THEY ARE NOT YET READY!');
  Writeln;
end.
