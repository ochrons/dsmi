(****************************************************************************

                                 EXAMPLE1.PAS
                                 ------------

                          (C) 1993 Jussi Lahdenniemi

Example program #1 for DSMI tutorial

****************************************************************************)

{$I dsmi.inc} ,crt;           { For the readkey }

var sample : TSampleInfo;
    sc     : TSoundCard;
    p      : pointer;
    w      : word;

begin
  if initDSMI(22000,2048,0,@sc)<>0 then exit;  { Error }
  if sc.ID<>ID_GUS then mcpStartVoice else gusStartVoice;
  cdiSetupChannels(0,2,nil);
  p:=malloc(5500);
  with sample do begin
    sample:=ptr(0,1);         { Pointer to sampledata }
    move(sample^,p^,5500);

{    sample:=malloc(5500);
    p:=sample;
    fillchar(sample^,5500,0);}

    length:=5500;             { Length of sample }
    loopstart:=0;
    loopend:=5500;               { looping }
    mode:=0;
    sampleID:=0;
  end;
  cdiDownloadSample(0,sample.sample,sample.sample,sample.length);
  cdiSetInstrument(0,@sample);
  cdiPlayNote(0,8800,32);    { Play at 8800Hz with }
                               { half volume }
  readkey;                     { Wait for keypress }
  cdiStopNote(0);           { Stop voice }
  for w:=0 to 5499 do if mem[seg(p^):ofs(p^)+w]<>mem[0:1+w] then writeln(w);
end.

