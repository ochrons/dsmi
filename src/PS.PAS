(****************************************************************************

                                 EXAMPLE3.PAS
                                 ------------

                          (C) 1993 Jussi Lahdenniemi

Example program #3 for DSMI tutorial

****************************************************************************)

{$I dsmi.inc} ,gus,cdi;

var sample : TSampleInfo;
    scard  : TSoundcard;
    w      : longint;
    f      : file;
begin
  assign(f,paramstr(1));
  {$I-} reset(f,1); {$I+}
  if IOresult<>0 then begin writeln('No sam'); halt(1) end;
  writeln(scard.name);
  with sample do begin
    sample:=malloc(sizeof(f)+8);
    blockread(f,sample^,sizeof(f));
    close(f);
    length:=sizeof(f);
    loopstart:=0;
    loopend:=0;
    mode:=0;
    sampleID:=0;
  end;
  if initDSMI(21000,2048,0,@scard)<>0 then exit;  { Error }
  if scard.id<>ID_GUS then begin
    mcpStartVoice;
    mcpOpenChannels(1,volume_Linear,nil);
  end else begin
    gusStartVoice;
  end;
  cdiDownloadSample(0,longint(sample.sample),32,sample.length);
  cdiSetInstrument(0,@sample);
  cdiPlayNote(0,8448,64);
  readln;
end.
