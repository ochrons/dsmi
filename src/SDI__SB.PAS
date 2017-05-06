(****************************************************************************

                                 SDI__SB.PAS
                                 -----------

                          (C) 1993 Jussi Lahdenniemi

Turbo/Borland pascal unit header file for SDI_SB.
Original C header by Otto Chrons

****************************************************************************)

Unit SDI__SB;
{$F+}

Interface
Uses MCP;

Procedure SDI_SB;
Procedure SDI_SBPro;

Implementation

{$L SDI_SB.OBJ}
{$L DMAPROCS.OBJ}

Procedure SDI_SB; External;
Procedure SDI_SBPro; External;

End.
