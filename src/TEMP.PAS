(****************************************************************************

                                 EXAMPLE3.PAS
                                 ------------

                          (C) 1993 Jussi Lahdenniemi

Example program #3 for DSMI tutorial

****************************************************************************)

{$I dsmi.inc} ,crt;

var module : PModule;
begin
  module:=ampLoadModule(paramstr(1),0);
  if initDSMI(22000,2048,0)<>0 then exit;  { Error }
  mcpStartVoice;
  writeln(module=nil);
  mcpOpenChannels(module^.channelCount,volume_Linear,nil);
  ampPlayModule(module,PM_Loop);   { Play looping }
  readkey;
  ampStopModule;
end.

