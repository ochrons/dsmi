(***************************************************************************

                                  LOADM.PAS
                                  ---------

                          (C) 1993 Jussi Lahdenniemi

ampLoadModule function
Original C version by Otto Chrons

***************************************************************************)

Unit LoadM;
{$I-}

Interface
Uses AMP,Loaders,S3Mload,STMload,MODload,AMFload,_669load,
     MTMload,FARload,Csupport;

Var moduleError:Integer;

Function  ampLoadModule(Name:String;Options:longint):PModule;

Implementation

Function multinum(l:longint):byte;
type
  num=string[2];
var
  s:num;
  b:byte;
  i:integer;
  p:^char;
begin
  s[0]:=#2;
  p:=@l;
  s[1]:=p^;
  inc(longint(p));
  s[2]:=p^;
  val(s,b,i);
  multinum:=b;
end;

Function getType(var f:file; var module:PModule):Integer;
var t  : integer;
    l  : longint;
    id : string;
begin
  t:=0;
  l:=0;
  module^.modType:=MOD_NONE;
  seek(f,0);
  blockread(f,l,4);
  if l=$fe524146 then begin
    module^.modType:=MOD_FAR;
    seek(f,0);
    getType:=module^.modType;
    exit;
  end;
  seek(f,0);
  blockread(f,t,2);
  if t=$6669 then begin
    module^.modType:=MOD_669;
    blockread(f,module^.name,32);
    module^.name[31]:=#0;
  end else begin
  seek(f,0);
  blockread(f,l,4);
  if (l and $ffffff=$004D544D) then  begin
    module^.modType:=MOD_MTM;
    seek(f,0);
    getType:=module^.modType;
    exit;
  end;
  if (l and $ffffff=$00464D41) then begin
    module^.modType:=MOD_AMF;
    blockread(f,module^.name,20);
    module^.name[20]:=#0;
    module^.channelCount:=4;
    move(order4,module^.channelPanning,4);
  end else begin
    seek(f,$2c);
    blockread(f,l,4);
    if l=$4D524353 then begin
      module^.modType:=MOD_S3M;
      seek(f,0);
      blockread(f,module^.name,28);
      module^.name[28]:=#0;
    end else begin
      seek(f,28);
      blockread(f,t,2);
      if t=$021A then begin
        module^.modType:=MOD_STM;
        seek(f,0);
        blockread(f,module^.name,20);
        module^.name[20]:=#0;
        module^.channelCount:=4;
        move(order4,module^.channelPanning,4);
      end else begin
        seek(f,1080);
        blockread(f,l,4);
        if (l=$2E4B2E4D) or (l=$34544C46) or (l=$214B214D) then begin
          module^.modType:=MOD_MOD;
          seek(f,0);
          blockread(f,module^.name,20);
          module^.name[20]:=#0;
          module^.channelCount:=4;
          move(order4,module^.channelPanning,4);
        end else
        if l=$38544C46 then begin
          module^.modType:=MOD_TREK;
          seek(f,0);
          blockread(f,module^.name,20);
          module^.name[20]:=#0;
          module^.channelCount:=8;
          move(order8,module^.channelPanning,8);
        end else
        if l=$4e484336 then begin
          module^.modType:=MOD_MOD;
          seek(f,0);
          blockread(f,module^.name,20);
          module^.name[20]:=#0;
          module^.channelCount:=6;
          move(order6,module^.channelPanning,6);
        end else
        if l=$4e484338 then begin
          module^.modType:=MOD_MOD;
          seek(f,0);
          blockread(f,module^.name,20);
          module^.name[20]:=#0;
          module^.channelCount:=8;
          move(order8,module^.channelPanning,8);
        end else
        if (l and $FFFF0000)=$48430000 then begin
          module^.modType:=MOD_MULTI;
          seek(f,0);
          blockread(f,module^.name,20);
          module^.name[20]:=#0;
          module^.channelCount:=multinum(l);
          move(ordermulti,module^.channelPanning,32);
        end else begin
          module^.modType:=MOD_15;
          seek(f,0);
          blockread(f,module^.name,20);
          module^.name[20]:=#0;
          module^.channelCount:=4;
          move(order4,module^.channelPanning,4);
        end;
      end;
    end;
  end;
  end;
  getType:=module^.modType;
end;

Function ampLoadModule;
Var f       : file;
    a,b,t,i : integer;
    module  : PModule;
    mem1    : Longint;
begin
  loadOptions:=options;
  module:=malloc(sizeof(TModule));
  if module=nil then begin
    moduleError:=-1;
    ampLoadModule:=nil;
    exit;
  end;
  fillchar(module^,sizeof(TModule),0);
  assign(f,name);
  reset(f,1);
  if IOresult<>0 then begin
    moduleError:=-2;
    ampLoadModule:=nil;
    exit;
  end;
  a:=getType(f,module);
  b:=-3;
  if a=MOD_669 then b:=load669(f,module) else
  if a=MOD_S3M then b:=loadS3M(f,module) else
  if a=MOD_STM then b:=loadSTM(f,module) else
  if (a=MOD_MOD) or (a=MOD_TREK) or (a=MOD_15) or (a=MOD_MULTI) then b:=loadMOD(f,module) else
  if a=MOD_AMF then b:=loadAMF(f,module) else
  if a=MOD_MTM then b:=loadMTM(f,module) else
  if a=MOD_FAR then b:=loadFAR(f,module);
  moduleError:=b;
  if (b=MERR_NONE) or (b=MERR_CORRUPT) then module^.filesize:=filesize(f) else
    ampFreeModule(module);
  close(f);
  ampLoadModule:=module;
end;

end.

