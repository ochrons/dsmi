{ EXAMPLE.PAS An example program for DSMI

  Copyright 1994 Jussi Lahdenniemi

  Original C version (C) 1994 Otto Chrons }

{$I DSMI.INC},crt
{$IFNDEF DPMI}
{$IFNDEF USE_EMS}
,emhm
{$ENDIF}
{$ENDIF}
,sfxeng;

type TSCtype = record
       name  : string;
       ID    : integer;
     end;

{$IFNDEF DPMI}

const scardcount=13;

      soundcards:array[0..scardcount-1] of TSCtype =
      ((name:'SoundBlaster';ID:1),
       (name:'SoundBlaster Pro';ID:2),
       (name:'SoundBlaster 16';ID:6),
       (name:'Pro Audio Spectrum';ID:3),
       (name:'Pro Audio Spectrum+';ID:4),
       (name:'Pro Audio Spectrum 16';ID:5),
       (name:'Aria sound card';ID:8),
       (name:'Windows Sound System (or compatible)';ID:9),
       (name:'Gravis Ultrasound';ID:10),
       (name:'DAC on LPT';ID:7),
       (name:'Stereo DACs on LPT1 and LPT2';ID:7),
       (name:'Stereo-on-1 DAC on LPT';ID:7),
       (name:'PC speaker';ID:7));

{$ELSE}

const scardcount=9;

      soundcards:array[0..scardcount-1] of TSCtype =
      ((name:'SoundBlaster';ID:1),
       (name:'SoundBlaster Pro';ID:2),
       (name:'SoundBlaster 16';ID:6),
       (name:'Pro Audio Spectrum';ID:3),
       (name:'Pro Audio Spectrum+';ID:4),
       (name:'Pro Audio Spectrum 16';ID:5),
       (name:'Aria sound card';ID:8),
       (name:'Windows Sound System (or compatible)';ID:9),
       (name:'Gravis Ultrasound';ID:10));

{$ENDIF}

      effectcount=5;
      effects:array[0..effectcount-1] of string[12] =
      ('effect1.raw','effect2.raw','effect3.raw','effect4.raw','effect5.raw');
      efloops:array[0..effectcount-1] of word =
      (0,0,0,32823,0);
      efloope:array[0..effectcount-1] of word =
      (0,0,0,50887,0);

var    emsOK : boolean;

Function hex(c:word):string;
const hltrs:string='0123456789ABCDEF';
var s:string;
begin
  s:='';
  if c=0 then s:='0' else
    while c<>0 do begin
      s:=hltrs[c and $f+1]+s;
      c:=c shr 4;
    end;
  hex:=s;
end;

Function getSoundHardware(scard:PSoundcard):integer;
var sc,i,autosel,select : integer;
    answer              : string;
    ch                  : char;
    e                   : integer;
label again;

begin
  fillchar(scard^,sizeof(TSoundcard),0);
again:
  sc:=detectGUS(scard);
  if sc<>0 then sc:=detectPAS(scard);
  if sc<>0 then sc:=detectAria(scard);
  if sc<>0 then sc:=detectSB(scard);

  { if no sound card found, zero scard }
  if sc<>0 then fillchar(scard^,sizeof(TSoundcard),0);

  autosel:=-1;
  if sc=0 then
    for i:=0 to scardcount-1 do
      if scard^.ID=soundcards[i].ID then begin
        { Set auto selection mark }
        autosel:=i+1;
        break;
      end;

  { Print the list of sound cards }
  for i:=0 to scardcount-1 do
    writeln(i+1,') ',soundcards[i].name);

  if autosel<>-1 then write(#10'Select (',autosel,'): ')
    else write(#10'Select : ');

  { Read user input }

  readln(answer);
  val(answer,select,e);

  { Default entry? }
  if select=0 then select:=autosel;
  if select<>autosel then begin
    { clear all assumptions }
    sc:=-1;
    fillchar(scard^,sizeof(TSoundcard),0);
    scard^.ID:=soundcards[select-1].ID; { set correct ID }
  end;

  { Query I/O address }
  if scard^.id=ID_DAC then scard^.ioPort:=$378;
  if sc=0 then write('Enter sound card''s base I/O address ($',hex(scard^.ioPort),'): ')
    else write('Enter sound card''s base I/O address: ');

  { Read user input }
  readln(answer);
  if answer[1]<>'$' then answer:='$'+answer; { make sure it's a hex number }
  val(answer,i,e);

  if i<>0 then scard^.ioPort:=i;
  if sc<>1 then { Not autodetected }
    case scard^.id of
      ID_SB16,
      ID_PAS16,
      ID_WSS,
      ID_ARIA,
      ID_GUS    : scard^.sampleSize:=2; { 16-bit card }
      ID_SBPRO,
      ID_PAS,
      ID_PASPLUS: scard^.stereo:=true;  { enable stereo }
      else begin
        scard^.sampleSize:=1;
        scard^.stereo:=false;
      end;
    end;

  if scard^.ID<>ID_DAC then begin
    { Query IRQ number }
    if sc=0 then write('Enter sound card''s IRQ number (',scard^.dmaIRQ,'): ')
      else write('Enter sound card''s IRQ number: ');

    { Read user input }
    readln(answer);
    val(answer,i,e);

    if i<>0 then scard^.dmaIRQ:=i;

    { Query DMA channel }
    if sc=0 then write('Enter sound card''s DMA channel (',scard^.dmaChannel,'): ')
      else write('Enter sound card''s DMA channel: ');

    { Read user input }
    readln(answer);
    val(answer,i,e);

    if i<>0 then scard^.dmaChannel:=i;
  end else begin
    { Select correct DAC }
    scard^.maxRate:=44100;
    if soundcards[select-1].name='Stereo DACs on LPT1 and LPT2' then begin
      scard^.stereo:=true;
      scard^.dmaChannel:=1;   { Special 'mark' }
      scard^.maxRate:=60000;
    end else
    if soundcards[select-1].name='Stereo-on-1 DAC on LPT' then begin
      scard^.stereo:=true;
      scard^.dmaChannel:=2;
      scard^.maxRate:=60000;
      if scard^.ioPort=0 then scard^.ioPort:=$378;
    end else
    if soundcards[select-1].name='PC speaker' then begin
      scard^.dmaChannel:=0;
      scard^.ioPort:=$42;     { Special 'mark' }
      scard^.maxRate:=44100;
    end;
  end;

  if scard^.ID<>ID_DAC then
    writeln('Your selection: ',soundcards[select-1].name,' at $',hex(scard^.ioPort),
            ' using IRQ ',scard^.dmaIRQ,' and DMA channel ',scard^.dmaChannel)
  else
    writeln('Your selection: ',soundcards[select-1].name,' at $',hex(scard^.ioPort));

  write('Is this correct (Y/n)? ');
  ch:=readkey;
  writeln(ch);
  if upcase(ch)='N' then goto again;
  getSoundHardware:=0;
end;

Function loadSample(fname:string;lps,lpe:word;var handle:integer):integer;
var f:file;
    a:integer;
    l:longint;
    sinfo:TSampleinfo;
    {$IFNDEF DPMI}
    e:TEMSH;
    {$ENDIF}
begin
  { Clear sinfo }
  fillchar(sinfo,sizeof(TSampleinfo),0);

  { Open sample file }
  {$I-}
  assign(f,fname);
  reset(f,1);
  loadSample:=-1;
  if IOresult<>0 then exit;

  { Get the length of the file }
  l:=filesize(f);
  if l>65520 then l:=65520;

  { Can we use EMS? }
  {$IFNDEF DPMI}
  e:=0;
  if emsOK then begin
    e:=emsAlloc(l);
    if e>0 then begin
      { Map into page frame }
      sinfo.sample:=emsLock(e,0,l);
      sinfo.sampleID:=e;
    end;
  end;
  if e=0 then begin
  {$ENDIF}
    sinfo.sample:=malloc(l);
    if sinfo.sample=nil then exit;
  {$IFNDEF DPMI}
  end;
  {$ENDIF}

  { Read sample data }
  blockread(f,sinfo.sample^,l);

  { Fill the other fields in sinfo }
  sinfo.length:=l;
  sinfo.loopstart:=lps;
  sinfo.loopend:=lpe;

  { Was it loaded into EMS? }
  if sinfo.sampleID<>0 then begin
    { Download with sampleID }
    cdiDownloadSample(0,sinfo.sample,pointer(sinfo.sampleID),l);
    sinfo.sample:=pointer(sinfo.sampleID);
  end else
    { Download with pointer }
    cdiDownloadSample(0,sinfo.sample,sinfo.sample,l);

  close(f);
  handle:=registerSFX(@sinfo);
  loadSample:=0;
end;

var     scard   : TSoundcard;
        mcpstrc : TMCPstruct;
        dds     : TDDS;
        module  : PModule;
        sdi     : TSDI_init;
        e,
        bufsize : integer;
        ch      : char;
        v86,
        vdsOK   : boolean;
        a,rate,
        tempSeg : longint;
        answer  : string;
        temp    : pointer;
        flags   : word;
        curCh   : word;
        moduleVolume : byte;
        volTable: array[0..31] of word;
        sfxHandles : array[0..effectcount-1] of integer;

begin
  { Read sound card information }
  if getSoundHardware(@scard)=-1 then halt(1);

  { Initialize the EMS heap manager }
  {$IFNDEF DPMI}
  if emsInit(378,378)=0 then begin
    writeln('Using 256k of EMS');
    emsOK:=true;
  end else emsOK:=false;
  {$ENDIF}

  { Initialize Timer Service }
  tsInit;
  atexit(@tsClose);
  if scard.ID=ID_GUS then begin
    { Initialize GUS player }
    {$IFNDEF DPMI}
    scard.extraField[2]:=1; { Use GUS DMA downloading               }
    {$ELSE}
    scard.extraField[3]:=0; { GUS DMA transfer does not work in V86 }
    {$ENDIF}
    scard.extraField[3]:=0; { Don't use GUS timer                   }
    gusInit(@scard);
    atexit(@gusClose);

    { Initialize GUS heap manager }
    gushmInit;

    { Init CDI }
    cdiInit;

    { Register GUS into CDI }
    cdiRegister(@CDI_GUS,0,31);

    { Add GUS event player engine into Timer Service }
    tsAddRoutine(@gusInterrupt,GUS_TIMER);
  end else begin
    { Initialize Virtual DMA Specification }
    {$IFNDEF DPMI}
    vdsOK:=vdsInit=0;
    {$ELSE}
    vdsOK:=false;
    {$ENDIF}

    fillchar(mcpstrc,sizeof(TMCPstruct),0);

    { Query for sampling rate }
    write('Enter the sampling rate (21000) : ');
    readln(answer);
    val(answer,a,e);
    if a>4000 then rate:=a else rate:=21000;

    { Query for quality }
    write('Use quality mode (Y/n)? ');
    ch:=readkey;
    writeln(ch);
    if upcase(ch)<>'N' then mcpstrc.options:=MCP_QUALITY;

    case scard.ID of
      ID_SB     : begin
                    sdi:=SDI_SB;
                    scard.maxRate:=22000;
                  end;
      ID_SBPRO  : begin
                    sdi:=SDI_SBPro;
                    scard.maxRate:=22000;
                  end;
      ID_PAS,
      ID_PASPLUS,
      ID_PAS16  : begin
                    sdi:=SDI_PAS;
                    scard.maxRate:=44100;
                  end;
      ID_SB16   : begin
                    sdi:=SDI_SB16;
                    scard.maxRate:=44100;
                  end;
      ID_ARIA   : begin
                    sdi:=SDI_ARIA;
                    scard.maxRate:=44100;
                  end;
      ID_WSS    : begin
                    sdi:=SDI_WSS;
                    scard.maxRate:=48000;
                  end;
      {$IFNDEF DPMI}
      ID_DAC    : sdi:=SDI_DAC; { Only available in real mode }
      {$ENDIF}
    end;

    mcpInitSoundDevice(sdi,@scard);
    a:=MCP_TABLESIZE;
    mcpstrc.reqSize:=0;

    { Calculate mixing buffer size }
    bufSize:=longint(2800*integer(scard.sampleSize) shl byte(scard.stereo))*
             longint(rate) div longint(22000);
    mcpstrc.reqSize:=0;
    if mcpstrc.options and MCP_QUALITY>0 then
      if scard.sampleSize=1 then inc(a,MCP_QUALITYSIZE) else
        a:=MCP_TABLESIZE16+MCP_QUALITYSIZE16;
    if longint(bufsize)+longint(a)>65500 then bufsize:=65500-a;

    {$IFDEF DPMI}
    dpmiVersion(byte(e),byte(e),byte(e),flags);
    v86:=(flags and 2)=0;
    {$ENDIF}

    { Allocate volume table + mixing buffer }
    {$IFDEF DPMI}

    { In the V86 mode, the buffer must be allocated below 1M }
    if v86 then begin
      tempSeg:=0;
      dpmiAllocDOS((a+bufSize) div 16+1,flags,word(tempSeg))
    end else begin
    {$ENDIF}
    getmem(temp,a+bufsize);
    if temp=nil then halt(2);
    {$IFDEF DPMI}
    tempSeg:=seg(temp^);
    end;
    {$ELSE}
    tempSeg:=seg(temp^)+ofs(temp^) div 16+1;
    {$ENDIF}
    mcpstrc.bufferSeg:=tempSeg;
    mcpstrc.bufferPhysical:=-1;

    if vdsOK and (scard.ID<>ID_DAC) then begin
      dds.size:=bufsize;
      dds.segment:=tempSeg;
      dds.offset:=0;

      { Lock DMA buffer if VDS present }
      if vdsLockDMA(@dds)=0 then mcpstrc.bufferPhysical:=dds.address;
    end;
    if mcpstrc.bufferPhysical=-1 then
      {$IFDEF DPMI}
      mcpstrc.bufferPhysical:=dpmiGetLinearAddr(tempSeg);
      {$ELSE}
      mcpstrc.bufferPhysical:=longint(tempSeg) shl 4;
      {$ENDIF}

    mcpstrc.buffersize:=bufsize;
    mcpstrc.samplingRate:=rate;
    { Initialize Multi Channel Player }
    if mcpInit(@mcpstrc)<>0 then halt(3);
    atexit(@mcpClose);

    { Initialize Channel Distributor }
    cdiInit;

    { Register MCP into CDI}
    cdiRegister(@CDI_MCP,0,31);
  end;

  { Try to initialize AMP }
  if ampInit(0)<>0 then halt(3);
  atexit(@ampClose);

  { Hook AMP player routine into Timer Service }
  tsAddRoutine(@ampInterrupt,AMP_TIMER);

  {$IFNDEF DPMI}
  { If using DAC, then adjust DAC timer }
  if scard.ID=ID_DAC then setDACTimer(tsGetTimerRate);
  {$ENDIF}

  if scard.ID<>ID_GUS then mcpStartVoice else gusStartVoice;

  { Load an example AMF }
  module:=ampLoadAMF('EXAMPLE.AMF',0);
  if module=nil then halt(4);

  { Is it MCP, Quality mode and 16-bit card? }
  if (scard.ID<>ID_GUS) and (mcpstrc.options and MCP_QUALITY>0)
     and (scard.sampleSize=2) then begin
    { Open module+3 channels with amplified volumetable (4.7 gain) }
    for a:=1 to 32 do volTable[a-1]:=a*150 div 32;
    cdiSetupChannels(0,module^.channelCount+3,@volTable);
  end else begin
    { Open module+3 channels with regular volumetable }
    cdiSetupChannels(0,module^.channelCount+3,nil);
  end;

  moduleVolume:=64;

  { Load effects }
  writeln('Loading effects...');
  initSFX(module^.channelCount,3);
  for e:=0 to effectCount-1 do
    if loadSample(effects[e],efloops[e],efloope[e],sfxHandles[e])<>0 then halt(4);

  { Play module }
  ampPlayModule(module,PM_LOOP);
  writeln('Playing EXAMPLE.AMF');
  writeln;
  writeln('Press + or - to adjust the volume of the module');
  writeln('Press 1-5 to play effects');
  writeln('Press 0 to stop all effects');

  ch:=#0;
  while not (ch=#27) do begin { Wait for escape }
    if keypressed then begin
      ch:=readkey;
      case ch of
        '+' : begin
                if moduleVolume<64 then inc(moduleVolume);
                ampSetMasterVolume(-1,moduleVolume);
              end;
        '-' : begin
                if moduleVolume>0 then dec(moduleVolume);
                ampSetMasterVolume(-1,moduleVolume);
               end;
        '0'..char(byte('1')+effectcount-1)
            : begin
                a:=byte(ch)-byte('1');
                { Play effect }
                if a>=0 then playSFX(sfxHandles[a],64,11025,PAN_MIDDLE);
                if a=-1 then stopAllSFX;
              end;
      end;
    end;
  end;
  ampStopModule;
end.
