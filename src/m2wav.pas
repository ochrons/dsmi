(****************************************************************************

                                 EXAMPLE3.PAS
                                 ------------

                          (C) 1993 Jussi Lahdenniemi

Example program #3 for DSMI tutorial

****************************************************************************)

{$I dsmi.inc} ,crt,dos,{emhm,}SDI__DISK;

{$m 4096,0,655360}

Const No_Soundcard  = -1;
      Invalid_SDI   = -2;
      No_Memory     = -3;
      MCP_InitError = -4;
      AMP_InitError = -5;

      SET_RATE      = 44100;
      SET_STEREO    = true;
      SET_16BIT     = true;

      fname         : string = 'OUTPUT.WAV';
      sdiname       : string = 'Disk output'#0;

var   ampTag:word;

Function initDSMIdisk(rate,buffer,options:longint;scard:PSoundcard):Integer;
var a,vdsOK : Integer;
    s       : Word;
    sdi     : TSDI_Init;
    temp    : Pointer;
    mcpstrc : TMCPStruct;
    dds     : TDDS;
    p:pointer;

begin
  with scard^ do begin
    ID:=ID_DISK;
    version:=0;
    move(sdiname[1],name,length(sdiname)+1);
    IOport:=0;
    dmaIrq:=0;
    dmaChannel:=0;
    minRate:=SET_RATE;
    maxRate:=SET_RATE;
    stereo:=SET_STEREO;
    mixer:=false;
    samplesize:=byte( SET_16BIT ) + 1;
    extrafield[2]:=lo(ofs(fname));
    extrafield[3]:=hi(ofs(fname));
    extrafield[4]:=lo(seg(fname));
    extrafield[5]:=hi(seg(fname));
  end;
{  tsInit;
  atexit(@tsClose);}
  p:=addr(SDI_DISK);
  sdi:=TSDI_init(p);
  mcpInitSoundDevice(sdi,scard);

  if scard^.id<>ID_GUS then begin
    mcpstrc.options:=0;
    s:=buffer*2+MCP_Tablesize+16;
    if options and MCP_Quality>0 then begin
      mcpstrc.options:=mcpstrc.options or MCP_Quality;
      inc(s,MCP_Qualitysize);
    end;
    {$IFDEF DPMI}
    temp:=ptr(dseg,0);
    dpmiAllocDOS(s div 16,word(a),mcpstrc.bufferSeg);
    {$ELSE}
    temp:=malloc(s);
    {$ENDIF}
    if temp=nil then begin
      initDSMIdisk:=No_Memory;
      exit;
    end;
    with mcpstrc do begin
      {$IFDEF DPMI}
      bufferPhysical:=dpmiGetLinearAddr(bufferSeg);
      {$ELSE}
      bufferSeg:=seg(temp^)+ofs(temp^) div 16+1;
      {$ENDIF}
      bufferSize:=buffer*2;
      reqSize:=buffer;
      samplingRate:=rate;
    end;
    if mcpInit(@mcpstrc)<>0 then begin
      initDSMIdisk:=MCP_Initerror;
      exit;
    end;
    atexit(@mcpClose);
    cdiInit;
    cdiRegister(@CDI_MCP,0,31);
  end;
  if ampInit(0)<>0 then begin
    initDSMIdisk:=AMP_Initerror;
    exit;
  end;
  atexit(@ampClose);
{  ampTag:=tsAddRoutine(@ampInterrupt,AMP_Timer);}
  initDSMIdisk:=0;
end;

type ia=array[0..32000] of integer;
     trev=record
       position : longint;
       gain     : longint;
     end;

var  delayLineLeft,
     delayLineRight,
     delayLineMono  : ^ia;

const {reverbcount   : longint = 2;
      reverbs       : array[0..1] of trev =
      ((position:160;gain:30),(position:300;gain:50));
      reverbFeedback: longint = 75;}                    { Distant echo }
      reverbcount   : longint = 1;
      reverbs       : array[0..0] of trev =
      ((position:0;gain:60));
      reverbFeedback: longint = 0;                      { Bass boost }
      delaylineposition:longint=0;
      delayLineSize:longint=16384;

{$f+}
procedure reverbEffectsAsm(buffer:pointer;length,dataType:longint); external;
{$l m2wav.obj}
{$f-}

procedure reverbEffects(buffer:pointer;length,dataType:longint); far;
var i,mask,t    : integer;
    intBuf      : ^integer;
    revval,
    outval,
    tempval     : longint;
    prevval     : longint;
    prevvalright: longint;
begin
  i:=length;
  mask:=delayLineSize-1;
  prevval:=0;
  prevvalright:=0;
  if dataType and 2>0 then
    if dataType and 1>0 then begin
      intbuf:=buffer;
      while i>0 do begin
        outval:=intbuf^;
        revval:=0;
        for t:=0 to reverbCount-1 do begin
          reverbs[t].position:=(reverbs[t].position+1) and mask;
          inc(revval,reverbs[t].gain*delayLineLeft^[reverbs[t].position]);
        end;
        revval:=(prevval+(revval div 256)) div 2;
        prevval:=revval;
        tempval:=outval+(revval*reverbFeedback div 256);
        inc(revval,outval);
        if revval>32767 then begin
          revval:=32767;
          if tempval>32767 then tempval:=32767;
        end else if revval<-32768 then begin
          revval:=-32768;
          if tempval<-32768 then tempval:=-32768;
        end;
        delayLinePosition:=(delayLinePosition+1) and mask;
        delayLineLeft^[delayLinePosition]:=tempval;
        intbuf^:=integer(revval);
        inc(longint(intbuf),2);

        outval:=intbuf^;
        revval:=0;
        for t:=0 to reverbCount-1 do begin
          inc(revval,reverbs[t].gain*delayLineRight^[reverbs[t].position]);
        end;
        revval:=(prevvalRight+(revval div 256)) div 2;
        prevvalRight:=revval;
        tempval:=outval+(revval*reverbFeedback div 256);
        inc(revval,outval);
        if revval>32767 then begin
          revval:=32767;
          if tempval>32767 then tempval:=32767;
        end else if revval<-32768 then begin
          revval:=-32768;
          if tempval<-32768 then tempval:=-32768;
        end;
        delayLineRight^[delayLinePosition]:=tempval;
        intbuf^:=integer(revval);
        inc(longint(intbuf),2);
        dec(i);
      end;
    end;
end;

var module : PModule;
    sc     : TSoundCard;
    volt   : array[0..31] of word;
    w      : word;
    p      : pointer;

begin
{  writeln(emsInit(800,800));
  atexit(@emsClose);}
  delayLineLeft:=malloc(32768);
  delayLineMono:=delayLineLeft;
  delayLineRight:=malloc(32768);
  fillchar(delayLineLeft^,32768,0);
  fillchar(delayLineRight^,32768,0);
  writeln(memavail);
{  module:=ampLoadModule('c:\music\mod\chariot.s3m',LM_IML);}
{  module:=ampLoadModule('c:\music\mod\smnogood.mtm',LM_IML);}
{  module:=ampLoadModule('avoid.amf',LM_IML);}
{  module := ampLoadModule( 'c:\music\mod\mental.s3m', LM_IML );}
{  module := ampLoadModule( 'c:\music\mod\2trip.s3m', LM_IML );}
  module := ampLoadModule( paramstr( 1 ), LM_IML );
  if module=nil then begin
    writeln(moduleError);
    exit;
  end;
  writeln(module^.channelCount);
  if initDSMIdisk(44100,4096,MCP_QUALITY,@sc)<>0 then exit;  { Error }
{  tsClose;}
  if sc.id<>ID_GUS then mcpStartVoice else gusStartVoice;
  for w:=0 to 31 do volt[w]:=(w+1)*150 div 32;
  cdiSetupChannels(0,module^.channelCount,@volt);
  ampPlayModule(module,0);   { Play looping }
{  for w:=0 to module^.channelcount-1 do
    ampSetPanning(w,PAN_SURROUND);}
  p:=addr(reverbEffectsAsm);
{  mcpSetEffectRoutine(TEffect_Routine(p));}
{  readkey;}
  clrscr;
  repeat
{    writeln(ampGetRow,' ',ampGetPattern);}
{    writeln(lo(ampGetTempo),' ',hi(ampGetTempo));}
    ampPoll;
    writeToDisk;
    write(ampGetPattern:2,'  -  ',ampGetRow:2,'  -  ',ampGetModuleStatus,#13);
  until keypressed or (ampGetModuleStatus and MD_Playing=0);
  ampStopModule;
  closeDisk;
end.

