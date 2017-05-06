{* GFDEFAUL.PAS Default General File System (high level), maps directly
 *              to low level
 *
 * Copyright 1994 Jussi Lahdenniemi, original C version (C) 1994 Otto Chrons
 *
*}

unit gfdefaul;

interface
uses F_STDIO;

function initGeneralFileSys(maxFiles:integer):integer;
function openFile(name:PChar;modeflags:integer):TGFile;
function closeFile(gfile:TGFile):integer;
function readFile(gfile:TGFile;buffer:pointer;size:longint):longint;
function writeFile(gfile:TGFile;buffer:pointer;size:longint):longint;
function seekFile(gfile:TGFile;position:longint;whence:integer):integer;
function tellFilePosition(gfile:TGFile):longint;
function flushFile(gfile:TGFile):integer;
function fileEOF(gfile:TGFile):integer;

implementation

{$l gfdefaul.obj}

function initGeneralFileSys(maxFiles:integer):integer; external;
function openFile(name:PChar;modeflags:integer):TGFile; external;
function closeFile(gfile:TGFile):integer; external;
function readFile(gfile:TGFile;buffer:pointer;size:longint):longint; external;
function writeFile(gfile:TGFile;buffer:pointer;size:longint):longint; external;
function seekFile(gfile:TGFile;position:longint;whence:integer):integer; external;
function tellFilePosition(gfile:TGFile):longint; external;
function flushFile(gfile:TGFile):integer; external;
function fileEOF(gfile:TGFile):integer; external;

end.
