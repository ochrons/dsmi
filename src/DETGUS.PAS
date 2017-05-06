{ -------------------------------------------------------------------------- }
{                                                                            }
{                                 DETGUS.PAS                                 }
{                                 ----------                                 }
{                                                                            }
{                         (C) 1993 Jussi Lahdenniemi                         }
{         Original C file (C) 1993 Otto Chrons                               }
{                                                                            }
{ Detect GUS                                                                 }
{                                                                            }
{ -------------------------------------------------------------------------- }

unit detgus;

interface
uses cdi,mcp;

function detectGUS(scard:PSoundcard):integer;

implementation
uses dos;

procedure strip(var s:string);
begin
  while (s[1]=' ') and (s[0]>#0) do delete(s,1,1);
  while (s[length(s)]=' ') and (s[0]>#0) do dec(s[0]);
end;

function hex2dec(s:string):word;
const hs:string='0123456789ABCDEF';
var w,w2:word;
begin
  w:=0;
  for w2:=1 to length(s) do
    w:=w+(pos(s[w2],hs)-1) shl (4*(length(s)-w2));
  hex2dec:=w;
end;

Function detectGUS(scard:PSoundcard):integer;
var ptr           : pointer;
    dummy,DMA,DMA2,
    IRQ,IRQ2      : integer;
    s,s2          : string;
    w             : word;

begin
  s:=getenv('ULTRASND');
  if s='' then begin detectGUS:=-1; exit end;
  strip(s);
  w:=pos(',',s);
  s2:=copy(s,1,w-1);
  delete(s,1,w);
  scard^.ioPort:=hex2dec(s2);
  strip(s);
  w:=pos(',',s);
  s2:=copy(s,1,w-1);
  delete(s,1,w);
  val(s2,DMA,dummy);
  strip(s);
  w:=pos(',',s);
  s2:=copy(s,1,w-1);
  delete(s,1,w);
  val(s2,DMA2,dummy);
  strip(s);
  w:=pos(',',s);
  s2:=copy(s,1,w-1);
  delete(s,1,w);
  val(s2,IRQ,dummy);
  strip(s);
  val(s,IRQ2,dummy);
  scard^.dmaChannel:=DMA;
  scard^.dmaIRQ:=IRQ;
  s:='Gravis Ultrasound'#0;
  move(s[1],scard^.name,length(s));
  scard^.id:=ID_GUS;
  scard^.minrate:=19293;
  scard^.maxrate:=44100;
  scard^.stereo:=true;
  scard^.mixer:=true;
  scard^.sampleSize:=1;
  scard^.version:=$100;
  scard^.extraField[0]:=DMA2;
  scard^.extraField[1]:=IRQ2;
  detectGUS:=0;
end;

end.
