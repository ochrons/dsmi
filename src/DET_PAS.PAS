(****************************************************************************

                                 DET_PAS.PAS
                                 -----------

                          (C) 1993 Jussi Lahdenniemi

Turbo/Borland pascal unit header file for PAS detection routines.
Original C header by Otto Chrons

****************************************************************************)

Unit Det_Pas;
{$F+}

Interface
Uses MCP;

Function detectPAS(sCard:PSoundCard):Integer;

Implementation

Function detectPAS(sCard:PSoundCard):Integer; External;

{$L Detpas.obj}

end.
