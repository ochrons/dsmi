Program PMP; { Protected Module Player, (C) 1993 Jussi Lahdenniemi }

Uses MCP,GUS,AMP,CDI,Timeserv,Mixer,
     SDI__SB,SDI__PAS,SDI__SB16,SDI__ARIA,SDI__WSS,
     Det_SB,Det_PAS,Det_Aria,DetGUS,
     LoadM,Loaders,
     DOS,Memory,CRT,
     Csupport,dpmiApi;

{$f+,i-}

{ $define debug}

Const PMPversion : String = 'HGF';

var fil           : file;
    Scard         : TSoundCard;
    i             : integer;
    mcps          : TMCPstruct;
    playBuf       : Pointer;
    r             : registers;
    temps         : word;
    ch            : char;
    pollTag       : integer;
    modiTag       : integer;

Procedure hideCursor;
begin
  r.ah:=3;
  r.bh:=0;
  intr($10,r);
  r.cx:=r.cx or 8192;
  r.ah:=1;
  intr($10,r);
end;

Procedure showCursor;
begin
  r.ah:=3;
  r.bh:=0;
  intr($10,r);
  r.cx:=r.cx and (65535-8192);
  r.ah:=1;
  intr($10,r);
end;

Procedure disableBlink;
var b:byte;
begin
  b:=port[$3da];
  port[$3c0]:=$10+32;
  b:=port[$3c1];
  b:=b and (not 8);
  port[$3c0]:=b;
end;

Procedure enableBlink;
Var b:byte;
begin
  b:=port[$3da];
  port[$3c0]:=$10+32;
  b:=port[$3c1];
  b:=b or 8;
  port[$3c0]:=b;
end;

Procedure bkgrnd(cl:byte);
var b:byte;
begin
  {$ifdef debug}
  b:=port[$3da];
  port[$3c0]:=$11+32;
  port[$3c0]:=cl;
  {$endif}
end;

Procedure bkgrndABS(cl:byte);
var b:byte;
begin
  b:=port[$3da];
  port[$3c0]:=$11+32;
  port[$3c0]:=cl;
end;

Const palette:array[0..47] of byte = (00,00,20, 00,00,26, 00,00,40, 00,00,58,
                                      59,59,30, 00,57,30, 00,00,00, 17,17,17,
                                      23,23,23, 42,42,42, 61,00,27, 00,00,20,
                                      00,00,20, 00,00,20, 00,00,20, 60,60,63);

      paletteMap:array[0..15] of byte = (0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15);
      palRemOrder:array[0..15] of byte = (11,12,13,14,7,8,6,5,9,10,4,1,2,3,15,0);
      palRemRepl:array[0..15] of byte = (0,0,3,15,15,4,0,8,9,15,15,15,15,15,15,0);

      colorMask:array[0..3999] of byte =
( 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,
  1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1,
  1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1, 1,1,1,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,
  1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1,
  1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1, 1,1,1,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,
  1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1,
  1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1, 1,1,1,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,
  1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1,
  1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1, 1,1,1,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,
  1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1,
  1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1, 1,1,1,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,
  1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1,
  1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1, 1,1,1,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,
  1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1,
  1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1, 1,1,1,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,
  1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1,
  1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1, 1,1,1,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,
  1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1,
  1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1, 1,1,1,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,
  1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1,
  1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1, 1,1,1,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,
  1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1,
  1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1, 1,1,1,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,
  1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1,
  1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1, 1,1,1,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,
  1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1,
  1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1, 1,1,1,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,
  1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1,
  1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1, 1,1,1,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,
  1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1,
  1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1, 1,1,1,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,
  1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1,
  1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1, 1,1,1,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,
  1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1,
  1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1, 1,1,1,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,
  1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1,
  1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1, 1,1,1,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,
  1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1,
  1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1, 1,1,1,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,
  1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1,
  1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1, 1,1,1,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,
  1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1,
  1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1, 1,1,1,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,
  1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1,
  1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1, 1,1,1,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,
  1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1,
  1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1, 1,1,1,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,
  1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1,
  1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1, 1,1,1,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,
  1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1,
  1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1, 1,1,1,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,
  1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1,
  1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1, 1,1,1,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0);

Const yellow=4;
      lightgreen=5;
      lightred=10;
      green=9;

Var screenbuf:word;
    fakescreen:pointer;

Procedure setCorrectPalette;
var b,b2:byte;
begin
  b:=port[$3da];
  port[$3c0]:=0;
  b:=port[$3da];
  port[$3c0]:=$14;
  port[$3c0]:=0;
  for b:=0 to 15 do begin
    port[$3c0]:=b;
    port[$3c0]:=b;
  end;
  port[$3c8]:=0;
  for b:=0 to 47 do port[$3c9]:=palette[b];
  b:=port[$3da];
  port[$3c0]:=$20;
end;

Procedure makePaletteMap(barNr:integer);
var w,w2:integer;
begin
  for w:=0 to 15 do paletteMap[w]:=w;
  for w:=0 to barNr-1 do
    for w2:=0 to 15 do if paletteMap[w2]=palRemOrder[w] then
      paletteMap[w2]:=palRemRepl[paletteMap[w2]];
  w:=port[$3da];
  for w:=0 to barNr-1 do begin
    port[$3c0]:=palRemOrder[w];
    port[$3c0]:=0;
  end;
  for w:=barNr to 15 do begin
    port[$3c0]:=palRemOrder[w];
    port[$3c0]:=palRemOrder[w];
  end;
  port[$3c0]:=$20;
end;

const whereAmI:word=0; { offset }

Procedure updateScreen(count:word); external;
{$L PMPSCRN.OBJ}

Procedure headerPic(offs:word); Forward;

Procedure Break(s:String);         { Break if an error occurs }
Begin
  asm mov ax,3; int 10h end;
  textmode(co80);
  textbackground(black);
  clrScr;
  textcolor(blink+12);
  Write('* ERROR! * ');
  textcolor(12);
  Writeln(s);
  halt(1);
end;

Function getDVversion:Word; assembler;
asm
 mov cx,'DE'
 mov dx,'SQ'
 mov ax,2b01h
 int 21h
 cmp al,0ffh
 je @GV1
 mov ax,bx
 jmp @GV2
@GV1:
 sub ax,ax
@GV2:
end;

Function getWindowsVersion:Word;
begin
  r.ax:=$1600;
  intr($2f,r);
  case r.al of
    0,$80 : getWindowsVersion:=byte((getEnv('WINDIR')<>'') or (getEnv('windir')<>''));
    1,$ff : getWindowsVersion:=2;
  else getWindowsVersion:=r.ax;
  end;
end;

const hexs:string='0123456789ABCDEF';
Function hex(w:word):String;
var s:string;
begin
  s[0]:=#4;
  s[1]:=hexs[w shr 12+1];
  s[2]:=hexs[w shr 8 and 15+1];
  s[3]:=hexs[w shr 4 and 15+1];
  s[4]:=hexs[w and 15+1];
  while s[1]='0' do delete(s,1,1);
  hex:=s;
end;
Function decm(s:string):word;
var w,w2:word;
begin
  w:=0;
  for w2:=1 to length(s) do w:=w+(pos(upcase(s[length(s)-w2+1]),hexs)-1) shl (4*w2-4);
  decm:=w;
end;

const horizLine : string =
      'ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ';
      hlpKeys    = 1;
      hlpOpt     = 2;

Procedure helpThem(which:word);
const opts=13;
      optss:array[1..opts] of string[80]=(
      ' /Sn                - Set sampling rate n',
      ' /M                 - Force mono mode',
      ' /O                 - Scramble module orders',
      ' /L                 - Turn looping off',
      ' /Q                 - Quality mode playing on (8-bit cards)',
      ' /Bn                - Volume bar type:0=off,1=mid,2=top,3=bot',
      ' /H, /?             - This help screen',
      ' /V                 - Force V86 support',
      ' /Fn                - Force PMP to leave at least n kB of',
      '                      memory free for DOS shell',
      ' /Tn                - Force PMP to use a buffer of n bytes',
      ' /Pp, /Ii, /Dd, /Cc - Force PMP to use card c, IO p, IRQ i,',
      '                      DMA d (see PMP.DOC for details)'
      );

      keys=15;
      keyss:array[1..keys] of string[80]=(
      ' P, alt-F11         - Pause / resume module',
      ' N, alt-F12         - Next module',
      ' -/+, shift-F11/12  - Decrease / increase master volume',
      ' F1 - F10           - Set master volume quickly',
      ' H, ?               - This help screen',
      ' I                  - Help about command line parameters',
      ' S                  - Toggle SB Pro stereo mode on / off',
      ' B                  - Toggle the volume bars on/off',
      ' C                  - Clear the information screen',
      ' D                  - DOS shell',
      ' , , ctrl-F11/12  - Previous / next pattern',
      ' ,                - Scroll the module list window',
      ' 1, 2, 3, 4, ...    - Turn channel on/off',
      ' <, >               - Slower / faster update rate (see docs)',
      ' (, )               - Dec./inc. number of volume bars'
      );

var w:word;
begin
  textbackground(black);
  textcolor(lightgray);
  write(copy(horizLine,1,63));
  if which=hlpOpt then begin
    textColor(3);
    write('                    Command line options :'); clrEol; writeln;
    write('                    ~~~~~~~~~~~~~~~~~~~~~~'); clrEol; writeln;
    textColor(9);
    write(' PMP modulename [modulename] @listfile [/opt] [/opt]'); clrEol; writeln;
    clrEol; writeln;
    for w:=1 to opts do begin
      textcolor(yellow);
      write(copy(optss[w],1,20));
      textcolor(white);
      write(copy(optss[w],21,length(optss[w])-20)); clrEol; writeln;
    end;
  end else begin
    textColor(3);
    write('                     Keys while playing :'); clrEol; writeln;
    write('                     ~~~~~~~~~~~~~~~~~~~~'); clrEol; writeln;
    for w:=1 to keys do begin
      textcolor(yellow);
      write(copy(keyss[w],1,20));
      textcolor(white);
      write(copy(keyss[w],21,length(keyss[w])-20)); clrEol; writeln;
    end;
    clrEol; writeln;
    textcolor(lightgreen);
    write(' Commands with F11 and F12 are available also in the DOS shell ');
  end;
  textColor(lightgray);
  write(copy(horizLine,1,63));
end;

Const eyellow=14;
      elightgreen=10;
      elightred=12;
      egreen=2;

Procedure endScreen;
begin
  asm mov ax,3; int 10h end;
  textmode(co80);
  window(1,1,80,25);
  textcolor(lightgray);
  textbackground(black);
  clrScr;
  textColor(elightred);
  write(horizLine);
  textColor(eyellow);
  writeln(' Thanks for using PMP '+char(122-ord(PMPversion[1]))+'.'+char(122-ord(PMPversion[2]))+char(122-ord(PMPversion[3]))+
          '                         How to contact the authors :');
  textColor(elightred);
  write(horizLine);
  textColor(lightcyan);
  write(' Contact Jussi Lahdenniemi, if you     ');
  textColor(white);write('³');textColor(lightcyan);
  writeln(' Contact Otto Chrons, if you have some-');
  write(' have something to ask or comment      ');
  textColor(white);write('³');textColor(lightcyan);
  writeln(' thing to ask about DSMI generally or');
  write(' about PMP, or the Pascal version      ');
  textColor(white);write('³');textColor(lightcyan);
  writeln(' the C/ASM version of it.');
  write(' of DSMI.                              ');
  textColor(white);writeln('³');
  writeln('                                       ³');
  textColor(lightMagenta);
  write(' Jussi Lahdenniemi                     ');
  textColor(white);write('³');textColor(lightmagenta);
  writeln(' Otto Chrons');
  write(' Rautia                                ');
  textColor(white);write('³');textColor(lightmagenta);
  writeln(' Vaajakatu 5 K 199');
  write(' SF-36420 Sahalahti                    ');
  textColor(white);write('³');textColor(lightmagenta);
  writeln(' SF-33720 Tampere');
  write(' Finland                               ');
  textColor(white);write('³');textColor(lightmagenta);
  writeln(' Finland');
  write(' tel. (voice) +358-31-3763273          ');
  textColor(white);write('³');textColor(lightmagenta);
  writeln;
  write(' Fidonet 2:221/105.7                   ');
  textColor(white);write('³');textColor(lightmagenta);
  writeln(' Fidonet 2:221/105.10');
{  write(' CABiNET 112:911/320.7                 ');}
  write('                                       ');
  textColor(white);write('³');textColor(lightmagenta);
{  writeln(' CABiNET 112:911/320.10');}
  writeln('                       ');
  write(' Internet jlahd@clinet.fi              ');
  textColor(white);write('³');textColor(lightmagenta);
  writeln(' Internet otto.chrons@cc.tut.fi');
  write('                                       ');
  textColor(white);write('³');textColor(lightmagenta);
  writeln;
  textColor(elightred);
  write(horizLine);
  textColor(elightgreen);
  writeln(' Read the documentation for information about the DSMI programming interface!');
  textColor(elightred);
  write(horizLine);
end;

Procedure interpolate(sam:PInstrument);
var s2:pointer;
    w,w2:word;
begin
  if (sam^.sample=nil) or (sam^.size>32700) then exit;
  s2:=malloc(sam^.size*2-1);
  if s2=nil then exit;
  mem[seg(s2^):ofs(s2^)]:=mem[seg(sam^.sample^):ofs(sam^.sample^)];
  for w:=1 to sam^.size-1 do begin
    mem[seg(s2^):ofs(s2^)+w*2]:=
      mem[seg(sam^.sample^):ofs(sam^.sample^)+w];
    w2:=mem[seg(sam^.sample^):ofs(sam^.sample^)+w]+
        mem[seg(sam^.sample^):ofs(sam^.sample^)+w-1];
    w2:=w2 div 2;
    mem[seg(s2^):ofs(s2^)+w*2-1]:=w2;
  end;
  sam^.rate:=sam^.rate*2;
  sam^.size:=sam^.size*2;
  sam^.loopStart:=sam^.rate*2;
  sam^.loopEnd:=sam^.size*2;
  free(sam^.sample);
  sam^.sample:=s2;
end;

Procedure headerPic(offs:word);
{$I PMPHDR.PAS}
begin
  move(header,mem[segb800:offs],header_Length);
  mem[segb800:42*2+4*160+offs]:=122-ord(PMPversion[1]);
  mem[segb800:43*2+4*160+offs]:=ord('.');
  mem[segb800:44*2+4*160+offs]:=122-ord(PMPversion[2]);
  mem[segb800:45*2+4*160+offs]:=122-ord(PMPversion[3]);
  window(1,2,80,28);
end;

Const Srate      : word    = 21000;
      Scramble   : boolean = false;
      LoopIt     : boolean = true;
      frcMono    : boolean = false;
      bufferSiz  : word    = 2048;
      bufferCh   : boolean = false;
      quality    : boolean = false;
      vol        : byte    = 64;
      forceV86   : boolean = false;

      cstIO      : word    = 0;
      cstIRQ     : byte    = 0;
      cstDMA     : byte    = 16;
      cstCard    : byte    = 0;

      maxNames   = 512;
      modNameCnt : word    = 0;
      modPointer : word    = 0;

      cursor     : byte    = 1;
      oldRow     : word    = 0;
      curChar    : char    = 'þ';

      multitask  : word    = 0;

      memmodcnt  : word    = 0;
      modbplayed : word    = 0;

      nextMod    : boolean = false;

      quit       : boolean = false;

      reqWriteP  : word    = 0;
      resStereo  : boolean = false;
      reqUpdAll  : boolean = true;
      reqUpdIns  : boolean = true;
      reqUpdMod  : boolean = true;
      reqUpdBar  : boolean = true;

      mwStart    : word    = 1;

      len        : array[1..32] of byte = (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
                                           0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0);

      drawBars   : word    = 1;

      barRow     : word    = 0;

      updRate    : word    = 3;

      chn10p     : boolean = false;

      autoShell  : boolean = false;
      loadingStpd: boolean = false;

Type  TMemMod     = Record
        name      : String[63];
        module    : PModule;
      end;

      TModArr     = Array[1..maxNames] of ^TMemMod;

Var   modn       : string;
      modNames   : TModArr;
      mn         : TMemMod;
      w,w2,w3    : word;
      tet        : text;
      s          : string;
      d          : dirstr;
      e          : namestr;
      g          : extstr;
      processor  : byte;
      V86        : boolean;
      maxSize    : word;
      oldKeyb    : pointer;
      oldExit    : pointer;
      proStereo  : boolean;
      oldStereo  : boolean;
      cl1,cl2,cl3: shortint;
      dl1,dl2,dl3: shortint;
      tc1,tc2,tc3: shortint;
      td1,td2,td3: shortint;
      dispBarC   : word;
      old21      : byte;
      olda1      : byte;
      as1,as2    : string;

Function f(w:integer):word;
begin
  if (w mod 1000)<1 then f:=w+modNameCnt else
  if (w mod 1000)>modNameCnt then f:=w-modNameCnt else f:=w;
end;

Procedure moduleIntProc; forward;

Procedure moduleInt; interrupt;
begin
  moduleIntProc;
end;

Procedure loadModules;
var ch:char;

Procedure removeCurrent;
var w:word;
begin
  for w:=modPointer to modNameCnt-1 do modNames[w]:=modNames[w+1];
  dec(modNameCnt);
  modPointer:=f(modPointer-1);
end;

var tmpmod:PModule;
    w:word;

begin
  if f(modPointer+1)=modBPlayed then exit;
  if (modPointer>=1000) and (modPointer<2000) then exit;
  loadingStpd:=false;
  if modPointer<1000 then begin
    modPointer:=f(modPointer+1);
    if modNames[modPointer]^.module<>nil then exit;
    pollTag:=tsAddRoutine(@ampInterrupt,AMP_TIMER);
    modiTag:=tsAddRoutine(@moduleInt,1193180 div 100);
    tmpmod:=ampLoadModule(modNames[modPointer]^.name,LM_IML);
    textColor(lightgreen);
    if tmpmod<>nil then begin
{      if tmpMod^.instrumentCount>0 then
        for w:=0 to tmpmod^.instrumentCount-1 do interpolate(@tmpmod^.instruments^[w]);}
      writeln('Loaded ',modNames[modPointer]^.name,' (size ',tmpmod^.size div 1024,'k, ',
              memAvail div 1024,'k left)');
      reqUpdMod:=true;
      if f(modPointer+1)=(modBPlayed mod 1000) then begin
        textColor(3);
        writeln('All modules reside in the memory!');
        loadingStpd:=true;
      end;
    end else begin
      if moduleError=MERR_FILE then begin
        textColor(lightRed);
        writeln('File error loading module! Module will be removed from the play list.');
        removeCurrent;
      end else begin
        textColor(3);
        writeln('Module loading suspended due to low memory');
        loadingStpd:=true;
      end;
    end;
    if moduleError=MERR_MEMORY then inc(modPointer,999) else begin
      if moduleError=MERR_CORRUPT then begin
        write('Module was corrupted! Play anyway or remove from the playing list (P/R) ?');
        repeat
          ch:=readkey;
        until upcase(ch) in ['P','R'];
        writeln(upcase(ch));
        if upcase(ch)='P' then moduleError:=MERR_NONE else begin
          removeCurrent;
          tsRemoveRoutine(pollTag);
          tsRemoveRoutine(modiTag);
          exit;
        end;
      end;
      modNames[modPointer]^.module:=tmpMod;
      if (modBPlayed>=1000) and (modBPlayed<2000) then inc(modBPlayed,1000);
    end;
    tsRemoveRoutine(pollTag);
    tsRemoveRoutine(modiTag);
  end else begin
    dec(modPointer,2000);
    loadModules;
  end;
end;

Procedure moduleIntProc;
var old21:byte;
    w:word;
begin
  inline($66/$60);   { PUSHAD }
  old21:=port[$21];
  port[$21]:=old21 or 1;
  for w:=1 to dispBarC do if len[w]>0 then dec(len[w]);
  if _curModule.patternCount>0 then
  if (ampGetPattern=_curModule.patternCount-1) and (modNameCnt>1) then
    cdiSetMasterVolume(0,vol*(64-ampGetRow) div 64) else cdiSetMasterVolume(0,vol);
  if ((ampGetModuleStatus and MD_PLAYING=0) or nextMod) and (modBPlayed<1000) then begin
    if (ampGetModuleStatus and MD_PLAYING)>0 then ampStopModule;
    if (modPointer>=1000) and (modPointer<2000) then inc(modPointer,1000);
    if modBPlayed<>0 then
      if (f(modPointer+1)<>ModBPlayed) and (modNameCnt>1) then
        ampFreeModule(modNames[modBPlayed]^.module)
      else modPointer:=f(modPointer+1);
    modBPlayed:=f(modBPlayed+1);
    reqUpdIns:=true;
    if modNames[modBPlayed]^.module<>nil then begin
      cdiSetupChannels(0,modNames[modBPlayed]^.module^.channelCount,nil);
      if dispBarC<>modNames[modBPlayed]^.module^.channelCount then begin
        dispBarC:=modNames[modBPlayed]^.module^.channelCount;
        if dispBarC>16 then dispBarC:=16;
        reqUpdBar:=true;
      end;
      ampPlayModule(modNames[modBPlayed]^.module,PM_Loop*byte(loopIt and (modNameCnt=1)));
      reqWriteP:=modBPlayed;
    end else begin
      inc(modBPlayed,1000);
      reqWriteP:=0;
    end;
  end else if modBPlayed>=2000 then begin
    dec(modBPlayed,2000);
    if modNames[modBPlayed]^.module<>nil then begin
      cdiSetupChannels(0,modNames[modBPlayed]^.module^.channelCount,nil);
      if dispBarC<>modNames[modBPlayed]^.module^.channelCount then begin
        dispBarC:=modNames[modBPlayed]^.module^.channelCount;
        if dispBarC>16 then dispBarC:=16;
        reqUpdBar:=true;
      end;
      ampPlayModule(modNames[modBPlayed]^.module,PM_Loop*byte(loopIt and (modNameCnt=1)));
      reqWriteP:=modBPlayed;
      reqUpdIns:=true;
    end else begin
      inc(modBPlayed,1000);
      reqWriteP:=0;
    end;
  end;
  nextMod:=false;
  port[$21]:=old21;
  inline($66/$61); { POPAD }
end;

Procedure updateStatus;

Procedure writeL(ofs:word;w:word;n:byte);
var s:string;
begin
  str(w,s);
  asm
    push   ds
    mov    cl,[n]
    sub    cl,byte ptr [s[0]]
    mov    ax,segb800
    mov    es,ax
    mov    di,[ofs]
    mov    ax,32+blue*256*16+lightgreen*256
    rep    stosw
    mov    cl,byte ptr [s[0]]
    mov    ax,ss
    mov    ds,ax
    lea    si,s
    inc    si
    mov    ah,16*blue+lightgreen
@1: lodsb
    stosw
    loop   @1
    pop    ds
  end;
end;

Procedure writeR(ofs:word;w:word;n:byte);
var s:string;
begin
  str(w,s);
  asm
    push   ds
    mov    ax,segb800
    mov    es,ax
    mov    di,[ofs]
    mov    cl,byte ptr [s[0]]
    mov    ax,ss
    mov    ds,ax
    lea    si,s
    inc    si
    mov    ah,16*blue+lightgreen
@1: lodsb
    stosw
    loop   @1
    mov    cl,[n]
    sub    cl,byte ptr [s[0]]
    mov    ax,32+blue*256*16+lightgreen*256
    rep    stosw
    pop    ds
  end;
end;

var oldx,oldy:word;
    w,w2:word;
begin
  if _curModule.patternCount=0 then exit;
  writeL(9*2,ampGetPattern,3);
  writeR(15*2,_curModule.patternCount-1,3);
  writeL(25*2,ampGetRow,2);
  writeL(37*2,vol,2);
end;

const mwx1=63;
      mwy1=1;
      mwx2=79;
      mwy2=43;

Procedure moduleWindow;
var w,w2:word;
    b:dirStr;
    c:nameStr;
    d:extStr;
    ta:byte;
    xx,yy:word;

begin
  ta:=textAttr;
  xx:=whereX;
  yy:=whereY;
  textbackground(blue);
  window(mwx1+2,mwy1+2,mwx2,mwy2);
  for w:=0 to mwy2-mwy1-2 do begin
    gotoxy(1,w+1);
    if modNameCnt>=w+mwStart then begin
      textColor(lightred);
      if modNames[w+mwStart]^.module<>nil then write('û ') else write('  ');
      if reqUpdAll then begin
        fsplit(modNames[w+mwStart]^.name,b,c,d);
        textColor(5);
        write(c+d);
      end;
    end;
    if reqUpdAll then clrEol;
  end;
  window(1,2,63,28);
  textAttr:=ta;
  gotoxy(xx,yy);
  reqUpdAll:=false;
  reqUpdMod:=false;
end;

Procedure instWindow;
var w,w2:word;
    ta:byte;
    xx,yy:word;
    s:string;
begin
  ta:=textAttr;
  xx:=whereX;
  yy:=whereY;
  window(1,29,63,44);
  textbackground(1);
  textcolor(3);
  clrScr;
  for w:=0 to 15 do memw[segb800:28*160+31*2+w*160]:=179+256*(1*16+2);
  for w:=0 to 15 do begin
    fillchar(s[1],32,' ');
    if _curModule.instrumentCount>=w+1 then strcpy(s[1],_curModule.instruments^[w].name);
    for w2:=0 to 30 do mem[segb800:28*160+w*160+w2*2]:=ord(s[w2+1]);
    fillchar(s[1],32,' ');
    if _curModule.instrumentCount>=w+17 then strcpy(s[1],_curModule.instruments^[w+16].name);
    for w2:=0 to 30 do mem[segb800:28*160+32*2+w*160+w2*2]:=ord(s[w2+1]);
  end;
  textAttr:=ta;
  window(1,2,63,28);
  gotoxy(xx,yy);
  reqUpdIns:=false;
end;

Procedure FindMods(name:String);
Var sr:SearchRec;
    ps:dirStr;
    ns:nameStr;
    es:extStr;
begin
  Fsplit(name,ps,ns,es);
  FindFirst(name,ReadOnly+Archive,sr);
  while dosError=0 do begin
    if modNameCnt<maxNames then begin
      inc(modNameCnt);
      modNames[modNameCnt]:=malloc(sizeof(TMemMod));
      modNames[modNameCnt]^.name:=fexpand(ps+sr.name);
      modNames[modNameCnt]^.module:=nil;
    end;
    FindNext(sr);
  end;
end;

Procedure fadeAway;
Procedure waitsc;
var w:word;
begin
  for w:=0 to 100 do begin
    while port[$3da] and 1=0 do;
    while port[$3da] and 1=1 do;
  end;
end;
var w:word;
begin
  for w:=63 downto 0 do begin cdiSetMasterVolume(0,w*vol div 64); ampPoll; waitsc end;
  if scard.id<>ID_GUS then mcpClearBuffer;
end;

const keyDecVol = $8700;
      keyIncVol = $8800;
      keyDecPat = $8900;
      keyIncPat = $8a00;
      keyPause  = $8b00;
      keyNxtMod = $8c00;

Procedure newKeyb; Interrupt;
var ptt,ptc:word;
begin
  inline($9c/$ff/$1e/oldKeyb);
  if memw[seg0040:$1a]<>memw[seg0040:$1c] then begin
    ptt:=memw[seg0040:$1c];
    dec(ptt,2);
    if ptt<memw[seg0040:$80] then ptt:=ptt+memw[seg0040:$82]-memw[seg0040:$80];
    ptc:=memw[seg0040:ptt];
    if ptc=keyDecVol then if vol>0 then dec(vol) else else
    if ptc=keyIncVol then if vol<64 then inc(vol) else else
    if ptc=keyDecPat then ampBreakPattern(-1) else
    if ptc=keyIncPat then ampBreakPattern(1) else
    if ptc=keyPause  then if (ampGetModuleStatus and MD_Paused)>0 then ampResumeModule else ampPauseModule;
    if ptc=keyNxtMod then nextMod:=true else
      exit;
    memw[seg0040:$1c]:=ptt;
  end;
end;

Procedure myExit;
begin
  exitProc:=oldExit;
  setIntVec(9,oldKeyb);
  if resStereo then mixerSet(MIX_Stereo,byte(oldStereo));
  ampClose;
  if scard.id<>ID_GUS then mcpClose else gusClose;
  tsClose;
  showCursor;
  enableBlink;
end;

const clrRowCount = 64;

(*Procedure clrBars(iR,iG,iB,dR,dG,dB,c1,c2,r1,r2,r3,r4:shortint;sRow:Word); external;
{$L pmpbar.obj}*)

type PColorStruct = ^TColorStruct;
     TColorStruct = Record
       barCount   : byte;
       emptyColor : byte;
       startRow   : word;
       exitRow    : word;
       barColor   : array[0..15] of byte;
       barStart   : array[0..15] of word;
       barEnd     : array[0..15] of word;
       startRed   : byte;
       startGreen : byte;
       startBlue  : byte;
       endRed     : byte;
       endGreen   : byte;
       endBlue    : byte;
       dacEntry   : byte;
       status     : array[0..15] of byte;
     end;

Procedure drawColorBars(p:PColorStruct;gus:boolean;ports:word); external;
{$L pmpbar2.obj}

const envCnt:word=0;
var envs:array[1..100] of string[63];

Procedure clipEnv(s:string);
var ss:string;
begin
  ss:=s;
  if pos(' ',ss)>0 then begin
    clipEnv(copy(ss,1,pos(' ',s)-1));
    delete(ss,1,pos(' ',s));
    clipEnv(ss);
  end else begin
    inc(envCnt);
    envs[envCnt]:=s;
  end;
end;

var bkLn:array[0..62] of word;

Procedure changeBarScreen(barcount:word);
var r,r2,r3:real;
    w,w2:word;
begin
  fillchar(bkLn,126,0);
  if barcount=0 then exit;
  r:=64/barcount-1;
  r2:=0;
  for w:=0 to barcount-1 do begin
    r3:=r2+r;
    for w2:=round(r2) to round(r3) do bkLn[w2]:=palRemOrder[w]*16*256;
    r2:=r3+1;
  end;
end;

Procedure fillbk(stRow:word);
begin
  asm
       push    ds
       mov     ax,segb800
       mov     es,ax
       mov     di,1*160
       mov     ax,[stRow]
       mov     bx,160
       mul     bx
       add     di,ax
       mov     ax,seg bkLn
       mov     ds,ax
       lea     si,bkLn
       mov     dx,2
@out:  mov     cx,63
@in:   mov     ax,[es:di]
       and     ax,0fffh
       or      ax,[ds:si]
       stosw
       add     si,2
       loop    @in
       sub     si,63*2
       add     di,17*2
       dec     dx
       jnz     @out
       pop     ds
  end;
end;

Function paramCount:word;
begin
  paramCount:=system.paramCount+envCnt;
end;

Function paramStr(w:word):string;
begin
  if w=0 then paramStr:=system.paramstr(0) else
  if w<=envCnt then paramstr:=envs[w] else
  paramstr:=system.paramstr(w-envCnt);
end;

var trackData:PTrackData;
    trackTime:Array[1..32] of word;
    cs:TColorStruct;

begin
{  getmem(fakescreen,160*50+16);}
  screenbuf:=dpmiSeg2slc($b9f4);
{  getmem(modNames,sizeof(TModArr));}
{  segb800:=seg(fakescreen^);}
  getintvec(9,oldKeyb);
  setintvec(9,@newKeyb);
  oldExit:=exitProc;
  exitProc:=@myExit;
  r.ax:=3;
  intr($10,r);
  textMode(co80+font8x8);
  portw[$3d4]:=16*256+$c;
  portw[$3d4]:=0*256+$d;
  setCorrectPalette;
  hideCursor;
  disableBlink;
  clrScr;
  window(1,1,80,1);
  textbackground(blue);
  textcolor(white);
  clrScr;
  write(' Pattern    /       Row      Volume                         Press H/I for help');
  headerPic(44*160);
  textbackground(black);
  clipEnv(getEnv('PMP'));
  if paramcount=0 then begin
    textColor(lightgreen);
    writeln('Use the switch /? or /h for the help screen.');
    halt(0);
  end;
  mem[segb800:mwx1*2+mwy1*160]:=218;
  mem[segb800:mwx2*2+mwy1*160]:=191;
  mem[segb800:mwx1*2+mwy2*160]:=192;
  mem[segb800:mwx2*2+mwy2*160]:=217;
  for w:=mwx1+1 to mwx2-1 do begin
    mem[segb800:w*2+mwy1*160]:=196;
    mem[segb800:w*2+mwy2*160]:=196;
  end;
  for w:=mwy1+1 to mwy2-1 do begin
    mem[segb800:mwx1*2+w*160]:=179;
    mem[segb800:mwx2*2+w*160]:=179;
  end;
  for w:=mwy1 to mwy2 do
    for w2:=mwx1 to mwx2 do
      mem[segb800:w*160+w2*2+1]:=1*16+2;
  window(1,2,63,28);
  modn:='';
  for w:=1 to paramcount do begin
    s:=paramstr(w);
    if (s[1]='-') or (s[1]='/') then
      case upcase(s[2]) of
        'S' : begin
                delete(s,1,2);
                val(s,r.bx,integer(r.cx));
                if (r.bx>=4) and (r.bx<=44) then r.bx:=r.bx*1000;
                if (r.bx<4000) or (r.bx>44100) then Break('Sampling rate must be between 4000 and 44100.');
                srate:=r.bx;
              end;
        'M' : frcMono:=true;
        'O' : Scramble:=true;
        'L' : LoopIt:=False;
        'Q' : quality:=True;
        '?',
        'H' : begin
            textmode(co80);
            textbackground(black);
            clrScr;
            headerPic(0);
            window(1,7,63,25);
            HelpThem(hlpOpt);
            halt(0)
          end;
        'F' : begin
                delete(s,1,2);
                val(s,r.bx,integer(r.cx));
                mallocMinLeft:=longint(r.bx)*1024;
              end;
        'T' : begin
                delete(s,1,2);
                val(s,r.bx,integer(r.cx));
                if (r.bx<=0) or (r.bx>32000) then Break('Buffer size must be between 1 and 30000.');
                bufferSiz:=r.bx;
                bufferCh:=true;
                multitask:=2;
              end;
        'P' : begin
                delete(s,1,2);
                cstIO:=decm(s);
              end;
        'I' : begin
                delete(s,1,2);
                val(s,cstIRQ,integer(r.cx));
              end;
        'D' : begin
                delete(s,1,2);
                val(s,cstDMA,integer(r.cx));
              end;
        'C' : begin
                delete(s,1,2);
                val(s,cstCard,integer(r.cx));
                if not cstCard in [1..8] then Break('Soundcard number must be between 1 and 5.');
              end;
        'V' : forceV86:=true;
        'B' : begin
                delete(s,1,2);
                val(s,drawBars,integer(r.cx));
              end;
        'A' : autoShell:=true;
      end
    else begin
      modn:=paramstr(w);
      if (modn[1]='@') and (length(modn)>1) then begin
        delete(modn,1,1);
        assign(tet,modn);
        reset(tet);
        while not eof(tet) do begin
          readln(tet,modn);
          fsplit(modn,d,e,g);
          r.bx:=modNameCnt;
          FindMods(modn);
          if (g='') and (r.bx=modNameCnt) then begin
            g:='.AMF';
            FindMods(d+e+g);
            g:='.MOD';
            FindMods(d+e+g);
            g:='.STM';
            FindMods(d+e+g);
            g:='.S3M';
            FindMods(d+e+g);
            g:='.669';
            FindMods(d+e+g);
            g:='.MTM';
            FindMods(d+e+g);
            g:='.FAR';
            FindMods(d+e+g);
          end;
        end;
        close(tet);
      end else begin
        fsplit(modn,d,e,g);
        r.bx:=modNameCnt;
        FindMods(modn);
        if (g='') and (r.bx=modNameCnt) then begin
          g:='.AMF';
          FindMods(d+e+g);
          g:='.MOD';
          FindMods(d+e+g);
          g:='.STM';
          FindMods(d+e+g);
          g:='.S3M';
          FindMods(d+e+g);
          g:='.669';
          FindMods(d+e+g);
          g:='.MTM';
          FindMods(d+e+g);
          g:='.FAR';
          FindMods(d+e+g);
        end;
      end;
    end;
  end;
  if modNameCnt=0 then Break('No files found!');
  randomize;
  if Scramble then
    for r.ax:=0 to modNameCnt*100 do begin
      r.cx:=random(modNameCnt)+1;
      r.dx:=random(modNameCnt)+1;
      if r.cx<>r.dx then begin
        longint(modNames[r.cx]):=longint(modNames[r.cx]) xor longint(modNames[r.dx]);
        longint(modNames[r.dx]):=longint(modNames[r.dx]) xor longint(modNames[r.cx]);
        longint(modNames[r.cx]):=longint(modNames[r.cx]) xor longint(modNames[r.dx]);
      end;
{      mn:=modNames[r.cx];
      modNames[r.cx]:=modNames[r.dx];
      modNames[r.dx]:=mn;}
    end;

  textcolor(magenta);
  if paramcount=0 then begin
    Writeln('Please specify the module name on the command line!');
    halt(1);
  end;
  if (cstIO<>0) or (cstIRQ<>0) or (cstDMA<>16) or (cstCard<>0) then begin
    if cstDMA=16 then scard.dmaChannel:=1 else scard.dmaChannel:=cstDMA;
    scard.sampleSize:=1;
    scard.stereo:=not frcMono;
    scard.minRate:=4000;
    scard.maxRate:=22222;
    case cstCard of
      1 : begin
            scard.ID:=ID_SB;
            scard.stereo:=false;
          end;
      2 : scard.ID:=ID_SBPro;
      3 : begin
            scard.ID:=ID_PASPLUS;
            if cstIO=0 then cstIO:=$388;
            scard.maxrate:=22222;
          end;
      4 : begin
            scard.ID:=ID_PAS16;
            scard.samplesize:=2;
            if cstIO=0 then cstIO:=$388;
            if cstDMA=16 then scard.dmaChannel:=5;
            scard.maxrate:=44100;
          end;
      5 : begin
            scard.ID:=ID_SB16;
            scard.samplesize:=2;
            if cstIRQ=0 then cstIRQ:=5;
            scard.maxrate:=44100;
          end;
      6 : begin
            scard.ID:=ID_ARIA;
            scard.maxrate:=44100;
          end;
      7 : begin
            scard.ID:=ID_WSS;
            scard.maxrate:=44100;
          end;
      8 : begin
            scard.ID:=ID_GUS;
            scard.maxrate:=44100;
          end;
    else Break('You have to specify the soundcard with the option -c.');
    end;
    if cstIRQ=0 then cstIRQ:=7;
    if cstIO=0 then cstIO:=$220;
    scard.IOport:=cstIO;
    scard.dmaIRQ:=cstIRQ;
  end else begin
    if detectGUS(@Scard)<>0 then
    if detectPAS(@Scard)<>0 then
    if detectAria(@Scard)<>0 then
    if detectSB(@Scard)<>0 then Break('No soundcard found!');
    textcolor(yellow);
    with scard do begin
      writeln('þ Using ',name,' found at ',hex(IOport),'h,');
      writeln('  DMA IRQ number ',dmaIRQ,', DMA channel ',dmaChannel);
    end;
  end;
  dpmiVersion(r.al,r.al,processor,r.bx);
  V86:=(r.bx and 2)<>2;
  textcolor(yellow);
  write('þ Processor : ');
  case processor of
    2 : writeln('80286');
    3 : write('80386, ');
    4 : write('80486, ');
  end;
  if processor<3 then Break('You need at least a 386sx to run this program!');
  if not V86 then write('not ');
  writeln('in the V86 mode.');
  if forceV86 then begin
    writeln('þ Forced to V86 mode!');
    V86:=true;
  end;
  writeln('þ Free memory ',memAvail div 1024,' kilobytes.');
  w:=getDVversion;
  if w<>0 then begin
    writeln('þ Detected DesqView ',w div 256,'.',w and $ff);
    multitask:=multitask or 1;
  end else begin
    w:=getWindowsVersion;
    if w>0 then
    if w=1 then writeln('þ Detected Windows 3.xx in standard or real mode') else
    if w=2 then writeln('þ Detected Windows/386 2.xx') else
                writeln('þ Detected Windows ',w and $ff,'.',w div 256,' in enhanced mode');
    if w>1 then multitask:=multitask or 1;
  end;
  i:=1;
  if frcMono then scard.Stereo:=false;
  case Scard.id of
    ID_SB    : i:=mcpInitSoundDevice(SDI_SB,@Scard);
    ID_SBPRO : i:=mcpInitSoundDevice(SDI_SBPro,@Scard);
    ID_ARIA  : i:=mcpInitSoundDevice(SDI_ARIA,@Scard);
    ID_PAS,
    ID_PASPLUS,
    ID_PAS16 : i:=mcpInitSoundDevice(SDI_PAS,@Scard);
    ID_SB16  : i:=mcpInitSoundDevice(SDI_SB16,@Scard);
    ID_WSS   : i:=mcpInitSoundDevice(SDI_WSS,@Scard);
    ID_GUS   : i:=0;
  end;
  If i<>0 then Break('Unable to initialize the soundcard!');

  if Scard.id<>ID_GUS then begin
    if multitask=1 then bufferSiz:=16384 else
    if (multitask=0) and not bufferCh then
      bufferSiz:=(srate div 30)*(2*(1+byte(scard.stereo)))*scard.sampleSize;
    with mcps do begin
      samplingRate:=srate;
      Options:=mcp_Quality*byte(quality)+mcp_486*byte(processor>=7);
      bufferSize:=bufferSiz*2;
      reqSize:=bufferSiz;
      if V86 then begin
        maxSize:=4096;
        while dpmiAllocDOS(maxSize,w3,temps)<>0 do dec(maxSize);
  {      if maxSize<>3760 then begin
          w3:=textAttr;
          textcolor(white+blink);
          textbackground(red);
          writeln('PMP debug :                                          ');
          writeln('Please report this number to Jussi Lahdenniemi : ',maxSize);
          writeln('Report also your system configuration, drivers etc.  ');
          writeln('Press any key..                                      ');
          readkey;
          textAttr:=w3;
        end;}
        dpmiFreeDOS(temps);
        dec(maxSize,1);
        w2:=(bufferSize+MCP_TableSize+MCP_QualitySize) div 16+1;
        dpmiAllocDOS(maxSize-w2,w3,temps);
        dpmiAllocDOS(w2,w3,bufferSeg);
        bufferPhysical:=dpmiGetLinearAddr(bufferSeg);
        dpmiFreeDOS(temps);
      end else begin
        getmem(playBuf,bufferSize+816+MCP_TableSize+MCP_QualitySize);
        bufferSeg:=seg(playBuf^);
        bufferPhysical:=dpmiGetLinearAddr(bufferSeg);
      end;
    end;
    i:=0;
    i:=i or tsInit;
    i:=i or mcpInit(@mcps);
    i:=i or cdiInit;
    i:=i or cdiRegister(@CDI_MCP,0,31);
  end else begin
    drawBars:=0;
    i:=tsInit;
    i:=i or gusInit(@Scard);
    i:=i or gushmInit;
    i:=i or cdiInit;
    i:=i or cdiRegister(@CDI_GUS,0,31);
  end;
  i:=i or ampInit(0);
  if scard.id<>ID_GUS then begin
    mcpStartVoice;
    if scard.id=ID_SBPro then begin
      mixerInit(MIXER_SBPro,scard.IOport);
      byte(oldStereo):=mixerGet(MIX_STEREO);
      proStereo:=not frcMono;
      mixerSet(MIX_Stereo,byte(proStereo));
      resStereo:=true;
    end;
  end else begin
    gusStartVoice;
    tsAddRoutine(@gusInterrupt,GUS_TIMER);
  end;
  if i<>0 then break('Could not initialize the player!');
  for w:=1 to 16 do trackTime[w]:=65535;
  randomize;
  if autoShell then writeln('þ AutoShell mode initiated');
  cl1:=0;
  cl2:=0;
  cl3:=20;
  dl1:=0;
  dl2:=0;
  dl3:=20;
  tc1:=random(48);
  tc2:=random(48);
  tc3:=16+random(48);
  td1:=random(48);
  td2:=random(48);
  td3:=16+random(48);
  with cs do begin
    emptyColor:=0;
    startRow:=0;
    exitRow:=215;
    for w:=0 to 15 do barColor[w]:=palRemOrder[w];
    barStart[0]:=0;
    barStart[1]:=0;
    barStart[2]:=0;
    barStart[3]:=0;
    barEnd[0]:=400;
    barEnd[1]:=400;
    barEnd[2]:=400;
    barEnd[3]:=400;
    dacEntry:=11;
  end;
  for w:=0 to 24 do fillbk(w);
  updateScreen(160*50);

  repeat
    bkgrnd(0);
    if (drawBars>0) and (dispBarC>0) then begin
      with cs do begin

        case drawBars of
          1 : for w:=0 to dispBarC-1 do begin
                barStart[w]:=111-round(len[w+1]*1.625);
                barEnd[w]:=round(len[w+1]*1.625)+111;
              end;
          2 : for w:=0 to dispBarC-1 do begin
                barStart[w]:=0;
                barEnd[w]:=round(len[w+1]*3.25)+4;
              end;
          3 : for w:=0 to dispBarC-1 do begin
                barStart[w]:=215-round(len[w+1]*3.25);
                barEnd[w]:=400;
              end;
        end;

        barCount:=dispBarC;
        startRed:=cl1;
        startGreen:=cl2;
        startBlue:=cl3;
        endRed:=dl1;
        endGreen:=dl2;
        endBlue:=dl3;
      end;
      old21:=port[$21]; olda1:=port[$a1];
      drawColorBars(@cs,scard.id=ID_GUS,(not (1 shl scard.dmairq)) and (not 4));

      fillbk(barRow);
      inc(barRow,2);
      if barRow=26 then barRow:=0;
      if cl1<tc1 then inc(cl1) else if cl1>tc1 then dec(cl1) else tc1:=random(48);
      if cl2<tc2 then inc(cl2) else if cl2>tc2 then dec(cl2) else tc2:=random(48);
      if cl3<tc3 then inc(cl3) else if cl3>tc3 then dec(cl3) else tc3:=16+random(48);
      if dl1<td1 then inc(dl1) else if dl1>td1 then dec(dl1) else td1:=random(48);
      if dl2<td2 then inc(dl2) else if dl2>td2 then dec(dl2) else td2:=random(48);
      if dl3<td3 then inc(dl3) else if dl3>td3 then dec(dl3) else td3:=16+random(48);
    end else if scard.id<>ID_GUS then begin
      if scard.id<>ID_GUS then asm cli end
                          else begin
                            old21:=port[$21];
                            olda1:=port[$a1];
                            w:=(not (1 shl scard.dmairq)) and (not 4);
                            port[$21]:=lo(w);
                            port[$a1]:=hi(w);
                          end;
      while port[$3da] and 8=0 do;
      while port[$3da] and 8=8 do;
      while port[$3da] and 1=1 do;
      while port[$3da] and 1=0 do;
    end;
    if scard.id<>ID_GUS then bkgrndABS(63);
    ampPoll;
    {$IFDEF DEBUG}
    bkgrnd(10);
    {$ELSE}
    if scard.id<>ID_GUS then bkgrndABS(0);
    {$ENDIF}
    moduleIntProc;
    updateScreen(160*updRate);
    if scard.id<>ID_GUS then asm sti end
                        else begin
                          port[$21]:=old21;
                          port[$a1]:=olda1;
                        end;
    if dispBarC>0 then
    for w:=0 to dispBarC-1 do begin
      w2:=w;
      trackData:=ampGetTrackData(w2);
      if (trackData^.playTime<trackTime[w2+1]) and
         (ampGetTrackStatus(w2) and TR_MUTED=0) then len[w+1]:=trackData^.volume;
      if trackData^.playTime>0 then trackTime[w2+1]:=trackData^.playTime;
    end;
    loadModules;
    updateStatus;
    if reqUpdBar then begin
      if drawBars>0 then makePaletteMap(dispBarC) else makePaletteMap(0);
      if drawBars>0 then changeBarScreen(dispBarC) else changeBarScreen(0);
      for w:=0 to 24 do fillbk(w);
      updateScreen(160*50);
      reqUpdBar:=false;
    end;
    if reqUpdMod then moduleWindow;
    if reqUpdIns then instWindow;
    if reqWriteP>0 then begin
      textcolor(green);
      writeln('Playing ',modNames[reqWriteP]^.module^.name);
      reqWriteP:=0;
    end;
    if ampGetRow<>oldRow then begin
      oldRow:=ampGetRow;
      textcolor(10+blink);
      textbackground(11);
      write(curChar,#13);
      textbackground(0);
    end;
    if keypressed then ch:=upcase(readkey) else ch:=#255;
    if autoShell and loadingStpd then ch:='d';
    if ch<>#255 then
    case ch of
      'P' : if (ampGetModuleStatus and MD_Paused)=0 then begin
              ampPauseModule;
              textcolor(green);
              writeln('Module paused');
            end else begin
              ampResumeModule;
              textcolor(green);
              writeln('Module resumed');
            end;
      '+' : if vol<64 then inc(vol);
      '-' : if vol>0 then dec(vol);
      '<' : if updRate>1 then dec(updRate);
      '>' : if updRate<25 then inc(updRate);
      '(' : if dispBarC>1 then begin dec(dispBarC); reqUpdBar:=true end;
      ')' : if dispBarC<16 then begin inc(dispBarC); reqUpdBar:=true end;
      'H',
      '?' : helpThem(hlpKeys);
      'I' : helpThem(hlpOpt);
      'C' : clrScr;
      'N' : begin fadeAway; ampStopModule; nextMod:=true; end;
      'S' : if scard.ID=ID_SBPro then begin
              proStereo:=not proStereo;
              mixerSet(MIX_Stereo,byte(proStereo));
            end;
      'B' : {if scard.id<>ID_GUS then} begin
              if drawBars=3 then drawBars:=0 else inc(drawBars);
              reqUpdBar:=true;
            end;
      'd','D' : begin
              pollTag:=tsAddRoutine(@ampInterrupt,AMP_Timer);
              modiTag:=tsAddRoutine(@moduleInt,1193180 div 100);
              asm mov ax,3; int 10h end;
              textmode(co80);
              gotoxy(1,2);
              showCursor;
              textcolor(lightmagenta);
              if ch='d' then write('Auto');
              writeln('Shelling to DOS..');
              swapvectors;
              if ch='d' then
                exec(getenv('COMSPEC'),'/CPMPSTART.BAT')
              else exec(getenv('COMSPEC'),'');
              swapvectors;
              if ch='d' then quit:=true;
              r.ax:=3;
              intr($10,r);
              textMode(co80+font8x8);
              hideCursor;
              setCorrectPalette;
              clrScr;
              window(1,1,80,1);
              textbackground(blue);
              textcolor(white);
              clrScr;
              write(' Pattern    /       Row      Volume                         Press H/I for help');
              headerPic(44*160);
              mem[segb800:mwx1*2+mwy1*160]:=218;
              mem[segb800:mwx2*2+mwy1*160]:=191;
              mem[segb800:mwx1*2+mwy2*160]:=192;
              mem[segb800:mwx2*2+mwy2*160]:=217;
              for w:=mwx1+1 to mwx2-1 do begin
                mem[segb800:w*2+mwy1*160]:=196;
                mem[segb800:w*2+mwy2*160]:=196;
              end;
              for w:=mwy1+1 to mwy2-1 do begin
                mem[segb800:mwx1*2+w*160]:=179;
                mem[segb800:mwx2*2+w*160]:=179;
              end;
              for w:=mwy1 to mwy2 do
                for w2:=mwx1 to mwx2 do
                  mem[segb800:w*160+w2*2+1]:=blue*16+white;
              window(1,2,63,28);
              textbackground(black);
              textcolor(2);
              if dosError<>0 then begin
                textColor(lightred);
                writeln('Unable to shell! Probably not enough memory.');
              end else
              writeln('Returned from the DOS shell');
              textcolor(green);
              if (modBPlayed<1000) and (modNames[modBPlayed]^.module<>nil) then
              writeln('Playing ',modNames[modBPlayed]^.module^.name,' ...');
              disableBlink;
              reqWriteP:=0;
              reqUpdIns:=true;
              reqUpdAll:=true;
              reqUpdMod:=true;
              tsRemoveRoutine(pollTag);
              tsRemoveRoutine(modiTag);
            end;
      'Z' : begin
              textcolor(15);
              writeln('Congratulations! You have found the secret key! Be proud of it!');
            end;
      'G' : if scard.id=ID_GUS then gushmShowHeap;
      #0  : begin
              ch:=readkey;
              case ch of
                #59..#68 : vol:=round((ord(ch)-58)*6.4);
                #75      : ampBreakPattern(-1);
                #77      : ampBreakPattern(1);
                #72      : begin if mwStart>1 then dec(mwStart); reqUpdAll:=true end;
                #80      : if mwStart+mwy2-mwy1-2<modNameCnt then begin inc(mwStart); reqUpdAll:=true end;
                #120..
                #129     : chn10p:=true;
              end;
            end;
    end;
    if (_curModule.patternCount>0) and (ch in ['0'..'9']) then begin
      if ch='0' then ch:=char(byte('9')+1);
      if ch in ['1'..char(_curModule.channelCount+ord('0'))] then begin
        r.ax:=ord(ch)-ord('1'); {curModule.channelPanning[ord(ch)-ord('1')];}
        if (ampGetTrackStatus(r.ax) and TR_MUTED)>0 then ampUnmuteTrack(r.ax)
                                                     else ampMuteTrack(r.ax);
      end;
    end;
    if chn10p and (_curModule.patternCount>10) then
      if ch in [#120..char(_curModule.channelCount+109)] then begin
        r.ax:=ord(ch)-110; {curModule.channelPanning[ord(ch)-ord('1')];}
        if (ampGetTrackStatus(r.ax) and TR_MUTED)>0 then ampUnmuteTrack(r.ax)
                                                     else ampMuteTrack(r.ax);
      end;
    chn10p:=false;
  until (ch in [#27]) or quit;
  fadeAway;
  ampStopModule;
  endScreen;
end.
