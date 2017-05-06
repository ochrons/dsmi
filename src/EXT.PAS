(****************************************************************************

                                 EXAMPLE3.PAS
                                 ------------

                          (C) 1993 Jussi Lahdenniemi

Example program #3 for DSMI tutorial

****************************************************************************)

{$I dsmi.inc} ,crt,dos,emhm;

{$m 4096,0,65536}

function gusmixbyte:byte;
var
  offset:word;
  mixed:longint;
  loop:byte;
  td:Ptrackdata;
  smp:pointer;
  samplevalue:^shortint;

begin
  mixed:=0;
  for loop:=0 to _curmodule.channelcount-1 do begin
    offset:=gusGetPosition(loop);
    td:=ampgettrackdata(loop);
    smp:=_curmodule.instruments^[td^.instrument].sample;
    if seg(smp^)=$ffff
      then samplevalue:=emslock(ofs(smp^),0,64000)
      else samplevalue:=smp;
    inc(longint(samplevalue),offset);
    mixed:=mixed+samplevalue^-128;
{    inc(mixed,samplevalue^-128);}
  end;
  mixed:=mixed div longint(_curmodule.channelcount);
  gusmixbyte:=mixed;
end;

var module : PModule;
    sc     : TSoundCard;
    w      : word;

begin
  if initDSMI(5000,4096,0,@sc)<>0 then exit;  { Error }
  module:=ampLoadModule('avoid.amf',0);
  if module=nil then begin
    writeln(moduleError);
    exit;
  end;
  if sc.id<>ID_GUS then mcpStartVoice else gusStartVoice;
  cdiSetupChannels(0,module^.channelCount,nil);
  ampPlayModule(module,PM_Loop);   { Play looping }
{  readkey;}
{  writeln(memavail);}
  asm
    mov ax,13h
    int 10h
  end;
  while not keypressed do begin
    ampPoll;
    fillchar(mem[$a000:0],64000,0);
    ampPoll;
    for w:=0 to 159 do mem[$a000:w*2+longint(gusmixbyte div 2)*320]:=15;
{    writeln(ampGetRow);}
  end;
{  swapvectors;
  exec(getenv('COMSPEC'),'');
  swapvectors;}
  readkey;
  ampStopModule;
end.

