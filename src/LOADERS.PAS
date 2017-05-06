(***************************************************************************

                                 LOADERS.PAS
                                 -----------

                          (C) 1993 Jussi Lahdenniemi

ampFreeModule function and order constants

***************************************************************************)

Unit Loaders;

Interface
uses AMP,CSupport;

Var LoadOptions : Integer;

const order4:array[0..3] of shortint = (PAN_Left,PAN_Right,PAN_Right,PAN_Left);
      order6:array[0..5] of shortint = (PAN_Left,PAN_Right,PAN_Right,PAN_Left,PAN_Left,PAN_Right);
      order8:array[0..7] of shortint = (PAN_Left,PAN_Right,PAN_Right,PAN_Left,PAN_Left,PAN_Right,PAN_Right,PAN_Left);
      ordermulti:array[0..31] of shortint = (PAN_Left,PAN_Right,PAN_Right,PAN_Left,PAN_Left,PAN_Right,PAN_Right,PAN_Left,
          PAN_Left,PAN_Right,PAN_Right,PAN_Left,PAN_Left,PAN_Right,PAN_Right,PAN_Left,
          PAN_Left,PAN_Right,PAN_Right,PAN_Left,PAN_Left,PAN_Right,PAN_Right,PAN_Left,
          PAN_Left,PAN_Right,PAN_Right,PAN_Left,PAN_Left,PAN_Right,PAN_Right,PAN_Left);

Procedure ampFreeModule(var module:PModule);

Implementation

Procedure ampFreeModule;
var t,i   : integer;
    ptr   : pointer;
Begin
  if module=nil then exit;
  if module^.modType<>0 then begin
    if module^.patterns<>nil then free(pointer(module^.patterns));
    if module^.instruments<>nil then begin
      if module^.instrumentCount>0 then
      for t:=0 to module^.instrumentCount-1 do begin
        ptr:=module^.instruments^[t].sample;
        if ptr<>nil then begin
          if t>0 then
            for i:=0 to t-1 do
              if ptr=module^.instruments^[i].sample then begin ptr:=nil; i:=t-1 end;
          if ptr<>nil then free(ptr);
        end;
      end;
      free(pointer(module^.instruments));
    end;
    if module^.tracks<>nil then begin
      for t:=1 to module^.trackCount do begin
        ptr:=module^.tracks^[t];
        if t>1 then
        for i:=1 to t-1 do
          if ptr=module^.tracks^[i] then begin
            ptr:=nil;
            i:=t-1;
          end;
        if ptr<>nil then free(ptr);
      end;
      free(pointer(module^.tracks));
    end;
  end;
  free(module);
  module:=nil;
end;

end.
