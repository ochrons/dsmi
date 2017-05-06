uses fssound,crt,mcp,cdi;

var si:TSampleInfo;
begin
  writeln(loadRaw('effect1.raw',si,false));
  cdiSetInstrument(3,@si);
  cdiPlayNote(3,11025,64);
  while not (keypressed and (readkey=#27)) do
    if (keypressed and (readkey=' ')) then cdiPlayNote(3,11025,64);
end.
