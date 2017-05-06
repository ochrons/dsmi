(****************************************************************************

                                 EXAMPLE3.PAS
                                 ------------

                          (C) 1993 Jussi Lahdenniemi

Example program #3 for DSMI tutorial

****************************************************************************)

{$I dsmi.inc} ,crt;

Function initDSMI(rate,buffer,options:Word):Integer;
var a       : Integer;
    s       : Word;
    sdi     : TSDI_Init;
    scard   : TSoundcard;
    temp    : Pointer;
    mcpstrc : TMCPStruct;

begin
{  a:=detectPAS(@scard);
  if a<>0 then a:=detectSB16(@scard);
  if a<>0 then a:=detectAria(@scard);
  if a<>0 then a:=detectSBPro(@scard);
  if a<>0 then a:=detectSB(@scard);
  if a=0 then
    case scard.ID of
      ID_SB    : sdi:=SDI_SB;
      ID_SBPro : sdi:=SDI_SBpro;
      ID_SB16  : begin
                   sdi:=SDI_SB16;
                   if options and MCP_Mono>0 then scard.stereo:=false;
                 end;
      ID_ARIA  : sdi:=SDI_ARIA;
      ID_PAS,
      ID_PASplus,
      ID_PAS16 : begin
                   sdi:=SDI_PAS;
                   if options and MCP_Mono>0 then scard.stereo:=false;
                 end;
    else begin
      initDSMI:=Invalid_SDI;
      exit;
    end
    end
  else begin
    initDSMI:=No_Soundcard;
    exit;
  end;}
  tsInit;
  scard.ioport:=$42;
  scard.samplesize:=1;
  scard.stereo:=false;
  if mcpInitSoundDevice(sdi_dac,@scard)<>0 then begin
    initDSMI:=Invalid_SDI;
    exit;
  end;
  mcpstrc.options:=0;
  s:=buffer*2+MCP_Tablesize+16;
  if options and MCP_Quality>0 then begin
    mcpstrc.options:=mcpstrc.options or MCP_Quality;
    inc(s,MCP_Qualitysize);
  end;
  (*
  {$IFDEF DPMI}
  temp:=ptr(1,1);
  dpmiAllocDOS(s div 16,word(a),mcpstrc.bufferSeg);
  {$ELSE}
  temp:=malloc(s);
  {$ENDIF}
  if temp=nil then begin
    initDSMI:=No_Memory;
    exit;
  end;
  with mcpstrc do begin
{    bufferSeg:=seg(temp^)+ofs(temp^) div 16+1;}
    {$IFDEF DPMI}
    bufferLinear:=dpmiGetLinearAddr(bufferSeg);
    {$ELSE}
    bufferSeg:=seg(temp^)+ofs(temp^) div 16+1;
    bufferLinear:=longint(bufferSeg)*16;
    {$ENDIF}
    bufferSize:=buffer*2;
    reqSize:=buffer;
    samplingRate:=rate;
  end;
  *)
  temp:=malloc(s);
  with mcpstrc do begin
    bufferSeg:=seg(temp^)+1;
    bufferLinear:=longint(bufferSeg)*16;
    bufferSize:=buffer*2;
    reqSize:=buffer;
    samplingRate:=rate;
  end;
  if mcpInit(mcpstrc)<>0 then begin
    initDSMI:=MCP_Initerror;
    exit;
  end;
  atexit(@mcpClose);
  atexit(@tsClose);
  if ampInit(0)<>0 then begin
    initDSMI:=AMP_Initerror;
    exit;
  end;
  atexit(@ampClose);
  tsAddRoutine(@ampInterrupt,AMP_Timer);
  setDACTimer(tsGetTimerRate);
  initDSMI:=0;
end;

var module : PModule;
begin
  initDSMI(20000,4096,0);
  mcpStartVoice;
  module:=ampLoadAMF('EXAMPLE.AMF',0);
  mcpOpenChannels(module^.channelCount,volume_Linear,nil);
  ampPlayModule(module,PM_Loop);   { Play looping }
  readkey;
  ampStopModule;
end.

