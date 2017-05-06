{$I dsmi.inc};

var l:longint;
    sc:TSoundCard;

begin
  initDSMI(22000,2048,0,@sc);
  for l:=0 to 1048575 do begin
    gusPoke(l,0);
    if l and 4095=0 then write(l,#13);
  end;
  writeln;
end.
