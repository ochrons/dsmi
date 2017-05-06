(****************************************************************************

                                 DET_SB.PAS
                                 ----------

                          (C) 1993 Jussi Lahdenniemi

Turbo/Borland pascal unit header file for SB detection routines.
Original C header by Otto Chrons

****************************************************************************)

unit det_SB; { (C) 1993 Jussi Lahdenniemi }

interface
uses MCP;

Function  detectSB(SCard:PSoundCard):Integer;

implementation
uses dos,csupport;

{$L detSBHW.OBJ}
{$L detSB16H.OBJ}

Function  detectSBHW(SCard:PSoundCard):Integer; external;
Function  detectSBproHW(SCard:PSoundCard):Integer; external;
Function  detectSB16HW(SCard:PSoundCard):Integer; external;

Function getstr(s:string;p:integer):string;
var ss:string;
begin
  ss:='';
  while not (s[p] in [' ',#0,#13]) do begin ss:=ss+s[p]; inc(p) end;
  getstr:=ss;
end;

Function  detectSB(SCard:PSoundCard):Integer;
const sbname:string='Sound Blaster'#0;
      sbpname:string='Sound Blaster Pro'#0;
      sb16name:string='Sound Blater 16'#0;
var ptr,t:string;
    i,a,dma,irq,stype,e:integer;
begin
  ptr:=getenv('BLASTER')+#0;
  if ptr='' then begin
    a:=detectSB16HW(scard);
    if a<>0 then a:=detectSBProHW(scard);
    if a<>0 then a:=detectSBHW(scard);
    if a<>0 then detectSB:=-1 else detectSB:=0;
    exit;
  end;
  with scard^ do begin
    dmaChannel:=1;
    dmaIRQ:=7;
    ioPort:=$220;
    strcpy(name,sbname[1]);
    ID:=ID_SB;
    minRate:=4000;
    maxRate:=44100;
    stereo:=false;
    mixer:=false;
    sampleSize:=1;
    version:=$100;
    i:=0;
    while ptr[i+1]<>#0 do begin
      if ptr[i+1] in [' ',#13] then begin
        inc(i);
        continue;
      end;
      case upcase(ptr[i+1]) of
        'A' : begin
          t:=getstr(ptr,i+2);
          val('$'+t,ioport,e);
        end;
        'I' : begin
          t:=getstr(ptr,i+2);
          val(t,dmairq,e);
        end;
        'H',
        'D' : begin
          t:=getstr(ptr,i+2);
          val(t,dmachannel,e);
        end;
        'T' : begin
          t:=getstr(ptr,i+2);
          val(t,stype,e);
          case stype of
            1 : maxrate:=22222;
            3 : version:=$200;
            2,
            4,
            5 : begin
              ID:=ID_SBPRO;
              stereo:=true;
              mixer:=true;
              strcpy(name,sbpname[1]);
            end;
            else begin
              ID:=ID_SB16;
              stereo:=true;
              mixer:=true;
              samplesize:=2;
              strcpy(name,sb16name[1]);
            end;
          end;
        end;
      end;
      while not (ptr[i+1] in [#0,' ',#13]) do inc(i);
    end;
  end;
  detectSB:=0;
end;

end.
