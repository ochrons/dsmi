(***************************************************************************

                                SDI__DAC.PAS
                                ------------

                          (C) 1993 Jussi Lahdenniemi

Turbo/Borland pascal unit header file for SDI_DAC.
Original C header by Otto Chrons

***************************************************************************)

unit SDI__DAC;

{$IFDEF DPMI}
'DAC does not work properly in the protected mode.'
{$ENDIF}

interface

procedure SDI_DAC;
procedure setDACTimer(rate:Word);

implementation
uses mcp;

procedure SDI_DAC; external;
procedure setDACTimer(rate:Word); external;
{$L SDI_DAC.OBJ}

end.
