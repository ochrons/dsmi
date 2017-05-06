Unit SDI__WSS; { (C) 1993 Jussi Lahdenniemi,
                 Original C version (C) 1993 Otto Chrons

                 Windows Sound System SDI }

Interface

procedure SDI_WSS;

Implementation
uses mcp;

procedure SDI_WSS; External;

{$L SDI_WSS.OBJ}
{$L DMAPROCS.OBJ}

end.
