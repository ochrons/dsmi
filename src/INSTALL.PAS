Program installDSMI;
{$M 8192,0,0}
uses crt,dos;

var fromd,tod:string;
    a:dirStr;
    b:nameStr;
    c:extStr;
    r:registers;
    oldCon,newNul:word;

Procedure error(s:string);
begin
  textcolor(lightred);
  writeln('ERROR ! ');
  writeln(s);
  writeln;
  writeln('Installation is not complete!');
  halt(1);
end;

Procedure init;
const s:string='NUL'#0;
begin
  r.ah:=$45;
  r.bx:=1;
  intr($21,r);
  oldCon:=r.ax;
  r.ah:=$3d;
  r.al:=2;
  r.ds:=seg(s);
  r.dx:=ofs(s[1]);
  intr($21,r);
  newNul:=r.ax;
end;

Function u(s:string):string;
var s2:string;
    w:word;
begin
  s2:=s;
  for w:=1 to length(s2) do s2[w]:=upcase(s2[w]);
  u:=s2;
end;

Procedure clOut;
begin
  r.ah:=$3e;
  r.bx:=1;
  intr($21,r);
  r.bx:=newNul;
  r.ah:=$46;
  r.cx:=1;
  intr($21,r);
end;

Procedure opOut;
begin
  r.ah:=$46;
  r.bx:=oldCon;
  r.cx:=1;
  intr($21,r);
end;

begin
  init;
  clrscr;
  textColor(lightGreen);
  writeln;
  writeln('              DSMI installation program (C) 1993 Jussi Lahdenniemi');
  writeln;
  writeln;
  textColor(white);
  write('Destination directory : ');
  readln(tod);
  fromd:=paramstr(0);
  fsplit(fromd,a,b,c);
  fromd:=a;
  writeln;
  textColor(lightmagenta);
  writeln('Installing, please wait..');
  {$I-}
  mkDir(tod);
  if IOresult<>0 then error('Invalid destination directory!');
  chDir(tod);
  mkDir('UNITS60');
  mkDir('UNITS70');
  mkDir('SOURCE');
  mkDir('EXAMPLES');
  chDir('UNITS60');
  textColor(white);
  writeln('Decompressing TP 6.0 units...');
  clOut;
  exec(fromd+'UNITS60.EXE','');
  opOut;
  if dosError<>0 then error('Unable to install TP 6.0 units! (Maybe too little disk space)');
  chDir('..\UNITS70');
  writeln('Decompressing TP 7.0 units...');
  clOut;
  exec(fromd+'UNITS70.EXE','');
  opOut;
  if dosError<>0 then error('Unable to install TP/BP 7.0 units! (Maybe too little disk space)');
  chDir('..\EXAMPLES');
  writeln('Decompressing example files...');
  clOut;
  exec(fromd+'EXAMPLES.EXE','');
  opOut;
  if dosError<>0 then error('Unable to install example files! (Maybe too little disk space)');
  chDir('..\SOURCE');
  writeln('Decompressing source files...');
  clOut;
  exec(fromd+'SOURCE.EXE','');
  opOut;
  if dosError<>0 then error('Unable to install source files! (Maybe too little disk space)');
  chDir('..');
  writeln;
  textColor(lightgreen);
  writeln('DSMI installation complete.');
  writeln('Now please add the directory '+u(tod)+'\UNITS70 or '+u(tod)+'\UNITS60');
  writeln('into your unit and include paths.');
  writeln;
  writeln;
  textColor(blink+white);
  writeln('Thanks for purchasing DSMI!');
end.
