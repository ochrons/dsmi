(****************************************************************************

                                SDI__PAS.PAS
                                ------------

                          (C) 1993 Jussi Lahdenniemi

Turbo/Borland pascal unit header file for SDI_PAS.
Original C header by Otto Chrons

****************************************************************************)

Unit SDI__PAS;
{$F+}

Interface
Uses MCP;

Procedure SDI_PAS;

Implementation

Procedure SDI_PAS; External;

{$L SDI_PAS.OBJ}
{$L DMAPROCS.OBJ}

End.
