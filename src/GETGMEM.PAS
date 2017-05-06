{$I dsmi.inc};

var f:file;
    l:longint;
    b:array[0..2047] of byte;
    sc:TSoundCard;

begin
  initDSMI(22000,2048,0,@sc);
  assign(f,'gus.mem');
  rewrite(f,1);
  for l:=0 to 1048575 do begin
    b[l and 2047]:=gusPeek(l);
    if (l and 2047)=2047 then begin
      blockwrite(f,b,2048);
      write(l,#13);
    end;
  end;
  close(f);
  writeln;
end.
