(****************************************************************************

                                 SDI__SB16.PAS
                                 -------------

                          (C) 1993 Jussi Lahdenniemi

Turbo/Borland pascal unit header file for SDI_SB16.
Original C header by Otto Chrons

****************************************************************************)

Unit SDI__SB16;
{$F+}

Interface
Uses MCP;

Procedure SDI_SB16;

Implementation

Procedure SDI_SB16; External;

{$L SDI_SB16.OBJ}
{$L DMAPROCS.OBJ}

End.
