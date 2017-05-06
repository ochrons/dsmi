(****************************************************************************

                                 DET_SB.PAS
                                 ----------

                          (C) 1993 Jussi Lahdenniemi

Turbo/Borland pascal unit header file for SB detection routines.
Original C header by Otto Chrons

****************************************************************************)

unit det_SB; { (C) 1993 Jussi Lahdenniemi }

interface
uses MCP;

Function  detectSBHW(SCard:PSoundCard):Integer;
Function  detectSBproHW(SCard:PSoundCard):Integer;
Function  detectSB16HW(SCard:PSoundCard):Integer;

implementation

{$L detectSB.OBJ}

Function  detectSBHW(SCard:PSoundCard):Integer; external;
Function  detectSBproHW(SCard:PSoundCard):Integer; external;
Function  detectSB16HW(SCard:PSoundCard):Integer; external;

end.
