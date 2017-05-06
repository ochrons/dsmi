{$I dsmi.inc},crt;

var r,r2,r3,r4:real;
    w,w2,w3,w4:word;
    si:TSampleInfo;
    scard:TSoundcard;

begin
  r:=20;
  r2:=(1/r)*21050*10;
  w:=round(r2);
  writeln(w);
  with si do begin
    sample:=malloc(w+16);
    length:=w;
    loopstart:=0;
    loopend:=w-1;
    mode:=0;
    sampleid:=0;
  end;
  r2:=0;
  for w2:=0 to w do begin
    mem[seg(si.sample^):ofs(si.sample^)+w2]:=round(sin(r2)*127+128);
    r2:=r2+pi/((1/r)*21050);
{    mem[seg(si.sample^):ofs(si.sample^)+w2]:=255*byte(r3>r2/20);
    write(255*byte(r3>r2/20),'   '#13);
    r3:=r3+1;
    if r3>r2/10 then r3:=r3-r2/10;}
  end;
  initDSMI(20000,2048,0,@scard);
  gusStartVoice;
  cdiDownloadSample(0,si.sample,si.sample,w);
  cdiSetPanning(0,PAN_LEFT);
  cdiSetupChannels(0,1,nil);
  cdiSetInstrument(0,@si);
  cdiPlayNote(0,21050,64);
  readkey;
  nosound;
end.
