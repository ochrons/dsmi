(****************************************************************************

                                 AMFSAVE.PAS
                                 -----------

                          (C) 1993 Jussi Lahdenniemi

Saves a module in AMF format

****************************************************************************)

unit amfSave;

interface
uses amp;

Function ampSaveAMF(name:string;module:PModule):Integer;

implementation

Function ampSaveAMF;
begin
  ampSaveAMF:=MERR_NONE;
end;

end.
