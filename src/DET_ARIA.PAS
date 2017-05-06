(****************************************************************************

                                 DET_ARIA.PAS
                                 ------------

                          (C) 1993 Jussi Lahdenniemi

Turbo/Borland pascal unit header file for ARIA detection routines.
Original C header by Otto Chrons

****************************************************************************)

Unit Det_Aria;
{$F+}

Interface
Uses MCP;

Function detectARIA(sCard:PSoundCard):Integer;

Implementation

Function detectARIA(sCard:PSoundCard):Integer; External;

{$L Detaria.obj}

end.
