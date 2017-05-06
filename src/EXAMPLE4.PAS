(****************************************************************************

                                 EXAMPLE4.PAS
                                 ------------

                          (C) 1993 Jussi Lahdenniemi

Example program #4 for DSMI tutorial

****************************************************************************)

{$f+}

{$I dsmi.inc} ,crt;

function loadAMFasm(var f:file;module:PModule):integer; external;
{$l amfload.obj}

procedure seekf(var f:file;pl:longint);
begin
  seek(f,pl);
end;

procedure blockrd(var f:file;var place;l:word);
begin
  blockread(f,place,l);
end;

function mallocf(w:word):pointer;
begin
  mallocf:=malloc(w);
end;

procedure freef(p:pointer);
begin
  free(p);
end;

var module : PModule;
    f      : file;
    sample : TSampleinfo;
    sc     : TSoundCard;

begin
  if initDSMI(22000,2048,0,@sc)<>0 then halt(1);   { Error }
  if sc.ID<>ID_GUS then mcpStartVoice else gusStartVoice;
  cdiSetupChannels(0,8,nil);
  module:=malloc(sizeof(TModule));
  assign(f,'d:\mod\dsmi_xmp.amf');
  reset(f,1);
  writeln(loadAMFasm(f,module));
  ampPlayModule(module,PM_LOOP);
  readkey;
  ampStopModule;
end.
