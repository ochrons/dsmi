uses gfdefaul,F_STDIO;

var gf:TGFile;
    ch:char;

begin
  initGeneralFileSys(20);
  gf:=openFile('669load.pas',GF_BINARY or GF_READ);
  if gf>=0 then begin
    while not (fileEOF(gf)>0) do begin
      readFile(gf,@ch,1);
      write(ch);
    end;
    closeFile(gf);
  end;
end.

