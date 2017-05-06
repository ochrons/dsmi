{************************************************************************
 *
 *	File        :	SDI_DISK.PAS
 *
 *	Description :	MCP disk sample routines
 *
 *	Copyright (C) 1994 Jussi Lahdenniemi
 *
 ***********************************************************************

	Revision history of SDI_DISK.PAS

	1.0	16.4.93
		First version.

 ***********************************************************************}

{$F+,I-}

unit SDI__DISK;

interface
uses mcp;

function  initDisk(sCard:PSoundCard):integer;
function  initOutput(buffer:pointer;maxsize,required:integer):integer;
function  initRate(rate:longint):longint;
procedure closeDisk;
procedure closeOutput;
procedure startOutput;
procedure stopOutput;
procedure pauseOutput;
procedure resumeOutput;
function  getBufferPos:longint;
procedure speakerOn;
procedure speakerOff;

const soundDeviceDisk : TSoundDevice =
      (InitDevice     : @initDisk;
       InitOutput     : @initOutput;
       InitRate       : @initRate;
       CloseDevice    : @closeDisk;
       CloseOutput    : @closeOutput;
       StartOutput    : @startOutput;
       StopOutput     : @stopOutput;
       PauseOutput    : @pauseOutput;
       ResumeOutput   : @resumeOutput;
       GetBufferPos   : @getBufferPos;
       SpeakerOn      : @speakerOn;
       SpeakerOff     : @speakerOff);

      DISK_TIMER      = 1193180 div 128;

implementation
uses timeserv;

var    ofile    : file;
       fname    : string;
       output   : boolean;
       tstag    : integer;
       currate  : longint;
       bufpos   : longint;
       dmabuf   : pointer;
       dmabsize : longint;

function SDI_DISK(sdi:PSoundDevice):integer;
begin
  move(soundDeviceDisk,sdi^,sizeof(TSoundDevice);
  SDI_DISK:=0;
end;

function initDisk(sCard:PSoundCard):integer;
begin
  fname:=pstring(pointer(@sCard^.extrafield[2])^)^;
  assign(ofile,fname);
  rewrite(ofile,1);
  output:=false;
  currate:=44100;
  mcpStatus := mcpStatus or 1;
  if IOresult<>0 then initDisk:=-1 else initDisk:=0;
end;

procedure writeToDisk; interrupt;
var ptr:pointer;
    oldbp:longint;
    toc:word;
begin
  ptr:=ptr(seg(dmabuf^):ofs(dmabuf^)+longint(bufpos) div 65536);
  oldbp:=bufpos;
  inc(bufpos,currate*(65536 div 128));
  toc:=((bufpos-oldbp) div 65536);
  if toc+bufpos div 65536>=dmabsize then begin
    blockwrite(ofile,ptr^,dmabsize-bufpos div 65536);
    dec(toc,dmabsize-bufpos div 65536);
    if toc<>0 then blockwrite(ofile,dmabuf^,toc);
    dec(bufpos,dmabsize*65536);
  end else begin
    blockwrite(ofile,ptr^,toc);
  end;
end;

function  initOutput(buffer:pointer;maxsize,required:longint):integer;
begin
  dmabuf:=buffer;
  dmabsize:=maxsize;
  bufpos:=0;
  tstag:=tsAddRoutine(@writeToDisk,DISK_TIMER);
  initOutput:=0;
end;

function  initRate(rate:longint):longint;
begin
  initRate:=rate;
end;

procedure speakerOn;
begin
end;

procedure speakerOff;
begin
end;

procedure startVoice;
begin
  output:=true;
end;

procedure stopVoice;
begin
  output:=false;
end;

procedure pauseVoice;
begin
  output:=false;
end;

procedure resumeVoice;
begin
  output:=true;
end;

procedure closeOutput;
begin
  tsRemoveRoutine(tstag);
end;

procedure closeDisk;
begin
  close(ofile);
end;

function  getBufferPos:longint;
begin
  getBufferPos:=bufPos div 65536;
end;

end.

