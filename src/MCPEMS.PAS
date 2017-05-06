{ -------------------------------------------------------------------------- }
{                                                                            }
{                                 MCPEMS.PAS                                 }
{                                 ----------                                 }
{                                                                            }
{                         (C) 1993 Jussi Lahdenniemi                         }
{         Original C file (C) 1993 Otto Chrons                               }
{                                                                            }
{ MCP EMS handler                                                            }
{                                                                            }
{ -------------------------------------------------------------------------- }

unit mcpems;

interface

function mcpSampleRealaddress(ID:longint;pos:longint):pointer;
procedure mcpEnableVirtualSamples;
procedure mcpDisableVirtualSamples;

implementation
uses emhm;

function mcpSampleRealaddress(ID:longint;pos:longint):pointer;
begin
  mcpSampleRealaddress:=emsLock(ID,0,64000);
end;

procedure mcpEnableVirtualSamples;
begin
  emsSaveState;
end;

procedure mcpDisableVirtualSamples;
begin
  emsRestoreState;
end;

end.
