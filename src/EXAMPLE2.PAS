(****************************************************************************
                                 EXAMPLE2.PAS
                                 ------------

                          (C) 1993 Jussi Lahdenniemi

Tutorial example program #2 for DSMI

****************************************************************************)

{$I dsmi.inc} ,crt;

var sample : TSampleInfo;
    f      : file;
    sc     : TSoundCard;

begin
  if initDSMI(22000,2048,0,@sc)<>0 then halt(1);   { Error }
  if sc.ID<>ID_GUS then mcpStartVoice else gusStartVoice;
  cdiSetupChannels(0,3,nil);
  assign(f,'CHORUS');
  reset(f,1);
  sample.sample:=malloc(fileSize(f));
  if sample.sample=nil then halt(1);
  blockread(f,sample.sample^,filesize(f));
  with sample do begin
    length:=filesize(f);
    loopstart:=0;
    loopend:=0;   { No looping }
    mode:=0;
    sampleID:=0;
  end;
  cdiDownloadSample(0,sample.sample,sample.sample,sample.length);
  cdiSetInstrument(0,@sample);
  cdiSetInstrument(1,@sample);
  cdiSetInstrument(2,@sample);
  cdiPlayNote(0,8800,32);   { Play at 8800 Hz }
  cdiPlayNote(1,11087,32);
  cdiPlayNote(2,13185,32);
  readkey;
  cdiStopNote(0);
  cdiStopNote(1);
  cdiStopNote(2);
end.
