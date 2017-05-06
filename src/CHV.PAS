uses dos;

var r:registers;

begin
  r.ax:=$400;
  intr($31,r);
  writeln(r.bx);
end.
