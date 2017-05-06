Unit PuraPCJ;
Interface

Type Pal256T=Array[0..767] of byte;
     Pic256T=Array[0..63999] of byte;
     PPic256T=^Pic256T;

Procedure UnpackPCJ(Source:Pointer;Var PalDest:Pal256T;Var PictDest:PPic256T);

Implementation
uses dos;

Procedure UnPackPCJ;
var f:file;
    pal:^Pal256T;
    b,c:byte;
    x:word;
    pcd:^Pic256t;
    p:word;
    r:registers;

begin
  Pal:=Source;
  PalDest:=Pal^;
  Pcd:=Ptr(Seg(Source^),Ofs(Source^)+768);
  x:=0;
  p:=0;
  repeat
    b:=pcd^[p];
    inc(p);
    if b<128 then begin
      c:=pcd^[p];
      inc(p);
      fillchar(Pictdest^[x],b,c);
      inc(x,b);
    end else begin
      for c:=1 to (b-128) do Pictdest^[c-1+x]:=pcd^[p+c-1];
      inc(p,b-128);
      inc(x,b-128);
    end;
  until x>=63999;
end;

Begin end.