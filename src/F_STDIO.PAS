{* F_STDIO.PAS General File System functions
 *
 * Copyright 1994 Jussi Lahdenniemi, original C version (C) 1994 Otto Chrons
 *
*}

unit F_STDIO;

{$I-}

interface

type PGFile   = ^TGFile;
     TGFile   = integer;

     PFile    = ^file;
     TFTarr   = array[0..0] of PFile;

var fileTable : ^TFTarr;
    maxFiles  : integer;

const GF_BINARY       = 0;
      GF_TEXT         = 1;
      GF_READ         = 2;
      GF_WRITE        = 4;
      GF_READWRITE    = 6;
      GF_APPEND       = 8;

      GF_SEEK_SET     = 0;
      GF_SEEK_CUR     = 1;
      GF_SEEK_END     = 2;

function initGeneralFileLow(maxF:integer):integer;
function openFileLow(name:PChar;modeflags:integer):TGFile;
function closeFileLow(gfile:TGFile):integer;
function readFileLow(gfile:TGFile;buffer:pointer;size:longint):longint;
function writeFileLow(gfile:TGFile;buffer:pointer;size:longint):longint;
function seekFileLow(gfile:TGFile;position:longint;whence:integer):integer;
function tellFilePositionLow(gfile:TGFile):longint;
function flushFileLow(gfile:TGFile):integer;
function fileEOFLow(gfile:TGFile):integer;

implementation
uses csupport;

function initGeneralFileLow(maxF:integer):integer;
begin
  if maxF=0 then maxF:=20;
  maxFiles:=maxF;
  fileTable:=calloc(maxF,4);
  initGeneralFileLow:=-1;
  if fileTable=nil then exit;
  initGeneralFileLow:=0;
end;

function openFileLow(name:PChar;modeflags:integer):TGFile;
var t : integer;
    f : PFile;

begin
  for t:=0 to maxFiles-1 do if fileTable^[t]=nil then break;
  openFileLow:=-1;
  if t=maxFiles then exit;
  f:=malloc(sizeof(file));
  assign(f^,name);
  if (modeflags and (GF_READ or GF_APPEND or GF_READWRITE))>0 then
    reset(f^,1);
  if IOresult<>0 then exit;
  if (modeflags and GF_APPEND)>0 then
    seek(f^,filesize(f^));
  if (modeflags and GF_WRITE)>0 then
    rewrite(f^,1);
  if IOresult<>0 then exit;
  fileTable^[t]:=f;
  openFileLow:=t;
end;

function closeFileLow(gfile:TGFile):integer;
begin
  closeFileLow:=-1;
  if gfile<0 then exit;
  if fileTable^[gfile]=nil then exit;
  close(fileTable^[gfile]^);
  free(fileTable^[gfile]);
  fileTable^[gfile]:=nil;
  closeFileLow:=0;
end;

function readFileLow(gfile:TGFile;buffer:pointer;size:longint):longint;
var readSize : longint;
    a        : word;
    f        : PFile;

begin
  readSize:=0;
  readFileLow:=-1;
  if gfile<0 then exit;
  readFileLow:=0;
  if fileTable^[gfile]=nil then exit;
  f:=fileTable^[gfile];
{$IFNDEF DPMI}
  while size>65520 do begin
    blockread(f^,buffer^,65520,a);
    dec(size,a);
    inc(readSize,a);
    readFileLow:=readSize;
    if (a<>65520) then exit;
    buffer:=ptr(seg(buffer^)+4096,ofs(buffer^));
  end;
  blockread(f^,buffer^,size,a);
  if a<>size then readFileLow:=readSize+a else readFileLow:=0;
{$ELSE}
  if size>65520 then begin
    readFileLow:=-1;
  end else begin
    blockread(f^,buffer^,size,a);
    if size<>a then readFileLow:=a else readFileLow:=0;
  end;
{$ENDIF}
end;

function writeFileLow(gfile:TGFile;buffer:pointer;size:longint):longint;
var writeSize : longint;
    a        : word;
    f        : PFile;

begin
  writeSize:=0;
  writeFileLow:=-1;
  if gfile<0 then exit;
  writeFileLow:=0;
  if fileTable^[gfile]=nil then exit;
  f:=fileTable^[gfile];
{$IFNDEF DPMI}
  while size>65520 do begin
    blockwrite(f^,buffer^,65520,a);
    dec(size,a);
    inc(writeSize,a);
    writeFileLow:=writeSize;
    if (a<>65520) then exit;
    buffer:=ptr(seg(buffer^)+4096,ofs(buffer^));
  end;
  blockwrite(f^,buffer^,size,a);
  if a<>size then writeFileLow:=writeSize+a else writeFileLow:=0;
{$ELSE}
  if size>65520 then begin
    writeFileLow:=-1;
  end else begin
    blockwrite(f^,buffer^,size,a);
    if size<>a then writeFileLow:=a else writeFileLow:=0;
  end;
{$ENDIF}
end;

function seekFileLow(gfile:TGFile;position:longint;whence:integer):integer;
begin
  seekFileLow:=-1;
  if gfile<0 then exit;
  if fileTable^[gfile]=nil then exit;
  case whence of
    GF_SEEK_SET : seek(fileTable^[gfile]^,position);
    GF_SEEK_CUR : seek(fileTable^[gfile]^,filepos(fileTable^[gfile]^)+position);
    GF_SEEK_END : seek(fileTable^[gfile]^,filesize(fileTable^[gfile]^)+position);
  end;
  seekFileLow:=IOresult;
end;

function tellFilePositionLow(gfile:TGFile):longint;
begin
  tellFilePositionLow:=-1;
  if gfile<0 then exit;
  if fileTable^[gfile]=nil then exit;
  tellFilePositionLow:=filepos(fileTable^[gfile]^);
end;

function flushFileLow(gfile:TGFile):integer;
begin
  flushFileLow:=-1;
  if gfile<0 then exit;
  if fileTable^[gfile]=nil then exit;
  flushFileLow:=0;
end;

function fileEOFLow(gfile:TGFile):integer;
begin
  fileEOFLow:=-1;
  if gfile<0 then exit;
  if fileTable^[gfile]=nil then exit;
  fileEOFLow:=integer(eof(fileTable^[gfile]^));
end;

end.
