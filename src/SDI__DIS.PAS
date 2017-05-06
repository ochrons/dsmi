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



procedure writeToDisk;




function  SDI_DISK(sdi:PSoundDevice):integer;

function  initDisk(sCard:PSoundCard):integer;
function  initOutput(buffer,physical:pointer;maxsize,required:longint):integer;
function  initRate(rate:longint):longint;
procedure closeDisk;
procedure closeOutput;
procedure startVoice;
procedure stopVoice;
procedure pauseVoice;
procedure resumeVoice;
function  getBufferPos:longint;
procedure speakerOn;
procedure speakerOff;

const soundDeviceDisk : TSoundDevice =
      (InitDevice     : @initDisk;
       InitOutput     : @initOutput;
       InitRate       : @initRate;
       CloseDevice    : @closeDisk;
       CloseOutput    : @closeOutput;
       StartOutput    : @startVoice;
       StopOutput     : @stopVoice;
       PauseOutput    : @pauseVoice;
       ResumeOutput   : @resumeVoice;
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
       samsize  : longint;
       stereo   : boolean;
       bits     : word;

function SDI_DISK(sdi:PSoundDevice):integer;
begin
  move(soundDeviceDisk,sdi^,sizeof(TSoundDevice));
  SDI_DISK:=0;
end;

type pstring=^string;
     TWavHeader=record
       riff           : array[0..3] of char;
       riffsize       : longint;
       wave           : array[0..3] of char;
       fmt            : array[0..3] of char;
       fmtsize        : longint;
       strange1       : word;
       channels       : word;
       srate          : longint;
       sratemulssize  : longint;
       ssize          : word;
       bitcount       : word;
       data           : array[0..3] of char;
       datasize       : longint;
     end;
const defaultwavheader: TWavHeader =
      (riff           : ('R','I','F','F');
       riffsize       : 0;
       wave           : ('W','A','V','E');
       fmt            : ('f','m','t',' ');
       fmtsize        : 16;
       strange1       : 1;
       channels       : 1;
       srate          : 44100;
       sratemulssize  : 44100;
       ssize          : 1;
       bitcount       : 8;
       data           : ('d','a','t','a');
       datasize       : 0);

function initDisk(sCard:PSoundCard):integer;
begin
  fname:=pstring(pointer(@sCard^.extrafield[2])^)^;
  assign(ofile,fname);
  rewrite(ofile,1);
  output:=false;
  currate:=sCard^.maxrate;
  samsize:=(byte(sCard^.stereo)+1)*scard^.samplesize;
  stereo:=scard^.stereo;
  bits:=scard^.samplesize*8;
  move(sCard^,SOUNDCARD,sizeof(TSoundCard));
  if IOresult<>0 then initDisk:=-1 else begin
    initDisk:=0;
    mcpStatus:=mcpStatus or 1;
    blockwrite(ofile,defaultwavheader,sizeof(TWavHeader));
    defaultwavheader.datasize:=0;
  end;
end;

const inuse:byte=0;

procedure writeToDisk; {interrupt;}
var p:pointer;
    oldbp:longint;
    toc:word;
label alreadyhere;
begin
{  asm
    cli
    push ax
    mov al,1
    xchg [inuse],al
    cmp al,1
    pop ax
    je alreadyhere
    mov dx,3dah
    in al,dx
    mov dx,3c0h
    mov al,31h
    out dx,al
    mov al,1
    out dx,al
  end;
  p:=ptr(seg(dmabuf^),ofs(dmabuf^)+longint(bufpos) div 65536);
  oldbp:=bufpos;
  inc(bufpos,currate*(65536 div 128)*samsize);
  toc:=((bufpos-oldbp) div 65536);
  if bufpos div 65536>=dmabsize then begin
    blockwrite(ofile,p^,dmabsize-oldbp div 65536);
    dec(toc,dmabsize-oldbp div 65536);
    if toc<>0 then blockwrite(ofile,dmabuf^,toc);
    dec(bufpos,dmabsize*65536);
  end else begin
    blockwrite(ofile,p^,toc);
  end;
  asm
    mov dx,3c0h
    mov al,31h
    out dx,al
    mov al,0
    out dx,al
    mov [inuse],0
alreadyhere:
    sti
  end;}
  blockwrite(ofile,ptr(seg(dmabuf^),ofs(dmabuf^)+bufpos)^,dmabsize div 2);
  inc(defaultwavheader.datasize,dmabsize div 2);
  if bufpos=dmabsize div 2 then
    bufpos:=0 else bufpos:=dmabsize div 2;
end;

function  initOutput(buffer,physical:pointer;maxsize,required:longint):integer;
begin
  dmabuf:=buffer;
  dmabsize:=maxsize;
  bufpos:=0;
  bufferSize:=maxsize;
  databuf:=ofs(buffer^);
{  tstag:=tsAddRoutine(@writeToDisk,DISK_TIMER);}
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
  with defaultwavheader do begin
    riffsize:=datasize+40;
    channels:=byte(stereo)+1;
    srate:=currate;
    sratemulssize:=currate*samsize;
    ssize:=samsize;
    bitcount:=bits;
    seek(ofile,0);
    blockwrite(ofile,defaultwavheader,sizeof(TWavHeader));
  end;
  close(ofile);
end;

function  getBufferPos:longint;
begin
  getBufferPos:=bufPos {div 65536};
end;

end.

