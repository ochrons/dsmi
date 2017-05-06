{ SFXENG.PAS    Sound effect engine

  Copyright 1994 Jussi Lahdenniemi

  Original C version (C) 1994 Otto Chrons               }

unit sfxeng;

interface
uses mcp,cdi;

const   MAX_SFX         = 40;

type    PSFX            = ^TSFX;
        TSFX            = Record
          sinfo         : TSampleinfo;
          handle        : integer;
        end;

function initSFX(firstCh,chCount:integer):integer;
function registerSFX(sinfo:PSampleinfo):integer;
function playSFX(handle,volume,rate,panning:integer):integer;
function stopSFX(sfxhandle:integer):integer;
function stopAllSFX:integer;

implementation
uses csupport;

var     sfxs            : array[0..MAX_SFX-1] of TSampleinfo;
        sfxChannel      : array[0..7] of TSFX;
        firstChannel,
        channelCount    : integer;

const   lastSFX         : integer = 0;
        lastUse         : integer = 0;

function initSFX(firstCh,chCount:integer):integer;
begin
  initSFX:=-1;
  if chCount>8 then exit;
  firstChannel:=firstCh;
  channelCount:=chCount;
  fillchar(sfxs,sizeof(sfxs),0);
  fillchar(sfxChannel,sizeof(sfxChannel),0);
  initSFX:=0;
end;

function registerSFX(sinfo:PSampleinfo):integer;
begin
  registerSFX:=-1;
  if lastSFX=MAX_SFX then exit;
  move(sinfo^,sfxs[lastSFX],sizeof(TSampleinfo));
  inc(lastSFX);
  registerSFX:=lastSFX-1;
end;

function playSFX(handle,volume,rate,panning:integer):integer;
var i,ch        : integer;
    s           : PSampleinfo;

const sfxHandle : integer = 0;

begin
  ch:=-1;
  playSFX:=-1;
  if (handle<0) or (handle>=lastSFX) then exit;
  s:=@sfxs[handle];
  for i:=0 to channelCount-1 do
    if (cdiGetChannelStatus(i+firstChannel) and CH_PLAYING)=0 then begin
      ch:=i;
      break;
    end;
  if ch=-1 then
    for i:=0 to channelCount-1 do
      if memcmp(@sfxChannel[i].sinfo,s,sizeof(TSampleinfo))=0 then begin
        ch:=i;
        break;
      end;
  if ch=-1 then if lastUse=channelCount-1 then ch:=0 else ch:=lastUse+1;
  lastUse:=ch;
  move(s^,sfxChannel[ch].sinfo,sizeof(TSampleinfo));
  inc(sfxHandle);
  sfxChannel[ch].handle:=sfxHandle;
  cdiSetInstrument(ch+firstChannel,s);
  cdiPlayNote(ch+firstChannel,rate,volume);
  cdiSetPanning(ch+firstChannel,panning);
  playSFX:=sfxHandle;
end;

function stopSFX(sfxhandle:integer):integer;
var i:integer;
begin
  for i:=0 to channelCount-1 do
    if sfxChannel[i].handle=sfxhandle then begin
      cdiStopNote(i+firstChannel);
      stopSFX:=0;
      exit;
    end;
  stopSFX:=-1;
end;

function stopAllSFX:integer;
var i:integer;
begin
  for i:=0 to channelCount-1 do
    cdiStopNote(i+firstChannel);
  stopAllSFX:=0;
end;

end.
