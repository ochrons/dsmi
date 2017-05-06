uses csupport;
var p,p2,p3:pointer;
begin
  writeln(memavail,',',maxavail);
  p:=malloc(10000);
  p2:=farmalloc(100000);
  p3:=farmalloc(231029);
  writeln(longint(p));
  writeln(longint(p2));
  writeln(longint(p3));
  writeln(memavail,',',maxavail);
  farfree(p2);
  p2:=farmalloc(150000);
  farfree(p3);
  free(p);
  farfree(p2);
  writeln(memavail,',',maxavail);
end.
