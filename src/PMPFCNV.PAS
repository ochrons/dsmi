uses dos;
var f:file;
    f2:file;
    w,w2,w3,w4:word;
    r:registers;

const ChrCount : byte = 93;

begin
  r.ax:=$13;
  intr($10,r);
  assign(f,'pmpfont.scx');
  reset(f,1);
  blockread(f,mem[$a000:0],778);
  blockread(f,mem[$a000:0],64000);
  close(f);
  for w:=0 to 63999 do if (mem[$a000:w]<>0) and (mem[$a000:w]<>255) then inc(mem[$a000:w],208);
  assign(f,'pmp.fnt');
  rewrite(f,1);
  blockwrite(f,ChrCount,1);
  w2:=0;
  for w:=0 to ChrCount-1 do begin
    w3:=w2;
    while mem[$a000:w3]<>$FF do inc(w3);
    w4:=w3-w2;
    blockwrite(f,w4,2);
    for w4:=0 to 15 do blockwrite(f,mem[$a000:w2+w4*320],w3-w2);
    mem[$a000:w2]:=12;
    inc(w3);
    while (mem[$a000:w3]<>$FF) and (w3 mod 320<>319) do inc(w3);
    inc(w3);
    if w3 mod 320=0 then inc(w3,16*320);
    w2:=w3;
  end;
  close(f);
end.
