{ Original :

// ************************************************************************
// *
// *	File        : DETECTMV.H
// *
// *	Description : Detection routines for Media Vision cards
// *
// *	Copyright (C) 1993 Otto Chrons
// *
// ************************************************************************

  Conversion :

// ************************************************************************
// *
// *	File        : DETECTMV.PAS
// *
// *	Description : Detection routines for Media Vision cards
// *
// *	Copyright (C) 1993 Jussi Lahdenniemi
// *
// ************************************************************************}

Unit Det_MV;
{$F+}

Interface
Uses MCP;

Function detectMV(sCard:PSoundCard):Integer;

Implementation

Function detectMV(sCard:PSoundCard):Integer; External;

{$L DETECTMV.OBJ}

end.
