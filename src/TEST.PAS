{$I dsmi.inc} ,crt;

var module : PModule;
    f      : file;
    sample : TSampleinfo;
    sc     : TSoundCard;

begin
  emsInit(1024,2048);
  atexit(@emsClose);
  if initDSMI(22000,2048,0,@sc)<>0 then halt(1);   { Error }
  if sc.ID<>ID_GUS then mcpStartVoice else gusStartVoice;
  module:=ampLoadModule('c:\tmp\dope.mod',0);
  if module=nil then begin
    writeln('Err: ',moduleError);
    exit;
  end else writeln('Playing');
  cdiSetupChannels(0,module^.channelCount,nil);
  ampPlayModule(module,PM_LOOP);
  readkey;
  ampStopModule;
end.
