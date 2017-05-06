uses dos;
var r:registers;
    w:word;
begin
{  for w:=4000 downto 0 do begin
    r.ax:=$100;
    r.bx:=w;
    intr($31,r);
    if r.ax<>8 then break;
  end;}
  r.ax:=$100;
  r.bx:=3760 div 2;
  intr($31,r);
  r.ax:=$100;
  r.bx:=3760 div 2-1;
  intr($31,r);
  writeln(r.ax);
  swapvectors;
  exec(getenv('comspec'),'');
  swapvectors;
end.
