Program testPMPBAR2;
uses crt;

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

{$f+}
Procedure drawColorBars(p:PColorStruct); external;
{$L pmpbar2.obj}

var w,w2,w3:word;
    cs:TColorStruct;

begin
  asm mov ax,3; int 10h end;
  for w:=0 to 24 do begin
    for w2:= 2 to 20 do mem[segb800:w2*2+1+w*160]:=2*16;
    for w2:=21 to 39 do mem[segb800:w2*2+1+w*160]:=3*16;
    for w2:=40 to 58 do mem[segb800:w2*2+1+w*160]:=4*16;
    for w2:=59 to 77 do mem[segb800:w2*2+1+w*160]:=5*16;
  end;
  with cs do begin
    barCount:=4;
    emptyColor:=0;
    startRow:=0;
    exitRow:=215;
    barColor[0]:=2;
    barColor[1]:=3;
    barColor[2]:=4;
    barColor[3]:=5;
    barStart[0]:=130;
    barStart[1]:=100;
    barStart[2]:=0;
    barStart[3]:=10;
    dacEntry:=11;
    startRed:=0;
    endRed:=0;
    startGreen:=0;
    endGreen:=0;
    startBlue:=63;
    endBlue:=0;
    barEnd[0]:=180;
    barEnd[1]:=150;
    barEnd[2]:=120;
    barEnd[3]:=125;
  end;
  while not keypressed do begin
    drawColorBars(@cs);
    asm sti end;
  end;
end.
