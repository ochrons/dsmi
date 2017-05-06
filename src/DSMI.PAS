(****************************************************************************

                                   DSMI.PAS
                                   --------

                          (C) 1993 Jussi Lahdenniemi

initDSMI routine for easer MCP, AMP and TS initialization

****************************************************************************)

unit DSMI;

{$X+}

interface
uses MCP,CDI;

Function initDSMI(rate,buffer,options:longint;scard:PSoundcard):Integer;

Const No_Soundcard  = -1;
      Invalid_SDI   = -2;
      No_Memory     = -3;
      MCP_InitError = -4;
      AMP_InitError = -5;

var   ampTag:word;

implementation
uses AMP,SDI__SB,SDI__SB16,SDI__PAS,SDI__ARIA,DET_SB,DET_PAS,DET_ARIA,DETGUS,
     TIMESERV,CSupport,VDS,GUS
{$IFDEF DPMI}
,dpmiAPI
{$ENDIF};

Function initDSMI(rate,buffer,options:longint;scard:PSoundcard):Integer;
var a,vdsOK : Integer;
    s       : Word;
    sdi     : TSDI_Init;
    temp    : Pointer;
    mcpstrc : TMCPStruct;
    dds     : TDDS;

begin
  a:=detectGUS(scard);
  if a<>0 then a:=detectPAS(scard);
  if a<>0 then a:=detectAria(scard);
  if a<>0 then a:=detectSB(scard);
  if a=0 then begin
    case scard^.ID of
      ID_SB    : sdi:=SDI_SB;
      ID_SBPro : sdi:=SDI_SBpro;
      ID_SB16  : begin
                   sdi:=SDI_SB16;
                   if options and MCP_Mono>0 then scard^.stereo:=false;
                 end;
      ID_ARIA  : begin
                   sdi:=SDI_ARIA;
                   if options and MCP_Mono>0 then scard^.stereo:=false;
                 end;
      ID_PAS,
      ID_PASplus,
      ID_PAS16 : begin
                   sdi:=SDI_PAS;
                   if options and MCP_Mono>0 then scard^.stereo:=false;
                 end;
      ID_GUS   : ;
      else begin
        initDSMI:=Invalid_SDI;
        exit;
      end
    end;
    if scard^.id<>ID_GUS then mcpInitSoundDevice(sdi,scard);
  end else begin
    initDSMI:=No_Soundcard;
    exit;
  end;

  if scard^.id<>ID_GUS then begin
    {$IFNDEF DPMI}
    vdsOK:=byte(vdsInit=0);
    {$ENDIF}
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
      initDSMI:=No_Memory;
      exit;
    end;
    with mcpstrc do begin
      {$IFDEF DPMI}
      bufferPhysical:=dpmiGetLinearAddr(bufferSeg);
      {$ELSE}
      bufferSeg:=seg(temp^)+ofs(temp^) div 16+1;
      if (vdsOK>0) and (scard^.id<>ID_DAC) then begin
        dds.size:=buffer;
        dds.segment:=bufferSeg;
        dds.offset:=0;
        if vdsLockDMA(@dds)=0 then begin
          bufferPhysical:=dds.address;
          vdsDisableDMATranslation(scard^.dmaChannel);
          vdsOK:=2;
        end else bufferPhysical:=longint(bufferSeg)*16;
      end else bufferPhysical:=longint(bufferSeg)*16;
      {$ENDIF}
      bufferSize:=buffer*2;
      reqSize:=buffer;
      samplingRate:=rate;
    end;
    if mcpInit(@mcpstrc)<>0 then begin
      initDSMI:=MCP_Initerror;
      exit;
    end;
    atexit(@mcpClose);
    cdiInit;
    cdiRegister(@CDI_MCP,0,31);
  end else begin
    scard^.extrafield[2]:=1;
    scard^.extrafield[3]:=1;
    gusInit(scard);
    atexit(@gusClose);
    gushminit;
    cdiInit;
    cdiRegister(@CDI_GUS,0,31);
  end;
  tsInit;
  atexit(@tsClose);
  if ampInit(0)<>0 then begin
    initDSMI:=AMP_Initerror;
    exit;
  end;
  atexit(@ampClose);
  ampTag:=tsAddRoutine(@ampInterrupt,AMP_Timer);
{  if scard^.id=ID_GUS then tsAddRoutine(@gusInterrupt,GUS_Timer);}
  initDSMI:=0;
end;

end.
