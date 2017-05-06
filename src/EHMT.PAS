Program EmsHeapManagerTest;
uses emhm;
var han1,han2:TEMSH;
    ptr:pointer;
begin
  writeln(emsInit(0,1024));
  han1:=emsAlloc(32768);
  writeln(han1);
  han2:=emsAlloc(162763);
  writeln(han2);
  ptr:=emsLock(han1,0,32768);
  writeln(longint(ptr));
  emsClose;
end.
