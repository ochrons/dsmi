{$i dsmi.inc};

var mod1,mod2:pmodule;
begin
  writeln(memavail);
  mod1:=amploadmodule('\mod\boesendo.mod',0);
  writeln(memavail);
  mod2:=amploadmodule('\mod\lifemayc.mod',0);
  writeln(memavail);
  ampfreemodule(mod1);
  writeln(memavail);
  ampfreemodule(mod2);
  writeln(memavail);
end.
